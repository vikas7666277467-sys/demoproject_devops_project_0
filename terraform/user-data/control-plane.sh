#!/bin/bash
set -e
dnf update -y

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

dnf install -y containerd git curl wget vim
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
systemctl enable --now containerd

cat >/etc/motd <<EOF
Kubernetes Control Plane
Provisioned by Terraform
EOF
