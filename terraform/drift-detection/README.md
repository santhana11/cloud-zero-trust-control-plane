# Terraform Drift Detection (Phase 7)

**Purpose:** Detect configuration drift between Terraform state and live AWS (and optionally Kubernetes) resources. A **nightly** GitHub Actions workflow runs `terraform plan -detailed-exitcode`; if drift is found (exit code 2), it uploads the plan artifact, sends a **Slack webhook** alert, and fails the job. Apply remains a separate, approved step.

---

## Terraform plan exit codes (`-detailed-exitcode`)

When you run:

```bash
terraform plan -detailed-exitcode -out=tfplan
```

Terraform uses the following exit codes:

| Exit code | Meaning | Typical action |
|-----------|---------|----------------|
| **0** | No changes. State matches the real infrastructure. | Success; no action. |
| **1** | Error. Plan failed (e.g. provider error, backend/state error, invalid config). | Fix the error; re-run. |
| **2** | Changes present. State and real infrastructure differ (drift). | Review plan; fix drift or apply approved changes. |

Without `-detailed-exitcode`, Terraform exits 0 when there are changes (and 1 only on error). With `-detailed-exitcode`, **2** is reserved for “changes present” so CI can distinguish “no drift” (0) from “drift” (2) without parsing output.

---

## Nightly workflow

**Location:** `../../ci-cd/github-actions/terraform-drift.yml`

- **Schedule:** `0 0 * * *` (nightly at 00:00 UTC). Also `workflow_dispatch` for on-demand runs.
- **Steps:** Checkout → Configure AWS (OIDC or keys) → Terraform init (optional backend config from secret) → **terraform plan -detailed-exitcode -out=tfplan**.
- **On exit code 2 (drift):** Upload `tfplan` as artifact (14 days), post to Slack webhook (`SLACK_WEBHOOK_URL_DRIFT`), then fail the job.
- **On exit code 1:** Job fails (plan error).

**Secrets / variables:**

- `AWS_ROLE_ARN_DRIFT` (or AWS keys) for Terraform backend and provider.
- `SLACK_WEBHOOK_URL_DRIFT` — Slack incoming webhook URL; if unset, drift is still detected and job fails but no Slack post.
- `TF_BACKEND_CONFIG` (optional) — Backend config file content (e.g. bucket, key, region).
- `TF_DRIFT_DIR` (var) — Terraform directory to check (default `terraform/org-guardrails`).
- `AWS_REGION` (var, optional).

---

## Contents

- **Workflow:** `ci-cd/github-actions/terraform-drift.yml` — nightly run, plan, artifact, Slack on drift.
- **Script:** `drift-check.sh` — example script for local or other CI; exits 2 on drift.

## Prerequisites

- Terraform state in S3 (and DynamoDB lock if used); CI identity with read access to state (e.g. OIDC role with `s3:GetObject`).
- Terraform and AWS CLI in the runner.

## References

- `../../architecture/system-design.md` (drift detection)
- `../../ci-cd/github-actions/README.md` (workflow list)
