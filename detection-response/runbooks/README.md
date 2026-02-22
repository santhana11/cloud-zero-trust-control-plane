# Runbooks

**Purpose:** Documented procedures for security and platform incidents. Updated post-incident and exercised periodically.

## Contents

- **GuardDuty automated isolate:** What was isolated, how to investigate, how to restore (or terminate) after decision.
- **Credential compromise:** Revoke key/user; rotate secrets; audit access; notify if required.
- **Malicious or vulnerable image in cluster:** Identify affected pods; cordon/drain or scale to zero; replace with patched image; post-mortem.
- **Terraform/Config drift:** Who can approve apply; how to run plan and apply safely; rollback.
- **Data exposure or cross-tenant access:** Contain (e.g. revoke access); assess scope; notify per policy; fix control gap.

## Format

- One markdown file per runbook. Sections: Detection, Triage, Containment, Eradication, Recovery, Post-Incident.

## References

- `../../architecture/system-design.md`
- `../../architecture/threat-model.md`
