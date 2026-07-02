# Installation and configuration runbook

## 1. Account and workstation preparation

Use a sandbox AWS account with MFA, a cost budget, and a role dedicated to the
lab. Confirm identity with `aws sts get-caller-identity`; do not continue if the
account or role is unexpected. Install Terraform 1.7+, Git, AWS CLI, `kubectl`,
and an SSH client. Create an EC2 key pair only if SSH is necessary.

Clone the repository, copy `terraform.tfvars.example` to the ignored
`terraform.tfvars`, and replace the TEST-NET address with the administrator's
public `/32`. Do not commit that file. Run format, validation, and a saved plan;
read every planned ingress rule, instance type, and tag before applying.

## 2. Host bootstrap

Terraform cloud-init performs noninteractive package setup. On every instance:

```bash
sudo cloud-init status --wait
sudo tail -n 100 /var/log/cloud-init-output.log
cat /etc/demoproject/role
```

Kubernetes nodes must show containerd active, swap disabled, overlay and
br_netfilter loaded, IP forwarding enabled, and kubelet installed:

```bash
systemctl is-active containerd
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
kubeadm version
```

## 3. Cluster bootstrap

Run `sudo bash bash/install_kubernetes.sh` on the control plane. It uses the
first private address, pod CIDR `192.168.0.0/16`, and Calico. Save the generated
join command only for the few minutes required to join nodes; it is a bearer
credential. Run `join_worker.sh` on both workers with those generated values.

After both join, wait for Ready and inspect components:

```bash
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

The final command should normally be empty. Confirm a pod can resolve DNS and
reach an external HTTPS site in accordance with organizational policy.

## 4. Jenkins Kubernetes identity

Do not give Jenkins the control-plane administrator kubeconfig. Create a
namespaced service account and least-privilege Role on the control plane:

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl -n demo create serviceaccount jenkins-deployer
kubectl -n demo create role jenkins-deployer \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments,replicasets,pods,services
kubectl -n demo create rolebinding jenkins-deployer \
  --role=jenkins-deployer --serviceaccount=demo:jenkins-deployer
kubectl create clusterrole jenkins-node-reader \
  --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding jenkins-node-reader \
  --clusterrole=jenkins-node-reader --serviceaccount=demo:jenkins-deployer
kubectl -n demo create token jenkins-deployer --duration=8760h
```

Build a kubeconfig using the cluster server, cluster CA from
`/etc/kubernetes/pki/ca.crt`, and generated token. Store it as a Jenkins Secret
file named `kubernetes-kubeconfig`, mode 0600, and delete any temporary copy.
Tokens with a one-year duration need a documented rotation date. For stricter
environments, use short-lived workload identity or an external delivery agent.

Validate the identity before running a pipeline:

```bash
KUBECONFIG=restricted-kubeconfig kubectl auth can-i patch deployments -n demo
KUBECONFIG=restricted-kubeconfig kubectl auth can-i delete nodes
```

The first answer is `yes`; the second is `no`.

## 5. Jenkins plugins and credentials

Unlock Jenkins, create a named administrator, disable anonymous permissions,
and install the plugins listed in `jenkins/plugins.txt`. Configure the Jenkins
URL exactly as external webhooks see it. Add the Docker Hub token as a
username/password credential with ID `dockerhub-credentials` and add the
kubeconfig Secret file with ID `kubernetes-kubeconfig`.

Create a Pipeline from SCM pointing to `jenkins/Jenkinsfile`. A private
repository requires a fine-grained GitHub credential. Enable the GitHub hook
trigger. Send a test webhook and confirm a 2xx delivery before debugging the
pipeline itself.

## 6. Registry and image validation

Before Jenkins, validate the build locally without publishing secrets:

```bash
docker build --tag demoproject/flask-app:local application
docker run --rm -p 8080:8080 demoproject/flask-app:local
curl -fsS http://127.0.0.1:8080/health
docker image inspect demoproject/flask-app:local --format '{{.Config.User}}'
```

The final command reports UID `10001`. Stop the foreground container with
Ctrl-C. Jenkins then publishes both the build number and latest tag. Kubernetes
is explicitly set to the numbered tag.

## 7. Monitoring

Run `bash monitoring/helm_install.sh` with the administrator kubeconfig. The
first install can take several minutes while CRDs and images settle. Confirm
every pod is Ready, inspect Prometheus targets, and evaluate `up`. Use local
port-forwards unless exact monitoring NodePorts have been approved in the SG.

Change Grafana's initial password immediately. In production, pass it through
an existing Kubernetes Secret or external secret provider rather than storing
it in values. Configure Alertmanager receivers through a Secret and test the
route during a maintenance window.

## 8. Acceptance checklist

- Terraform plan is clean immediately after apply.
- Four EC2 instances are SSM managed and have encrypted volumes/IMDSv2.
- Three Kubernetes nodes are Ready and system pods are healthy.
- Two Flask replicas are available on different workers when capacity allows.
- `/`, `/health`, and `/version` return expected content.
- A GitHub push starts Jenkins and publishes a numbered image.
- Rollout history names that numbered image and completes without downtime.
- Prometheus targets are up and the custom dashboard has current data.
- All five alert rules are loaded and a controlled test reaches its receiver.
- `terraform destroy` is scheduled when the exercise ends.

