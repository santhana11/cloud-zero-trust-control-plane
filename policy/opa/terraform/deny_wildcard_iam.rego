# ------------------------------------------------------------------------------
# OPA/Conftest — Deny Wildcard IAM (Terraform)
# ------------------------------------------------------------------------------
# IAM policies must not use Action = "*" or Resource = "*" for sensitive actions
# (least privilege). We check aws_iam_role_policy, aws_iam_user_policy,
# aws_iam_group_policy (inline), and aws_iam_policy (managed) documents.
# Conftest input: Terraform plan JSON (resource_changes).
# ------------------------------------------------------------------------------

package terraform.zerotrust.wildcard_iam

import future.keywords.if
import future.keywords.in

# Policy document: "policy" (JSON string, most common in plan) or "policy_json"; or object
get_policy_doc(rc) := doc if {
	after := object.get(rc.change, "after", {})
	raw := object.get(after, "policy", "")
	raw != ""
	doc := json.unmarshal(raw)
}

get_policy_doc(rc) := doc if {
	after := object.get(rc.change, "after", {})
	raw := object.get(after, "policy_json", "")
	raw != ""
	doc := json.unmarshal(raw)
}

# Policy as object (rare in plan)
get_policy_doc(rc) := after.policy if {
	after := object.get(rc.change, "after", {})
	after.policy.Statement
}

iam_policy_resource_types := ["aws_iam_role_policy", "aws_iam_user_policy", "aws_iam_group_policy", "aws_iam_policy"]

# Statement has Action "*" or Resource "*"
statement_has_wildcard(stmt) if {
	action := object.get(stmt, "Action", "")
	action == "*"
}

statement_has_wildcard(stmt) if {
	action := object.get(stmt, "Action", [])
	action[_] == "*"
}

statement_has_wildcard(stmt) if {
	resource := object.get(stmt, "Resource", "")
	resource == "*"
}

statement_has_wildcard(stmt) if {
	resource := object.get(stmt, "Resource", [])
	resource[_] == "*"
}

# Dangerous: broad IAM write with wildcard (Action or Resource is "*")
dangerous_wildcard(stmt) if {
	statement_has_wildcard(stmt)
	action := object.get(stmt, "Action", "")
	action == "*"
}

dangerous_wildcard(stmt) if {
	statement_has_wildcard(stmt)
	resource := object.get(stmt, "Resource", "")
	resource == "*"
}

dangerous_wildcard(stmt) if {
	statement_has_wildcard(stmt)
	actions := object.get(stmt, "Action", [])
	actions[_] == "*"
}

# Deny: resource change is IAM policy with wildcard in any statement
deny[msg] if {
	rc := input.resource_changes[_]
	rc.type in iam_policy_resource_types
	doc := get_policy_doc(rc)
	stmt := doc.Statement[_]
	stmt.Effect == "Allow"
	dangerous_wildcard(stmt)
	msg := sprintf("IAM policy '%s' must not use Action or Resource '*' (least privilege). Specify concrete actions and resources.", [rc.address])
}
