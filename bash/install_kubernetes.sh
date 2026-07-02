#!/usr/bin/env bash
# Install Kubernetes and initialize the Amazon Linux 2023 control plane.
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-v3.32.0}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
KUBERNETES_MINOR="${KUBERNETES_MINOR:-1.36}"
ADMIN_USER="${ADMIN_USER:-ec2-user}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

until [[ -f /var/lib/cloud/instance/bootstrap-complete ]]; do
  echo "Waiting for Terraform cloud-init bootstrap..."
  sleep 10
done

source /etc/os-release
[[ "${ID}" == "amzn" && "${VERSION_ID}" == "2023" ]] || {
  echo "This script supports Amazon Linux 2023 only." >&2
  exit 2
}

swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
printf 'overlay\nbr_netfilter\n' >/etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system
setenforce 0 || true
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

dnf -y install containerd
install -d -m 0755 /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd
systemctl restart containerd

cat >/etc/yum.repos.d/kubernetes.repo <<REPO
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
REPO
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

PRIVATE_IP="$(hostname -I | awk '{print $1}')"

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  kubeadm init \
    --apiserver-advertise-address="${PRIVATE_IP}" \
    --control-plane-endpoint="${PRIVATE_IP}:6443" \
    --pod-network-cidr="${POD_CIDR}" \
    --upload-certs
fi

install -d -m 0700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "/home/${ADMIN_USER}/.kube"
install -m 0600 -o "${ADMIN_USER}" -g "${ADMIN_USER}" /etc/kubernetes/admin.conf "/home/${ADMIN_USER}/.kube/config"
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
kubectl -n kube-system rollout status daemonset/calico-node --timeout=300s

kubeadm token create --ttl 2h --print-join-command | tee "/home/${ADMIN_USER}/join-command.sh"
chown "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/join-command.sh"
chmod 0700 "/home/${ADMIN_USER}/join-command.sh"

echo
echo "Control plane initialized. Run the printed join command with sudo on both workers."
kubectl get nodes -o wide
