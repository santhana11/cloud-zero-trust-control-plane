#!/usr/bin/env bash
# Terraform drift check (example)
# Run from CI; expects TF_DIR and backend config. Exit 2 if drift detected.
set -euo pipefail
TF_DIR="${TF_DIR:-terraform/eks-cluster}"
export TF_IN_AUTOMATION=1
terraform init -input=false -backend-config="${BACKEND_CONFIG:-}"
terraform plan -input=false -detailed-exitcode -out=/dev/null || exitcode=$?
if [[ "${exitcode:-0}" -eq 2 ]]; then
  echo "Drift detected in $TF_DIR"
  exit 2
fi
exit 0
