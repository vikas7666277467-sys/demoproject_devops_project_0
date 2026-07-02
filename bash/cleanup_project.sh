#!/usr/bin/env bash
# Safely clean up Kubernetes workloads and Terraform-managed AWS infrastructure.
# Preview: bash bash/cleanup_project.sh
# Apply:   bash bash/cleanup_project.sh --execute
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
EXPECTED_PROJECT="demoproject-devops-project2"

EXECUTE=false
AUTO_APPROVE=false
SKIP_KUBERNETES=false

usage() {
  cat <<'USAGE'
Usage: cleanup_project.sh [options]

Options:
  --execute          Perform cleanup. Without this flag, only previews actions.
  --auto-approve     Skip the final typed confirmation and Terraform prompt.
                     Valid only with --execute; intended for controlled CI jobs.
  --skip-kubernetes  Skip Helm and namespace cleanup and destroy only Terraform.
  -h, --help         Display this help message.

The script does not delete the GitHub repository, Docker Hub images, Terraform
state, credentials, or local source files. Those have independent retention
and audit requirements.
USAGE
}

log() {
  printf '[cleanup] %s\n' "$*"
}

fail() {
  printf '[cleanup] ERROR: %s\n' "$*" >&2
  exit 1
}

for argument in "$@"; do
  case "${argument}" in
    --execute) EXECUTE=true ;;
    --auto-approve) AUTO_APPROVE=true ;;
    --skip-kubernetes) SKIP_KUBERNETES=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: ${argument}" ;;
  esac
done

if [[ "${AUTO_APPROVE}" == true && "${EXECUTE}" != true ]]; then
  fail "--auto-approve requires --execute"
fi

[[ -d "${TERRAFORM_DIR}" ]] || fail "Terraform directory not found: ${TERRAFORM_DIR}"
[[ -f "${TERRAFORM_DIR}/main.tf" ]] || fail "Expected Terraform root is incomplete"
grep -q 'demoproject-devops-project2' "${TERRAFORM_DIR}/variables.tf" || \
  fail "Project identity check failed; refusing to continue"

command -v terraform >/dev/null 2>&1 || fail "terraform is required"

log "Project root: ${PROJECT_ROOT}"
log "Terraform root: ${TERRAFORM_DIR}"

if [[ "${SKIP_KUBERNETES}" != true ]]; then
  if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    CURRENT_CONTEXT="$(kubectl config current-context)"
    log "Kubernetes context: ${CURRENT_CONTEXT}"

    if [[ "${EXECUTE}" == true ]]; then
      if command -v helm >/dev/null 2>&1 && \
         helm status kube-prometheus-stack --namespace monitoring >/dev/null 2>&1; then
        log "Uninstalling kube-prometheus-stack"
        helm uninstall kube-prometheus-stack --namespace monitoring --wait --timeout 10m
      else
        log "Monitoring Helm release is absent or Helm is unavailable"
      fi

      for namespace in demo monitoring; do
        if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
          log "Deleting namespace: ${namespace}"
          kubectl delete namespace "${namespace}" --wait=true --timeout=10m
        else
          log "Namespace already absent: ${namespace}"
        fi
      done
    else
      log "PREVIEW: uninstall Helm release kube-prometheus-stack in monitoring"
      log "PREVIEW: delete Kubernetes namespaces demo and monitoring"
    fi
  else
    log "No reachable Kubernetes context; Kubernetes cleanup will be skipped"
    log "Terraform destroy will still terminate the EC2 cluster when executed"
  fi
else
  log "Kubernetes cleanup explicitly skipped"
fi

terraform -chdir="${TERRAFORM_DIR}" init -input=false

if [[ "${EXECUTE}" != true ]]; then
  log "PREVIEW: Terraform destroy plan for ${EXPECTED_PROJECT}"
  terraform -chdir="${TERRAFORM_DIR}" plan -destroy -input=false
  log "Preview complete. Re-run with --execute only after reviewing the plan."
  exit 0
fi

if [[ "${AUTO_APPROVE}" != true ]]; then
  printf '\nThis permanently destroys Terraform-managed AWS resources.\n'
  printf 'Type %s to continue: ' "${EXPECTED_PROJECT}"
  read -r confirmation
  [[ "${confirmation}" == "${EXPECTED_PROJECT}" ]] || fail "Confirmation did not match; cleanup cancelled"
fi

log "Destroying Terraform-managed AWS resources"
if [[ "${AUTO_APPROVE}" == true ]]; then
  terraform -chdir="${TERRAFORM_DIR}" destroy -input=false -auto-approve
else
  terraform -chdir="${TERRAFORM_DIR}" destroy
fi

log "Cleanup complete"
log "Review AWS for retained snapshots, volumes, or resources created outside Terraform."
log "GitHub, Docker Hub, credentials, Terraform state, and local files were not deleted."

