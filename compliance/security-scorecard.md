# Security Scorecard Format (Phase 8)

**Purpose:** Standard format for a **security scorecard** that summarizes control coverage, status, evidence, and (optionally) risk. Use for internal reporting, audit prep, and trend over time.

---

## 1. Scorecard Structure

Each row is a **control or control area**. Columns below are the recommended minimum; add columns (e.g. risk score, owner, last tested) as needed.

| Column | Description | Example |
|--------|-------------|---------|
| **Domain** | Category (Identity, Network, Data, Detection, etc.) | Identity |
| **Control ID** | Framework or internal ID | CIS 1.3, or GD-QUARANTINE |
| **Control name** | Short name of the control | MFA for IAM users |
| **Status** | Met / Partial / Gap / N/A | Met |
| **Evidence** | How we prove it (automated or manual) | Config rule, IdP config |
| **Owner** | Team or role responsible | Platform Security |
| **Last verified** | Date or “Continuous” if automated | 2024-01-15 or Continuous |
| **Notes** | Exceptions, scope limits, links | Prod only; dev excluded |

---

## 2. Status Definitions

| Status | Meaning |
|--------|---------|
| **Met** | Control is fully implemented and evidenced as defined. |
| **Partial** | Partially implemented (e.g. only prod) or evidence is manual/periodic. |
| **Gap** | Not implemented or no evidence; remediation planned or accepted. |
| **N/A** | Not applicable to scope (e.g. control for a service we don’t use). |

---

## 3. Example Scorecard (subset)

| Domain | Control ID | Control name | Status | Evidence | Owner | Last verified | Notes |
|--------|------------|--------------|--------|----------|-------|----------------|------|
| Identity | CIS 1.3 | MFA for IAM users | Met | IdP + Config | Platform Sec | Continuous | SSO enforced |
| Identity | CIS 1.6 | Least privilege IAM | Met | Permission boundary, SCPs | Platform Sec | Continuous | Terraform |
| Data | CIS 4.1 | EBS encryption | Met | Config + Terraform + OPA | Platform Sec | Continuous | |
| Data | CIS 5.4 | S3 block public access | Met | SCP deny public S3 | Platform Sec | Continuous | |
| Detection | — | GuardDuty + auto-response | Met | GuardDuty, Lambda, runbook | Platform Sec | Continuous | |
| Integrity | — | Terraform drift detection | Met | Nightly plan, Slack | Platform Sec | Daily | |
| Supply chain | — | SBOM + CVE gate | Met | Syft, Trivy, artifact | DevSecOps | Per build | |
| Supply chain | — | Image signing | Partial | Cosign; admission in progress | DevSecOps | Per release | Prod only |

---

## 4. Aggregated Metrics (optional)

- **Coverage:** % of in-scope controls with status Met or Partial.
- **Fully automated evidence:** % of controls where evidence is automated (see `evidence-automation.md`).
- **Open gaps:** Count (or list) of controls in Gap.
- **Risk:** Count of High/Critical open findings or average risk score (see `risk-scoring.md`).

These can be computed from the scorecard table and reported in a dashboard or executive summary.

---

## 5. How to Use

- **Refresh:** Tie scorecard to a recurring review (e.g. monthly/quarterly); update status and “Last verified” when evidence is checked or automation is confirmed.
- **Audit:** Export as CSV or table for auditors; point to `cis-mapping.md` and `evidence-automation.md` for how evidence is produced.
- **Trend:** Keep snapshots (e.g. by date) to show improvement in Met % or reduction in gaps.

---

## 6. References

- `cis-mapping.md` — CIS control mapping and implementation.
- `evidence-automation.md` — How evidence is automated.
- `risk-scoring.md` — Risk score for findings/controls.
