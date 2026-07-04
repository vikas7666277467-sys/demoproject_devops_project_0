#!/bin/bash
set -e
dnf update -y

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

modprobe overlay
modprobe br_netfilter

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

dnf install -y containerd git curl wget vim
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
systemctl enable --now containerd

cat >/etc/motd <<EOF
Kubernetes Worker Node
Provisioned by Terraform
EOF
