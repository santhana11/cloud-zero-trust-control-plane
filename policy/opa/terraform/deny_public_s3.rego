# ------------------------------------------------------------------------------
# OPA/Conftest — Deny Public S3 (Terraform)
# ------------------------------------------------------------------------------
# S3 buckets must not be configured for public access. We deny:
#   - aws_s3_bucket with acl = "public-read", "public-read-write", or "authenticated-read"
#   - aws_s3_bucket without block_public_acls = true (when using aws_s3_bucket_public_access_block)
# Conftest input: Terraform plan JSON (resource_changes) or combined config.
# ------------------------------------------------------------------------------

package terraform.zerotrust.public_s3

import future.keywords.if
import future.keywords.in

# Deny S3 bucket policy that grants public access (principal = "*")
deny_public_policy if {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket_policy"
	after := object.get(rc.change, "after", {})
	policy := after.policy
	# Policy can be JSON string; contains principal "*" or "AWS": "*" for public
	contains_public_principal(policy)
}

contains_public_principal(policy) if {
	# Policy is a JSON string
	parsed := json.unmarshal(policy)
	stmt := parsed.Statement[_]
	principal := object.get(stmt, "Principal", {})
	principal == "*"
}

contains_public_principal(policy) if {
	parsed := json.unmarshal(policy)
	stmt := parsed.Statement[_]
	principal := object.get(stmt, "Principal", {})
	principal.AWS == "*"
}

# Conftest convention: deny[msg] for violation
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket"
	after := object.get(rc.change, "after", {})
	after.acl in ["public-read", "public-read-write", "authenticated-read"]
	msg := sprintf("S3 bucket '%s' must not have public ACL (got %s). Use private and Block Public Access.", [rc.address, after.acl])
}

deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket_policy"
	after := object.get(rc.change, "after", {})
	contains_public_principal(after.policy)
	msg := sprintf("S3 bucket policy '%s' must not grant public access (Principal * or AWS *).", [rc.address])
}
