# ------------------------------------------------------------------------------
# IRSA — IAM Roles for Service Accounts (EKS)
# ------------------------------------------------------------------------------
# IRSA allows a Kubernetes ServiceAccount to assume an IAM role without storing
# long-lived credentials in the cluster. The EKS OIDC provider issues tokens
# that AWS STS trusts; the pod exchanges the token for temporary credentials.
#
# Why IRSA:
#   - No access keys in Secrets or env; eliminates key theft and rotation burden.
#   - Least privilege: each role is scoped to one namespace + service account.
#   - Audit: CloudTrail shows AssumeRoleWithWebIdentity with role ARN (and
#     session name can include SA/namespace), so we know which workload did what.
#
# This file creates one IAM role per service account with a trust policy
# that allows only that SA in that namespace to assume the role.
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# OIDC trust policy (reusable)
# ------------------------------------------------------------------------------
# The role can only be assumed by pods that have the specified ServiceAccount
# in the specified namespace. EKS injects the OIDC token with the SA claim;
# we restrict by audience (sts.amazonaws.com) and subject (system:serviceaccount:ns:sa).
# ------------------------------------------------------------------------------
locals {
  # Build list of role + trust policy per service account
  irsa_roles = {
    for sa in var.service_accounts : "${sa.namespace}/${sa.name}" => {
      namespace  = sa.namespace
      name       = sa.name
      role_name  = sa.role_name
      policy     = sa.policy
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles

  name        = each.value.role_name
  description = "IRSA role for EKS SA ${each.value.namespace}/${each.value.name}"

  # Only the specified ServiceAccount in the specified namespace can assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    "zero-trust.io/irsa-namespace" = each.value.namespace
    "zero-trust.io/irsa-sa"       = each.value.name
  })
}

# Inline policy for the role (least privilege: only what this workload needs).
resource "aws_iam_role_policy" "irsa" {
  for_each = local.irsa_roles

  name   = "${each.value.role_name}-policy"
  role   = aws_iam_role.irsa[each.key].id
  policy = each.value.policy
}

output "irsa_role_arns" {
  value       = { for k, r in aws_iam_role.irsa : k => r.arn }
  description = "Map of namespace/name to IRSA role ARN; annotate ServiceAccount with eks.amazonaws.com/role-arn"
}
