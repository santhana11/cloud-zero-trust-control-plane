# ------------------------------------------------------------------------------
# Quarantine Security Group — No Ingress, No Egress (Phase 6)
# ------------------------------------------------------------------------------
# Lambda replaces an instance's security groups with this one so the instance
# cannot communicate in or out (containment). Preserve evidence; human decides
# restore or terminate per runbook.
# ------------------------------------------------------------------------------

variable "vpc_id" {
  type        = string
  description = "VPC ID where EC2 instances to be quarantined live"
  default     = ""
}

resource "aws_security_group" "quarantine" {
  count        = var.vpc_id != "" ? 1 : 0
  name_prefix  = "guardduty-quarantine-"
  description  = "No ingress/egress; used by GuardDuty Lambda to isolate compromised EC2"
  vpc_id       = var.vpc_id
  tags         = merge(var.tags, { Name = "guardduty-quarantine" })
  lifecycle { create_before_destroy = true }
}

# No ingress rules (default deny)
# No egress rules (explicit deny all egress for containment)
resource "aws_vpc_security_group_egress_rule" "quarantine_deny_all" {
  count             = var.vpc_id != "" ? 1 : 0
  security_group_id = aws_security_group.quarantine[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  from_port         = -1
  to_port           = -1
  # Default egress is allow; we use a deny rule. In AWS SG model, you cannot add "deny" egress;
  # you remove all egress rules. So we create a group with no egress rules added —
  # in default VPC SG behavior, no egress rules can mean "no egress" in some configurations.
  # Actually: by default a new SG has one egress rule (allow all 0.0.0.0/0). To get "no egress"
  # we must remove it. Terraform's aws_security_group with no egress block creates the default
  # allow-all egress. So we need to set egress = [] to have no egress.
}

# So we need to override: create the SG with no egress. In AWS, when you create a security
# group with no egress rules, AWS adds a default "allow all outbound". To get deny-all
# we use a security group with a single egress rule that allows nothing, or we use
# VPC endpoint policies. The standard approach is: one egress rule with protocol -1,
# cidr 0.0.0.0/0, and then we don't use "deny" — we use "no allow". So actually the
# quarantine is: replace SGs with a SG that has NO egress rules. In Terraform,
# egress = [] removes the default; the SG will have no egress rules. But in AWS
# documentation, a security group with no egress rules blocks all traffic. Let me check.
# Actually: "If you don't specify any egress rules, no outbound traffic is allowed."
# So we just need egress = [] in the aws_security_group. Remove the egress_rule.
resource "aws_vpc_security_group_egress_rule" "quarantine_deny_all" {
  count             = 0
  security_group_id = aws_security_group.quarantine[0].id
  ...
}
</think>
Fixing the security group: AWS SGs don't support explicit "deny" rules; use no egress rules to block outbound traffic.
<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace