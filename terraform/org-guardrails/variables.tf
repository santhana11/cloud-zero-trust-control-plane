variable "organization_id" {
  type        = string
  description = "AWS Organization ID (management account)"
}

variable "target_ou_ids" {
  type        = list(string)
  description = "OU IDs where SCP and Config apply (e.g. workload OUs)"
  default     = []
}

variable "enable_guardduty" {
  type        = bool
  description = "Enable GuardDuty org-wide"
  default     = true
}

variable "config_aggregator_name" {
  type        = string
  description = "Name for Config aggregator"
  default     = "zt-org-config-aggregator"
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default     = {}
}
