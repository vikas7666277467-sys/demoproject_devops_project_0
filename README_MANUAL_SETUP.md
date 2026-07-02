# DEMO Project — 0 With manual setup 

This guide configures the complete project step by step without invoking any
repository `.sh` file. It is intended for engineers who want to understand each
Linux, containerd, Kubernetes, Jenkins, Docker, Helm, and monitoring operation.

For the automated shell-script workflow, use [README.md](README.md).

## Scope

The guide uses Amazon Linux 2023 for all four EC2 instances:

- `k8s-control-plane`
- `k8s-worker1`
- `k8s-worker2`
- `jenkins-server`

Terraform still provisions AWS infrastructure and applies a minimal cloud-init
baseline. Every platform component is installed manually below.

## Step 1 — Provision the EC2 infrastructure

On the administrator workstation:

```bash
cd demoproject_devops_project2/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with the administrator `/32`, an existing EC2 key-pair
name when SSH is used, and the required instance sizes. Keep
`kubernetes_version = "1.36"`.

```bash
aws sts get-caller-identity
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Capture addresses:

```bash
CONTROL_PLANE_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-control-plane"]')"
WORKER1_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-worker1"]')"
WORKER2_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["k8s-worker2"]')"
JENKINS_PUBLIC_IP="$(terraform output -json public_ips | jq -r '.["jenkins-server"]')"
CONTROL_PLANE_PRIVATE_IP="$(terraform output -json private_ips | jq -r '.["k8s-control-plane"]')"
```

The login account is `ec2-user`. Prefer SSM Session Manager; an SSH connection
has this form:

```bash
ssh ec2-user@"${CONTROL_PLANE_PUBLIC_IP}"
```

On every server, wait for the Terraform baseline:

```bash
sudo cloud-init status --wait
test -f /var/lib/cloud/instance/bootstrap-complete
cat /etc/os-release
cat /etc/demoproject/role
```

`/etc/os-release` must identify Amazon Linux 2023.

## Step 2 — Prepare every Kubernetes node

Perform Steps 2 through 5 on the control plane and both workers.

### 2.1 Install baseline packages

```bash
sudo dnf -y update
sudo dnf -y install ca-certificates curl git jq tar gzip unzip wget \
  openssl iproute iptables conntrack-tools socat
```

### 2.2 Disable swap

```bash
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
swapon --show
```

The last command should return no devices.

### 2.3 Load kernel modules

```bash
printf 'overlay\nbr_netfilter\n' | \
  sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe overlay
sudo modprobe br_netfilter
lsmod | grep -E 'overlay|br_netfilter'
```

### 2.4 Configure Kubernetes networking sysctls

```bash
printf '%s\n' \
  'net.bridge.bridge-nf-call-iptables = 1' \
  'net.bridge.bridge-nf-call-ip6tables = 1' \
  'net.ipv4.ip_forward = 1' | \
  sudo tee /etc/sysctl.d/99-kubernetes-cri.conf

sudo sysctl --system
sysctl net.ipv4.ip_forward
```

The forwarding value must be `1`.

### 2.5 Configure SELinux for kubeadm

```bash
getenforce
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' \
  /etc/selinux/config
getenforce
```

Permissive mode follows the current kubeadm RPM installation guidance. Treat it
as a documented security exception in environments that require enforcing
SELinux policy.

## Step 3 — Install containerd on every Kubernetes node

```bash
sudo dnf -y install containerd
sudo install -d -m 0755 /etc/containerd
containerd config default | \
  sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd
sudo systemctl status containerd --no-pager
grep 'SystemdCgroup = true' /etc/containerd/config.toml
```

Kubelet and containerd must use compatible cgroup drivers.

## Step 4 — Add the Kubernetes RPM repository

Run on all three Kubernetes nodes:

```bash
KUBERNETES_MINOR=1.36

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

## Step 5 — Install kubeadm, kubelet, and kubectl

```bash
sudo dnf install -y kubelet kubeadm kubectl \
  --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
kubeadm version
kubelet --version
kubectl version --client
```

Kubelet may restart until kubeadm provides its configuration. That is expected.

## Step 6 — Initialize the control plane

Run only on `k8s-control-plane`:

```bash
CONTROL_PLANE_PRIVATE_IP="$(hostname -I | awk '{print $1}')"
sudo kubeadm init \
  --apiserver-advertise-address="${CONTROL_PLANE_PRIVATE_IP}" \
  --control-plane-endpoint="${CONTROL_PLANE_PRIVATE_IP}:6443" \
  --pod-network-cidr=192.168.0.0/16 \
  --upload-certs
```

Keep the generated worker join command in a protected terminal. Configure
kubectl for `ec2-user`:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 0600 "$HOME/.kube/config"
kubectl cluster-info
```

## Step 7 — Install Calico

On the control plane:

```bash
CALICO_VERSION=v3.32.0
kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
kubectl -n kube-system rollout status daemonset/calico-node \
  --timeout=300s
kubectl -n kube-system get pods -o wide
```

Ensure `192.168.0.0/16` does not overlap the VPC or connected networks.

## Step 8 — Join worker1 and worker2

On each worker, execute the exact join command displayed by `kubeadm init`:

```bash
sudo kubeadm join "${CONTROL_PLANE_PRIVATE_IP}:6443" \
  --token "${KUBEADM_TOKEN}" \
  --discovery-token-ca-cert-hash "${DISCOVERY_HASH}"
```

Set the variables from the generated command. Do not commit the token. When it
expires, generate another on the control plane:

```bash
sudo kubeadm token create --ttl 2h --print-join-command
```

Verify on the control plane:

```bash
kubectl get nodes -o wide
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl -n kube-system get pods
```

## Step 9 — Install Docker on Jenkins

Run on `jenkins-server`:

```bash
sudo dnf -y update
sudo dnf -y install docker
sudo systemctl enable --now docker
sudo docker version
```

## Step 10 — Install Java 21 and Jenkins LTS

```bash
sudo dnf -y install fontconfig java-21-amazon-corretto-headless wget
java -version

sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo
sudo rpm --import \
  https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key
sudo dnf -y install jenkins
sudo systemctl daemon-reload
sudo usermod -aG docker jenkins
sudo systemctl enable --now jenkins
sudo systemctl restart jenkins
sudo systemctl status jenkins --no-pager
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Step 11 — Install kubectl on Jenkins

```bash
KUBERNETES_MINOR=1.36

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y kubectl --disableexcludes=kubernetes
kubectl version --client
sudo -u jenkins docker version
```

Open the Terraform `jenkins_url`, unlock Jenkins, create a named administrator,
disable anonymous access, and install the plugins in `jenkins/plugins.txt`.

## Step 12 — Create a restricted Jenkins Kubernetes identity

Run on the control plane:

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

Create the restricted kubeconfig:

```bash
JENKINS_TOKEN="$(kubectl -n demo create token jenkins-deployer --duration=8760h)"
CLUSTER_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
CLUSTER_CA="$(sudo base64 -w0 /etc/kubernetes/pki/ca.crt)"
umask 077

cat > /tmp/jenkins-kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: demoproject
  cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_SERVER}
contexts:
- name: jenkins@demoproject
  context:
    cluster: demoproject
    namespace: demo
    user: jenkins-deployer
current-context: jenkins@demoproject
users:
- name: jenkins-deployer
  user:
    token: ${JENKINS_TOKEN}
EOF
```

Validate permissions:

```bash
KUBECONFIG=/tmp/jenkins-kubeconfig kubectl auth can-i patch deployments -n demo
KUBECONFIG=/tmp/jenkins-kubeconfig kubectl auth can-i delete nodes
```

Expected answers are `yes` and `no`. Transfer the file through an approved
secure channel and add it to Jenkins as a **Secret file** credential named
`kubernetes-kubeconfig`. Then remove the temporary copy:

```bash
shred -u /tmp/jenkins-kubeconfig
unset JENKINS_TOKEN CLUSTER_CA CLUSTER_SERVER
```

## Step 13 — Configure Jenkins credentials and Pipeline

Create these credentials:

| ID | Type | Purpose |
|---|---|---|
| `dockerhub-credentials` | Username/password | Docker Hub scoped token |
| `kubernetes-kubeconfig` | Secret file | Namespace-limited deployment access |
| SCM credential | SSH key or token | Private GitHub checkout |

Create a Pipeline from SCM, use branch `main`, set script path to
`jenkins/Jenkinsfile`, and enable the GitHub hook trigger.

## Step 14 — Configure the GitHub webhook

In GitHub repository settings create a webhook:

- Payload URL: `JENKINS_URL/github-webhook/`
- Content type: `application/json`
- Secret: generated high-entropy value
- Events: push events

Use the actual Terraform `jenkins_url` output in place of `JENKINS_URL`.

## Step 15 — Build and push the first image manually

On the Jenkins server or another trusted Docker host:

```bash
docker build --pull --tag demoproject/flask-app:1 application
docker tag demoproject/flask-app:1 demoproject/flask-app:latest
docker login
docker push demoproject/flask-app:1
docker push demoproject/flask-app:latest
docker logout
```

## Step 16 — Deploy the application manually

On the control plane:

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl -n demo set image deployment/flask-app \
  flask-app=demoproject/flask-app:1
kubectl -n demo set env deployment/flask-app APP_VERSION=1
kubectl -n demo rollout status deployment/flask-app --timeout=180s
kubectl -n demo get pods,deployment,service -o wide
```

Verify from an allowed client:

```bash
APPLICATION_URL="$(terraform output -raw application_url)"
curl -fsS "${APPLICATION_URL}/health"
curl -fsS "${APPLICATION_URL}/version"
```

## Step 17 — Install Helm manually

On the control plane:

```bash
HELM_VERSION=v4.0.0
ARCH=amd64
curl -fsSLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
curl -fsSLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum"
sha256sum --check "helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum"
tar -xzf "helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
sudo install -m 0755 "linux-${ARCH}/helm" /usr/local/bin/helm
helm version
```

## Step 18 — Install monitoring manually

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
GRAFANA_PASSWORD="$(openssl rand -base64 30 | tr -d '\n')"
kubectl -n monitoring create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="${GRAFANA_PASSWORD}"
unset GRAFANA_PASSWORD

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/values.yaml \
  --wait \
  --timeout 15m

kubectl apply -f monitoring/alerts/platform-alerts.yaml
kubectl apply -f monitoring/grafana/custom-dashboard.yaml
kubectl -n monitoring get pods
```

Access through port forwarding:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Run them in separate terminals. Retrieve the Grafana password:

```bash
kubectl -n monitoring get secret grafana-admin-credentials \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

## Step 19 — Test the complete CI/CD flow

Commit and push an application change:

```bash
git add application
git commit -m "feat: update application"
git push origin main
```

Confirm:

1. GitHub delivers the webhook successfully.
2. Jenkins starts a build.
3. Docker Hub receives the numbered tag.
4. Kubernetes completes the rolling update.
5. Both application replicas become Ready.
6. `/version` reports the Jenkins build number.
7. Prometheus continues scraping healthy targets.

## Step 20 — Final verification

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods
kubectl -n demo get deployment,pods,service -o wide
kubectl -n demo rollout history deployment/flask-app
kubectl -n monitoring get pods
kubectl -n monitoring get prometheusrules
helm -n monitoring list
```

## Step 21 — Manual cleanup

```bash
helm -n monitoring uninstall kube-prometheus-stack
kubectl delete namespace monitoring demo --wait=true --timeout=10m
cd terraform
terraform plan -destroy
terraform destroy
```

Review the destroy plan before approval. Confirm AWS no longer contains project
EC2 instances, EBS volumes, security groups, Internet gateway, or VPC. GitHub,
Docker Hub, credentials, Terraform state, and local source files have separate
retention policies.

## Related guides

- [Script-based setup](README.md)
- [Architecture](docs/PROJECT_ARCHITECTURE.md)
- [CI/CD workflow](docs/CI_CD_WORKFLOW.md)
- [Monitoring](docs/MONITORING_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
