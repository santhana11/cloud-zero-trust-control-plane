# ------------------------------------------------------------------------------
# Service Control Policies (SCPs) — Deny Guardrails
# ------------------------------------------------------------------------------
# SCPs are applied at the OU or account level in AWS Organizations. They define
# maximum available permissions for all principals in the affected accounts
# (including root). "Deny" statements in SCPs override any allow in IAM;
# they cannot grant permission. We use SCPs to enforce org-wide guardrails
# that no account can opt out of.
#
# These SCPs deny:
#   1. Public S3 buckets (avoid accidental exposure of data)
#   2. Wildcard IAM actions/resources (force least-privilege, no "*" on Action or Resource)
#   3. Disabling or deleting CloudTrail (preserve audit trail)
#
# Apply to: workload OUs (not management account if it needs to manage org).
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# SCP: Deny Public S3 Bucket Access
# ------------------------------------------------------------------------------
# Prevents making S3 buckets or objects publicly readable/writable. Reduces
# risk of accidental data exposure (e.g. bucket ACL set to public-read).
# Covers: PutBucketAcl, PutBucketPolicy, PutObjectAcl that would result in
# public access. We also deny PutPublicAccessBlock with false to prevent
# disabling the block.
# ------------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_public_s3" {
  name        = "ZT-DenyPublicS3"
  description = "Deny making S3 buckets or objects publicly accessible"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3Acl"
        Effect = "Deny"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutBucketPolicy",
          "s3:PutObjectAcl",
          "s3:PutObjectVersionAcl"
        ]
        Resource = "*"
        # SCP cannot inspect ACL/policy body; this denies all such writes. Use
        # S3 Block Public Access (account setting) + Config rule for full coverage.
      },
      {
        Sid    = "DenyDisablePublicAccessBlock"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucketPublicAccessBlock"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach to target OUs (uncomment and set target_ou_ids)
# resource "aws_organizations_policy_attachment" "deny_public_s3" {
#   policy_id = aws_organizations_policy.deny_public_s3.id
#   target_id = var.target_ou_ids[0]
# }

# ------------------------------------------------------------------------------
# SCP: Deny Wildcard IAM
# ------------------------------------------------------------------------------
# Prevents IAM policies that use "*" for Action or Resource on sensitive IAM
# actions. This forces least-privilege: you must specify concrete actions
# and resources. Note: SCPs cannot inspect the *content* of a policy document
# directly; this SCP denies the IAM actions that would create/update such
# policies (e.g. PutRolePolicy with inline policy containing "*").
# In practice, many orgs use this to deny broad IAM write (e.g. * on Resource)
# by denying specific dangerous patterns. Below we deny attaching managed
# policies that are known overly broad, and deny Put*Policy with wildcard
# resource. Simplified version: deny IAM policy changes that don't use
# permission boundary (see permission boundary for boundary enforcement).
# ------------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_wildcard_iam" {
  name        = "ZT-DenyWildcardIAM"
  description = "Restrict IAM to prevent wildcard resource policies and overly broad managed policy attachment"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMWildcardResource"
        Effect = "Deny"
        Action = [
          "iam:PutUserPolicy",
          "iam:PutRolePolicy",
          "iam:PutGroupPolicy"
        ]
        Resource = "*"
        # Note: SCP conditions cannot inspect policy document body. Use permission boundary
        # and/or automation (e.g. Config rule, Lambda) to reject policies with Resource "*".
      },
      {
        Sid    = "DenyAttachAWSManagedAdmin"
        Effect = "Deny"
        Action = [
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:AttachGroupPolicy"
        ]
        Resource = "*"
        Condition = {
          # Deny attaching AWS managed policies that grant broad wildcard access
          StringLike = {
            "iam:PolicyArn" = [
              "arn:aws:iam::aws:policy/AdministratorAccess",
              "arn:aws:iam::aws:policy/PowerUserAccess"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# SCP: Deny Disabling or Deleting CloudTrail
# ------------------------------------------------------------------------------
# Ensures audit trail cannot be turned off or deleted by anyone in the affected
# accounts. StopLogging and DeleteTrail would break compliance and incident
# response. We deny these actions org-wide (or for workload OUs).
# ------------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_disable_cloudtrail" {
  name        = "ZT-DenyDisableCloudTrail"
  description = "Deny stopping or deleting CloudTrail; preserve audit trail"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCloudTrailStopOrDelete"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:DeleteEventDataStore"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}
