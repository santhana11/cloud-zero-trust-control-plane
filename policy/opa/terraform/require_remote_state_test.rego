# ------------------------------------------------------------------------------
# Tests for require_remote_state.rego
# Run: opa test policy/opa/terraform/ -v
# ------------------------------------------------------------------------------

package terraform.zerotrust.remote_state

import future.keywords.if

test_deny_local_backend if {
	test_input := {
		"terraform": [
			{
				"backend": [
					{ "name": "local" }
				]
			}
		]
	}
	result := deny with input as test_input
	expected := "Terraform backend must be remote (e.g. s3, gcs, azurerm). Do not use local backend for team/shared state."
	result[expected]
}

test_deny_no_backend if {
	test_input := {
		"terraform": [
			{
				"backend": []
			}
		]
	}
	result := deny with input as test_input
	count(result) >= 1
	expected := "Terraform must define a remote backend (e.g. backend \"s3\" { ... }) for state storage and locking."
	result[expected]
}

test_allow_s3_backend if {
	test_input := {
		"terraform": [
			{
				"backend": [
					{ "name": "s3", "config": { "bucket": "my-tfstate" } }
				]
			}
		]
	}
	result := deny with input as test_input
	count(result) == 0
}
