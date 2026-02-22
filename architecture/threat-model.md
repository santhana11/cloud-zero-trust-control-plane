# Threat Model (STRIDE)

**Version:** 2.0  
**Scope:** Cloud Zero Trust Platform — multi-account AWS, EKS, CI/CD, detection and response.  
**Method:** STRIDE (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege).  
**Use:** Interview-ready summary of assets, actors, attack vectors, STRIDE mapping, controls, and residual risk.

---

## 1. Scope and Assumptions

- **In scope:** Management and workload accounts; EKS clusters; IRSA; Terraform and Config; CI/CD (GitHub Actions, image build/sign, GitOps); GuardDuty and automated response; audit logging.
- **Out of scope:** Application-layer business logic (separate product threat model); physical security; third-party SaaS internal security (we trust GitHub and AWS as providers).
- **Assumptions:** Identity (SSO, IRSA) is correctly configured; we focus on external and compromised-identity threats rather than malicious insiders deliberately bypassing controls.

---

## 2. Assets

What we are protecting: data, systems, and identities that, if compromised, would impact confidentiality, integrity, or availability.

| Asset | Description | Sensitivity |
|-------|-------------|-------------|
| **Tenant data** | Dealer/OEM data in multi-tenant stores (DB, object storage) | High — regulatory, contractual |
| **Secrets and credentials** | API keys, DB credentials, signing keys (CI, Cosign) | High — enables impersonation and data access |
| **Terraform state** | State files (S3) describing live infra | High — tampering enables malicious infra change |
| **Container images** | Production images in registry | High — supply-chain and runtime integrity |
| **Audit and security logs** | CloudTrail, EKS audit, Config, GuardDuty findings | High — repudiation and investigation |
| **CI/CD pipelines and config** | Workflows, repo, branch protection | High — controls what gets deployed |
| **IAM and RBAC** | Roles, policies, service accounts | High — elevation of privilege and lateral movement |
| **EKS control plane and workloads** | API server, nodes, pods | High — availability and integrity of services |

---

## 3. Actors

Who interacts with the system; useful for “who can do what” and “who might attack.”

| Actor | Role | Trust level | Typical access |
|-------|------|-------------|----------------|
| **External attacker** | No legitimate access; aims to steal data, disrupt service, or abuse resources | None | None by design; must exploit vulnerability or stolen identity |
| **Compromised identity** | Legitimate user or workload whose credentials or session are stolen or abused | Assumed hostile once compromised | Bounded by that identity’s permissions; we minimize blast radius |
| **Developer** | Pushes code, triggers CI; may have read to prod config, no direct prod write by default | Trusted with guardrails | GitHub, CI (OIDC); scope limited by branch and role |
| **Platform / SRE** | Operates infra, applies Terraform, manages cluster; break-glass when needed | Trusted with higher privilege | AWS (role), kubectl (RBAC); actions logged and time-bound where possible |
| **Automation** | CI (GitHub Actions), GitOps, Lambda (GuardDuty response) | Trusted but least-privilege | OIDC/IRSA; only the permissions granted to each role |
| **Third-party provider** | GitHub, AWS | Trusted | We rely on their security; we don’t model their internal threats here |

---

## 4. Attack Vectors

How an attacker could target our assets; helps prioritize controls and explain STRIDE entries.

| Vector | Description | Example |
|--------|-------------|--------|
| **Credential theft** | Steal long-lived keys or session tokens to impersonate user or workload | Stolen access key used to call AWS APIs or push to registry |
| **Supply chain** | Compromise build or dependency so malicious code or image enters pipeline or runtime | Malicious base image, poisoned dependency, or compromised CI |
| **Misconfiguration** | Exploit overly permissive IAM, RBAC, or network policy to access or move | Overly broad IRSA role; namespace without network policy |
| **Tampering with state or pipeline** | Modify Terraform state or CI config to apply malicious change | State file edited to add backdoor; workflow changed to skip scans |
| **Log and audit evasion** | Delete or alter logs to hide activity or avoid accountability | CloudTrail or EKS audit log deleted or modified |
| **Resource abuse** | Exhaust compute, API, or network to cause denial of service | Noisy neighbor in cluster; API throttling; cost abuse |
| **Privilege escalation** | Use a low-privilege identity to gain higher privilege (IAM or cluster) | Pod with broad IRSA; user with cluster-admin via misconfigured RBAC |
| **Cross-tenant access** | Access another tenant’s data via bug or misconfiguration | Missing tenant_id filter; namespace or RBAC misconfiguration |

---

## 5. STRIDE Mapping

Threats categorized by STRIDE, with affected asset, mitigation, and owner. Use this table to walk through “how we address each category” in interviews.

| ID | Category | Threat | Affected asset / component | Mitigation | Owner |
|----|----------|--------|----------------------------|------------|--------|
| **S1** | **S**poofing | Attacker impersonates CI or deploy identity to push malicious image or Terraform | CI/CD, registry, EKS | OIDC for CI (no long-lived keys); cosign verification at deploy; IRSA for workloads | Platform Security |
| **S2** | **S**poofing | Stolen or forged pod identity to call AWS APIs | EKS, IRSA | IRSA with minimal role per workload; CloudTrail for AssumeRole; no static keys in cluster | Platform Security |
| **T1** | **T**ampering | Terraform state or pipeline config modified to apply malicious change | Terraform state, GitHub | State in S3 with versioning and lock; pipeline from protected branch; code review; nightly drift detection | DevSecOps |
| **T2** | **T**ampering | Malicious image substituted in registry or at deploy | Registry, GitOps | Image signing (cosign); admission policy only allows signed images; registry integrity | DevSecOps |
| **T3** | **T**ampering | Audit logs altered or deleted | Central log store | WORM (e.g. S3 Object Lock); SCP deny StopLogging/DeleteTrail; no delete for writers | Security Engineering |
| **R1** | **R**epudiation | Actor denies having made a change or access | All sensitive actions | CloudTrail, EKS audit log, pipeline logs; immutable where possible; every action tied to identity | Security Engineering |
| **I1** | **I**nformation disclosure | Secret or key leaked from repo, log, or pod | Secrets, keys, config | Secret scan in CI (Gitleaks); no secrets in code; Secrets Manager/Vault; least-privilege IRSA | DevSecOps |
| **I2** | **I**nformation disclosure | Cross-tenant data access via misconfiguration or bug | Tenant data | tenant_id in queries; network policy and RBAC; namespace isolation; access review | Platform Security |
| **D1** | **D**enial of service | Resource exhaustion (API, node, network) in shared cluster | EKS, AWS APIs | Resource quotas and limit ranges; rate limiting; GuardDuty for abuse; multi-account blast radius | SRE / Platform |
| **D2** | **D**enial of service | Pipeline or deploy system unavailable | CI/CD, GitOps | HA for CI and GitOps; runbooks; dependency on GitHub/AWS accepted with incident plan | DevSecOps |
| **E1** | **E**levation of privilege | Pod or role gains more AWS permission than intended | IRSA, IAM | Least-privilege roles per workload; permission boundary; SCPs (deny wildcard IAM); periodic review | Platform Security |
| **E2** | **E**levation of privilege | User or pod gains cluster-admin or cross-tenant RBAC | EKS RBAC, Kyverno | RBAC and admission policy; no broad cluster-admin; break-glass with audit and time limit | Platform Security |

---

## 6. Controls Implemented

Concrete controls we have implemented (in this repo or referenced design) that map to the STRIDE mitigations above. Use this to show “we didn’t just list threats; we implemented these.”

| Control area | Controls implemented | Where / how |
|--------------|----------------------|-------------|
| **Identity (AWS)** | Permission boundary; SCPs (deny public S3, wildcard IAM, CloudTrail delete); no root for daily ops | Terraform: `org-guardrails/iam-permission-boundary.tf`, `scp-deny-guardrails.tf` |
| **Identity (EKS)** | IRSA per workload; no long-lived keys in cluster | Terraform: `irsa/`; OIDC trust, minimal role policies |
| **CI/CD** | OIDC for GitHub Actions; secret scan (Gitleaks); SAST (Semgrep); Checkov/Conftest for Terraform; Trivy (fail on critical/high); SBOM (Syft); Cosign signing | GitHub Actions: `secret-scan`, `sast-semgrep`, `checkov-terraform`, `conftest-terraform`, `trivy-container`, `sbom-syft`, `cosign-sign`, `supply-chain-full` |
| **Admission (EKS)** | Kyverno: signed images, resource limits, no privileged, serviceAccount, default-deny network policy | Kubernetes: `kyverno/*.yaml` |
| **Policy (Terraform)** | OPA/Conftest: deny public S3, wildcard IAM, require encryption, remote state | Policy: `policy/opa/terraform/`; CI: `conftest-terraform.yml` |
| **Detection** | GuardDuty org-wide; EventBridge → Lambda: quarantine EC2, snapshot, SNS | Terraform + Lambda: `detection-response/guardduty-quarantine-lambda/`; runbook: `guardduty-auto-isolate.md` |
| **Drift** | Nightly `terraform plan -detailed-exitcode`; Slack on drift; plan artifact | CI: `terraform-drift.yml` |
| **Config** | Config recorder and rules; remediation where safe | Terraform: `config-rules/`, org-guardrails |
| **Network (EKS)** | Default-deny network policies; allow-only namespace-to-namespace; Pod Security (restricted) | Kubernetes: `network-policies/`, `pod-security/` |
| **Audit** | CloudTrail (SCP prevents deletion); EKS audit log; pipeline and Lambda logs | SCP; CloudTrail; Config |

---

## 7. Residual Risk

Risks that remain after controls; we accept or mitigate them as stated and review periodically. Use this to show “we know what we haven’t eliminated.”

| Risk | Description | Mitigation / acceptance |
|------|-------------|--------------------------|
| **Third-party compromise** | Compromise of GitHub or AWS could allow abuse of CI or cloud resources | Rely on vendor security and detection; OIDC and role scope limit blast radius; monitor for anomalous AssumeRole and pipeline runs. |
| **Insider misuse** | Admin or developer with elevated access could intentionally bypass controls | Assume breach; segment and audit; break-glass and sensitive actions logged; access review and least privilege. |
| **False positives in automation** | GuardDuty or automation could isolate or revoke legitimate activity | Tune detectors; narrow automation to high-confidence findings; runbook to restore; post-incident review. |
| **Policy bypass** | New resource types or APIs might not yet be covered by Config or admission | Continuous coverage review; add rules and policies as new services are adopted. |
| **Supply chain beyond image** | Compromise of base image or dependency not yet in CVE DB | SBOM and scan; pin and review bases; monitor for new CVEs and respond per runbook. |
| **Availability impact of controls** | Admission or IAM failure could block deploy or runtime | HA for IdP and policy store; runbooks; fail closed only where security outweighs availability. |

*Residual risk acceptance is owned by Platform Security and Risk; review at least annual or on major scope change.*

---

## 8. Data Flows and Trust Boundaries

Short narrative for interviews: “Where does data flow and where do we enforce trust?”

- **Developer → GitHub → CI:** Developer pushes code; CI runs with OIDC (no stored secrets). Trust boundary: only approved branches and PRs trigger deploy path.
- **CI → Registry → GitOps:** CI builds and signs image; pushes to registry. GitOps syncs only references to signed images. Trust boundary: admission controller enforces “signed only.”
- **GitOps / kubectl → EKS API:** Identity is service account or human (SSO); RBAC and admission limit what can be created. Trust boundary: no anonymous or over-privileged access.
- **Pod → AWS API:** Pod uses IRSA; receives short-lived creds. Trust boundary: role scope minimal; no cross-account unless designed.
- **GuardDuty → Lambda / Runbook:** Finding triggers automation or alert. Trust boundary: only predefined, safe actions (e.g. isolate instance); no arbitrary code execution from finding.

---

## 9. Review and Update

- **Trigger for update:** New major component (e.g. new account type, new CI path); post-incident; annual review.
- **Owner:** Platform Security with input from DevSecOps and SRE.

---

## References

- `system-design.md` — Full architecture and residual risks.
- `zero-trust-mapping.md` — Controls mapped to zero-trust pillars.
- `../compliance/cis-mapping.md` — CIS control mapping.
- `../detection-response/runbooks/` — Incident runbooks.
