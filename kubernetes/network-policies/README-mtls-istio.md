# mTLS — Istio Integration (Placeholder)

**Zero Trust Network Layer (mTLS)**

## Purpose

Zero trust requires **mutual TLS (mTLS)** for service-to-service communication so that:
- Every connection is authenticated (both client and server present valid certificates).
- Traffic is encrypted in transit.
- No implicit trust by network: a pod cannot impersonate another without a valid certificate from the mesh CA.

Istio (or similar service mesh) provides mTLS between sidecar proxies without application code changes.

## Intended Design (Placeholder)

1. **Istio** (or Linkerd) installed in the cluster with mTLS enabled (STRICT mode) for the mesh.
2. **Sidecar injection** for namespaces that need mesh (e.g. `app-prod`); workloads get a proxy that terminates and originates mTLS.
3. **PeerAuthentication** resource set to `STRICT` so only TLS from mesh is accepted.
4. **AuthorizationPolicy** (optional) to allow only specific service-to-service paths (e.g. `app-prod/svc-a` can call `app-prod/svc-b` on port 8080).

## Why Placeholder

- Service mesh rollout is a separate phase (operational complexity, upgrade path).
- Current phase uses **NetworkPolicy** for segmentation and **application-level auth** where needed. mTLS adds defense in depth and will be added when mesh is adopted.
- This file serves as the design note and pointer for the next phase.

## References

- Istio: https://istio.io/latest/docs/tasks/security/authentication/authn-policy/
- Zero trust mapping: `../../architecture/zero-trust-mapping.md`
