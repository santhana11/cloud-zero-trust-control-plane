# Config Rules (Compliance and Drift)

**Purpose:** AWS Config rules to enforce desired state and support compliance (CIS, custom). Can be deployed at org level (from org-guardrails) or per account. This module is for **account-level** Config rules when the aggregator and org GuardDuty are in management account.

## Contents

- **Config rules:** e.g. ebs-encrypted-by-default, s3-bucket-public-read-prohibited, iam-password-policy, mfa-enabled-for-iam-console-access. Use managed rules where possible; custom Lambda-backed rules for organization-specific policy.
- **Remediation:** Optional auto-remediation (e.g. enable EBS encryption on new volumes) via SSM automation or Lambda; only for low-risk, well-defined actions.
- **Conformance pack (optional):** CIS AWS Foundations or custom conformance pack for bulk rules.

## Prerequisites

- Config recorder and delivery channel already set (e.g. by org-guardrails or bootstrap).
- IAM permissions for Config and remediation actions.

## Usage

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## References

- `../../compliance/cis-mapping.md`
- `../../architecture/system-design.md` (drift detection)
