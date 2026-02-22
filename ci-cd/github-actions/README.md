# GitHub Actions (CI/CD) — Supply Chain Security

**Purpose:** Workflows for secure SDLC: secret scan, SAST, IaC scan, container scan, SBOM, and image signing. Use `supply-chain-full.yml` as the single pipeline that runs all stages and **fails on critical CVEs** and secrets.

## Workflows

| Workflow | Purpose | When it fails |
|----------|---------|----------------|
| **secret-scan.yml** | Pre-commit/PR secret scan (Gitleaks) | Any secret detected |
| **sast-semgrep.yml** | SAST with Semgrep | Configurable (e.g. high/critical) |
| **checkov-terraform.yml** | Checkov Terraform scan | Misconfig (medium+ by default) |
| **conftest-terraform.yml** | OPA/Rego Terraform policy (Conftest) | Deny public S3, wildcard IAM, encryption, remote state |
| **trivy-container.yml** | Trivy container image scan | CRITICAL/HIGH CVEs (exit-code 1) |
| **sbom-syft.yml** | SBOM generation (Syft, CycloneDX) | — |
| **cosign-sign.yml** | Cosign image signing | — (manual or after build) |
| **supply-chain-full.yml** | All stages in one pipeline | Secrets, critical/high CVEs, Checkov |
| **terraform-drift.yml** | Nightly Terraform drift (plan -detailed-exitcode) | Exit 2 = drift; Slack alert, plan artifact |

## Stage summary (with comments in each file)

- **Secret scan:** Prevents committed secrets; fail early so keys can be rotated before merge.
- **Semgrep SAST:** Finds code-level issues (injection, hardcoded secrets, unsafe patterns) before runtime.
- **Checkov:** Terraform misconfig (unencrypted storage, open SG, missing logging) so bad infra is not applied.
- **Conftest:** Custom Rego policies (deny public S3, wildcard IAM, require encryption, remote state); run against plan and .tf.
- **Trivy container:** CVE and misconfig in image; we fail on CRITICAL/HIGH so vulnerable images don’t deploy.
- **SBOM (Syft):** Software bill of materials for audit and vulnerability correlation.
- **Cosign:** Sign images so only trusted artifacts are deployable; admission verifies signature.
- **Terraform drift (nightly):** `terraform plan -detailed-exitcode`; on exit 2 (drift) upload plan artifact and notify Slack; exit codes documented in `terraform/drift-detection/README.md`.

## Security

- No long-lived secrets in repo; use OIDC for AWS; GitHub secrets for cosign key (or keyless with Fulcio).
- Pipeline identity scoped to minimal permissions.

## References

- `../../architecture/system-design.md` (Secure SDLC)
- `../sbom/` for SBOM format and storage
