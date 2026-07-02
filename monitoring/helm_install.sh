#!/usr/bin/env bash
set -euo pipefail

HELM_VERSION="${HELM_VERSION:-v3.17.3}"
NAMESPACE="monitoring"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v helm >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  case "${ARCH}" in amd64|arm64) ;; *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; esac
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  curl -fsSLo "${TMP_DIR}/helm.tar.gz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
  tar -xzf "${TMP_DIR}/helm.tar.gz" -C "${TMP_DIR}"
  sudo install -m 0755 "${TMP_DIR}/linux-${ARCH}/helm" /usr/local/bin/helm
fi

kubectl get nodes
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n "${NAMESPACE}" get secret grafana-admin-credentials >/dev/null 2>&1; then
  GRAFANA_PASSWORD="$(openssl rand -base64 30 | tr -d '\n')"
  kubectl -n "${NAMESPACE}" create secret generic grafana-admin-credentials \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="${GRAFANA_PASSWORD}"
  unset GRAFANA_PASSWORD
fi

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${SCRIPT_DIR}/values.yaml" \
  --wait \
  --timeout 15m

kubectl apply -f "${SCRIPT_DIR}/alerts/platform-alerts.yaml"
kubectl apply -f "${SCRIPT_DIR}/grafana/custom-dashboard.yaml"
kubectl -n "${NAMESPACE}" get pods

echo "Grafana:    http://<worker-public-ip>:30300"
echo "Prometheus: http://<worker-public-ip>:30090"
echo "Grafana user: admin"
echo "Retrieve the generated password with:"
echo "kubectl -n monitoring get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d; echo"
