# Risk Scoring Example (Phase 8)

**Purpose:** Define a simple, repeatable way to score and compare risks for prioritization and reporting. This is an **example** framework; adjust thresholds and scales to match your risk appetite and audit needs.

---

## 1. Scoring Model

We use a **Likelihood × Impact** grid. Each dimension is scored 1–5; the product gives a **risk score** (1–25). Optionally map the score to a **rating** (e.g. Low / Medium / High / Critical) for dashboards and scorecards.

| Dimension | 1 | 2 | 3 | 4 | 5 |
|-----------|---|---|---|---|---|
| **Likelihood** | Rare | Unlikely | Possible | Likely | Almost certain |
| **Impact** | Negligible | Minor | Moderate | Major | Severe |

**Risk score = Likelihood × Impact**

| Score | Rating | Typical action |
|-------|--------|----------------|
| 1–4 | Low | Accept or track; no immediate action. |
| 5–9 | Medium | Plan remediation; document acceptance if deferred. |
| 10–16 | High | Remediate within agreed SLA; escalate. |
| 17–25 | Critical | Immediate remediation; leadership visibility. |

---

## 2. Example: Scoring a Few Risks

| Risk / finding | Likelihood | Impact | Score | Rating |
|----------------|------------|--------|-------|--------|
| Unencrypted S3 bucket in dev | Possible (3) | Minor (2) | 6 | Medium |
| GuardDuty C2 finding on prod EC2 | Rare (1) | Severe (5) | 5 | Medium |
| Terraform drift (unknown change in prod) | Possible (3) | Major (4) | 12 | High |
| No MFA on root account | Unlikely (2) | Severe (5) | 10 | High |
| Critical CVE in production image | Possible (3) | Major (4) | 12 | High |
| Missing SBOM for legacy image | Likely (4) | Minor (2) | 8 | Medium |

**Notes:**

- **Likelihood** can be informed by past events, threat intel, or control strength (e.g. “we have GuardDuty and auto-quarantine” may reduce likelihood of prolonged C2).
- **Impact** can reflect data sensitivity, availability, regulatory (e.g. PII, PCI), and reputation.
- Adjust definitions of 1–5 per domain (e.g. “Severe” = data breach, regulatory fine, or full env compromise).

---

## 3. Using Scores in the Scorecard

- **Aggregate:** e.g. “% of open findings that are High/Critical” or “average risk score of open items.”
- **Trend:** Track score over time (e.g. quarterly) to show improvement or new risks.
- **Prioritization:** Sort backlog by score (or rating) for remediation order.

---

## 4. References

- `security-scorecard.md` — where risk score or rating can appear per control/finding.
- `../architecture/system-design.md` (Residual risks)
- `../architecture/threat-model.md` (STRIDE)
