# OSMU Image Signing Policy

This policy defines the prototype image registry target, signing method, and evidence required before pilot or B2B distribution.

## Registry Target

- Registry: GitHub Container Registry.
- Backend image: `ghcr.io/<owner>/osmu-backend`.
- Frontend image: `ghcr.io/<owner>/osmu-frontend`.
- Version tag format: `vMAJOR.MINOR.PATCH`, with release candidates using `vMAJOR.MINOR.PATCH-rc.N`.
- Immutable trace tag: full Git commit SHA.

## Signing Method

- Signing tool: Sigstore Cosign.
- Signing mode: keyless signing through GitHub Actions OIDC.
- Required GitHub workflow permissions: `contents: read`, `packages: write`, `id-token: write`.
- Secret policy: do not store private signing keys in repository or GitHub secrets for the default prototype path.
- Signature target: both version tag and commit SHA tag for backend and frontend images.

## Publish Workflow

- Workflow: `.github/workflows/image-publish-sign-ci.yml`.
- Trigger: `workflow_dispatch` only.
- Default behavior: build-only dry run when `publish=false`.
- Publish behavior: when `publish=true`, login to GHCR with `GITHUB_TOKEN`, push backend/frontend images, capture backend/frontend manifest digests, sign pushed tags with Cosign, then verify signatures.
- Evidence behavior: when `publish=true`, the workflow writes `.osmu-run/latest-image-signing-evidence.json` through `scripts/write-image-signing-evidence.ps1` and uploads it as an artifact. The evidence is PASS only when backend/frontend version tags and commit SHA tags have all been verified by Cosign and backend/frontend `sha256:` digests are present.
- Finalization behavior: after downloading the image signing artifact and the container security/SBOM artifact, run `scripts/finalize-security-evidence.ps1` or `.github/workflows/security-evidence-finalizer-ci.yml` to reject synthetic evidence, promote the passing JSON files to `.osmu-run/latest-image-signing-evidence.json` and `.osmu-run/latest-container-security-evidence.json`, and write `.osmu-run/latest-security-evidence-finalize.json`.

## Verification Requirements

Before durable pilot distribution:

- Container vulnerability scan and SBOM workflow has a successful GitHub-hosted run.
- Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.
- Cosign verification passes for backend and frontend version tags.
- Release notes include image references, image digests, SBOM artifact link, SBOM SHA256 hashes, and signing evidence link.

## Verification Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-image-signing-policy.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-writers.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-finalizer.ps1
```

Example post-publish operator checks:

```powershell
cosign verify ghcr.io/<owner>/osmu-backend:<version> --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
cosign verify ghcr.io/<owner>/osmu-frontend:<version> --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## Current Status

- Policy: drafted.
- Registry target: GHCR selected.
- Workflow draft: included.
- Evidence writer: included.
- Evidence finalizer: included.
- Digest evidence: required by the publish/sign workflow and finalizer.
- Actual signed image evidence: pending successful GitHub-hosted workflow run.
