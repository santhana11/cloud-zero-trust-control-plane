variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for EKS"
  default     = "1.28"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private subnets (e.g. for nodes)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Use private API endpoint only (no public)"
  default     = false
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of nodes in default node group"
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default     = {}
}
