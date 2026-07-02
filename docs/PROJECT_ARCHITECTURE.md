# Project architecture

## Design intent

This system is deliberately small enough for one engineer to understand, but
it preserves real delivery boundaries: Terraform owns AWS resources; cloud-init
and shell automation own host prerequisites; kubeadm owns cluster bootstrap;
Kubernetes manifests own the application; Jenkins owns delivery orchestration;
Helm and custom resources own monitoring. Each layer has a clear verification
command and can be replaced without rewriting the others.

## Terraform workflow

```text
configuration --> terraform init --> validate --> plan --> approval --> apply
      ^                                                        |
      |                                                        v
 source control <-- reviewed change <-- outputs/state <-- AWS APIs
                                                               |
                                                        destroy when done
```

Terraform state contains resource identifiers and may contain sensitive data.
For team use, migrate it to an encrypted S3 backend with versioning, DynamoDB
state locking where applicable, restrictive IAM, and audit logging. This lab
keeps backend selection out of the repository so it does not invent account-
specific bucket names.

## Network and trust boundaries

The VPC uses one public subnet because the exercise explicitly requires all
four instances in the same subnet and security group. The Internet gateway and
default route make package installation, GitHub, and Docker Hub reachable.
Every instance receives a public IP. In production, workers, control planes,
and Jenkins agents should normally live in private subnets across availability
zones, use NAT/VPC endpoints for egress, and expose applications through an
authenticated TLS load balancer.

The one security group implements two classes of trust:

- Explicit ingress from administrator or web CIDRs for the exact public ports.
- An all-protocol self-reference for members of the group. This is broad inside
  the cluster but not Internet-accessible and supports Calico encapsulation,
  health checks, Kubernetes control-plane ports, and NodePorts.

The IAM instance role includes only `AmazonSSMManagedInstanceCore`. It allows
managed-session access without distributing AWS access keys to servers. The
application does not call AWS APIs and receives no IAM credentials.

## Kubernetes control flow

```text
Desired Deployment --> API server --> etcd
                            |
               controller manager creates ReplicaSet
                            |
                 scheduler selects worker nodes
                            |
                kubelet asks containerd to run pods
                            |
                   Calico wires pod networking
```

The control plane is intentionally single-node, which means it is not highly
available. etcd data and the API endpoint are single points of failure. A
production self-managed design needs three or five control-plane/etcd members,
an API load balancer, tested etcd snapshots, PodDisruptionBudgets, and multiple
availability zones. A managed service such as EKS reduces this operational
burden.

## Application runtime

The Dockerfile resolves Python dependencies in a builder stage and copies only
the virtual environment and source to the runtime stage. The runtime process is
Gunicorn under UID 10001. Kubernetes further requires non-root execution,
RuntimeDefault seccomp, no capabilities, no privilege escalation, and a read-
only filesystem. The app writes no local state.

Readiness removes an unhealthy pod from Service endpoints; liveness restarts a
stuck process. Resource requests guide scheduling and limits contain accidental
resource consumption. Two replicas and `maxUnavailable: 0` preserve capacity
during a routine update, while `maxSurge: 1` allows one replacement at a time.

## Delivery trust chain

GitHub authenticates source changes and delivers a webhook. Jenkins obtains
source, uses a scoped Docker Hub token to push images, and uses a namespaced
Kubernetes identity to deploy. Docker Hub holds the immutable numbered image.
Kubernetes records the image in each ReplicaSet, so rollout history is
auditable and rollback does not depend on a moving `latest` tag.

For a production supply chain, add signed commits, branch protection, pull-
request reviews, unit and integration tests, dependency/image scanning, SBOM
generation, image signing and admission verification, isolated ephemeral build
agents, and provenance attestations.

## Monitoring data flow

Prometheus discovers operator-generated scrape configurations. node-exporter
describes operating-system resources; kube-state-metrics translates Kubernetes
object state; Kubernetes components and kubelets expose control-plane and
container metrics. Prometheus stores time series and evaluates rules. Grafana
queries Prometheus for exploration and dashboards. Alertmanager handles alert
delivery policy.

The included storage uses a single PVC and is educational. Production requires
an appropriate StorageClass, capacity and retention planning, backups or remote
write, replicas or a long-term system such as Thanos/Mimir, and controlled
cardinality.

## Ownership matrix

| Artifact | Owner/reconciler | Drift response |
|---|---|---|
| VPC, EC2, IAM, SG | Terraform | plan and reviewed apply |
| OS prerequisites | cloud-init and shell automation | rerun idempotent scripts |
| control-plane state | kubeadm/Kubernetes | cluster operations |
| Flask resources | kubectl/Jenkins | next pipeline reconciles |
| monitoring release | Helm/Operator | `helm upgrade` and reconciliation |
| dashboards | Grafana sidecar | ConfigMap is reloaded |
| alert rules | Prometheus Operator | PrometheusRule is reconciled |
