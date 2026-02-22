# ------------------------------------------------------------------------------
# IAM Role for GuardDuty Quarantine Lambda (Phase 6)
# ------------------------------------------------------------------------------
# Least privilege: only the permissions needed to quarantine EC2 (replace SGs),
# create EBS snapshots, tag snapshots, and publish to SNS. No broader EC2 or IAM.
# ------------------------------------------------------------------------------

resource "aws_iam_role" "guardduty_quarantine" {
  name               = "zt-guardduty-quarantine-lambda"
  description        = "Execution role for GuardDuty quarantine Lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Quarantine: replace instance security groups; describe instances/volumes; create snapshot + tags
data "aws_iam_policy_document" "guardduty_quarantine" {
  statement {
    sid    = "EC2Quarantine"
    effect = "Allow"
    actions = [
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSecurityGroups",
      "ec2:CreateSnapshot",
      "ec2:DescribeSnapshots",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = var.sns_topic_arn != "" ? [1] : []
    content {
      sid       = "SNSNotify"
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [var.sns_topic_arn]
    }
  }
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:*:*:*"]
  }
}

data "aws_partition" "current" {}

resource "aws_iam_role_policy" "guardduty_quarantine" {
  name   = "guardduty-quarantine"
  role   = aws_iam_role.guardduty_quarantine.id
  policy = data.aws_iam_policy_document.guardduty_quarantine.json
}

# Optional: SNS topic may be in same account; if empty, omit SNS statement or create topic
variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for quarantine notifications"
  default     = ""
}
