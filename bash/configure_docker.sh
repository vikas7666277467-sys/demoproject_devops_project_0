#!/usr/bin/env bash
# Install the Amazon Linux 2023 Docker package.
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER}}"
if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

source /etc/os-release
[[ "${ID}" == "amzn" && "${VERSION_ID}" == "2023" ]] || {
  echo "This script supports Amazon Linux 2023 only." >&2
  exit 2
}

dnf -y install docker
systemctl enable --now docker
usermod -aG docker "${TARGET_USER}"
docker version
echo "Sign out and back in before using Docker without sudo."
