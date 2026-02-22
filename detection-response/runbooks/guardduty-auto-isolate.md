# Runbook: GuardDuty Automated Isolate (Phase 6)

**Trigger:** GuardDuty generates a high-severity finding → automation quarantines the EC2 instance, creates snapshots, and notifies SNS. This runbook covers the **event flow**, **containment strategy**, and **human follow-up**.

---

## Event Flow

```
GuardDuty (finding)
    → EventBridge (rule: severity >= threshold)
    → Lambda (quarantine logic)
    → Quarantine EC2 (replace SGs with no-egress SG)
    → Snapshot (EBS volumes for forensics)
    → Notify SNS (alert for human review)
```

| Step | What happens |
|------|----------------|
| **GuardDuty** | Detects threat (e.g. C2, crypto mining, credential abuse) and emits a finding to EventBridge. |
| **EventBridge** | Rule matches `source: aws.guardduty`, `detail-type: GuardDuty Finding`, and e.g. `severity >= 7`. Forwards event to Lambda. |
| **Lambda** | Extracts EC2 instance ID from the finding; replaces instance security groups with the **quarantine SG** (no ingress, no egress); creates **EBS snapshots** of all attached volumes; publishes a **summary to SNS**. |
| **SNS** | Delivers message to subscribers (email, Slack, PagerDuty) so on-call can triage and follow this runbook. |

**Artifacts:** Quarantine SG ID, Lambda role, and EventBridge rule are defined in `../guardduty-quarantine-lambda/` (Terraform + Python).

---

## Containment Strategy

**Why this order (Quarantine → Snapshot → Notify)?**

1. **Quarantine first**  
   Stop the instance from talking to the internet or other hosts. Replacing its security groups with a **no-egress** group immediately contains lateral movement and exfiltration. The instance stays running so we can snapshot it; we do not rely on the attacker “going quiet” while we investigate.

2. **Snapshot second**  
   Before terminating or changing the instance further, we **preserve evidence**: EBS snapshots of all volumes, tagged (e.g. `GuardDutyQuarantine`, `SourceInstance`). Forensics and root-cause analysis can use these later. The Lambda creates snapshots right after quarantine so the disk state is as close as possible to the moment of detection.

3. **Notify last**  
   After automated containment and evidence preservation, we **notify humans** (SNS). The message includes finding ID, instance ID, severity, and what was done (quarantine applied, snapshot IDs). Humans then triage (true vs false positive), investigate, and decide restore or terminate per sections below.

**Containment = limit blast radius and preserve evidence, then hand off to people.** Automation does not terminate the instance; that decision is intentional (avoid destroying evidence or a false positive).

---

## 1. Detection

- **SNS/email/Slack:** “GuardDuty auto-response: instance i-xxxxx quarantined” (or “FAILED: …”).
- **GuardDuty console:** Open the finding by ID from the SNS payload; note type, resource, account, region, time.

---

## 2. Triage

- Open the GuardDuty finding; note **finding type**, **resource ID**, **account**, **time**.
- Decide: **True positive** (compromised) vs **False positive** (e.g. authorized tooling, expected behavior).
- **If false positive:** Proceed to **Recovery / Restore** and add an exception or tune the Lambda/EventBridge rule to avoid recurrence.

---

## 3. Containment (already done by automation)

- **Instance:** Security groups were replaced with the quarantine SG (no ingress, no egress). Instance is isolated.
- **Snapshots:** EBS snapshots were created and tagged; use them for forensics before any termination.
- No further automated action; human decides next step (investigate, restore, or terminate).

---

## 4. Investigation

- Use the **snapshots** created by the Lambda for forensics (mount in a separate forensics instance if needed).
- Review **CloudTrail** for the instance and IAM activity in the time window before the finding.
- Document timeline and scope for post-mortem. If confirmed malicious, proceed to Recovery (terminate + rotate secrets).

---

## 5. Recovery / Restore

- **If false positive:** Restore the instance: attach the **original security groups** (from change history or backup), document the exception, and tune GuardDuty or the EventBridge rule to reduce future false positives.
- **If true positive:** Do **not** restore. Terminate the instance after forensics; rotate all secrets that may have been on it; notify per policy (security, compliance, or customers as required).

---

## 6. Post-Incident

- Update this runbook if steps were wrong or missing.
- Consider tuning GuardDuty severity threshold or finding-type filters and the Lambda (e.g. DRY_RUN, MIN_SEVERITY) to balance safety and false positives.
- Share a short summary with security and platform teams.

---

## References

- `../guardduty-quarantine-lambda/` — Lambda code, IAM, EventBridge rule, quarantine SG.
- [GuardDuty finding types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types.html)
- `../../architecture/system-design.md` (Detection and response)
