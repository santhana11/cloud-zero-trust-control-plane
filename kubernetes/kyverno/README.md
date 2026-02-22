# Kyverno Policies — Phase 4

**Purpose:** Kyverno ClusterPolicies for EKS: signed images, resource limits, no privileged containers, required service account, and default-deny network policy. Kyverno is installed separately (Helm or manifest); this directory contains policy definitions only.

## Policy Files

| File | What it does |
|------|--------------|
| `enforce-signed-images.yaml` | Only allow Cosign-signed images (verifyImages). Configure public key via inline PEM or `secretRef`. |
| `require-resource-limits.yaml` | Require `resources.limits` (memory and cpu) on every container. |
| `block-privileged-containers.yaml` | Reject pods with `securityContext.privileged: true` or `allowPrivilegeEscalation: true`. |
| `require-service-account.yaml` | Require `spec.serviceAccountName` in app-prod/app-dev (e.g. for IRSA). |
| `default-deny-network-policy.yaml` | **Generate** a default-deny NetworkPolicy in namespaces labeled `zero-trust.io/default-deny: "true"`. |
| `require-registry-and-no-latest.yaml` | (Existing) Block `:latest` tag; restrict to approved registry. |

## Audit → Enforce Strategy

**Why start with Audit:** New policies can break existing workloads (e.g. unsigned images, missing limits). Running in **Audit** mode lets Kyverno report violations without blocking admission. You can:

1. **Apply policies with `validationFailureAction: Audit`** so all matching resources are evaluated and violations appear in reports/events but no requests are rejected.
2. **Fix workloads** (add limits, sign images, set serviceAccountName, add namespace labels).
3. **Switch to Enforce** once compliance is acceptable: set `validationFailureAction: Enforce` so future non-compliant resources are **rejected** at admission.

**Suggested order:**

1. Apply all policies with **Audit**.
2. Run `kyverno apply` or check cluster events / Kyverno reports for violations.
3. Remediate (CI/CD, Helm values, base manifests).
4. Change high-severity policies to **Enforce** (e.g. block-privileged, then require-resource-limits, then require-service-account).
5. Enable **Enforce** for signed images only after Cosign signing is in place for all images used in app-prod/app-dev.

## validationFailureAction Explained

- **`Enforce`** (default in many policies): When the rule **fails** (validation or verifyImages fails), the admission request is **rejected** (HTTP 403). The user sees a message like "admission webhook denied the request" with the policy message.
- **`Audit`**: When the rule fails, the request is **allowed**, but Kyverno records a **violation** (PolicyReport/ClusterPolicyReport, and often audit logs). Use for gradual rollout or reporting-only.

**Per-policy:** Each ClusterPolicy has its own `spec.validationFailureAction`. You can keep some policies in Audit (e.g. image signing until all images are signed) and others in Enforce (e.g. block privileged).

**Background scan:** With `background: true`, Kyverno also evaluates existing resources in the cluster and updates PolicyReports. So even in Audit mode you get a list of existing violating resources.

## Apply Order

1. Install Kyverno (see [Kyverno docs](https://kyverno.io/docs/installation/)).
2. (Optional) Create Secret with Cosign public key: `kubectl create secret generic cosign-pub-key -n kyverno --from-file=cosign.pub`.
3. Update `enforce-signed-images.yaml` to use `secretRef` or replace the inline key.
4. Apply policies (Audit first):  
   `kubectl apply -f kubernetes/kyverno/`
5. Label namespaces for default-deny generation:  
   `kubectl label namespace app-prod zero-trust.io/default-deny=true`
6. After validation, switch policies to Enforce as needed.

## References

- `../../architecture/system-design.md`
- `../../ci-cd/github-actions/cosign-sign.yml` — image signing
- [Kyverno Verify Images](https://kyverno.io/docs/writing-policies/verify-images/)
