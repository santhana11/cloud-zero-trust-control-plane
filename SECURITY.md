# Security Policy

## Scope

This repository is a production-oriented reference implementation for an enterprise Zero Trust security control plane on AWS and Kubernetes. It includes Terraform modules, Kubernetes policies, CI/CD workflows, detection and response automation, and compliance mapping. Security issues in this codebase, documentation, or design that could lead to misconfiguration, privilege escalation, or control bypass in adopters' environments are in scope.

## Responsible Disclosure

We follow responsible disclosure. If you believe you have found a security vulnerability:

1. **Do not open a public GitHub issue** for the vulnerability.
2. Report it privately to the maintainers via the contact method listed in MAINTAINERS.md, or by creating a **private** security advisory in this repository (GitHub: Security > Advisories > New draft advisory).
3. Include a clear description, steps to reproduce, and impact assessment. Where possible, suggest a fix or mitigation.
4. Allow time for the maintainers to triage and respond before any public disclosure.

## Response Timeline

- **Acknowledgement:** We aim to acknowledge receipt of a valid security report within 48 hours (business days).
- **Triage:** We aim to complete initial triage and confirm in-scope vs. out-of-scope within 7 to 14 days.
- **Remediation:** For confirmed vulnerabilities, we will work toward a fix and coordinate disclosure timing with the reporter where appropriate.

We do not guarantee specific fix dates; remediation depends on severity, complexity, and maintainer capacity.

## In-Scope

- Vulnerabilities in Terraform, Rego, or Kubernetes manifests that could lead to overly permissive IAM, SCP bypass, or admission control bypass when used as documented.
- Design or documentation errors that would cause adopters to deploy insecure configurations (e.g. missing permission boundaries, unsafe default values).
- CI/CD workflow or script flaws that could expose secrets or allow unauthorized pipeline execution when integrated as described.

## Out-of-Scope / Non-Supported

- Security issues in third-party services (AWS, Kubernetes, GitHub Actions, Cosign, Kyverno, etc.) unless the issue is in how this repository configures or uses them in a demonstrably unsafe way.
- General hardening or compliance advice; this repository is a reference implementation, not a managed service.
- Security of environments where this code is deployed; adopters are responsible for their own deployment, secrets management, and operational security.
- Request for security review or penetration testing of adopter environments.

## Safe Harbor

We support safe harbor for security researchers who report vulnerabilities in good faith and in line with this policy. We will not pursue legal action or support complaints related to good-faith vulnerability research and reporting. We ask that you avoid accessing or modifying data or systems that are not your own, and that you not exploit the vulnerability beyond what is necessary to demonstrate it.

## Security Updates

Security-relevant changes (e.g. policy updates, Terraform changes that tighten permissions, dependency updates for known CVEs) will be documented in release notes and, for critical issues, called out in the repository release or advisory.
