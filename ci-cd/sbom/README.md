# SBOM Strategy — Phase 5

**Purpose:** Define how we generate, store, and use Software Bills of Materials (SBOMs) for **supply chain transparency**, vulnerability correlation, and audit. This document covers the SBOM generation step, artifact upload, CycloneDX format, and how SBOMs support transparency.

---

## 1. SBOM Generation Step

We generate an SBOM **after** the container image is built and before (or alongside) vulnerability scanning.

| Where | What |
|-------|------|
| **sbom-syft.yml** | Standalone workflow: build image → run Syft → upload CycloneDX (and optional SPDX) artifact. |
| **supply-chain-full.yml** | Stage 6: after build + Trivy; uses Syft (or `anchore/sbom-action`) → upload `sbom.cyclonedx.json`. |

**Tool:** [Syft](https://github.com/anchore/syft) by Anchore. It:

- Scans a container image (filesystem + package databases).
- Detects OS packages (dpkg, rpm, apk, etc.) and language ecosystems (npm, pip, go mod, etc.).
- Outputs **CycloneDX** or **SPDX** JSON.

**Example (local):**

```bash
syft myregistry/app:abc123 -o cyclonedx-json=sbom.cyclonedx.json
```

Generation is the **single source of truth** for “what’s in this image” at that tag/sha.

---

## 2. Artifact Upload Step

After generation, we upload the SBOM so it can be retained, attached to releases, or queried later.

| Destination | Purpose |
|-------------|---------|
| **GitHub Actions artifacts** | Retention (e.g. 90 days), download from workflow run, attach to release. |
| **S3 (optional)** | Long-term store keyed by image digest/tag; query “which images contain package X?” for CVE response. |
| **OCI artifact / registry (optional)** | Attach SBOM to the image (e.g. `cosign attach sbom`) so image and SBOM are versioned together. |

**In CI:**

- **Upload step** in `sbom-syft.yml`: `actions/upload-artifact@v4` with `name: sbom-cyclonedx-${{ github.sha }}`, `path: sbom.cyclonedx.json`, `retention-days: 90`.
- Same pattern in `supply-chain-full.yml` for the combined pipeline.

Naming with `github.sha` (or image digest) keeps one SBOM per build and avoids overwrites.

---

## 3. Supply Chain Transparency

**What we mean by “supply chain transparency”**

- **Visibility:** Anyone with access (auditors, security, compliance) can see exactly which open-source and third-party components are in a given image or release.
- **Traceability:** When a new CVE is announced, we can correlate it to our SBOMs and answer “which images or services are affected?” without rescanning from scratch.
- **Evidence:** SBOMs are auditable evidence for SOC 2, PCI, or customer questionnaires (“do you produce SBOMs?”).

**How SBOM supports it**

1. **Build time:** One SBOM per image (or per application manifest). No hidden dependencies.
2. **Storage:** Artifacts and/or S3/registry so SBOMs are available for the lifetime of the image or retention policy.
3. **Consumption:**  
   - **CVE correlation:** Feed SBOM into a vulnerability DB (e.g. dependency-track, Grype, or Trivy DB) to map “package P at version V” → “CVE-2024-XXXX”.  
   - **Policy:** Optional gate (e.g. block on forbidden license or critical CVE in SBOM).  
   - **Audit:** Provide CycloneDX JSON to auditors or customers.

**Recommended approach**

- Generate SBOM in CI for every image we build (or for every release).
- Upload as pipeline artifact; optionally push to S3 or attach to image in registry.
- Use CycloneDX as the primary format (see below); keep SPDX as optional for tools that require it.

---

## 4. CycloneDX Format Explained

**CycloneDX** is an OASIS standard for SBOMs. We use it because it is compact, widely supported (Trivy, Grype, dependency-track, many scanners), and supports both components and dependency relationships.

### High-level structure

A CycloneDX document (JSON) typically has:

| Section | Meaning |
|--------|--------|
| **`bomFormat`** | `"CycloneDX"` and **`specVersion`** (e.g. `1.4`) |
| **`metadata`** | Who generated it, when, and the component this BOM describes (e.g. the container image). |
| **`components`** | List of **components** (packages, libraries, files). Each has identity (name, version, type, purl, etc.). |
| **`dependencies`** | Optional graph: which component depends on which (e.g. app → lib A → lib B). |

### Key fields for components

- **`type`:** e.g. `library`, `application`, `container`, `operating-system`.  
- **`name`**, **`version`:** Package name and version.  
- **`purl`** (Package URL): Unique identifier, e.g. `pkg:deb/debian/openssl@1.1.1n-0+deb11u4`. Used for CVE matching.  
- **`licenses`:** Declared license(s) for the component.  
- **`description`:** Optional text.

### Example (minimal)

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "metadata": {
    "timestamp": "2024-01-15T12:00:00Z",
    "tools": [{ "vendor": "anchore", "name": "syft" }],
    "component": {
      "type": "container",
      "name": "app",
      "version": "abc123"
    }
  },
  "components": [
    {
      "type": "library",
      "name": "openssl",
      "version": "1.1.1n",
      "purl": "pkg:deb/debian/openssl@1.1.1n-0+deb11u4"
    }
  ],
  "dependencies": []
}
```

### Why CycloneDX (vs SPDX)

- **Compact:** Good for APIs and storage; dependency graph is explicit.  
- **Tool support:** Trivy, Grype, dependency-track, and many vendors consume CycloneDX.  
- **Standard:** OASIS standard; acceptable for regulatory and customer SBOM requirements.

We still generate **SPDX** optionally for tools or contracts that require SPDX.

---

## 5. Summary

| Item | Location / Detail |
|------|-------------------|
| **SBOM generation step** | `ci-cd/github-actions/sbom-syft.yml` (Syft → CycloneDX + optional SPDX); also stage 6 in `supply-chain-full.yml`. |
| **Artifact upload step** | `actions/upload-artifact@v4` in the same workflows; name includes `github.sha`; retention 90 days. |
| **Supply chain transparency** | One SBOM per image; store and use for CVE correlation, policy, and audit evidence. |
| **CycloneDX** | Primary format: `bomFormat`, `metadata`, `components` (with purl, name, version), optional `dependencies`. |

## References

- [CycloneDX spec](https://cyclonedx.org/docs/latest/)
- [Syft](https://github.com/anchore/syft)
- `../../architecture/system-design.md` (Secure SDLC)
- `../github-actions/README.md` (workflow list)
