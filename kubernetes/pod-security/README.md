# Pod Security

**Purpose:** Enforce restricted pod security (no root, read-only root filesystem where possible, drop capabilities). Aligns with Kubernetes Pod Security Standards (restricted) and zero-trust workload hardening.

## Contents

- **Pod Security Standards:** Namespace labels or admission (Kyverno/Gatekeeper) to enforce `restricted` or `baseline` per namespace.
- **Pod Security Context example:** Minimal safe defaults for a typical app pod (runAsNonRoot, readOnlyRootFilesystem where possible, drop ALL capabilities, seccomp).
- **Exemptions:** Documented and scoped (e.g. system namespaces, one-off job with approval); use namespace labels or admission exception.

## Apply

- If using built-in Pod Security Admission (Kubernetes 1.23+): set namespace labels `pod-security.kubernetes.io/enforce=restricted`.
- If using Kyverno/Gatekeeper: policies in `../kyverno` or `../gatekeeper` enforce equivalent rules.

## References

- `../../architecture/system-design.md`
- `../../architecture/threat-model.md`
