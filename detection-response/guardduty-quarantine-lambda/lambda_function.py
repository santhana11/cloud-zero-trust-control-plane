# ------------------------------------------------------------------------------
# GuardDuty Automated Response — Quarantine EC2, Snapshot, Notify (Phase 6)
# ------------------------------------------------------------------------------
# Event flow: GuardDuty → EventBridge → this Lambda → Quarantine EC2 → Snapshot → SNS
# Triggered by EventBridge rule on GuardDuty finding (e.g. severity >= 7 or specific types).
# Actions: replace instance security groups with quarantine SG (no egress), create EBS
# snapshots for forensics, publish notification to SNS.
# ------------------------------------------------------------------------------

import json
import os
import boto3
from typing import Any, Optional

# Clients (initialized on cold start)
ec2 = boto3.client("ec2")
sns = boto3.client("sns")

# Config from environment
QUARANTINE_SG_ID = os.environ.get("QUARANTINE_SG_ID", "")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
MIN_SEVERITY = int(os.environ.get("MIN_SEVERITY", "7"))
DRY_RUN = os.environ.get("DRY_RUN", "").lower() in ("1", "true", "yes")


def get_instance_id_from_finding(detail: dict) -> Optional[str]:
    """Extract EC2 instance ID from GuardDuty finding resource."""
    resource = detail.get("resource", {})
    instance_details = resource.get("instanceDetails", {})
    return instance_details.get("instanceId")


def quarantine_instance(instance_id: str) -> dict:
    """Replace instance security groups with quarantine SG (no egress)."""
    if not QUARANTINE_SG_ID:
        raise ValueError("QUARANTINE_SG_ID not set")
    return ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[QUARANTINE_SG_ID],
        DryRun=DRY_RUN,
    )


def create_snapshots_for_instance(instance_id: str) -> list[dict]:
    """Create EBS snapshots for all volumes attached to the instance (for forensics)."""
    if DRY_RUN:
        return []
    desc = ec2.describe_instances(InstanceIds=[instance_id])
    instances = desc.get("Reservations", [{}])[0].get("Instances", [])
    if not instances:
        return []
    volumes = [b["Ebs"]["VolumeId"] for b in instances[0].get("BlockDeviceMappings", []) if "Ebs" in b]
    snapshots = []
    for vol_id in volumes:
        snap = ec2.create_snapshot(
            VolumeId=vol_id,
            Description=f"GuardDuty quarantine forensics - instance {instance_id}",
            TagSpecifications=[
                {
                    "ResourceType": "snapshot",
                    "Tags": [
                        {"Key": "GuardDutyQuarantine", "Value": "true"},
                        {"Key": "SourceInstance", "Value": instance_id},
                    ],
                }
            ],
        )
        snapshots.append({"VolumeId": vol_id, "SnapshotId": snap.get("SnapshotId", "pending")})
    return snapshots


def notify_sns(
    finding_id: str,
    finding_type: str,
    severity: float,
    instance_id: str,
    snapshots: list[dict],
    quarantined: bool,
    error: Optional[str] = None,
) -> None:
    """Publish summary to SNS for human review and runbook follow-up."""
    if not SNS_TOPIC_ARN:
        return
    subject = f"GuardDuty auto-response: {instance_id} quarantined" if quarantined else f"GuardDuty auto-response FAILED: {instance_id}"
    body = {
        "summary": "GuardDuty automated containment",
        "findingId": finding_id,
        "findingType": finding_type,
        "severity": severity,
        "instanceId": instance_id,
        "actions": {
            "quarantine": "applied" if quarantined else "skipped or failed",
            "snapshots": snapshots,
        },
        "error": error,
        "dryRun": DRY_RUN,
    }
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject[:100],
        Message=json.dumps(body, indent=2),
    )


def lambda_handler(event: dict, context: Any) -> dict:
    """
    Entrypoint. Expects EventBridge event with GuardDuty finding in event.detail.
    One invocation = one finding (EventBridge rule matches one finding at a time).
    """
    results = {"processed": 0, "quarantined": [], "errors": []}
    detail = event.get("detail") or {}
    if not detail.get("id"):
        return {"statusCode": 200, "body": json.dumps({"skipped": "no GuardDuty finding in event"})}

    for detail in [detail]:
        if not detail or not detail.get("id"):
            continue
        finding_id = detail.get("id", "")
        finding_type = detail.get("type", "")
        severity = float(detail.get("severity", 0))
        if severity < MIN_SEVERITY:
            continue
        instance_id = get_instance_id_from_finding(detail)
        if not instance_id:
            results["errors"].append({"findingId": finding_id, "reason": "no EC2 instance in finding"})
            continue
        results["processed"] += 1
        quarantined = False
        snapshots = []
        err_msg = None
        try:
            if QUARANTINE_SG_ID and not DRY_RUN:
                quarantine_instance(instance_id)
                quarantined = True
            elif DRY_RUN:
                quarantined = True  # report as "would quarantine"
            snapshots = create_snapshots_for_instance(instance_id)
        except Exception as e:
            err_msg = str(e)
            results["errors"].append({"instanceId": instance_id, "error": err_msg})
        notify_sns(finding_id, finding_type, severity, instance_id, snapshots, quarantined, err_msg)
        results["quarantined"].append({"instanceId": instance_id, "snapshots": [s.get("SnapshotId") for s in snapshots]})

    return {"statusCode": 200, "body": json.dumps(results)}
