# Enterprise Zero Trust Security Control Plane for AWS & Kubernetes

## Architecture Overview

This diagram illustrates the layered Zero Trust control plane across AWS accounts, Kubernetes workloads, CI/CD, governance, and automated response.

<p align="center">
  <img src="architecture/arch.png"
       alt="Enterprise Zero Trust Security Control Plane Architecture"
       width="100%" />
</p>

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-blue?logo=kubernetes)](https://kubernetes.io)
[![Zero Trust](https://img.shields.io/badge/Architecture-Zero%20Trust-0E4C92)](https://www.nist.gov/zero-trust)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OPA](https://img.shields.io/badge/Policy-OPA%20%7C%20Conftest-7B42BC)](https://www.openpolicyagent.org)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=github-actions)](.github/workflows)

**Production-grade security control plane for AWS and Kubernetes.**  
This document describes the implemented design, trust boundaries, controls, operational practices, and residual risks. It is written for senior DevSecOps engineers, security architects, cloud governance leads, and auditors who operate or evaluate the control plane in enterprise environments.

---

## Operational Principles

The control plane is built on four operational principles that govern how we enforce and operate security:

1. **Identity over network trust.** Every access decision is based on verified identity (OIDC for CI, IRSA for workloads, SSO for humans). Network location does not grant trust; explicit policy does.
2. **Policy enforcement before deployment.** Nothing reaches production without passing pipeline gates (Conftest, Checkov, Trivy, Gitleaks) and admission control (Kyverno). Terraform and Kubernetes changes are enforced at commit and at apply.
3. **Centralized detection with decentralized blast radius.** GuardDuty and Config aggregate at the org level; SCPs and permission boundaries limit what any single account or role can do. One compromised identity cannot disable detection or unbind guardrails.
4. **Containment before investigation.** On high-severity GuardDuty findings, automation quarantines the affected resource and preserves evidence (snapshots, logs) before human triage. We do not wait for investigation to contain.

---

## Design Highlights

- **Multi-account AWS governance** with SCP guardrails (deny public S3, wildcard IAM, CloudTrail deletion) and permission boundaries on all workload identities.
- **OIDC-based CI identity** — no long-lived AWS keys in repo or secrets; GitHub Actions assume a scoped role.
- **IRSA workload identity** with permission boundaries; one role per service account, least privilege.
- **Signed image enforcement** — Cosign in CI, Kyverno verifyImages at admission; only signed images run in enforced namespaces.
- **Policy-as-code for Terraform** — OPA/Conftest in CI (deny public S3, wildcard IAM, require encryption, remote state); non-compliant plans fail before apply.
- **Nightly Terraform drift detection** — `terraform plan -detailed-exitcode`; exit 2 triggers Slack and plan artifact; apply remains a separate, approved step.
- **GuardDuty-driven automated containment** — EventBridge → Lambda quarantines EC2, snapshots volumes, notifies SNS; runbook-owned triage and restore/terminate.
- **CIS-aligned evidence mapping** — Controls mapped to CIS AWS Foundations; evidence automated (Config, GuardDuty, drift, CI artifacts) with documented ownership and review cadence.

---

## 1. Executive Framing

### The enterprise problem

Multi-tenant SaaS platforms operating in regulated or enterprise sales environments face a consistent set of problems: **blast radius** (one compromised identity or account can affect many tenants or environments), **governance gaps** (policies that exist on paper but are not enforced in pipeline or runtime), and **credential sprawl** (long-lived keys in config, shared automation accounts, and static secrets in clusters). The result is either security that blocks velocity or security that is deferred until audit or incident—neither is sustainable.

This control plane enforces those boundaries in code: identity, network segmentation, workload admission, supply-chain verification, drift detection, and detection-and-response are implemented and operated with clear ownership. The focus is not application features but **how access is granted, how change is controlled, and how compromise is contained**.

### Scope and nature of this repo

**This implementation reflects production operating realities** for a Zero Trust security control plane in a cloud-native enterprise environment. The design and code are built to withstand scrutiny from senior engineers and auditors. Backend configuration, account structure, key storage, and rollout sequencing are operational decisions that teams set for their environment and risk tolerance. The repository is not tied to any specific employer or customer environment.

The focus of this repository is the **security control plane**: the layers that enforce identity, network, workload, and pipeline policy, plus detection and response. Application logic, tenant data flows, and business-specific authorization are out of scope.

---

## 2. Trust Boundaries & Threat Model Summary

The control plane enforces explicit trust boundaries at five layers. Attacker paths we constrain include **credential theft** (stolen keys or tokens), **supply-chain compromise** (malicious or tampered image or dependency), **misconfiguration abuse** (overly permissive IAM or RBAC), **tampering** (state or pipeline modified to apply malicious change), and **privilege escalation** (pod or role gaining more access than intended). We assume breach of a legitimate identity and limit what that identity can do and how far it can reach; we do not assume malicious insiders with intent to deliberately bypass controls.

| Boundary | What it defines | Attacker path it constrains |
| ---------- | ----------------- | ----------------------------- |
| **Identity** | Every human and workload has a scoped identity; no shared long-lived keys for automation. | Impersonation of CI, deploy identity, or workload to push malicious change or call AWS APIs. |
| **Network** | No implicit trust by network location; traffic is explicitly allowed by policy. | Lateral movement and exfiltration after compromise of a workload. |
| **Workload** | Only policy-compliant, signed images and specs are admitted; runtime behavior is constrained. | Malicious or misconfigured workloads running in the cluster. |
| **CI/CD** | Code and artifacts flow through a defined pipeline with gates; identity for pipeline is OIDC-assumed role. | Tampering with pipeline or state to deploy unauthorized change. |
| **Account** | Management vs workload accounts; SCPs apply at OU/account and cannot be disabled by a single account. | Blast radius from one compromised account; root or broad IAM abuse. |

**STRIDE mapping (summary):** Spoofing is addressed by OIDC (CI), IRSA (workloads), and Cosign (images). Tampering is addressed by state versioning and lock, protected branches, image signing and admission, and SCPs that deny CloudTrail deletion. Repudiation is addressed by CloudTrail, EKS audit log, and pipeline logs tied to identity. Information disclosure is addressed by secret scan, least-privilege IRSA, and tenant/namespace isolation. Denial of service is addressed by multi-account segmentation, quotas, and limit ranges. Elevation of privilege is addressed by permission boundaries, SCPs, least-privilege roles, and admission policy. Full STRIDE table, assets, actors, and attack vectors are in **`architecture/threat-model.md`**.

---

## 3. Layered Security Architecture

Each layer mitigates a specific risk, is implemented in a known place, has a defined failure mode, and is monitored or evidenced. The intent is defensive depth: one layer failing does not grant unbounded access.

| Layer | Risk mitigated | Where implemented | If it fails | How it is monitored |
| ------ | ---------------- | ------------------- | ----------- | ---------------------- |
| **AWS Identity & SCP** | Unbounded IAM or root abuse; public S3; CloudTrail disabled. | Permission boundary and SCPs in `terraform/org-guardrails/`. | Identity could grant more than intended; SCPs still apply at org level and deny high-risk APIs. | Config and CloudTrail; SCPs are in Terraform state; boundary attachment is auditable. |
| **IRSA & workload identity** | Static AWS keys in cluster; over-privileged pod calling AWS. | `terraform/irsa/`; one role per service account; permission boundary attached. | Pod assumes role with limited scope; compromise is bounded to that role’s permissions. | CloudTrail (AssumeRoleWithWebIdentity); periodic review of role usage. |
| **CI OIDC** | Long-lived AWS keys in repo or secrets used for deploy. | GitHub Actions assume role via OIDC; no access keys for deploy. | CI runs with scoped role; compromise of repo or runner does not grant keys usable outside the role’s scope. | CloudTrail (AssumeRoleWithWebIdentity from GitHub); pipeline logs. |
| **Kubernetes admission (Kyverno)** | Unsigned images, privileged pods, missing limits, missing serviceAccount. | `kubernetes/kyverno/`; policies for signed images, resource limits, no privileged, serviceAccount, default-deny network policy. | Admission rejects non-compliant creates/updates when in Enforce; in Audit, violations are reported. | Kyverno PolicyReport/ClusterPolicyReport; EKS audit log for admission decisions. |
| **OPA Terraform policy** | Public S3, wildcard IAM, unencrypted resources, local backend in Terraform. | `policy/opa/terraform/`; Conftest in CI. | Non-compliant plan or config fails in CI before apply. | CI logs and Conftest output; policy in Git. |
| **Network segmentation** | Lateral movement and egress from workloads to arbitrary destinations. | `kubernetes/network-policies/` (default-deny, then allow rules). | Traffic not explicitly allowed is dropped; blast radius within cluster is limited. | NetworkPolicy in cluster; debugging via pod connectivity tests and flow logs if enabled. |
| **Supply chain security** | Secrets in repo; vulnerable or malicious images; unverified artifacts. | `ci-cd/github-actions/`: Gitleaks, SAST, Checkov, Conftest, Trivy (fail on critical/high), SBOM, Cosign. | Pipeline fails at the relevant gate; only signed, scanned images progress when admission is enforced. | CI artifacts (SBOM, scan results); admission allows only signed when Kyverno Enforce is on. |
| **Drift detection** | Live infrastructure diverging from code without going through pipeline. | Nightly `terraform plan -detailed-exitcode`; `ci-cd/github-actions/terraform-drift.yml`; Slack on exit 2. | Drift is detected and alerted; apply remains a separate, approved step. | Plan artifact in CI; Slack; Config for desired-state rules. |
| **Detection & response** | High-severity threat (e.g. EC2 compromise) left uncontained. | GuardDuty → EventBridge → Lambda (quarantine EC2, snapshot, SNS); runbooks in `detection-response/runbooks/`. | Automation contains and notifies; human triages and decides restore or terminate. | GuardDuty findings; CloudWatch Logs (Lambda); SNS; runbook execution. |

None of these layers alone is “zero trust”; together they implement verify explicitly, least privilege, assume breach, and verify every resource.

---

## 4. Image Signing Trust Model

Supply-chain trust for container images depends on **what is trusted at deploy time**. The control plane uses Cosign for signing; admission (Kyverno) enforces that only signed images run in designated namespaces. Key storage, rotation, and compromise response are part of production operating reality.

**Where the Cosign private key is stored:** In this implementation, the private key used by CI to sign images is stored as a **GitHub Actions secret** (e.g. `COSIGN_PRIVATE_KEY`, with `COSIGN_PASSWORD` for passphrase). GitHub encrypts secrets at rest and exposes them only to the workflow run. For higher-assurance deployments, the key is stored in **AWS KMS** or another HSM-backed service; the CI role calls KMS to sign (no key material in CI). This repo implements the GitHub-secret approach in **`ci-cd/github-actions/cosign-sign.yml`**; KMS is an operational decision for the deploying team.

**Rotation:** Key rotation requires (1) generating a new key pair, (2) adding the new public key to Kyverno (e.g. in a Secret or policy), (3) re-signing existing images that must remain deployable with the new key (or running a transition period where both keys are accepted), and (4) removing the old public key and retiring the old private key. Rotation is scheduled (e.g. annually) and documented in runbooks. Rotation is manual and coordinated; automation of rotation is planned evolution.

**Compromise response:** If the Cosign private key is compromised, (1) revoke or delete the key from CI and from any KMS, (2) update Kyverno to remove the corresponding public key so previously signed images no longer pass verification (or switch to a new key and re-sign only known-good images), (3) re-sign all production images with a new key, (4) rotate any other secrets that might have been co-located, and (5) conduct a post-incident review. Admission blocks images signed with the old key once the public key is removed.

**Keyless signing (planned evolution).** Keyless signing (e.g. Fulcio + CT log) removes key management from the organization; verification uses the certificate chain and transparency log. The control plane will support a move to keyless for reduced operational burden and clearer revocation semantics; current artifacts use key-based Cosign.

**Why this matters:** Without signing and admission enforcement, a compromised pipeline or registry could push a malicious image and it could be deployed. Signing ties an image to a specific key (or identity in keyless); admission ensures only those images run. The trust boundary is “deploy only what was signed by our process,” not “trust the registry label.”

---

## 5. Policy Rollout Strategy

Rolling out admission and policy without breaking production is an enterprise requirement. The control plane uses an **Audit → Enforce** lifecycle and, where applicable, **namespace-based rollout**.

**Audit → Enforce lifecycle:** New Kyverno policies are applied first with **`validationFailureAction: Audit`**. In Audit mode, violating resources are still admitted, but Kyverno produces **PolicyReports** (or ClusterPolicyReports) and violations appear in cluster events and in any dashboard consuming them. Teams measure the volume and type of violations, remediate workloads (e.g. add resource limits, sign images, set serviceAccountName), and only then switch the policy to **`validationFailureAction: Enforce`**. Enforce rejects non-compliant create/update requests at admission time. High-impact policies (e.g. block privileged, require resource limits) are moved to Enforce first; image-signing enforcement is enabled only after all images used in the target namespaces are signed.

**Measuring violations before enforcement:** Use `kyverno apply` or query PolicyReports/ClusterPolicyReport to list violating resources. Track violation count by policy and namespace; set a threshold (e.g. zero critical violations in prod) before flipping to Enforce. Background scan (`background: true`) ensures existing resources are evaluated so the report reflects current state.

**Namespace-based rollout:** Apply policies to a subset of namespaces first (e.g. one app namespace or a non-prod environment). Use `match.namespaces` in Kyverno to scope the policy. Once stable, expand to additional namespaces. This limits blast radius if a policy misconfiguration blocks legitimate workloads.

**Monitoring violations:** PolicyReports and admission denial events are visible in the EKS audit log and in Kyverno’s metrics. Pipeline failures from Conftest or Checkov are visible in CI logs and artifacts. Drift is surfaced by the nightly Terraform workflow and Slack. Operational dashboards surface violation trends and admission denials so teams can fix issues before they become incidents.

**Avoiding production breakage:** Never enable Enforce for a new policy in production without first running Audit in that environment and remediating. Have a rollback plan (revert the policy to Audit or remove the policy) and document the decision to enable Enforce. Platform Security or DevSecOps owns this process, with input from application owners.

---

## 6. Break-Glass Strategy

Emergency access must exist for incident response and recovery, but it must be **logged, time-bound, and reviewed**. This repo does not implement break-glass (it is environment-specific) but defines the strategy so governance and auditors can evaluate it.

**Emergency access role:** A dedicated IAM role (or equivalent) used only for break-glass, not for daily operations. The role has elevated permissions (e.g. ability to modify security groups, restore resources, or assume roles that are otherwise restricted). It is not assumed by CI or by standard developer roles.

**MFA requirement:** Break-glass access to the AWS account (or to assume the emergency role) requires MFA. No long-lived access keys for break-glass; use SSO or IdP with MFA, or temporary credentials gated by MFA.

**CloudTrail logging:** All use of the break-glass role is logged in CloudTrail. Alerts can be configured for assumption of that role. Logs are retained and reviewed; they are not deletable by the break-glass identity (SCPs deny CloudTrail deletion).

**Time-bound session:** Sessions that assume the break-glass role have a short duration (e.g. one hour). Renewal requires re-authentication. This limits the window of exposure if credentials are compromised.

**Post-incident review requirement:** Every use of break-glass triggers a post-incident review: what was done, why it was necessary, and whether controls or runbooks should be updated to reduce future break-glass need. Platform Security or the incident commander owns this.

This strategy is governance-aligned and auditable: emergency access is treated as an exception, not a back door.

---

## 7. Detection & Response Depth

Detection and response cover **both AWS and Kubernetes**. Containment precedes investigation; evidence is preserved before termination.

**AWS: GuardDuty automation.** GuardDuty emits findings to EventBridge. A rule invokes a Lambda that (1) quarantines the affected EC2 instance (replaces security groups with a no-egress quarantine SG), (2) creates EBS snapshots of attached volumes for forensics, and (3) publishes a summary to SNS. The runbook (**`detection-response/runbooks/guardduty-auto-isolate.md`**) describes triage, investigation, and recovery or termination. **Evidence preservation:** Snapshots are tagged (e.g. `GuardDutyQuarantine`, `SourceInstance`); the instance is not terminated by automation so that humans can decide after review. **Alerting:** SNS delivers to email, Slack, or PagerDuty. **Ownership:** Platform Security owns the automation and runbook; on-call performs triage. Containment is automated for high-severity, well-understood finding types; ambiguous cases are handled by runbook without automated action.

**Kubernetes: runtime detection.** The control plane includes **Falco** (or equivalent) for runtime detection inside the cluster (e.g. unexpected process execution, file changes, network activity). Falco alerts are wired to the same notification pipeline (Slack, SNS) and to runbooks. **Evidence preservation:** Pod and node logs, and any captured artifacts, are retained before pod termination. **Containment:** For severe runtime findings, containment may include cordoning a node, scaling down a deployment, or isolating a pod via network policy; the exact action is environment-specific and is defined in a runbook. **Ownership:** Platform Security or SRE owns runbooks; detection rules are tuned to reduce false positives.

**Containment-first thinking:** The control plane does not rely on the attacker “going quiet.” Quarantine (or equivalent) is applied as soon as the finding is processed so that lateral movement and exfiltration are limited. Investigation and termination decisions follow containment and evidence capture.

---

## 8. Observability & Debugging Controls

Engineers must be able to debug blocked traffic, understand policy violations, and investigate drift without weakening the control plane.

**Debugging blocked network traffic:** Pod-to-pod or pod-to-external traffic blocked by NetworkPolicy is debugged by (1) reviewing the NetworkPolicy resources that apply to the source and destination namespaces and pods, (2) checking whether the intended flow is covered by an allow rule (e.g. ingress from ingress-nginx, egress to DNS and allowed namespaces), and (3) using connectivity tests (e.g. `kubectl run` a debug pod in the same namespace and curl or nc to the target). Flow logs (e.g. VPC Flow Logs, or CNI-specific observability) can confirm drops. The control plane does not require opening broad egress for debugging; temporary allow rules or a dedicated debug namespace with controlled egress are the operational standard.

**How policy violations are surfaced:** Kyverno violations appear in PolicyReport/ClusterPolicyReport resources and in the EKS audit log (admission webhook response). CI policy failures (Conftest, Checkov, Gitleaks, Trivy) appear in pipeline logs and, where configured, in the GitHub Security tab or equivalent. Drift is surfaced by the nightly Terraform workflow (Slack, plan artifact). Config non-compliance is visible in the Config console or aggregator. Engineers have read access to these outputs; ownership of remediation is per runbook or team.

**Where logs are aggregated:** CloudTrail (AWS API calls), EKS control plane audit log (API server and admission), and pipeline logs (GitHub Actions or central logging) are the primary sources. Logs are retained in a central store (e.g. S3 with WORM, or a SIEM) with access controlled and audited. Lambda (GuardDuty response) logs go to CloudWatch Logs. Aggregation and retention are operational decisions; the control plane produces the events.

**How drift is investigated:** When the nightly drift workflow fails (exit code 2), the plan artifact is downloaded from CI. Engineers run `terraform plan` locally (or in a dedicated job) with the same backend and compare with the artifact to see what changed. Investigation identifies whether the change was intentional (and should be applied via pipeline) or unauthorized (and should be reverted or corrected in code). Runbooks define who is responsible for drift triage and the escalation path.

---

## 9. Architecture Diagram Section

The file **`architecture/architecture-diagram.drawio`** provides a visual of the control plane. Open it in [draw.io](https://draw.io) or a compatible editor.

**How to interpret the diagram:**

- **Top row:** Developer → GitHub → CI/CD → ECR. This is the build-and-publish flow; identity is GitHub OIDC, and the output is a signed image in the registry.  
- **Middle row:** ArgoCD → EKS → Kyverno → NetworkPolicy → Falco. GitOps deploys to the cluster; admission (Kyverno) and network policy constrain what runs and how it communicates; Falco represents runtime detection.  
- **Bottom row:** AWS Organizations → SCP → Config → Security Hub → GuardDuty. Org-level governance (SCP, Config) and aggregation (Security Hub) sit alongside GuardDuty as the primary AWS detection source.  
- **Side chain:** EventBridge → Lambda → SNS, triggered by GuardDuty. This is the automated response path.

**Account boundaries:** The diagram does not show multiple accounts explicitly; in practice, SCP and Config apply at the OU or account level. Management (or delegated admin) account holds GuardDuty, Config aggregator, and optionally Security Hub; workload accounts hold EKS, Lambda (if run there), and resources. Trust flows assume workload accounts cannot disable GuardDuty or SCPs.

**Identity assumptions:** CI identity is OIDC-assumed role with no long-lived keys. Workload identity is IRSA. Human access is SSO with MFA. Break-glass is a separate, logged path. Actual account and identity layout may vary by deployment.

---

## 10. Enterprise Governance & Compliance

The control plane is built for **continuous compliance** and **evidence-driven audit**. Ownership and auditability are explicit.

**CIS mapping:** Controls are mapped to the CIS AWS Foundations Benchmark (and related controls) in **`compliance/cis-mapping.md`**. Each mapping states how the control is implemented and where evidence lives (Config, GuardDuty, Terraform, CI artifacts).

**Evidence automation:** Evidence is produced automatically where possible: Config compliance state, GuardDuty findings and response, Terraform drift result, CI policy and scan outputs, and CloudTrail. **`compliance/evidence-automation.md`** describes what is automated, where it lives, and what remains manual (e.g. IdP configuration, narrative exceptions).

**Security scorecard:** **`compliance/security-scorecard.md`** defines the scorecard format (control, status, evidence, owner, last verified). The scorecard is populated from the implementation and evidence locations; it is updated when controls or evidence sources change.

**Continuous compliance:** Config rules and GuardDuty run continuously; drift runs nightly; CI runs on every relevant change. Compliance is not a point-in-time snapshot but a continuous state with known evidence locations.

**Residual risk documentation:** Residual risks (third-party compromise, insider misuse, false positives, policy bypass, supply chain beyond image, availability impact of controls) are documented in **`architecture/system-design.md`** and **`architecture/threat-model.md`**. Ownership and review cadence (e.g. annual or on major scope change) are stated. Explicit acknowledgment and ownership of residual risk is a governance maturity requirement; the control plane’s limitations are documented and owned.

---

## 11. How to Deploy (Structured & Ordered)

Deployment order matters: later phases depend on state, identity, and guardrails from earlier phases. The sequence below is the production rollout order.

1. **Backend and state.** Configure Terraform state (e.g. S3 bucket, DynamoDB lock table) and ensure the identity that runs Terraform in CI (OIDC role or equivalent) can read and write state. Without this, no module can be applied or drift-checked consistently.

2. **Org guardrails.** Apply **`terraform/org-guardrails/`**: permission boundary policy and SCPs (deny public S3, wildcard IAM, CloudTrail deletion). Uncomment SCP attachments and set `target_ou_ids` for the OUs that should be constrained. These apply at the org/account level and constrain every principal; they must be in place before workload accounts or roles are used at scale.

3. **Config rules.** Apply **`terraform/config-rules/`** (or equivalent) to enable Config recorder and rules. This provides continuous compliance signals and evidence; it should be in place before relying on Config for audit.

4. **EKS and IRSA.** Apply **`terraform/eks-cluster/`** (or your EKS module), then **`terraform/irsa/`** so workloads have IAM roles via service accounts. Attach the permission boundary to IRSA roles if the same boundary is used for all identities in the account.

5. **Kubernetes policies.** Install Kyverno (or Gatekeeper), then apply **`kubernetes/network-policies/`** (default-deny, then allow rules) and **`kubernetes/pod-security/`**. Apply **`kubernetes/kyverno/`** policies in **Audit** first; remediate violations, then switch to **Enforce** per policy and namespace as described in the policy rollout strategy.

6. **CI/CD.** Wire **`ci-cd/github-actions/`** into the repo: configure OIDC for AWS, store Cosign key (or use keyless) in secrets, and enable **`supply-chain-full.yml`** and **`terraform-drift.yml`** (with Terraform backend and Slack webhook for drift). CI depends on OIDC and secrets; drift depends on state access.

7. **Detection automation.** Deploy **`detection-response/guardduty-quarantine-lambda/`** (Lambda, IAM role, EventBridge rule, quarantine security group). Ensure GuardDuty is enabled and that the SNS topic (and any Slack integration) is configured. Run through **`detection-response/runbooks/guardduty-auto-isolate.md`** so on-call understands the flow.

Each module has its own README for variables and prerequisites. Deviating from this order leaves gaps (e.g. workloads running before admission is enforced, or drift running without state access).

---

## 12. How to Break It (Attack Simulation)

Controlled attack simulations verify that controls respond as intended. For each scenario, the table below states the **control that blocks or detects**, the **log or alert generated**, and the **evidence artifact** produced. Run only in non-production or with explicit approval.

| Attack | What you do | Control that blocks or detects | Log / alert | Evidence artifact |
| ------ | ----------- | -------------------------------- | ----------- | -------------------- |
| **Unsigned image** | Deploy a pod with an image not signed by the trusted Cosign key. | Kyverno verifyImages (when Enforce). | EKS audit log (admission denied); Kyverno PolicyReport. | Admission event in audit log; PolicyReport. |
| **Public S3 bucket** | Apply Terraform or CLI to set bucket ACL to `public-read` or policy with `Principal "*"`. | SCP denies `PutBucketAcl` / `PutBucketPolicy`; Conftest or Checkov in CI flags Terraform. | API denial in CloudTrail; CI failure. | CloudTrail event; CI log and Conftest/Checkov output. |
| **Root use** | Perform sensitive action as root (e.g. create user, delete trail). | SCP and permission boundary constrain or deny; Config can alert on root. | CloudTrail (userIdentity.type Root); Config rule. | CloudTrail event; Config compliance. |
| **Secret in repo** | Push a file containing a fake secret. | Gitleaks in CI. | Pipeline failure; Gitleaks report. | CI artifact or log; no deploy. |
| **No resource limits** | Submit a Pod without `resources.limits`. | Kyverno require-resource-limits (Enforce or Audit). | Admission denied or PolicyReport. | PolicyReport; EKS audit log. |
| **GuardDuty finding (EC2)** | Trigger a high-severity GuardDuty finding (e.g. threat list or simulation) for an EC2 instance. | EventBridge invokes Lambda; Lambda quarantines instance, creates snapshots, notifies SNS. | GuardDuty finding; Lambda log; SNS. | EBS snapshots (tagged); SNS payload; runbook execution. |
| **Terraform drift** | Manually change a resource in AWS so it no longer matches state. | Nightly `terraform plan -detailed-exitcode` exits 2. | Workflow failure; Slack. | Plan artifact in CI; Slack message. |

These scenarios illustrate defensive depth: multiple controls (SCP, CI policy, admission) can apply to the same class of risk; logs and artifacts support investigation and audit.

---

## 13. Known Limitations & Residual Risk

The control plane reduces risk but does not eliminate it. The following are explicitly acknowledged and owned.

**Zero-day risk.** Unknown vulnerabilities in dependencies, the OS, or the control plane itself can be exploited before a patch or rule exists. Mitigation: SBOM and scanning, patching cadence, and detection (GuardDuty, Falco) to limit dwell time; the residual risk remains.

**Insider threat limitations.** The control plane assumes breach of a legitimate identity and limits what that identity can do. A determined insider with administrative access and intent to bypass controls may be able to disable or circumvent some controls (e.g. modifying policy in cluster, using break-glass). Mitigation: audit logging, break-glass review, and access review; we do not claim to prevent all insider misuse.

**Third-party supply chain risk.** Compromise of GitHub, AWS, or an upstream dependency could affect the pipeline or runtime. Mitigation: OIDC and role scope limit blast radius; signing and admission limit what can run; the residual risk includes reliance on third-party security.

**False positives.** GuardDuty or Falco may generate false positives; automated quarantine or response can impact legitimate workloads. Mitigation: tune detectors, narrow automation to high-confidence findings, and runbooks to restore; the residual risk includes operational impact from false positives.

**Manual response dependency.** Not all findings are automated; some require human triage and action. Response time depends on on-call and runbook execution. The residual risk includes delay or error in manual response.

**Policy and coverage gaps.** New resource types or APIs may not be covered by Config or admission until rules are added. Continuous coverage review is the operational standard; the residual risk includes gaps until controls are extended.

Residual risk acceptance is documented and owned (e.g. Platform Security, Risk); review is at least annual or on major scope change. See **`architecture/system-design.md`** (Residual risks) and **`architecture/threat-model.md`** for the full set and mitigation statements.

---

## 14. Planned Evolution

- **Keyless signing:** Move from Cosign key-based signing to keyless (Fulcio + CT log) to simplify key management and improve revocation semantics.  
- **mTLS strict mode:** Introduce a service mesh (e.g. Istio) with STRICT mTLS and authorization policies for service-to-service traffic; **`kubernetes/network-policies/README-mtls-istio.md`** is a placeholder.  
- **Automated remediation:** Where safe, automate remediation for drift (e.g. tags, encryption settings) while keeping IAM and network changes human-approved.  
- **Multi-region security aggregation:** Ensure GuardDuty and findings are aggregated and acted on consistently across regions.  
- **Tenant isolation improvements:** Harden tenant isolation (e.g. cluster-per-tenant or stricter namespace and data isolation) and document in the threat model.

---

## Repository Contents

| Area | Purpose |
| ---- | ------- |
| **architecture/** | System design, threat model (STRIDE, assets, actors, attack vectors, controls, residual risk), zero-trust mapping, architecture diagram, diagram layout plan. |
| **terraform/** | Org guardrails (SCPs, permission boundary), EKS baseline, IRSA, Config rules, drift detection. |
| **kubernetes/** | Network policies, pod security, Kyverno (and Gatekeeper placeholder). |
| **policy/** | OPA/Conftest Rego for Terraform (public S3, wildcard IAM, encryption, remote state). |
| **ci-cd/** | GitHub Actions (secret scan, SAST, Checkov, Conftest, Trivy, SBOM, Cosign, supply-chain-full, terraform-drift); SBOM strategy. |
| **detection-response/** | GuardDuty quarantine Lambda (EventBridge, IAM, quarantine SG), runbooks. |
| **compliance/** | CIS mapping, risk scoring example, security scorecard format, evidence automation. |

---

## Prerequisites

- Terraform ≥ 1.5  
- kubectl (cluster access)  
- AWS CLI v2 (with appropriate role)  
- cosign (for image signing; optional if using keyless)

---

## References

- **Architecture and threat model:** **`architecture/system-design.md`**, **`architecture/threat-model.md`**, **`architecture/zero-trust-mapping.md`**.  
- **Deploying:** Per-module READMEs under **`terraform/`**.  
- **Policy and admission:** **`kubernetes/kyverno/README.md`**.  
- **CI/CD and SBOM:** **`ci-cd/github-actions/README.md`**, **`ci-cd/sbom/README.md`**.  
- **Detection and runbooks:** **`detection-response/guardduty-quarantine-lambda/README.md`**, **`detection-response/runbooks/`**.  
- **Compliance:** **`compliance/README.md`**, **`compliance/cis-mapping.md`**, **`compliance/evidence-automation.md`**.

---

## Change Control

All changes via pull request. Architecture and Terraform changes require security/platform review. Threat model and compliance mapping are updated when scope or controls change. Runbooks are updated post-incident and exercised periodically.
