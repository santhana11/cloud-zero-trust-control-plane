output "lambda_role_arn" {
  value       = aws_iam_role.guardduty_quarantine.arn
  description = "IAM role ARN for the GuardDuty quarantine Lambda"
}

output "quarantine_security_group_id" {
  value       = var.vpc_id != "" ? aws_security_group.quarantine[0].id : null
  description = "Security group ID to use as QUARANTINE_SG_ID in Lambda env"
}

output "eventbridge_rule_arn" {
  value       = aws_cloudwatch_event_rule.guardduty_finding.arn
  description = "EventBridge rule ARN (GuardDuty finding → Lambda)"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.guardduty_quarantine.arn
  description = "Lambda function ARN (GuardDuty quarantine)"
}
