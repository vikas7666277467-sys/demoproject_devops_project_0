#!/bin/bash
set -e
dnf update -y

dnf install -y java-17-amazon-corretto git curl wget vim docker

systemctl enable --now docker
usermod -aG docker ec2-user

cat >/etc/motd <<EOF
Jenkins Server
Provisioned by Terraform

Next Steps:
- Install Jenkins
- Install kubectl
- Configure Docker
EOF
