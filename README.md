# DEMO Project 0 — Script-Based Setup

This is the primary setup guide for `demoproject_devops_project 0`. It provisions
four Amazon Linux 2023 EC2 instances with Terraform and uses the repository's
shell scripts to build a kubeadm Kubernetes cluster, configure Jenkins, deploy a
Flask application through CI/CD, and install Prometheus and Grafana.

For a setup that does not invoke repository shell scripts, use
[README_MANUAL_SETUP.md](README_MANUAL_SETUP.md).

## Architecture

```text
Git push --> GitHub webhook --> Jenkins --> Docker build --> Docker Hub
                                  |
                                  v
                         Kubernetes API :6443
                                  |
               +------------------+------------------+
               |                                     |
       k8s-worker1                            k8s-worker2
       Flask replica                         Flask replica
       node-exporter                         node-exporter
               +------------------+------------------+
                                  |
                    Prometheus --> Grafana
                          |
                     Alertmanager
```

Terraform creates:

- One VPC and one public subnet
- One shared security group with self-referenced cluster traffic
- One `k8s-control-plane` EC2 instance
- Two workers: `k8s-worker1` and `k8s-worker2`
- One `jenkins-server` EC2 instance
- Encrypted gp3 root volumes and IMDSv2-only metadata
- An EC2 IAM role for Systems Manager access

All instances use the current official Amazon Linux 2023 x86_64 AMI resolved
from the AWS public Systems Manager parameter.

## Repository layout

```text
demoproject_devops_project2/
├── application/                 Flask source and Docker image definition
├── bash/                        Amazon Linux setup and cleanup scripts
├── docs/                        Architecture, CI/CD, monitoring, troubleshooting
├── jenkins/                     Jenkinsfile, plugin list, pipeline guide
├── kubernetes/                  Namespace, Deployment, NodePort Service
├── monitoring/                  Helm values, dashboard, alerts, PromQL
├── terraform/                   AWS infrastructure and cloud-init baseline
├── README.md                    Script-based setup (this guide)
└── README_MANUAL_SETUP.md       Fully manual setup
```

## Prerequisites

Install on the administrator workstation:

- AWS CLI authenticated to a sandbox AWS account
- Terraform 1.7 or later
- Git
- `jq`
- An EC2 key pair when SSH is required
- GitHub and Docker Hub accounts

The Docker Hub account must have write access to
`demoproject/flask-app`. This project creates billable AWS resources.

Confirm the intended AWS identity before provisioning:

```bash
aws sts get-caller-identity
```

## Step 1 — Configure Terraform

```bash
cd demoproject_devops_project2/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Replace the documentation address in `admin_cidr_blocks` with the trusted
  administrator public IP followed by `/32`.
- Set `key_name` to an existing EC2 key pair, or set it to `null` when using
  Systems Manager exclusively.
- Keep `kubernetes_version = "1.36"` so every node uses the same minor release.
- Review instance sizes and root-volume capacity.

Never commit `terraform.tfvars`, private keys, passwords, or tokens.

## Step 2 — Provision AWS infrastructure

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Terraform installs only a small Amazon Linux baseline, sets hostnames, and
writes the node role to `/etc/demoproject/role`. Kubernetes and Jenkins are
installed by the following scripts.

Capture the outputs:

```bash
CONTROL_PLANE_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-control-plane"]')"
WORKER1_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-worker1"]')"
WORKER2_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-worker2"]')"
JENKINS_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["jenkins-server"]')"
CONTROL_PLANE_PRIVATE_IP="$(terraform output -json private_ips | jq -r '.["k8s-control-plane"]')"
```

Wait for the baseline on every server:

```bash
sudo cloud-init status --wait
test -f /var/lib/cloud/instance/bootstrap-complete
cat /etc/demoproject/role
```

Use SSM Session Manager where possible. The SSH login user is `ec2-user`:

```bash
ssh ec2-user@"${CONTROL_PLANE_PUBLIC_IP}"
```

## Step 3 — Put the repository on each server

Create a GitHub repository, push this project, and clone it on every EC2
instance. With GitHub CLI on the workstation:

```bash
GITHUB_OWNER="$(gh api user --jq .login)"
gh repo create "${GITHUB_OWNER}/demoproject_devops_project2" \
  --private --source=. --remote=origin --push
```

On each EC2 server, clone using an approved SSH deploy key or scoped GitHub
credential, then enter the repository:

```bash
git clone "https://github.com/${GITHUB_OWNER}/demoproject_devops_project2.git"
cd demoproject_devops_project2
```

For a private repository, do not place a token directly in the clone URL or
shell history.

## Step 4 — Initialize the Kubernetes control plane

On `k8s-control-plane`:

```bash
cd demoproject_devops_project2
sudo bash bash/install_kubernetes.sh
```

The script:

1. Verifies Amazon Linux 2023.
2. Disables swap.
3. Loads overlay and bridge-netfilter modules.
4. Enables IP forwarding.
5. sets SELinux to permissive for kubeadm compatibility.
6. Installs and configures containerd with systemd cgroups.
7. Installs kubeadm, kubelet, and kubectl from `pkgs.k8s.io`.
8. Initializes the control plane with pod CIDR `192.168.0.0/16`.
9. Installs Calico.
10. Saves a two-hour join command in `/home/ec2-user/join-command.sh`.

Display the join command on the control plane:

```bash
cat /home/ec2-user/join-command.sh
```

Treat its token as a temporary secret.

## Step 5 — Join both workers

The generated command contains the private control-plane IP, token, and CA
discovery hash. On each worker, pass those three values to the worker script:

```bash
sudo bash bash/join_worker.sh \
  "${CONTROL_PLANE_PRIVATE_IP}" \
  "${KUBEADM_TOKEN}" \
  "${DISCOVERY_HASH}"
```

The worker script performs the complete Amazon Linux Kubernetes-node setup and
then runs `kubeadm join`. Set the variables from the generated join command in
the current protected shell; do not store them in Git.

Verify from the control plane:

```bash
kubectl get nodes -o wide
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl -n kube-system get pods
```

All three nodes must report `Ready`.

## Step 6 — Install Docker and Jenkins

On `jenkins-server`:

```bash
cd demoproject_devops_project2
sudo bash bash/configure_docker.sh
sudo bash bash/install_jenkins.sh
sudo systemctl restart jenkins
```

The scripts install the Amazon Linux Docker package, Amazon Corretto 21,
Jenkins LTS from its signed RPM repository, and kubectl. They add Jenkins to the
Docker group.

Verify:

```bash
systemctl is-active docker
systemctl is-active jenkins
java -version
kubectl version --client
id jenkins
sudo -u jenkins docker version
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open the Terraform `jenkins_url` output, unlock Jenkins, create a named
administrator, disable anonymous access, and install the plugins listed in
`jenkins/plugins.txt`.

## Step 7 — Give Jenkins restricted Kubernetes access

On the control plane:

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl -n demo create serviceaccount jenkins-deployer
kubectl -n demo create role jenkins-deployer \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments,replicasets,pods,services
kubectl -n demo create rolebinding jenkins-deployer \
  --role=jenkins-deployer \
  --serviceaccount=demo:jenkins-deployer
kubectl create clusterrole jenkins-node-reader \
  --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding jenkins-node-reader \
  --clusterrole=jenkins-node-reader \
  --serviceaccount=demo:jenkins-deployer
```

Generate a service-account token and create a kubeconfig using the API server,
cluster CA, and token. The exact secure procedure is documented in
`docs/INSTALLATION_AND_CONFIGURATION.md`. Store the resulting file in Jenkins
as a **Secret file** credential named `kubernetes-kubeconfig`.

Validate before deleting the temporary kubeconfig:

```bash
KUBECONFIG=/tmp/jenkins-kubeconfig kubectl auth can-i patch deployments -n demo
KUBECONFIG=/tmp/jenkins-kubeconfig kubectl auth can-i delete nodes
```

Expected answers are `yes` and `no`.

## Step 8 — Add Jenkins credentials

In **Manage Jenkins → Credentials**, create:

| ID | Type | Content |
|---|---|---|
| `dockerhub-credentials` | Username/password | Docker Hub username and scoped access token |
| `kubernetes-kubeconfig` | Secret file | Restricted Jenkins kubeconfig |
| SCM credential | SSH key or token | Only when the GitHub repository is private |

Never use a personal account password or control-plane administrator kubeconfig.

## Step 9 — Create the Jenkins Pipeline

1. Create a new **Pipeline** job.
2. Select **Pipeline script from SCM**.
3. Select **Git** and enter the repository URL.
4. Select the SCM credential when private.
5. Set branch to `main`.
6. Set script path to `jenkins/Jenkinsfile`.
7. Enable **GitHub hook trigger for GITScm polling**.
8. Save the job.

The pipeline checks out source, builds `demoproject/flask-app`, publishes
`BUILD_NUMBER` and `latest`, verifies the cluster, applies the manifests,
performs a rolling update, waits for readiness, and prints pods, Deployment,
and Service state.

## Step 10 — Configure the GitHub webhook

In GitHub repository **Settings → Webhooks → Add webhook**:

- Payload URL: the Terraform Jenkins URL followed by `/github-webhook/`
- Content type: `application/json`
- Secret: a generated high-entropy webhook secret
- Events: push events
- Active: enabled

Terraform reads GitHub's published webhook source ranges and admits them to
Jenkins port 8080. Use TLS and a reverse proxy outside a controlled lab.

## Step 11 — Run the first deployment

Push a change to `main` or select **Build Now** in Jenkins. Watch each stage.
After success, verify on the control plane:

```bash
kubectl -n demo rollout status deployment/flask-app
kubectl -n demo get pods -o wide
kubectl -n demo get deployment flask-app
kubectl -n demo get service flask-app
kubectl -n demo rollout history deployment/flask-app
```

From an allowed client:

```bash
APPLICATION_URL="$(terraform output -raw application_url)"
curl -fsS "${APPLICATION_URL}/health"
curl -fsS "${APPLICATION_URL}/version"
```

The browser page displays **Welcome to DEMO Project**, **Running on
Kubernetes**, and the deployed build version.

## Step 12 — Install monitoring

On the control plane:

```bash
cd demoproject_devops_project2
bash monitoring/helm_install.sh
```

The script installs Helm when absent, creates a generated Grafana administrator
Secret, installs `kube-prometheus-stack`, and applies the repository alert rules
and Grafana dashboard.

Verify:

```bash
helm -n monitoring list
kubectl -n monitoring get pods
kubectl -n monitoring get prometheus,alertmanager,prometheusrule
kubectl -n monitoring get servicemonitors
```

Use port forwarding for administrative access:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Run each port-forward in a separate terminal. Retrieve the Grafana password:

```bash
kubectl -n monitoring get secret grafana-admin-credentials \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

The included dashboard covers nodes, pods, deployments, namespaces, CPU,
memory, filesystem, and network. Alert rules cover CPU above 80%, memory above
85%, disk above 90%, node down, and frequent pod restarts.

## Step 13 — Acceptance checklist

- Terraform reports four Amazon Linux 2023 instances.
- All three Kubernetes nodes are `Ready`.
- Calico and CoreDNS pods are healthy.
- The Flask Deployment reports `2/2` available replicas.
- NodePort 30080 serves `/`, `/health`, and `/version`.
- A GitHub push triggers Jenkins.
- Docker Hub contains the numbered build image.
- Kubernetes uses the numbered image rather than relying on `latest`.
- Prometheus targets are up.
- Grafana loads the custom dashboard.
- Prometheus loads all project alert rules.

## Step 14 — Troubleshooting

```bash
# Cloud baseline
sudo cloud-init status --long
sudo tail -n 100 /var/log/cloud-init-output.log

# Kubernetes node
sudo journalctl -u kubelet --since '20 minutes ago' --no-pager
sudo journalctl -u containerd --since '20 minutes ago' --no-pager
kubectl describe node k8s-worker1
kubectl -n kube-system get pods -o wide

# Application
kubectl -n demo describe deployment flask-app
kubectl -n demo get events --sort-by=.lastTimestamp
kubectl -n demo logs deployment/flask-app --tail=100

# Jenkins
sudo journalctl -u jenkins --since '20 minutes ago' --no-pager
sudo -u jenkins docker version

# Monitoring
kubectl -n monitoring get pods
kubectl -n monitoring logs deployment/kube-prometheus-stack-operator --tail=100
```

See `docs/TROUBLESHOOTING.md` for detailed decision trees.

## Step 15 — Cleanup

Preview cleanup first:

```bash
bash bash/cleanup_project.sh
```

After reviewing the Kubernetes actions and Terraform destroy plan:

```bash
bash bash/cleanup_project.sh --execute
```

The script removes the monitoring release and project namespaces before
destroying Terraform-managed AWS infrastructure. It deliberately preserves the
GitHub repository, Docker Hub images, credentials, Terraform state, and local
source files.

## Additional documentation

- [Manual setup](README_MANUAL_SETUP.md)
- [Architecture](docs/PROJECT_ARCHITECTURE.md)
- [CI/CD workflow](docs/CI_CD_WORKFLOW.md)
- [Monitoring](docs/MONITORING_GUIDE.md)
- [PromQL examples](monitoring/prometheus_queries.md)
- [Alerting](monitoring/alerts.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

This repository is licensed under the MIT License.
