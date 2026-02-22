# ------------------------------------------------------------------------------
# EventBridge Rule — GuardDuty Finding → Lambda (Phase 6)
# ------------------------------------------------------------------------------
# Event flow: GuardDuty emits finding → EventBridge rule matches → invokes Lambda.
# Rule filters by source (aws.guardduty), detail-type (GuardDuty Finding), and
# optionally severity or finding type. One event per finding.
# ------------------------------------------------------------------------------

variable "eventbridge_rule_enabled" {
  type        = bool
  description = "Set to true to enable the EventBridge rule (disable for dry-run or testing)"
  default     = true
}

# GuardDuty sends findings to EventBridge in the same region. Event structure:
# { "source": "aws.guardduty", "detail-type": "GuardDuty Finding", "detail": { ... } }
resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name_prefix         = "zt-guardduty-quarantine-"
  description         = "High-severity GuardDuty findings trigger quarantine Lambda"
  event_bus_name      = "default"
  is_enabled          = var.eventbridge_rule_enabled
  schedule_expression = null
  # Match all GuardDuty findings; Lambda filters by MIN_SEVERITY (e.g. 7+).
  # To filter in the rule, use detail.severity with a list of values (see AWS GuardDuty EventBridge docs).
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "GuardDutyQuarantineLambda"
  arn       = aws_lambda_function.guardduty_quarantine.arn
}

# Allow EventBridge to invoke the Lambda
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty_quarantine.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_finding.arn
}
