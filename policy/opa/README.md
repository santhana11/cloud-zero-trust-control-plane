# OPA Policies for Terraform (Conftest)

**Purpose:** Rego policies evaluated with [Conftest](https://www.conftest.dev/) to enforce Terraform guardrails in CI: deny public S3, deny wildcard IAM, require encryption at rest, and enforce remote state.

## Policy Summary

| Policy | File | What it does |
|--------|------|--------------|
| Deny public S3 | `terraform/deny_public_s3.rego` | Rejects `aws_s3_bucket` with `acl` = public-read/public-read-write/authenticated-read; rejects `aws_s3_bucket_policy` with `Principal "*"`. |
| Deny wildcard IAM | `terraform/deny_wildcard_iam.rego` | Rejects IAM policies (role/user/group/managed) that use `Action: "*"` or `Resource: "*"` (least privilege). |
| Require encryption | `terraform/require_encryption.rego` | Requires S3 `server_side_encryption_configuration`, EBS `encrypted = true`, RDS `storage_encrypted = true`, DynamoDB `server_side_encryption`. |
| Require remote state | `terraform/require_remote_state.rego` | Requires Terraform `backend` to be s3/gcs/azurerm/remote (run against `.tf` files, not plan). |

## Conftest Execution

### Prerequisites

- [Conftest](https://www.conftest.dev/install/) (e.g. `brew install conftest` or download from GitHub releases).
- Terraform (for generating plan).

### Option 1: Test Terraform plan (recommended in CI)

Policies **deny_public_s3**, **deny_wildcard_iam**, and **require_encryption** use Terraform plan JSON. **require_remote_state** needs `.tf` files (see Option 2).

```bash
# From repo root
cd terraform/org-guardrails   # or any terraform dir
terraform init -backend=false
terraform plan -out=tfplan -input=false
terraform show -json tfplan > plan.json

# Run Conftest against plan (policy path relative to repo root)
conftest test plan.json --namespace terraform.zerotrust.public_s3    -p ../policy/opa/terraform/
conftest test plan.json --namespace terraform.zerotrust.wildcard_iam -p ../policy/opa/terraform/
conftest test plan.json --namespace terraform.zerotrust.encryption   -p ../policy/opa/terraform/
```

Run all namespaces in one go (Conftest runs all policies and fails if any `deny`):

```bash
conftest test plan.json -p ../policy/opa/terraform/
```

### Option 2: Test Terraform config (`.tf` files)

For **remote state** and for policies that need HCL before plan:

```bash
# Backend and remote state (run from repo root)
conftest test terraform/org-guardrails/*.tf terraform/irsa/*.tf --parser terraform -p policy/opa/terraform/
```

Combine with plan: run plan-based policies on `plan.json` and config-based on `*.tf`.

### Option 3: Scripted example (run from repo root)

See `policy/opa/conftest-example.sh` for a single script that runs Conftest against a Terraform directory.

## Running OPA Unit Tests

Tests live next to the policies (`*_test.rego`). Run with OPA (not Conftest):

```bash
# Install OPA: brew install opa
opa test policy/opa/terraform/ -v
```

## CI Integration

- **Checkov** (existing workflow) and **Conftest** are complementary: Checkov has many built-in rules; Conftest runs your custom Rego.
- Add a job that: `terraform plan -out=tfplan`, `terraform show -json tfplan > plan.json`, then `conftest test plan.json -p policy/opa/terraform/`.
- For remote state, add a step: `conftest test terraform/**/*.tf --parser terraform -p policy/opa/terraform/` (adjust paths to where backend is defined).

## Input Format

- **Plan JSON:** From `terraform show -json tfplan`. Policies expect `input.resource_changes[]` with `type`, `address`, `change.after`.
- **Config (HCL):** From `conftest test *.tf --parser terraform`. Remote state policy expects `input.terraform[0].backend[]` with `name` (e.g. `s3`).
