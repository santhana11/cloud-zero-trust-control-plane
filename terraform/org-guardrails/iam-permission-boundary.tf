# ------------------------------------------------------------------------------
# IAM Permission Boundary
# ------------------------------------------------------------------------------
# A permission boundary is an IAM policy (managed or inline) that defines the
# MAXIMUM permissions any IAM identity (user or role) can have. It is attached
# to users/roles and caps what they can do, even if their attached policies
# grant more. This prevents privilege escalation: e.g. a role cannot grant
# itself or others more than the boundary allows.
#
# Use case: Apply this boundary to all IAM roles/users created in workload
# accounts so that even admins cannot accidentally (or maliciously) create
# identities with more power than the boundary allows (e.g. no org-level
# or cross-account escalation).
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "zt_permission_boundary" {
  name        = "ZTPermissionBoundary"
  description = "Maximum permissions for IAM identities in workload accounts; prevents escalation beyond this scope."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRequiredServices"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "s3:Get*",
          "s3:List*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyOrgAndAccountEscalation"
        Effect = "Deny"
        Action = [
          "organizations:*",
          "iam:CreateUser",
          "iam:CreateRole",
          "iam:PutUserPolicy",
          "iam:PutRolePolicy",
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "iam:PermissionBoundary" = aws_iam_policy.zt_permission_boundary.arn
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Output for use when creating roles/users: attach this as permission boundary.
output "permission_boundary_arn" {
  value       = aws_iam_policy.zt_permission_boundary.arn
  description = "ARN of the permission boundary policy; attach to IAM roles/users in workload accounts."
}
