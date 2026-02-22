variable "cluster_name" {
  type        = string
  description = "EKS cluster name (for OIDC trust)"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (without https://)"
}

variable "service_accounts" {
  type = list(object({
    namespace = string
    name      = string
    role_name = string
    policy    = string
  }))
  description = "List of namespace, SA name, role name, and policy JSON for each IRSA role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default     = {}
}
