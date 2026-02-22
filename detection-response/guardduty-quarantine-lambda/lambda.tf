# ------------------------------------------------------------------------------
# Lambda Function — GuardDuty Quarantine (Phase 6)
# ------------------------------------------------------------------------------
# Package: lambda_function.py (and optional dependencies). Set QUARANTINE_SG_ID
# and SNS_TOPIC_ARN from outputs/variables. EventBridge invokes this on GuardDuty finding.
# ------------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "guardduty_quarantine" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "zt-guardduty-quarantine"
  role             = aws_iam_role.guardduty_quarantine.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  environment {
    variables = {
      QUARANTINE_SG_ID = var.vpc_id != "" ? aws_security_group.quarantine[0].id : ""
      SNS_TOPIC_ARN    = var.sns_topic_arn
      MIN_SEVERITY     = tostring(var.severity_threshold)
      DRY_RUN          = var.dry_run ? "true" : "false"
    }
  }
  tags = var.tags
}

variable "dry_run" {
  type        = bool
  description = "If true, Lambda logs actions but does not modify EC2 or create snapshots"
  default     = false
}
