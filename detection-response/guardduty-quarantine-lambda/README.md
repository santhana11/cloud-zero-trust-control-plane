# GuardDuty Automated Response — Quarantine Lambda (Phase 6)

**Purpose:** Respond to high-severity GuardDuty findings by **quarantining** the affected EC2 instance (replace security groups with a no-egress group), **creating EBS snapshots** for forensics, and **notifying SNS**. Reduces dwell time; actions are reversible per runbook.

---

## Event Flow

```
GuardDuty (finding)
    → EventBridge (rule: GuardDuty Finding)
    → Lambda (quarantine + snapshot + notify)
    → Quarantine EC2 (replace SGs with quarantine SG)
    → Snapshot (EBS volumes)
    → Notify SNS
```

| Component | Role |
|-----------|------|
| **GuardDuty** | Emits findings to EventBridge (source: `aws.guardduty`, detail-type: `GuardDuty Finding`). |
| **EventBridge** | Rule matches all GuardDuty findings; invokes Lambda. |
| **Lambda** | Reads `event.detail` (finding); if severity ≥ threshold and resource is EC2: replace instance SGs with `QUARANTINE_SG_ID`, create snapshots of attached volumes, publish summary to `SNS_TOPIC_ARN`. |
| **Quarantine SG** | Security group with no ingress/egress; instance can’t communicate. |
| **SNS** | Alert for human triage and runbook follow-up. |

---

## Contents

- **lambda_function.py** — Python 3.12 handler: parse finding → quarantine EC2 → snapshot → SNS.
- **iam.tf** — IAM role for Lambda (EC2 modify/describe, snapshot, SNS publish, logs).
- **security-group.tf** — Quarantine security group (no ingress, no egress).
- **eventbridge.tf** — EventBridge rule (GuardDuty → Lambda) and Lambda permission.
- **lambda.tf** — Lambda function (zip from `lambda_function.py`, env: `QUARANTINE_SG_ID`, `SNS_TOPIC_ARN`, `MIN_SEVERITY`, `DRY_RUN`).
- **variables.tf** / **outputs.tf** — Inputs and outputs.

---

## Deployment

1. **Prerequisites:** GuardDuty enabled in the account/region; SNS topic for notifications; VPC ID where EC2 instances run.
2. **Variables:** Set `vpc_id`, `sns_topic_arn`; optionally `severity_threshold` (default 7), `dry_run` (default false).
3. **Apply:**  
   `terraform init && terraform apply`  
   Ensure `build/` is writable (Terraform archives `lambda_function.py` to `build/lambda.zip`).
4. **Verify:** Trigger a test finding (or use EventBridge console “Test event”) and check Lambda logs and SNS.

---

## Safety

- **Least privilege:** Lambda role only has EC2 (modify instance attribute, describe, snapshot, tag) and SNS publish.
- **No auto-terminate:** Instance is quarantined and snapshotted; human decides restore or terminate per runbook.
- **DRY_RUN:** Set `dry_run = true` (or env `DRY_RUN=true`) to log actions without modifying EC2 or creating snapshots.

---

## Runbook

See **../runbooks/guardduty-auto-isolate.md** for detection, triage, containment (already done by Lambda), investigation, recovery/restore, and post-incident. Contains **containment strategy** (why quarantine → snapshot → notify).

---

## References

- `../../architecture/system-design.md` (Detection and response)
- `../../architecture/threat-model.md` (D1)
- [GuardDuty with EventBridge](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings_cloudwatch.html)
