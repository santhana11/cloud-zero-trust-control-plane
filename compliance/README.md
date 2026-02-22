# Compliance Layer (Phase 8)

**Purpose:** Map controls to frameworks, score risk, maintain a security scorecard, and document how evidence is automated for audit and internal reporting.

---

## Contents

| Document | Purpose |
|----------|---------|
| **cis-mapping.md** | CIS AWS Foundations mapping table: which platform controls implement which CIS recommendations and where evidence lives. |
| **risk-scoring.md** | Risk scoring example (Likelihood × Impact, 1–5 scale); example scores and how to use them in the scorecard. |
| **security-scorecard.md** | Security scorecard format (domain, control ID, status, evidence, owner, last verified) and example rows. |
| **evidence-automation.md** | How we automate evidence (Config, GuardDuty, Terraform drift, CI artifacts, CloudTrail) and what remains manual. |

---

## Quick Links

- **CIS controls:** See `cis-mapping.md` for the full mapping table.
- **Scorecard:** Use the format in `security-scorecard.md`; fill status and evidence from implementation and `evidence-automation.md`.
- **Risk:** Use `risk-scoring.md` to score findings or controls; add risk column to scorecard if desired.
- **Audit:** Point auditors to `evidence-automation.md` and the evidence locations in `cis-mapping.md`.

---

## References

- `../architecture/system-design.md`
- `../architecture/threat-model.md`
- `../ci-cd/github-actions/` (drift, policy, scans)
