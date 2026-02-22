# Zero Trust Architecture Mapping

**Version:** 1.0  
**Purpose:** Map platform components and controls to zero-trust principles (identity, device/workload, network, data, visibility).

---

## 1. Zero-Trust Principles (Reference)

1. **Verify explicitly** — Every access is authenticated and authorized; no implicit trust.
2. **Least privilege** — Minimum access necessary; time- and scope-limited where possible.
3. **Assume breach** — Segment and limit blast radius; detect and respond.
4. **Verify and secure all resources** — Apply to data, workloads, and identity stores.
5. **Visibility and analytics** — Log and monitor; use signals for policy and response.

---

## 2. Mapping: Platform to Zero Trust

| Zero-trust principle | How we implement it | Components / artifacts |
|----------------------|----------------------|-------------------------|
| **Verify explicitly (identity)** | Every human and workload has an explicit identity. No shared “robot” keys. | SSO (IAM Identity Center); IRSA for pods; OIDC for CI; every CloudTrail/EKS audit event has principal. |
| **Least privilege** | IAM roles and RBAC scoped to minimum required. No wildcard admin. | Terraform IAM roles (org-guardrails, irsa); EKS RBAC and service accounts; Kyverno/Gatekeeper policies (resource limits, no privileged). |
| **Assume breach (segment)** | Network and identity boundaries limit blast radius. One compromised pod/account doesn’t grant broad access. | Multi-account; network policies (default-deny); namespace isolation; GuardDuty + automated isolate. |
| **Verify and secure all resources** | Images and infra are verified before use. Drift is detected. | Image signing (cosign); admission policy; Terraform + Config; SBOM and scan in CI. |
| **Visibility and analytics** | All sensitive actions logged; logs immutable and queryable. | CloudTrail; EKS audit log; pipeline logs; central S3 + Athena or SIEM; GuardDuty and Security Hub. |

---

## 3. Per-Domain Mapping

### 3.1 Identity

- **Human:** SSO only; MFA; role tied to group; no long-lived access keys for interactive use.
- **Workload (EKS):** IRSA only; no static AWS keys in cluster; service account per app with dedicated role.
- **CI:** OIDC with GitHub; role scoped to specific repos and actions (e.g. push to registry, update state bucket).

### 3.2 Network

- **EKS:** Private subnets; network policies default-deny; egress filtered where possible; no direct internet from prod pods unless via proxy/NAT with policy.
- **AWS:** VPC and security groups restrict traffic; no 0.0.0.0/0 on sensitive components; Transit Gateway or similar if multi-VPC.

### 3.3 Data

- **At rest:** KMS encryption for EBS, S3, RDS; keys scoped to account/use.
- **In transit:** TLS for all APIs and user traffic; certificate management and rotation.
- **Tenant isolation:** Data partitioned by tenant_id; access enforced at API and DB; no cross-tenant query possible by design.

### 3.4 Workload and pipeline

- **Image:** Only signed images deployable; admission enforces.
- **Config:** Terraform and Config detect drift; changes via Git and pipeline only (no manual console for critical resources where we can enforce).
- **Secrets:** No secrets in Git; secret scan in CI; runtime secrets from Secrets Manager or Vault with IRSA.

---

## 4. Gaps and Roadmap

- **Current:** Identity, least privilege, network segmentation, image verification, logging, and GuardDuty response are in place or in implementation.
- **Planned:** mTLS for service-to-service in cluster (optional next phase); automated revocation of compromised IRSA roles (triggered by GuardDuty); formal zero-trust assessment with external party (optional).

---

## 5. References

- `architecture/system-design.md`
- `architecture/threat-model.md`
- `compliance/cis-mapping.md`
