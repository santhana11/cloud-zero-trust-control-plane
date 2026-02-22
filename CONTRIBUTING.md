# Contributing

This document describes how to contribute to the Enterprise Zero Trust Security Control Plane repository. Contributions must align with the project's security and governance standards.

## Branching Model

- Work is done on **feature branches** created from the default branch (e.g. `main`).
- Branch names should be descriptive: `feature/description`, `fix/description`, or `docs/description`.
- All changes reach the default branch via **pull request (PR)**. No direct pushes to the default branch.
- Keep branches short-lived and rebase or merge from the default branch as needed to avoid drift.

## Pull Request Requirements

### Architecture and Threat Model

- **If your change affects architecture, trust boundaries, or control placement:** You must update the threat model and any affected architecture documentation.
- **Files to consider:** `architecture/threat-model.md`, `architecture/system-design.md`, `architecture/zero-trust-mapping.md`, and the README sections on trust boundaries and layered security.
- Document any new attack paths, assets, or controls; keep STRIDE and residual risk sections accurate.

### Policy and Security-Critical Changes

- **Terraform:** Changes to `terraform/org-guardrails/`, `terraform/irsa/`, or any SCP/permission boundary require explicit review for least-privilege and blast-radius impact.
- **Kubernetes policies (Kyverno, Gatekeeper, network policies):** Changes must be reviewed for correctness and for impact on existing workloads (Audit vs Enforce, namespace scope).
- **OPA/Rego:** Policy changes in `policy/opa/terraform/` must include or update tests; Conftest must pass against the intended Terraform plan or config.
- **CI/CD:** Workflow or script changes that touch credentials, OIDC, or deployment logic require security-minded review.

### Testing Expectations

Before submitting a PR, ensure:

- **Terraform:** `terraform init`, `terraform validate`, and (where applicable) `terraform plan` succeed for affected modules.
- **OPA/Conftest:** From repo root or appropriate directory, `conftest test` runs successfully against the policy path and sample plan/config (see `policy/opa/README.md`).
- **Kyverno:** For new or modified ClusterPolicies/ClusterPolicyReports, a dry-run or apply against a test namespace is recommended; document any namespace or label assumptions.
- **General:** No known broken links or outdated references in documentation you changed.

Automated checks (e.g. GitHub Actions for Conftest, Terraform validate) must pass where configured.

### Documentation

- **README, architecture, compliance, runbooks:** Update any section that becomes inaccurate due to your change. Do not leave stale references or "TODO" in merged content.
- **New modules or workflows:** Add or update the relevant README (purpose, inputs, outputs, prerequisites) and, if appropriate, the main README's repository contents or deployment order.
- **Versioning:** For user-facing behavior changes, consider whether `VERSIONING.md` or release notes need an update.

### Code Review Standards

- At least one approval from a maintainer (or designated reviewer) is required before merge.
- Reviewers will check: correctness, security impact, test coverage where applicable, documentation updates, and alignment with the project's zero-trust and governance goals.
- Address review comments with commits on the same branch; avoid force-pushing after review has started unless the team prefers rebase-and-force-push workflow.

### Commit Message Format

Use **Conventional Commits** for clarity and automated tooling:

- `feat: add X` for new features or capabilities.
- `fix: correct Y` for bug or misconfiguration fixes.
- `docs: update Z` for documentation-only changes.
- `chore: dependency or tooling update` for maintenance.
- `policy: update Rego/Kyverno for Z` for policy-only changes.

Optionally include scope: `feat(terraform): add config rule for MFA`. Keep the first line under roughly 72 characters; add body and footer if needed (e.g. breaking change, issue reference).

## Scope of Contributions

Contributions that improve correctness, security, clarity, or maintainability of the reference implementation are welcome. Changes that alter the intended security posture (e.g. relaxing SCPs or admission policies without clear justification and documentation) will be scrutinized and may be rejected. When in doubt, open an issue or draft PR and ask for maintainer guidance.
