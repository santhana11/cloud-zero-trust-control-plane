# IRSA (IAM Roles for Service Accounts)

**Purpose:** Create IAM roles and associate them with EKS service accounts via OIDC. Each application or system component that needs AWS API access gets a dedicated role with least-privilege policy. No long-lived keys in the cluster.

## Contents

- **OIDC provider:** EKS cluster OIDC provider (if not already created by eks-cluster module); used for trust policy.
- **Roles:** One or more IAM roles with trust policy allowing `AssumeRoleWithWebIdentity` from a specific namespace and service account.
- **Policies:** Inline or managed policies attached to roles (e.g. S3 read for a bucket prefix, Secrets Manager get for a path).

## Prerequisites

- EKS cluster with OIDC provider URL known.
- Cluster name and OIDC provider ARN (from eks-cluster or data source).

## Usage

```bash
terraform init
terraform plan -var-file=env.tfvars -out=tfplan
terraform apply tfplan
```

Then in Kubernetes: create ServiceAccount with annotation `eks.amazonaws.com/role-arn: <role_arn>` and reference that SA in pod spec.

## Naming convention

- Role name: `zt-<env>-<app>-irsa` (e.g. `zt-prod-api-irsa`).
- Trust policy: restrict to `system:serviceaccount:<namespace>:<service-account-name>`.

## References

- `../../architecture/system-design.md`
- `../../architecture/threat-model.md` (S2, E1)
