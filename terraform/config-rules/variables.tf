variable "account_id" {
  type        = string
  description = "AWS account ID (for rule scope)"
}

variable "config_rules" {
  type = map(object({
    source_identifier = string
    input_parameters  = optional(map(string), {})
  }))
  description = "Map of rule name to Config rule config"
  default     = {}
}

variable "enable_remediation" {
  type        = bool
  description = "Enable automatic remediation where defined"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default     = {}
}
