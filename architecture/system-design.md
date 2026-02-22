# Cloud Zero Trust Platform — System Design Document

**Document Version:** 2.0  
**Classification:** Internal — Platform Security  
**Status:** Accepted  
**Last Updated:** [Date]  
**Owner:** Platform Security & DevSecOps

---

## Executive Summary

This document defines the **Cloud Zero Trust Platform** — the security architecture, governance model, and technical design for protecting AWS and Kubernetes footprints in enterprise, multi-tenant environments while enabling secure, high-velocity delivery.

The design adopts **zero trust** as the governing principle: no implicit trust by network or identity; every access is authenticated, authorized, and least-privileged. We implement this through **multi-account AWS governance**, **hardened EKS** with policy-as-code (OPA/Kyverno), a **secure SDLC** (SBOM, image signing, pipeline gates), **runtime detection** (GuardDuty, audit), **automated incident response**, and **continuous drift detection**. Compliance (CIS, SOC 2) is mapped to controls and evidence is automated where possible.

This architecture reduces blast radius, enforces guardrails by default, and provides auditable evidence for security and compliance without making security a bottleneck for product delivery.

---

## 1. Problem Statement

The platform must operate as a cloud-native system that:

- **Protects tenant data** in a multi-tenant model with strict isolation and regulatory expectations.
- **Maintains trust** with enterprise customers who require SOC 2, CIS-aligned controls, and evidence of secure design and operation.
- **Scales securely** as the number of tenants, services, and cloud accounts grows, without ad-hoc access, long-lived credentials, or ungoverned change.
- **Enables velocity** so engineering can ship features and fixes quickly while staying within security and compliance guardrails.

The absence of a unified, zero-trust-aligned design would result in fragmented controls, manual compliance evidence, higher risk of credential abuse and supply-chain compromise, and either over-restrictive gates that slow delivery or under-governed environments that increase audit and incident risk.

---

## 2. Current Security Gaps (Pre–Platform)

The following gaps were identified before or during the design of this platform. This architecture directly addresses them.

| Gap | Impact | Addressed by |
|-----|--------|--------------|
| **Long-lived credentials** (keys in config, shared “robot” accounts) | Credential theft, lateral movement, difficult rotation | IRSA, OIDC for CI, no static keys in cluster or pipeline |
| **Single-account or weak account boundaries** | Blast radius; one compromise affects all envs | Multi-account strategy; SCPs; workload accounts per env |
| **No uniform policy at deploy time** | Inconsistent pod security, images, network policy | Kyverno/Gatekeeper; admission blocks non-compliant workloads |
| **Images not verified before deploy** | Supply-chain and malicious image risk | Image signing (cosign); admission allows only signed images; SBOM |
| **Manual compliance evidence** | Audit prep bottleneck; inconsistency | Config, GuardDuty, audit log; CIS mapping; automated reports |
| **Delayed or manual response to threats** | Dwell time; operator dependency | GuardDuty-driven automation (quarantine, revoke); runbooks |
| **Configuration drift** | Unauthorized or accidental change; compliance drift | Terraform drift detection; Config rules; remediation where safe |
| **Weak tenant isolation** | Cross-tenant access risk | Namespace + RBAC + network policy + data-layer tenant_id |

---

## 3. Business Constraints

- **Budget:** Security and platform investments must align with business growth; we prefer managed services and automation over custom build where TCO is favorable.
- **Timeline:** Rollout is phased; production workloads migrate to the new model without big-bang cutover.
- **Skills:** Design uses mainstream tools (Terraform, EKS, GitHub Actions, GuardDuty) so existing teams can operate and extend it.
- **Compliance:** Must support SOC 2 and CIS-aligned controls with demonstrable evidence; no design that inherently blocks audit requirements.
- **Vendor:** AWS and GitHub are strategic; design stays within their ecosystem for core control plane and CI/CD.
- **Availability:** Security controls (admission, network policy, IAM) must not introduce single points of failure that materially impact availability; we accept fail-closed for auth where appropriate.

---

## 4. Design Goals

### 4.1 Security Goals

| Goal | Success criteria |
|------|-------------------|
| **Zero trust** | No implicit trust by network or identity; every access authenticated and authorized with least privilege. |
| **Blast radius containment** | Compromise of one workload or account does not grant broad access; segmentation via account, network, and RBAC. |
| **Supply-chain integrity** | Only verified, signed images deploy to production; SBOM and vulnerability visibility in pipeline and at runtime. |
| **Configuration integrity** | Drift detected and remediated or escalated; infra and policy as code, change via review and pipeline. |
| **Detection and response** | Threats detected (GuardDuty, audit); high-severity findings trigger automated containment where safe; runbooks for all major incident types. |
| **Auditability** | All sensitive actions logged; logs immutable and queryable; evidence available for compliance (CIS, SOC 2). |

### 4.2 Business Goals

| Goal | Success criteria |
|------|-------------------|
| **Developer experience** | Guardrails are default; exceptions are time-bound and audited; developers can self-serve within policy. |
| **Compliance readiness** | Controls mapped to frameworks; evidence automated; audit prep predictable and repeatable. |
| **Operational sustainability** | Runbooks, automation, and clear ownership; security and platform teams can sustain the model as scale increases. |
| **Risk-informed trade-offs** | Residual risks documented and accepted by appropriate stakeholders; no “perfect” at the cost of delivery. |

---

## 5. Threat Model (STRIDE)

A full threat model is maintained in **`threat-model.md`**. Below is an executive summary of STRIDE categories and how this design mitigates them.

| Category | Representative threats | Mitigations in this design |
|----------|-------------------------|----------------------------|
| **Spoofing** | Impersonation of CI, deploy identity, or workload to push malicious change or call AWS APIs | OIDC for CI (no long-lived keys); IRSA for workloads; cosign verification at deploy; CloudTrail for AssumeRole |
| **Tampering** | Modification of state, pipeline, image, or audit logs | S3 state versioning and lock; protected branches and code review; image signing and admission; WORM for audit log |
| **Repudiation** | Denial of having performed an action | CloudTrail, EKS audit log, pipeline logs; immutable; every action tied to identity |
| **Information disclosure** | Leak of secrets or cross-tenant data | Secret scan in CI; Secrets Manager/Vault; least-privilege IRSA; tenant_id and RBAC; network policy |
| **Denial of service** | Resource exhaustion or pipeline unavailability | Multi-account and quotas; limit ranges; rate limiting; HA for CI/GitOps; runbooks |
| **Elevation of privilege** | Pod or role gains excessive AWS or cluster permissions | Least-privilege IAM per workload; RBAC and admission; no broad cluster-admin; break-glass with audit |

Data flows and trust boundaries (developer → GitHub → CI → registry → GitOps → EKS → AWS APIs; GuardDuty → automation) are documented in **`threat-model.md`**.

---

## 6. Zero Trust Model

Zero trust is implemented across identity, network, workload, and data.

| Pillar | Implementation |
|--------|-----------------|
| **Identity** | Every human and workload has an explicit identity. Humans: SSO (e.g. IAM Identity Center), MFA, no long-lived user keys for automation. Workloads: IRSA only; short-lived credentials; role per service/pod with minimal permissions. |
| **Network** | No “trust by network.” Private subnets by default; egress filtered; no broad 0.0.0.0/0 from prod workloads. Service-to-service and ingress authenticated and authorized (application auth or mTLS where adopted). |
| **Workload** | Only signed, policy-compliant images are deployable. Admission controllers enforce pod security, resource limits, and network policy presence. Default-deny namespaces; explicit allow only. |
| **Data** | Encryption at rest (KMS) and in transit (TLS). Tenant data partitioned by tenant_id; access enforced at API and data layer. Access to sensitive data and to audit log store is logged. |
| **Visibility** | Central, immutable audit trail (CloudTrail, EKS audit, pipeline logs); GuardDuty and Security Hub; findings drive automation or runbook-driven response. |

A detailed mapping of controls to zero-trust principles is in **`zero-trust-mapping.md`**.

---

## 7. Multi-Account Governance Strategy

### 7.1 Account structure

| Account type | Purpose | Key controls |
|--------------|---------|--------------|
| **Management** | Billing, SSO, org-level guardrails, central security tooling | SCPs, Config aggregator, GuardDuty delegated admin (or primary), Security Hub, no production workloads |
| **Shared services** (optional) | Shared artifact registry, CI runners, DNS, shared tooling | Scoped IAM; no tenant data; access from workload accounts via role assumption or VPC/peering as designed |
| **Workload** | One or more per environment (e.g. dev, staging, prod) | Dedicated EKS, VPC, IAM; SCPs constrain what the account can do; Config and GuardDuty report to management |

### 7.2 Governance mechanisms

- **SCPs (Service Control Policies):** Deny or constrain high-risk actions (e.g. leave org, disable Config/GuardDuty, create root API keys) and enforce guardrails (e.g. require MFA for sensitive APIs). Applied at OU or account level.
- **AWS Config:** Rules for desired state (e.g. EBS encryption, S3 public block, IAM password policy); aggregator in management account; remediation where safe and predefined.
- **GuardDuty:** Enabled org-wide; findings in Security Hub; optional delegated admin in security account.
- **Identity:** SSO from management; workload accounts do not create long-lived user keys for automation; cross-account access via IAM roles with minimal trust.

### 7.3 Blast radius

- Compromise in one workload account does not grant access to another account or to management without additional exploitation.
- Compromise of CI (e.g. GitHub) is contained by OIDC scope and role scope (e.g. push only to designated registry and state bucket).

---

## 8. Secure SDLC Design

### 8.1 Source and CI

- **Source:** Code in GitHub; protected branches; PR required; code review and approval as per policy.
- **CI (e.g. GitHub Actions):** Triggered by PR/push; no long-lived AWS keys; OIDC to assume role with minimal permissions (e.g. plan/apply for Terraform, push to ECR). Pipelines run:
  - **SAST/SCA/secret scan** on code; block or warn per policy.
  - **Terraform plan** on infra changes; Trivy (or equivalent) on Terraform.
  - **Build** of container image; **image scan** (e.g. Trivy); **SBOM generation** (CycloneDX/SPDX); **signing** (cosign). Only images that pass gates and are signed are pushed to production registry.

### 8.2 Deploy (GitOps)

- **GitOps (e.g. Argo CD):** Syncs from Git; deploys only references to images that exist in registry and, where enforced, are signed. No direct kubectl to production from developer machines for standard deploys.
- **Admission:** At apply time, Kyverno/Gatekeeper enforce: image from allowed registry, image signed (if policy requires), no latest tag, resource limits, pod security, and (optionally) network policy presence. Non-compliant manifests are rejected.

### 8.3 Assurance summary

| Stage | Control | Outcome |
|-------|---------|---------|
| Code | SAST, SCA, secret scan | Block or track findings before merge |
| Build | Image scan, SBOM, sign | Only signed, scanned images in registry |
| Deploy | GitOps + admission | Only intended, signed, policy-compliant workloads run |

---

## 9. EKS Security Architecture

### 9.1 Cluster and network

- **Cluster:** Dedicated VPC per workload account (or shared VPC with strict segmentation); EKS API endpoint private or public with restricted access; node groups in private subnets; no public node IPs in production.
- **Network policies:** Default-deny at namespace level; explicit allow for ingress (e.g. from ingress controller) and egress (DNS, required APIs, internal CIDRs). No cross-namespace traffic unless explicitly allowed.

### 9.2 Identity and access (EKS)

- **IRSA:** Every pod that needs AWS API access uses a service account linked to an IAM role (IRSA). No static AWS keys in cluster. Roles are least-privilege and scoped to namespace/service account.
- **RBAC:** Cluster and namespace roles and role bindings; no broad cluster-admin for day-to-day use; break-glass with time limit and audit.
- **Admission:** Kyverno and/or OPA Gatekeeper enforce pod security (e.g. restricted profile), image registry and signing, resource limits, and custom policy. Policy is versioned in Git and applied via GitOps.

### 9.3 Workload hardening

- **Pod security:** Restricted profile (or equivalent): runAsNonRoot, drop ALL capabilities, read-only root filesystem where possible, seccomp. Exceptions documented and scoped.
- **Images:** Only from approved registry; no `:latest`; only signed images in production namespaces (when policy enabled).

### 9.4 Tenant isolation (logical)

- Tenants map to namespaces and/or labels; RBAC and network policy enforce no cross-tenant access at cluster level. Data layer enforces tenant_id in all queries and storage paths.

---

## 10. Runtime Detection Design

### 10.1 GuardDuty

- **Scope:** Enabled org-wide; all member accounts; findings aggregated in management account (or security account) and sent to Security Hub.
- **Use:** Threat detection (e.g. compromised EC2, credential abuse, crypto mining). Findings drive automated response (see Section 11) or runbook-driven investigation.

### 10.2 Audit logging

- **Sources:** CloudTrail (management and workload accounts), EKS control-plane audit log, application audit events (where instrumented).
- **Storage:** Central store (e.g. S3 with Object Lock / WORM); retention per policy (e.g. 90 days hot, 7 years archive); access to the log store itself is restricted and audited.
- **Query:** Athena, OpenSearch, or SIEM for investigation and compliance reporting (“who did what,” “all access to resource X”).

### 10.3 Security Hub and findings

- **Security Hub:** Aggregates GuardDuty, Config, and other supported findings; standard (e.g. CIS) or custom framework; severity and deduplication.
- **Alerting:** High/critical findings trigger notifications (SNS, Slack, PagerDuty) and, where defined, automated response.

---

## 11. Incident Response Automation

### 11.1 Design principles

- **Predefined actions only:** Automation executes only well-defined, safe actions (e.g. isolate EC2, revoke key). No arbitrary code execution from finding payload.
- **Reversibility:** Every automated action has a documented rollback (runbook); human can restore or terminate after investigation.
- **Audit:** All automation invocations and outcomes are logged (CloudTrail, application log).

### 11.2 GuardDuty-driven automation

- **Trigger:** EventBridge rule on GuardDuty finding (e.g. severity ≥ 7 or specific finding types such as Backdoor:EC2, CredentialAccess).
- **Actions (examples):** Isolate EC2 (security group to no-egress or stop instance); deactivate IAM access key; notify security and owner.
- **Implementation:** Lambda (or equivalent) in management or security account; IAM role with minimal permissions; runbook linked from **`../detection-response/runbooks/`**.

### 11.3 Runbooks

- Documented procedures for: GuardDuty auto-isolate (investigation and restore/terminate), credential compromise, malicious or vulnerable image in cluster, Terraform/config drift, data exposure. Format: Detection, Triage, Containment, Eradication, Recovery, Post-Incident. Updated post-incident and exercised periodically.

---

## 12. Drift Detection Strategy

### 12.1 Objectives

- Detect when live configuration diverges from intended (Terraform) or from policy (Config rules).
- Reduce unauthorized or accidental change; support compliance (“config matches standard”).

### 12.2 Mechanisms

| Mechanism | Scope | Frequency | Response |
|-----------|--------|-----------|----------|
| **Terraform plan** | Terraform-managed resources (org-guardrails, eks-cluster, irsa, config-rules) | On PR and on schedule (e.g. daily) | Non-empty plan → artifact, alert, and optionally fail pipeline or create ticket; apply only via approved pipeline or break-glass. |
| **AWS Config** | Config rules (e.g. EBS encryption, S3 public block) | Continuous | Non-compliant resource → finding; optional auto-remediation (e.g. enable encryption) where safe; else runbook. |
| **Conformance packs** | CIS or custom pack | Continuous | Same as Config; aggregate compliance view. |

### 12.3 Remediation policy

- **Automated:** Only for low-risk, well-understood changes (e.g. attach encryption to new volume, add tag). No automated change to IAM, SCP, or network path without explicit design.
- **Manual / runbook:** All other drift is alerted and handled via runbook: assess impact, approve, apply or revert.

---

## 13. Compliance & Reporting

### 13.1 Frameworks

- **CIS AWS Foundations:** Controls mapped to Terraform, Config, and operational practice; see **`../compliance/cis-mapping.md`**.
- **SOC 2:** Control objectives (security, availability as applicable) supported by same controls; evidence from Config, GuardDuty, audit log, and runbooks.
- **Internal policy:** Organization security standards reflected in SCPs, Config rules, and admission policies.

### 13.2 Evidence and reporting

- **Evidence location:** Config compliance dashboard/report; GuardDuty and Security Hub; audit log (S3/Athena or SIEM); Terraform state and Git history; runbook execution records.
- **Reports:** “Who had admin in last 90 days,” “All GuardDuty findings in period,” “Config compliance by rule,” “Images deployed with SBOM and scan status.” Generated on schedule or on demand for audit.
- **Retention:** Per policy (e.g. 1 year hot, 7 years archive for audit); WORM where required.

### 13.3 Ownership

- **Platform Security:** Architecture, threat model, zero-trust mapping, GuardDuty and automation.
- **DevSecOps:** Secure SDLC, Terraform, drift detection, CI/CD and image signing.
- **SRE / Platform:** EKS operations, network and node configuration, availability.
- **Compliance / Risk:** Framework mapping, audit liaison, residual risk acceptance.

---

## 14. Trade-Off Analysis

| Decision | Options considered | Choice | Rationale |
|----------|--------------------|--------|-----------|
| **Multi-account vs single account** | Single account with tagging and IAM boundaries | Multi-account | Blast radius; clear ownership; alignment with AWS and compliance best practice. |
| **Cluster per env vs cluster per tenant** | Cluster per tenant for strongest isolation | Cluster per env; tenant isolation via namespace, RBAC, network policy, data | Cost and operability at current scale; sufficient for current tenants; cluster-per-tenant later if needed. |
| **Kyverno vs Gatekeeper vs both** | Gatekeeper only; Kyverno only; both | Kyverno primary; Gatekeeper for complex OPA if needed | Kyverno readability and common policies; reduce duplication and operational complexity. |
| **Image signing** | Sign only critical workloads vs all prod | Sign all production images | Uniform supply-chain guarantee and simpler policy (“all prod signed”). |
| **Drift remediation** | Full automation vs alert-only | Automated only where safe (e.g. tagging, encryption); alert + runbook for IAM, network, SCP | Balance consistency and safety; human in the loop for high-impact change. |
| **GuardDuty auto-response** | None vs quarantine/revoke | Quarantine/revoke for high-severity, well-defined findings | Reduce dwell time; limit to safe, reversible actions with runbook. |
| **Fail open vs fail closed (auth)** | Fail open for availability | Fail closed for authentication/authorization | Security over availability for auth decisions; IdP and policy store HA to minimize impact. |

---

## 15. Residual Risks

The following risks remain after implementation of this design. They are accepted or mitigated as stated and reviewed periodically.

| Risk | Description | Mitigation / acceptance |
|------|-------------|-------------------------|
| **Third-party compromise** | Compromise of GitHub or AWS could allow abuse of CI or cloud resources | Rely on vendor security and detection; OIDC and role scope limit blast radius; monitor for anomalous AssumeRole and pipeline runs. |
| **Insider misuse** | Admin or developer with elevated access could intentionally bypass controls | Assume breach; segment and audit; break-glass and sensitive actions logged; access review and least privilege. |
| **False positives in automation** | GuardDuty or automation could isolate or revoke legitimate activity | Tune detectors; narrow automation to high-confidence findings; runbook to restore; post-incident review. |
| **Policy bypass** | New resource types or APIs might not yet be covered by Config or admission | Continuous coverage review; add rules and policies as new services are adopted. |
| **Supply chain beyond image** | Compromise of base image or dependency not yet in CVE DB | SBOM and scan; pin and review bases; monitor for new CVEs and respond per runbook. |
| **Availability impact of controls** | Admission or IAM failure could block deploy or runtime | HA for IdP and policy store; runbooks; fail closed only where security outweighs availability. |

Residual risk acceptance is documented and owned by Platform Security and Risk; review is at least annual or on major scope change.

---

## 16. References

| Document | Purpose |
|----------|---------|
| **`threat-model.md`** | Full STRIDE table, data flows, trust boundaries. |
| **`zero-trust-mapping.md`** | Mapping of controls to zero-trust pillars. |
| **`../compliance/cis-mapping.md`** | CIS control mapping and evidence. |
| **`../detection-response/runbooks/`** | Incident runbooks. |
| **Terraform and Kubernetes modules in this repo** | Implementation of the above. |

---

*This document is the single source of truth for the Cloud Zero Trust Platform architecture. Changes require review by Platform Security and relevant stakeholders.*
