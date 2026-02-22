# Network Policies

**Purpose:** Default-deny and explicit-allow network policies for EKS namespaces. No cross-namespace or egress traffic unless explicitly allowed. Applied after namespace creation and before application workloads.

## Contents

- **Default deny:** Namespace-level policy that denies all ingress and egress; then allow-list by selector.
- **Per-namespace allows:** Ingress from ingress controller or specific namespaces; egress to DNS, registry, and required APIs (e.g. AWS API via VPC endpoint).
- **Template/example:** One example policy for a typical app namespace (allow ingress from ingress-controller, egress to DNS and internal CIDRs).

## Apply order

1. Create namespaces.
2. Apply default-deny (or use Kyverno to generate default-deny).
3. Apply allow policies per namespace.

## References

- `../../architecture/system-design.md`
- `../../architecture/zero-trust-mapping.md`
