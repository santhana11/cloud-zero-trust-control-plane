# ------------------------------------------------------------------------------
# Tests for require_encryption.rego
# Run: opa test policy/opa/terraform/ -v
# ------------------------------------------------------------------------------

package terraform.zerotrust.encryption

import future.keywords.if

test_deny_s3_without_encryption if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_s3_bucket",
				"address": "aws_s3_bucket.nocrypto",
				"change": {
					"after": {
						"bucket": "nocrypto"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	expected := "S3 bucket 'aws_s3_bucket.nocrypto' must have server_side_encryption_configuration (encryption at rest)."
	result[expected]
}

test_deny_ebs_unencrypted if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_ebs_volume",
				"address": "aws_ebs_volume.vol",
				"change": { "after": { "encrypted": false } }
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
}

test_allow_ebs_encrypted if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_ebs_volume",
				"address": "aws_ebs_volume.vol",
				"change": { "after": { "encrypted": true } }
			}
		]
	}
	result := deny with input as test_input
	count(result) == 0
}

test_deny_rds_without_encryption if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_db_instance",
				"address": "aws_db_instance.db",
				"change": { "after": { "storage_encrypted": false } }
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
}
