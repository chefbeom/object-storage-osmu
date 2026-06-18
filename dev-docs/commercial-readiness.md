# OSMU Commercial Readiness Draft

This draft keeps B2B sales, licensing, and pilot packaging decisions visible while the project remains a prototype.

## Positioning

- Product category: private S3-compatible object storage platform.
- Target buyers: teams that need internal large-file storage, media asset storage, department sharing, or self-hosted object storage.
- Early customer fit: streaming/media teams, cloud storage platform teams, and organizations that want private storage instead of public-cloud-only object storage.
- Current sellable state: local lightweight demo only.
- Current non-sellable state: durable pilot and production sale remain NO-GO until external gates and commercial/legal decisions pass.

## Pilot Package

- Pilot name: OSMU MVP v0.1 lightweight demo.
- Pilot duration target: 2 to 4 weeks.
- Pilot deployment mode: local demo first, then customer-controlled Kubernetes or Docker environment after durable gates pass.
- Included support: installation handoff, API walkthrough, S3 client compatibility walkthrough, and operator runbook review.
- Excluded support: production SLA, managed operations, legal warranty, data migration warranty, and regulated workload certification.

## Licensing Draft

- Recommended initial model: annual B2B subscription per deployed environment.
- Optional evaluation model: time-limited pilot license for non-production use.
- Usage metric candidates:
  - stored capacity tier
  - number of active users
  - number of buckets or projects
  - support tier
- License enforcement for MVP: documentation and contract only. Do not add hard runtime lockouts before product/legal review.

## Pricing Draft

- Evaluation: free or fixed-price pilot.
- Team tier: small internal deployment with best-effort support.
- Business tier: larger deployment with backup/restore drill support and priority response.
- Enterprise tier: SSO/LDAP, custom retention/compliance requirements, deployment review, and dedicated support.
- Final prices: pending market validation and legal/commercial approval.

## Required Before Paid Pilot

- Docker/MariaDB/MinIO integration gate passes.
- Real S3 client gate passes with AWS CLI, boto3, host MinIO Client, or Dockerized MinIO Client.
- Browser E2E gate passes.
- Container security/SBOM workflow has a successful GitHub-hosted run.
- Container security evidence JSON is generated as `.osmu-run/latest-container-security-evidence.json`.
- Container security evidence records backend/frontend SBOM SHA256 hashes.
- Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.
- Image signing evidence JSON is generated as `.osmu-run/latest-image-signing-evidence.json`.
- Image signing evidence records backend/frontend `sha256:` image digests.
- Security evidence finalizer report is generated as `.osmu-run/latest-security-evidence-finalize.json` from non-synthetic CI artifacts through `.github/workflows/security-evidence-finalizer-ci.yml`.
- IAM/RBAC finalizer report is generated as `.osmu-run/latest-iam-rbac-finalize.json`; backend focused RBAC tests and live `kubectl auth can-i` evidence from `.github/workflows/iam-rbac-finalizer-ci.yml` are attached for production pilots.
- Pilot contract states data durability limits, support scope, backup/restore responsibility, and license term.

## Required Before Production/B2B Sale

- Durable pilot GO decision.
- Restore drill executed in the target environment.
- Kubernetes HA/DR readiness report is generated as `.osmu-run/latest-kubernetes-ha-dr-readiness.json` from the target namespace through `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` or the operations readiness finalizer.
- Secret/certificate rotation executed in the target environment.
- Monitoring alerts connected to a real Prometheus/Alertmanager/Grafana stack.
- SSO/LDAP or enterprise auth plan implemented or explicitly scoped out.
- Security review, dependency/vulnerability review, and signed image evidence complete.
- Operations readiness artifact import report is generated as `.osmu-run/latest-operations-readiness-artifact-import.json` when evidence is assembled from prior workflow artifacts.
- Operations readiness finalizer report is generated as `.osmu-run/latest-operations-readiness-finalize.json` and the underlying operations readiness result is `ready`.
- Pricing, terms, support SLA, and license agreement approved.

## Current Status

- Commercial positioning: drafted.
- Pilot packaging: drafted.
- License model: drafted.
- Pricing tiers: drafted.
- Final legal/commercial approval: pending.
