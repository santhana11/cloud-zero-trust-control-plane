# OPA Gatekeeper Policies

**Purpose:** Gatekeeper constraint templates and constraints when OPA-native policy is preferred (e.g. complex logic, reuse of existing OPA rules). Can run alongside Kyverno for specific use cases (e.g. custom ConstraintTemplates) or as primary admission controller.

## Contents

- **Templates:** Reusable ConstraintTemplates (e.g. allowed-repos, require-labels).
- **Constraints:** Instances that apply templates to namespaces/resources (e.g. all pods must have label X; images only from repo Y).
- **Sync:** Optional sync of AWS/GCP resources into OPA for cross-cloud policy (advanced).

## Apply order

1. Install Gatekeeper (see Gatekeeper docs).
2. Apply ConstraintTemplates first, then Constraints.

## References

- `../../architecture/system-design.md`
- Gatekeeper library: https://github.com/open-policy-agent/gatekeeper-library
