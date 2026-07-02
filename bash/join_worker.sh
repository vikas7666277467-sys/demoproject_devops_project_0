#!/usr/bin/env bash
# Usage: sudo ./join_worker.sh <control-plane-private-ip> <token> <sha256-discovery-hash>
set -euo pipefail

KUBERNETES_MINOR="${KUBERNETES_MINOR:-1.36}"

if [[ "${EUID}" -ne 0 || "$#" -ne 3 ]]; then
  echo "Usage: sudo $0 <control-plane-private-ip> <token> <sha256-discovery-hash>" >&2
  exit 1
fi

until [[ -f /var/lib/cloud/instance/bootstrap-complete ]]; do sleep 10; done

source /etc/os-release
[[ "${ID}" == "amzn" && "${VERSION_ID}" == "2023" ]] || {
  echo "This script supports Amazon Linux 2023 only." >&2
  exit 2
}

CONTROL_PLANE_IP="$1"
TOKEN="$2"
DISCOVERY_HASH="$3"

if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "This worker is already joined."
  exit 0
fi

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

if [[ ! "${TOKEN}" =~ ^[a-z0-9]{6}\.[a-z0-9]{16}$ ]]; then
  echo "Invalid kubeadm token format." >&2
  exit 2
fi

if [[ ! "${DISCOVERY_HASH}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "Invalid discovery hash format; include the sha256: prefix." >&2
  exit 2
fi

kubeadm join "${CONTROL_PLANE_IP}:6443" \
  --token "${TOKEN}" \
  --discovery-token-ca-cert-hash "${DISCOVERY_HASH}"
systemctl enable --now kubelet
