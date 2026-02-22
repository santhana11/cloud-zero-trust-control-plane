# ------------------------------------------------------------------------------
# Tests for deny_wildcard_iam.rego
# Run: opa test policy/opa/terraform/ -v
# ------------------------------------------------------------------------------

package terraform.zerotrust.wildcard_iam

import future.keywords.if

test_deny_wildcard_action if {
	# IAM policy with Action = "*"
	test_input := {
		"resource_changes": [
			{
				"type": "aws_iam_role_policy",
				"address": "aws_iam_role_policy.broad",
				"change": {
					"after": {
						"policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
}

test_allow_specific_action if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_iam_role_policy",
				"address": "aws_iam_role_policy.specific",
				"change": {
					"after": {
						"policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\"],\"Resource\":\"arn:aws:s3:::mybucket/*\"}]}"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	count(result) == 0
}

test_deny_wildcard_resource if {
	test_input := {
		"resource_changes": [
			{
				"type": "aws_iam_policy",
				"address": "aws_iam_policy.managed",
				"change": {
					"after": {
						"policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"iam:GetUser\"],\"Resource\":\"*\"}]}"
					}
				}
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
}
