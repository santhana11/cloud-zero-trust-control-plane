# ------------------------------------------------------------------------------
# OPA/Conftest — Require Encryption (Terraform)
# ------------------------------------------------------------------------------
# Enforce encryption at rest:
#   - aws_s3_bucket: must have server_side_encryption_configuration (or default encryption)
#   - aws_ebs_volume: encrypted = true
#   - aws_rds_cluster / aws_db_instance: storage_encrypted = true
#   - aws_dynamodb_table: server_side_encryption enabled
# Conftest input: Terraform plan JSON (resource_changes).
# ------------------------------------------------------------------------------

package terraform.zerotrust.encryption

import future.keywords.if

# S3: server_side_encryption_configuration must be set
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket"
	after := object.get(rc.change, "after", {})
	# S3 bucket without server_side_encryption_configuration
	object.get(after, "server_side_encryption_configuration", null) == null
	object.get(after, "server_side_encryption_configuration", "") == ""
	msg := sprintf("S3 bucket '%s' must have server_side_encryption_configuration (encryption at rest).", [rc.address])
}

# aws_s3_bucket_server_side_encryption_configuration (separate resource) is also valid; skip if bucket has rule via that
# For simplicity we require encryption on the bucket or via default. Above checks bucket attribute.

# EBS volume must be encrypted
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_ebs_volume"
	after := object.get(rc.change, "after", {})
	after.encrypted != true
	msg := sprintf("EBS volume '%s' must have encrypted = true.", [rc.address])
}

# RDS cluster
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_rds_cluster"
	after := object.get(rc.change, "after", {})
	after.storage_encrypted != true
	msg := sprintf("RDS cluster '%s' must have storage_encrypted = true.", [rc.address])
}

# RDS instance
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_db_instance"
	after := object.get(rc.change, "after", {})
	after.storage_encrypted != true
	msg := sprintf("RDS instance '%s' must have storage_encrypted = true.", [rc.address])
}

# DynamoDB table
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type == "aws_dynamodb_table"
	after := object.get(rc.change, "after", {})
	object.get(after, "server_side_encryption", []) == []
	msg := sprintf("DynamoDB table '%s' must have server_side_encryption block (encryption at rest).", [rc.address])
}
