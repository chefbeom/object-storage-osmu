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
- Internal chargeback preview: `GET/PUT /api/admin/billing/pricing-policy`, `GET /api/admin/billing/chargeback-preview`, `GET /api/admin/billing/chargeback-alerts`, `GET /api/admin/billing/chargeback-preview/export.csv`, `GET /api/admin/billing/chargeback-invoice-draft/export.csv`, and the Admin billing panel can model organization storage, ingress, egress, internal copy, operation costs, warning/critical threshold alerts, scoped CSV export, and draft invoice CSV export from current usage and data-flow events; this is not a final invoice or approved commercial price list.

## Required Before Paid Pilot

- Docker/MariaDB/MinIO integration gate passes.
- Real S3 client gate passes with AWS CLI, boto3, AWS SDK JavaScript, AWS SDK Java via `OSMU_AWS_SDK_JAVA_CLASSPATH`, host MinIO Client, or Dockerized MinIO Client.
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
- SSO/LDAP or enterprise auth plan implemented or explicitly scoped out. Current code exposes the enterprise auth plan through `GET /api/admin/security/enterprise-auth-plan`, claim preview/audit through `POST /api/admin/security/enterprise-auth/claim-preview`, admin-approved JIT provisioning through `POST /api/admin/security/enterprise-auth/jit-provision`, OIDC authorization request start through `GET /api/auth/oidc/authorize`, callback/token exchange/JWKS validation through `GET /api/auth/oidc/callback`, and LDAP bind/search login through `POST /api/auth/ldap/login`; real IdP/directory smoke remains a production follow-up.
- Enterprise auth target smoke evidence is generated as `.osmu-run/latest-enterprise-auth-smoke.json` with `result=passed` from the customer or pilot IdP/directory through `scripts/write-enterprise-auth-smoke-plan.ps1` or `.github/workflows/enterprise-auth-smoke-ci.yml`, or the enterprise auth scope is explicitly deferred in the pilot contract.
- Security review, dependency/vulnerability review, and signed image evidence complete.
- Operations readiness artifact import report is generated as `.osmu-run/latest-operations-readiness-artifact-import.json` when evidence is assembled from prior workflow artifacts, including enterprise auth smoke evidence when provided.
- Operations readiness finalizer report is generated as `.osmu-run/latest-operations-readiness-finalize.json` and the underlying operations readiness result is `ready`; operations readiness includes the enterprise auth target smoke evidence check.
- Pricing, terms, support SLA, and license agreement approved.

## Current Status

- Commercial positioning: drafted.
- Pilot packaging: drafted.
- License model: drafted.
- Pricing tiers: drafted.
- Chargeback preview: API, persistent pricing policy, Admin billing panel, scoped threshold alerts, scoped preview CSV export, and draft invoice CSV export implemented; finalized invoice approval/persistence, approved pricing workflow, and external alert notification routes remain pending.
- Enterprise auth plan: implemented as local-only plan/readiness API plus OIDC claim preview/audit, admin-approved JIT provisioning, authorization URL start, callback validation for existing local users, LDAP bind/search adapter for existing local users, a guarded enterprise auth smoke evidence helper, and a manual GitHub Actions smoke workflow. Real target directory smoke result is pending.
- Final legal/commercial approval: pending.
