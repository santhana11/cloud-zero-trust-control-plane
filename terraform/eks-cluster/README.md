# EKS Cluster (Baseline)

**Purpose:** Baseline EKS cluster for a workload account: VPC, subnet layout, cluster with private endpoint option, node group(s), and core add-ons. Does **not** include application workloads; those are deployed via GitOps. IRSA is configured in a separate module (`../irsa`) so roles can be added per application.

## Contents

- **VPC:** Private and optional public subnets; NAT for egress; no direct 0.0.0.0/0 to internet from private nodes where possible.
- **EKS cluster:** Kubernetes version; private endpoint (optional); OIDC for IRSA; control-plane logging (api, audit, authenticator).
- **Node group(s):** Managed node group(s) in private subnets; IAM role for nodes (minimal); optional custom AMI or launch template for hardening.
- **Core add-ons:** EBS CSI, VPC CNI (or custom); optional CoreDNS and kube-proxy tuning. Kyverno/Gatekeeper and network policies are applied from `../../kubernetes/`.

## Prerequisites

- AWS account and VPC (or create in this module).
- Terraform >= 1.5; AWS provider >= 5.x.

## Usage

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
# Then configure kubeconfig and apply kubernetes/ manifests (in order)
```

## State

- Remote backend recommended (S3 + DynamoDB); state lock; encryption.

## References

- `../../architecture/system-design.md`
- `../../architecture/zero-trust-mapping.md`
