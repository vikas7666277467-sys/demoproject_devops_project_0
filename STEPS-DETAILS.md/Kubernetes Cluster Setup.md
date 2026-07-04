# Part 3A - Kubernetes Cluster Setup (kubeadm)

In this section, we will prepare all three Kubernetes servers and install the required components to build a Kubernetes cluster using **kubeadm**.

By the end of this section, all nodes will be prepared and ready to initialize the Kubernetes Control Plane.

---

# Kubernetes Cluster Architecture

The Kubernetes cluster consists of three nodes.

| Server | Hostname | Role |
|----------|----------|------|
| EC2-1 | k8s-control-plane | Kubernetes Control Plane |
| EC2-2 | k8s-worker1 | Kubernetes Worker Node |
| EC2-3 | k8s-worker2 | Kubernetes Worker Node |

The Jenkins server will remain outside the cluster and will be used to deploy applications.

---

# Kubernetes Architecture

```text
                         Kubernetes Cluster

                 +-------------------------------+
                 |        Control Plane          |
                 |-------------------------------|
                 | API Server                    |
                 | Scheduler                     |
                 | Controller Manager            |
                 | etcd                          |
                 +---------------+---------------+
                                 |
               -----------------------------------------
               |                                       |
               ▼                                       ▼
      +--------------------+                 +--------------------+
      |   Worker Node 1    |                 |   Worker Node 2    |
      |--------------------|                 |--------------------|
      | kubelet            |                 | kubelet            |
      | kube-proxy         |                 | kube-proxy         |
      | containerd         |                 | containerd         |
      | Application Pods   |                 | Application Pods   |
      +--------------------+                 +--------------------+
```

---

# Prerequisites

Complete **Part 2** before proceeding.

Verify:

- Four EC2 instances are running.
- SSH connectivity is working.
- Security Group is configured.
- Private networking is working.

---

# Required Software

The following software will be installed on **all Kubernetes nodes**.

| Software | Purpose |
|----------|----------|
| containerd | Container Runtime |
| kubeadm | Cluster Initialization |
| kubelet | Kubernetes Node Agent |
| kubectl | Kubernetes CLI |
| crictl | Container Runtime CLI |

---

# Connect to Every Server

Connect to each server.

Control Plane

```bash
ssh -i demo-key.pem ec2-user@<ControlPlane-IP>
```

Worker 1

```bash
ssh -i demo-key.pem ec2-user@<Worker1-IP>
```

Worker 2

```bash
ssh -i demo-key.pem ec2-user@<Worker2-IP>
```

All commands in this section should be executed on **all three Kubernetes nodes** unless specified otherwise.

---

# Step 1 - Update the Operating System

Update all installed packages.

```bash
sudo dnf update -y
```

Verify

```bash
cat /etc/os-release
```

---

# Step 2 - Set Hostnames

Control Plane

```bash
sudo hostnamectl set-hostname k8s-control-plane
```

Worker 1

```bash
sudo hostnamectl set-hostname k8s-worker1
```

Worker 2

```bash
sudo hostnamectl set-hostname k8s-worker2
```

Verify

```bash
hostname
```

---

# Step 3 - Configure /etc/hosts

Edit

```bash
sudo vi /etc/hosts
```

Example

```text
172.31.xx.xx    k8s-control-plane
172.31.xx.xx    k8s-worker1
172.31.xx.xx    k8s-worker2
```

Verify

```bash
ping k8s-worker1

ping k8s-worker2
```

---

# Step 4 - Disable SELinux

Check current status.

```bash
getenforce
```

Temporarily disable.

```bash
sudo setenforce 0
```

Permanently disable.

```bash
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

Verify

```bash
getenforce
```

Expected

```text
Permissive
```

---

# Step 5 - Disable Swap

Kubernetes requires swap to be disabled.

Temporarily

```bash
sudo swapoff -a
```

Permanently

```bash
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Verify

```bash
free -h
```

Swap should be

```text
0B
```

---

# Step 6 - Enable Required Kernel Modules

Load required modules.

```bash
sudo modprobe overlay

sudo modprobe br_netfilter
```

Persist them.

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Verify

```bash
lsmod | grep overlay

lsmod | grep br_netfilter
```

---

# Step 7 - Configure Kernel Parameters

Create

```bash
sudo vi /etc/sysctl.d/k8s.conf
```

Add

```text
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

Reload

```bash
sudo sysctl --system
```

Verify

```bash
sysctl net.ipv4.ip_forward
```

Expected

```text
1
```

---

# Step 8 - Install Containerd

Install package.

```bash
sudo dnf install containerd -y
```

Create configuration.

```bash
sudo mkdir -p /etc/containerd
```

Generate default configuration.

```bash
containerd config default | sudo tee /etc/containerd/config.toml
```

---

# Step 9 - Enable Systemd Cgroup Driver

Edit

```bash
sudo vi /etc/containerd/config.toml
```

Find

```text
SystemdCgroup = false
```

Change to

```text
SystemdCgroup = true
```

Save the file.

---

# Step 10 - Enable and Start Containerd

```bash
sudo systemctl enable containerd

sudo systemctl restart containerd
```

Verify

```bash
sudo systemctl status containerd
```

Expected

```text
active (running)
```

---

# Step 11 - Verify Container Runtime

Check version.

```bash
containerd --version
```

Verify socket.

```bash
sudo crictl info
```

If `crictl` is not installed yet, it will be installed in the next section.

---

# Step 12 - Open Required Firewall Ports (Optional)

If using firewalld, allow Kubernetes ports.

Example

```bash
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload
```

For AWS Security Groups, this is generally handled by the Security Group configuration created in Terraform.

---

# Verification Checklist

Before moving to the next section, verify the following on all three nodes:

- Operating system updated
- Hostname configured
- `/etc/hosts` updated
- SELinux set to **Permissive**
- Swap disabled
- Kernel modules loaded
- Kernel parameters applied
- Containerd installed
- Containerd running successfully

---

# Part 3B - Installing Kubernetes Components & Initializing the Control Plane

In this section, we will install Kubernetes on all three nodes and initialize the Kubernetes Control Plane.

At the end of this section, you will have:

- kubeadm installed
- kubelet installed
- kubectl installed
- Kubernetes Control Plane initialized
- kubeconfig configured
- Worker join command generated

---

# Kubernetes Installation Workflow

```text
All Nodes
     │
     ▼
Install Kubernetes Repository
     │
     ▼
Install kubeadm
Install kubelet
Install kubectl
     │
     ▼
Enable kubelet
     │
     ▼
Initialize Control Plane
     │
     ▼
Configure kubectl
     │
     ▼
Generate Worker Join Command
```

---

# Step 1 - Add the Kubernetes Repository

Perform this step on **all three Kubernetes nodes**.

Create the Kubernetes repository.

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl
EOF
```

Clean the repository cache.

```bash
sudo dnf clean all
```

Refresh package metadata.

```bash
sudo dnf makecache
```

---

# Step 2 - Install Kubernetes Components

Run on **all Kubernetes nodes**.

```bash
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

Verify the installed versions.

```bash
kubeadm version

kubectl version --client

kubelet --version
```

Expected Output

```text
kubeadm version: v1.30.x

kubectl Client Version: v1.30.x

Kubernetes v1.30.x
```

---

# Step 3 - Enable kubelet

Enable the kubelet service.

```bash
sudo systemctl enable kubelet
```

Start the service.

```bash
sudo systemctl start kubelet
```

Verify.

```bash
sudo systemctl status kubelet
```

Expected Output

```text
Active: active (running)
```

> **Note:** At this stage, kubelet may repeatedly restart because the cluster has not yet been initialized. This is expected behavior.

---

# Step 4 - Verify Required Services

Run on all nodes.

Containerd

```bash
sudo systemctl status containerd
```

Kubelet

```bash
sudo systemctl status kubelet
```

Both services should be enabled.

---

# Step 5 - Pull Kubernetes Images

On the **Control Plane** node only.

```bash
sudo kubeadm config images pull
```

Verify downloaded images.

```bash
sudo crictl images
```

Expected images include:

- kube-apiserver
- kube-controller-manager
- kube-scheduler
- etcd
- pause
- coredns

---

# Step 6 - Initialize the Control Plane

Run only on the **Control Plane**.

```bash
sudo kubeadm init \
--pod-network-cidr=192.168.0.0/16
```

Explanation

| Option | Purpose |
|---------|----------|
| `--pod-network-cidr=192.168.0.0/16` | Required by Calico CNI |

Initialization may take several minutes.

---

# Expected Output

When successful, you should see a message similar to:

```text
Your Kubernetes control-plane has initialized successfully!
```

It also displays a worker join command similar to:

```bash
kubeadm join 172.31.xx.xx:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Do not close the terminal until you save this command.**

You will use it in **Part 3C**.

---

# Step 7 - Configure kubectl

Run only on the **Control Plane**.

Create the Kubernetes configuration directory.

```bash
mkdir -p $HOME/.kube
```

Copy the admin configuration.

```bash
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

Update ownership.

```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

# Step 8 - Verify Cluster Access

Check cluster information.

```bash
kubectl cluster-info
```

Expected Output

```text
Kubernetes control plane is running at

https://172.xx.xx.xx:6443
```

---

# Step 9 - Verify the Control Plane Node

List cluster nodes.

```bash
kubectl get nodes
```

Expected Output

```text
NAME                 STATUS      ROLES           AGE

k8s-control-plane    NotReady    control-plane   2m
```

**Why is the node NotReady?**

At this stage, the Kubernetes network plugin has not been installed.

This is expected.

Once Calico is installed in **Part 3C**, the node status changes to:

```text
Ready
```

---

# Step 10 - Verify System Pods

```bash
kubectl get pods -n kube-system
```

Expected Output

```text
etcd

kube-apiserver

kube-controller-manager

kube-scheduler
```

CoreDNS pods may remain in **Pending** status until the network plugin is installed.

---

# Step 11 - Save the Worker Join Command

If you forgot to copy the join command, generate a new one.

```bash
kubeadm token create --print-join-command
```

Example

```bash
kubeadm join 172.31.xx.xx:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Save this command.

It will be executed on both worker nodes in **Part 3C**.

---

# Verification Checklist

Before moving to the next section, verify the following:

- Kubernetes repository configured
- kubeadm installed
- kubelet installed
- kubectl installed
- kubelet service enabled
- Control Plane initialized successfully
- kubeconfig configured
- kubectl cluster-info works
- Worker join command saved

---

# Common Errors

## kubelet is restarting continuously

This is normal before the cluster is initialized.

Verify:

```bash
sudo systemctl status kubelet
```

---

## Port 6443 already in use

Check running Kubernetes components.

```bash
sudo netstat -tulpn | grep 6443
```

If this is a previous failed setup, reset the cluster.

```bash
sudo kubeadm reset -f
```

Then initialize again.

---

## Existing Cluster Configuration

If `kubeadm init` reports existing configuration files:

```bash
sudo kubeadm reset -f

sudo rm -rf ~/.kube

sudo rm -rf /etc/kubernetes

sudo systemctl restart containerd
```

Run the initialization again.

---

# Next Section

In **Part 3C**, we will:

- Join both Worker Nodes to the cluster
- Install the Calico CNI plugin
- Verify all nodes are in the **Ready** state
- Verify CoreDNS
- Test pod networking
- Deploy a sample application
- Troubleshoot common Kubernetes networking issues

# Part 3C - Joining Worker Nodes, Installing Calico CNI & Verifying the Kubernetes Cluster

In this section, we will complete the Kubernetes cluster setup by:

- Joining both worker nodes to the Kubernetes cluster
- Installing the Calico CNI plugin
- Verifying all Kubernetes components
- Testing networking
- Deploying a sample application
- Troubleshooting common Kubernetes issues

At the end of this section, your Kubernetes cluster will be fully operational and ready for application deployment.

---

# Kubernetes Cluster Workflow

```text
Control Plane Initialized
            │
            ▼
Generate Join Command
            │
            ▼
Join Worker Node 1
            │
            ▼
Join Worker Node 2
            │
            ▼
Install Calico CNI
            │
            ▼
CoreDNS Starts
            │
            ▼
Nodes Become Ready
            │
            ▼
Verify Cluster
            │
            ▼
Deploy Sample Application
            │
            ▼
Cluster Ready for CI/CD
```

---

# Step 1 - Join Worker Node 1

Login to Worker Node 1.

```bash
ssh -i demo-key.pem ec2-user@<Worker1-Public-IP>
```

Execute the join command generated from the Control Plane.

Example

```bash
sudo kubeadm join 172.31.xx.xx:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Expected Output

```text
This node has joined the cluster.
```

---

# Step 2 - Join Worker Node 2

Login to Worker Node 2.

```bash
ssh -i demo-key.pem ec2-user@<Worker2-Public-IP>
```

Run the same join command.

```bash
sudo kubeadm join 172.31.xx.xx:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Expected Output

```text
This node has joined the cluster.
```

---

# Step 3 - Verify Cluster Nodes

Login to the Control Plane.

```bash
kubectl get nodes
```

Expected Output

```text
NAME                 STATUS      ROLES           AGE

k8s-control-plane    NotReady    control-plane

k8s-worker1          NotReady    <none>

k8s-worker2          NotReady    <none>
```

This is expected because the Container Network Interface (CNI) plugin has not yet been installed.

---

# Step 4 - Install Calico CNI

Install Calico from the official manifest.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml
```

Expected Output

```text
namespace/calico-system created

daemonset.apps/calico-node created

deployment.apps/calico-kube-controllers created
```

---

# Step 5 - Verify Calico Pods

```bash
kubectl get pods -n kube-system
```

or

```bash
kubectl get pods -A
```

Expected Output

```text
calico-node

calico-kube-controllers

coredns

etcd

kube-apiserver

kube-controller-manager

kube-scheduler
```

---

# Step 6 - Wait for Nodes to Become Ready

Wait approximately 1–2 minutes.

Run

```bash
kubectl get nodes
```

Expected Output

```text
NAME                 STATUS   ROLES           AGE

k8s-control-plane    Ready    control-plane

k8s-worker1          Ready    <none>

k8s-worker2          Ready    <none>
```

Congratulations!

Your Kubernetes cluster is now operational.

---

# Step 7 - Verify System Pods

```bash
kubectl get pods -n kube-system
```

All pods should be in the Running state.

Example

```text
calico-node

calico-kube-controllers

coredns

etcd

kube-apiserver

kube-controller-manager

kube-proxy

kube-scheduler
```

---

# Step 8 - Verify Cluster Information

```bash
kubectl cluster-info
```

Expected Output

```text
Kubernetes control plane is running at

https://172.xx.xx.xx:6443
```

---

# Step 9 - Verify Kubernetes Components

```bash
kubectl get componentstatuses
```

> **Note:** In newer Kubernetes versions, `kubectl get componentstatuses` is deprecated. Instead, verify the control plane by checking the pods in the `kube-system` namespace:

```bash
kubectl get pods -n kube-system
```

All control plane pods should be in the **Running** state.

---

# Step 10 - Verify Node Details

```bash
kubectl get nodes -o wide
```

Expected Output

```text
NAME                 STATUS   ROLES

k8s-control-plane    Ready    control-plane

k8s-worker1          Ready

k8s-worker2          Ready
```

This command also displays:

- Internal IP
- Operating System
- Kernel Version
- Kubernetes Version

---

# Step 11 - Verify Running Namespaces

```bash
kubectl get namespaces
```

Expected Output

```text
default

kube-node-lease

kube-public

kube-system

calico-system
```

---

# Step 12 - Verify Running Services

```bash
kubectl get svc -A
```

Example

```text
kubernetes

kube-dns
```

---

# Step 13 - Deploy a Sample Application

Deploy NGINX.

```bash
kubectl create deployment nginx --image=nginx
```

Verify.

```bash
kubectl get deployments
```

Expected

```text
nginx

READY

1/1
```

---

# Step 14 - Expose the Application

```bash
kubectl expose deployment nginx \
--type=NodePort \
--port=80
```

Verify.

```bash
kubectl get svc
```

Example

```text
NAME

nginx

TYPE

NodePort
```

---

# Step 15 - Verify Pods

```bash
kubectl get pods -o wide
```

Expected

```text
NAME

nginx-xxxxxxxx

STATUS

Running
```

Notice on which worker node the pod is running.

---

# Step 16 - Scale the Deployment

Increase the number of replicas.

```bash
kubectl scale deployment nginx --replicas=3
```

Verify.

```bash
kubectl get pods -o wide
```

Expected

```text
3 Pods

Running

Distributed across Worker Nodes
```

This demonstrates Kubernetes scheduling.

---

# Step 17 - Describe a Node

```bash
kubectl describe node k8s-worker1
```

This displays:

- Capacity
- Allocatable Resources
- Labels
- Conditions
- Running Pods

---

# Step 18 - Describe a Pod

```bash
kubectl describe pod <pod-name>
```

Useful for troubleshooting:

- Events
- Scheduling
- Image Pull
- Resource Limits

---

# Step 19 - View Cluster Events

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

This helps diagnose:

- Scheduling issues
- Failed Pods
- Node problems

---

# Step 20 - Verify DNS

Run a temporary pod.

```bash
kubectl run dns-test \
--image=busybox \
-it \
--rm \
--restart=Never -- sh
```

Inside the pod.

```bash
nslookup kubernetes.default
```

Expected

```text
Name:

kubernetes.default.svc.cluster.local
```

Exit.

```bash
exit
```

---

# Verification Checklist

Before proceeding to the Jenkins installation, verify the following:

- Control Plane is Ready
- Worker Node 1 is Ready
- Worker Node 2 is Ready
- Calico is Running
- CoreDNS is Running
- kube-proxy is Running
- API Server is Healthy
- NGINX Deployment is Running
- NodePort Service Created
- Pod Scheduling Working
- Cluster DNS Working

---

# Common Troubleshooting

## Worker Node Not Joining

Check

```bash
sudo systemctl status kubelet
```

Verify the token.

```bash
kubeadm token list
```

Generate a new join command.

```bash
kubeadm token create --print-join-command
```

---

## Nodes Remain NotReady

Check Calico.

```bash
kubectl get pods -n kube-system
```

Describe Calico pods.

```bash
kubectl describe pod <calico-pod> -n kube-system
```

View logs.

```bash
kubectl logs <calico-pod> -n kube-system
```

---

## CoreDNS Pending

Usually caused by:

- Calico not running
- CNI installation failure

Reapply Calico.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml
```

---

## Worker Node Shows NotReady

Check kubelet.

```bash
sudo systemctl status kubelet
```

Check containerd.

```bash
sudo systemctl status containerd
```

Restart services if necessary.

```bash
sudo systemctl restart containerd

sudo systemctl restart kubelet
```

---

# Learning Outcomes

After completing this section, you have successfully:

- Installed Kubernetes using kubeadm
- Built a three-node Kubernetes cluster
- Joined worker nodes
- Installed the Calico CNI plugin
- Verified cluster health
- Deployed your first Kubernetes application
- Exposed the application using a NodePort Service
- Tested Kubernetes networking and scheduling
- Learned basic Kubernetes troubleshooting

---

# Next Section

In **Part 4**, we will configure the **Jenkins Server** by:

- Installing Java
- Installing Jenkins
- Unlocking Jenkins
- Installing recommended plugins
- Installing Docker
- Installing Git
- Installing kubectl
- Configuring Docker permissions
- Preparing Jenkins to deploy applications to the Kubernetes cluster

