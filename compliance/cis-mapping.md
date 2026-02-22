# CIS AWS Foundations Mapping

**Version:** 1.1  
**Purpose:** Map platform controls to CIS AWS Foundations Benchmark (v2) for audit evidence and gap closure. Used with the security scorecard and evidence automation.

---

## 1. Scope

- **In scope:** Management and workload account controls implemented via this repo (Terraform, Config, GuardDuty, IAM, EKS, SCPs, drift detection, supply chain).
- **Out of scope:** Application-layer and business logic; some CIS controls are partially or fully owned by other teams (e.g. password policy in IdP, database encryption in app).

---

## 2. CIS AWS Mapping Table

| CIS ID | Recommendation | How we implement it | Evidence / artifact |
|--------|----------------|---------------------|----------------------|
| **1.1** | Avoid use of root account | SCP and policy; no root keys; alert on root use | Config rule, CloudTrail |
| **1.2** | Ensure MFA for root (if used) | MFA enabled; root not used for daily ops | IAM, Config |
| **1.3** | Ensure MFA for IAM users | Enforced in IdP/SSO; no long-lived user keys for automation | IAM Identity Center, Config |
| **1.4** | Rotate access keys | No keys for automation (IRSA, OIDC); user keys rotated per policy | Policy, Config (optional) |
| **1.5** | No root API keys | No root keys; automation uses roles | IAM, CloudTrail |
| **1.6** | IAM policies only as needed | Permission boundary, SCPs (deny wildcard IAM), least-privilege roles | Terraform (org-guardrails), IAM |
| **2.1.1** | AWS Config enabled | Config recorder and delivery channel (config-rules) | Terraform, Config console |
| **2.1.2** | Config rules | Managed and custom rules; remediation where safe | Terraform, Config compliance dashboard |
| **2.1.3** | Config remediation | Lambda remediation for approved rules | Terraform, Config |
| **3.1** | GuardDuty enabled | Org-wide GuardDuty (org-guardrails) | Terraform, GuardDuty console |
| **3.2** | GuardDuty in all regions | Org-level GuardDuty with member accounts | Terraform, GuardDuty |
| **3.3** | GuardDuty findings protected | Findings in GuardDuty; export to S3 if needed | GuardDuty, S3 lifecycle |
| **4.1** | EBS encryption | Config rule + Terraform default encryption; require_encryption (OPA) | Config, Terraform, Conftest |
| **4.2** | EBS public snapshot | Config rule; no public snapshots | Config |
| **4.3** | EBS volume encryption | Terraform + Config; OPA require_encryption | Terraform, Config |
| **5.1** | No root API keys | No root keys; automation uses roles | IAM, CloudTrail |
| **5.2** | MFA delete for S3 | Bucket policy / versioning; optional MFA delete | Terraform, S3 |
| **5.3** | S3 bucket encryption | Terraform server_side_encryption; OPA require_encryption | Terraform, Conftest |
| **5.4** | S3 block public access | SCP deny public S3; Block Public Access account setting | Terraform (scp-deny-guardrails), S3 |
| **6.1** | S3 access logging | Enable logging for sensitive buckets | Terraform |
| **6.2** | S3 bucket versioning | Versioning for state and critical buckets | Terraform |
| **7.1** | EBS default encryption | Account default + Terraform; Config rule | Terraform, Config |
| **8.1** | RDS encryption | Terraform storage_encrypted; OPA require_encryption | Terraform, Conftest |
| **—** | Drift detection | Nightly terraform plan -detailed-exitcode; Slack on drift | CI (terraform-drift.yml), artifacts |
| **—** | Supply chain / SBOM | SBOM (CycloneDX), image signing, CVE gate | CI (sbom-syft, trivy, cosign) |
| **—** | Logging / audit | CloudTrail (SCP deny delete); Config; GuardDuty | CloudTrail, Config, GuardDuty |

*CIS section numbering may vary by benchmark version; align to your adopted CIS v2.x PDF. “—” denotes platform controls that support CIS themes (integrity, visibility) but may not map to a single CIS ID.*

---

## 3. Evidence Location

- **Config:** AWS Config console or aggregator; compliance report export; automated via `evidence-automation.md`.
- **GuardDuty:** GuardDuty console; findings and delegation; automation (quarantine Lambda) and runbooks.
- **Terraform:** State and code in this repo; plan/apply in CI; drift workflow and Conftest.
- **IAM:** IAM console and CloudTrail for AssumeRole and API calls; permission boundary and SCPs in Terraform.
- **CI/CD:** GitHub Actions artifacts (SBOM, plan); SARIF for SAST/Trivy; see `evidence-automation.md`.

---

## 4. Gaps and Ownership

- **Gap:** [List any CIS controls not yet implemented and owner.]
- **Review:** Quarterly or on major scope change; update this doc, security scorecard, and architecture/threat-model as needed.

---

## 5. Related Compliance Docs

- **Risk scoring:** `risk-scoring.md`
- **Security scorecard:** `security-scorecard.md`
- **Evidence automation:** `evidence-automation.md`

## 6. References

- CIS AWS Foundations Benchmark v2.x (https://www.cisecurity.org)
- `../architecture/system-design.md`
- `../architecture/zero-trust-mapping.md`
- `../terraform/org-guardrails/`, `../terraform/config-rules/`
