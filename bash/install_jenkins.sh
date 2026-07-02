#!/usr/bin/env bash
# Idempotent Jenkins LTS installation for Amazon Linux 2023.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

source /etc/os-release
[[ "${ID}" == "amzn" && "${VERSION_ID}" == "2023" ]] || {
  echo "This script supports Amazon Linux 2023 only." >&2
  exit 2
}

dnf -y install fontconfig java-21-amazon-corretto-headless wget
wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/rpm-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key
KUBERNETES_MINOR="${KUBERNETES_MINOR:-1.36}"
cat >/etc/yum.repos.d/kubernetes.repo <<REPO
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
REPO
dnf -y install jenkins
dnf install -y kubectl --disableexcludes=kubernetes
systemctl enable --now jenkins

if getent group docker >/dev/null; then
  usermod -aG docker jenkins
  systemctl restart jenkins
fi

echo "Jenkins status: $(systemctl is-active jenkins)"
echo "Initial password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
