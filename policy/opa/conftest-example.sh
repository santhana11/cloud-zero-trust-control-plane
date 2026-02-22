#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Conftest execution example — Terraform policy
# ------------------------------------------------------------------------------
# Run from repo root. Requires: terraform, conftest.
# Usage: ./policy/opa/conftest-example.sh [terraform-dir]
# Default terraform-dir: terraform/org-guardrails
# ------------------------------------------------------------------------------
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="${1:-terraform/org-guardrails}"
POLICY_PATH="${REPO_ROOT}/policy/opa/terraform"
cd "${REPO_ROOT}/${TERRAFORM_DIR}"

echo "==> Terraform init (backend=false) and plan"
terraform init -backend=false -input=false
terraform plan -out=tfplan -input=false
terraform show -json tfplan > plan.json

echo "==> Conftest test plan.json (all Terraform Rego policies)"
conftest test plan.json -p "${POLICY_PATH}"

echo "==> Conftest test .tf files for remote state (if backend is in this dir)"
shopt -s nullglob
tf_files=(*.tf)
if [[ ${#tf_files[@]} -gt 0 ]]; then
  conftest test "${tf_files[@]}" -p "${POLICY_PATH}" --parser terraform 2>/dev/null || true
fi

echo "==> Done. Remove plan artifacts if desired: rm -f tfplan plan.json"
rm -f tfplan plan.json
