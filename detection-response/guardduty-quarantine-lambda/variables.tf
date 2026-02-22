variable "finding_types" {
  type        = list(string)
  description = "GuardDuty finding type IDs that trigger response (e.g. Backdoor:EC2/C&CActivity.B!DNS)"
  default     = []
}

variable "severity_threshold" {
  type        = number
  description = "Minimum severity (1-8) to trigger automated response"
  default     = 7
}

variable "action" {
  type        = string
  description = "Action to take: isolate_ec2 | revoke_key | notify_only"
  default     = "notify_only"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic for notifications"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default     = {}
}
