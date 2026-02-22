# ------------------------------------------------------------------------------
# OPA/Conftest — Enforce Remote State (Terraform)
# ------------------------------------------------------------------------------
# Terraform backend must be remote (e.g. s3, gcs, azurerm) so state is not
# stored locally and is shared/locked. We check the parsed Terraform config.
# Conftest with --parser terraform on .tf files: input may be config with
# configuration.terraform.backend or (for plan) backend is not in resource_changes.
# This policy supports:
#   1. Terraform plan JSON that includes backend config (some pipelines inject it)
#   2. Combined input: when using conftest test *.tf --parser terraform --combine
#      the input can be array of file contents; we look for backend "s3" (or similar).
# For plan-only workflows, run this policy against a separate backend.tf check
# or use a small wrapper that outputs backend block as JSON.
# ------------------------------------------------------------------------------

package terraform.zerotrust.remote_state

import future.keywords.if

# Terraform plan JSON sometimes has configuration.backend or terraform_config
has_remote_backend if {
	backend := object.get(input, "configuration", {})["terraform"][0].backend[0]
	backend[_].name in ["s3", "gcs", "azurerm", "remote"]
}

# Alternative: input is the root module and we have backend config
has_remote_backend if {
	terraform_block := input.terraform[0]
	backend := object.get(terraform_block, "backend", [])
	count(backend) > 0
	# backend has a type (e.g. s3)
	backend[0].name != "local"
}

# When Conftest parses HCL, structure may be: input.configuration.root_module
# or input.terraform.backend. Conftest Terraform parser (for .tf) output:
# https://www.conftest.dev/plugins/terraform/ - the parsed config has "terraform"
# with "backend" as list of backend configs.
has_remote_backend if {
	# Direct backend in top-level (some parsers)
	object.get(input, "backend", [])[0].name in ["s3", "gcs", "azurerm", "remote"]
}

# Deny when we can see terraform config but backend is local or missing
deny[msg] if {
	# If terraform block exists and backend is "local" or missing
	terraform_block := object.get(input, "terraform", [])[0]
	backend := object.get(terraform_block, "backend", [])
	backend[0].name == "local"
	msg := "Terraform backend must be remote (e.g. s3, gcs, azurerm). Do not use local backend for team/shared state."
}

deny[msg] if {
	# Terraform block exists but backend is empty (input.terraform[0].backend)
	terraform_block := object.get(input, "terraform", [])[0]
	backend := object.get(terraform_block, "backend", [])
	count(backend) == 0
	msg := "Terraform must define a remote backend (e.g. backend \"s3\" { ... }) for state storage and locking."
}

deny[msg] if {
	# Configuration format (conftest parser): configuration.terraform
	cfg := object.get(input, "configuration", {})
	terraform_cfg := object.get(cfg, "terraform", [])
	count(terraform_cfg) > 0
	backend := object.get(terraform_cfg[0], "backend", [])
	count(backend) == 0
	msg := "Terraform must define a remote backend (e.g. backend \"s3\" { ... }) for state storage and locking."
}

# Note: Terraform plan JSON does not include backend config. To enforce remote state
# in CI, run conftest against .tf files: conftest test --parser terraform backend.tf -p policy/
