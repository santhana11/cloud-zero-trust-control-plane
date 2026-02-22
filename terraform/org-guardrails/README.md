# Org Guardrails (SCP, Config, GuardDuty)

**Purpose:** Organization-level guardrails: SCPs to limit what accounts can do, AWS Config for compliance and drift, and GuardDuty for threat detection. Deployed from the **management account** or a dedicated security account.

## Contents

- **SCP (Service Control Policies):** Deny or constrain high-risk actions (e.g. leave org, disable Config, change GuardDuty) and enforce guardrails (e.g. require MFA for sensitive APIs).
- **Config:** Rules for desired state (e.g. EBS encryption, S3 public block, IAM password policy); optional conformance pack (e.g. CIS). Aggregator in management account.
- **GuardDuty:** Enabled org-wide; delegated admin if using a security account; findings to Security Hub.

## Prerequisites

- AWS Organizations with management account access.
- Permissions to attach SCPs, enable Config and GuardDuty.

## Usage

```bash
terraform init
terraform plan -out=tfplan
# Review; then apply from secure pipeline or with break-glass role
terraform apply tfplan
```

## State

- Remote backend (S3 + DynamoDB) in management account; state encrypted; access restricted.
- Do not store credentials in repo; use OIDC or assumed role for CI.

## References

- `../../architecture/system-design.md`
- `../../compliance/cis-mapping.md`
