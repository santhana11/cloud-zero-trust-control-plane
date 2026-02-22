# ------------------------------------------------------------------------------
# Tests for deny_public_s3.rego
# Run: opa test policy/opa/terraform/ -v
# ------------------------------------------------------------------------------

package terraform.zerotrust.public_s3

import future.keywords.if
import future.keywords.in

test_deny_public_read_acl if {
	# Simulate Terraform plan input: S3 bucket with acl = "public-read"
	test_input := {
		"resource_changes": [
			{
				"type": "aws_s3_bucket",
				"name": "mybucket",
				"address": "aws_s3_bucket.mybucket",
				"change": {
					"after": {
						"acl": "public-read",
						"bucket": "mybucket"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	count(result) > 0
	expected := "S3 bucket 'aws_s3_bucket.mybucket' must not have public ACL (got public-read). Use private and Block Public Access."
	result[expected]
}

test_allow_private_acl if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_s3_bucket",
				"address": "aws_s3_bucket.private",
				"change": {
					"after": {
						"acl": "private"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	count(result) == 0
}

test_deny_public_read_write_acl if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_s3_bucket",
				"address": "aws_s3_bucket.bad",
				"change": { "after": { "acl": "public-read-write" } }
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
}

test_no_deny_when_no_s3 if {
	test_input := {
		"resource_changes": [
			{ "type": "aws_iam_role", "address": "aws_iam_role.foo", "change": { "after": {} } }
		]
	}
	result := deny with input as test_input
	count(result) == 0
}
