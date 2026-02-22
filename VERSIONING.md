# Versioning

This project uses **Semantic Versioning (SemVer)** in the form `MAJOR.MINOR.PATCH` (e.g. `1.2.3`). Version numbers are assigned to releases (tags) and communicated in release notes.

## Semantic Versioning

- **MAJOR:** Incompatible changes to the security architecture, trust model, or usage contract. Adopters may need to change their deployment, configuration, or integration to remain correct and secure.
- **MINOR:** New backward-compatible capability (e.g. new Terraform module, new policy, new workflow). Existing use remains valid; new options or modules are additive.
- **PATCH:** Backward-compatible fixes: bug fixes, documentation corrections, dependency updates that do not change behavior or security posture, and minor refinements that do not alter the documented contract.

## What Qualifies as a Breaking Change (MAJOR)

- **Trust boundaries or threat model:** Changing which boundaries are enforced, or removing or fundamentally altering a control layer (e.g. dropping SCPs, changing IRSA model, removing admission enforcement) in a way that weakens or re-scopes security.
- **Deployment or integration contract:** Changing the order of deployment phases, removing a required phase, or changing inputs/outputs of modules in a way that breaks documented usage.
- **Policy and compliance:** Changing the meaning or scope of policies (Rego, Kyverno, SCP) so that previously compliant configurations become non-compliant, or so that evidence or control mapping no longer holds without adopter action.
- **API or interface:** If the project ever exposes an API or stable interface, breaking that interface would be MAJOR.

Raising the minimum supported version of Terraform, Kubernetes, or AWS provider in a way that forces adopters to upgrade before they are ready can be treated as MAJOR or MINOR depending on support policy; such changes must be documented in release notes.

## What Qualifies as Policy-Only or Non-Breaking (MINOR or PATCH)

- **New policies or rules:** Adding a new Rego rule, Kyverno policy, or Config rule is typically MINOR (new capability). Tightening an existing policy (e.g. new deny rule) may be MINOR if it is additive and documented; if it causes previously valid configs to fail, treat as MAJOR and call out migration.
- **New modules or workflows:** Adding a new Terraform module, GitHub Action, or runbook is MINOR.
- **Documentation and examples:** Fixes, clarifications, and new examples are PATCH (or MINOR if they introduce a new documented pattern).
- **Dependency and tool version bumps:** Updating Terraform provider, Conftest, or other tool versions for security or compatibility is usually PATCH, with release notes stating the change and any new minimum versions.

## Governance and Version Alignment

- **Compliance and evidence:** When controls or evidence locations change, the compliance mapping (`compliance/cis-mapping.md`, evidence automation) must be updated in the same release and noted in release notes. Governance stakeholders may need to re-baseline evidence or control IDs.
- **Threat model:** Any change that affects trust boundaries, controls, or residual risk must be reflected in `architecture/threat-model.md` and related docs; such changes are often MAJOR or at least a notable MINOR.
- **Changelog and release notes:** Each release should list user-visible and security-relevant changes. Breaking changes must be clearly called out with migration or upgrade guidance where applicable.
