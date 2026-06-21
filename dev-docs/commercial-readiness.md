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
- Internal chargeback preview and invoice workflow: `GET/PUT /api/admin/billing/pricing-policy`, `GET/POST /api/admin/billing/pricing-policy-proposals`, `POST /api/admin/billing/pricing-policy-proposals/{proposalId}/approve`, `POST /api/admin/billing/pricing-policy-proposals/{proposalId}/commercial-approval`, `GET /api/admin/billing/chargeback-preview`, `GET /api/admin/billing/chargeback-daily-rollup`, `GET /api/admin/billing/chargeback-alerts`, `GET /api/admin/billing/chargeback-alert-notifications/preview`, `GET/POST /api/admin/billing/chargeback-alert-notifications/outbox`, `POST /api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-result`, `POST /api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-send`, `GET /api/admin/billing/chargeback-adapter-retry-worker/status`, `POST /api/admin/billing/chargeback-adapter-retry-worker/run`, `GET /api/admin/billing/payment-provider-adapter-readiness`, `GET/POST /api/admin/billing/chargeback-invoice-drafts`, `POST /api/admin/billing/chargeback-invoice-drafts/{invoiceId}/approve`, `POST /api/admin/billing/chargeback-invoice-drafts/{invoiceId}/finalize`, `GET /api/admin/billing/chargeback-invoices`, `POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-request`, `GET/POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff`, `GET /api/admin/billing/chargeback-payment-provider-handoffs`, `POST /api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-result`, `POST /api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-send`, `POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-record`, `GET /api/admin/billing/chargeback-preview/export.csv`, `GET /api/admin/billing/chargeback-daily-rollup/export.csv`, `GET /api/admin/billing/chargeback-invoice-draft/export.csv`, and the Admin billing panel can model organization storage, ingress, egress, internal copy, operation costs, data-flow daily rollup chargeback trends and CSV export, warning/critical threshold alerts, ADMIN-only pricing policy proposal/internal approval, commercial price-list approval reference, scoped notification payload preview, scoped notification outbox/history with adapter retry state and configured generic webhook/Slack/EMAIL SMTP relay send, private/local webhook and SMTP relay host blocking, outbound payload size caps, optional generic notification/payment webhook HMAC signature headers, adapter retry worker dry-run/run controls, scoped CSV export, draft invoice CSV export, ADMIN-only draft invoice persistence/internal approval, final invoice creation, payment request/paid state tracking, payment provider handoff outbox/history with adapter retry state and configured generic/CARD/BANK/TAX/ERP webhook profile handoff send, native payment provider adapter SPI/composite dispatch, and ADMIN-only payment provider adapter readiness from current usage and data-flow events; concrete card/bank/tax/ERP native processor implementations and raw provider response storage remain out of scope.

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
- Secret/certificate rotation evidence is generated as `.osmu-run/latest-secret-rotation-evidence.json` with `result=passed` from the target environment through `scripts/write-secret-rotation-evidence.ps1` or `.github/workflows/manual-secret-rotation-evidence.yml`; the evidence stores external references and booleans only, never secret values.
- Monitoring alerts connected to a real Prometheus/Alertmanager/Grafana stack.
- SSO/LDAP or enterprise auth plan implemented or explicitly scoped out. Current code exposes the enterprise auth plan through `GET /api/admin/security/enterprise-auth-plan`, claim preview/audit through `POST /api/admin/security/enterprise-auth/claim-preview`, admin-approved JIT provisioning through `POST /api/admin/security/enterprise-auth/jit-provision`, OIDC authorization request start through `GET /api/auth/oidc/authorize`, callback/token exchange/JWKS validation through `GET /api/auth/oidc/callback`, and LDAP bind/search login through `POST /api/auth/ldap/login`; real IdP/directory smoke remains a production follow-up.
- Enterprise auth target smoke evidence is generated as `.osmu-run/latest-enterprise-auth-smoke.json` with `result=passed` from the customer or pilot IdP/directory through `scripts/write-enterprise-auth-smoke-plan.ps1` or `.github/workflows/enterprise-auth-smoke-ci.yml`; if enterprise auth is contractually deferred, the same helper records `result=scope-out` with `-ConfirmScopeOut`, a non-secret approval reference, and a non-secret reason.
- Security review, dependency/vulnerability review, and signed image evidence complete.
- Operations readiness artifact import report is generated as `.osmu-run/latest-operations-readiness-artifact-import.json` when evidence is assembled from prior workflow or manual evidence artifacts, including secret rotation, commercial integration, commercial approval, enterprise auth smoke, and operations handoff package evidence when provided.
- Commercial integration evidence is generated as `.osmu-run/latest-commercial-integration-evidence.json` with `result=passed` from the target environment through `scripts/write-commercial-integration-evidence.ps1` or `.github/workflows/manual-commercial-integration-evidence.yml`; it covers configured notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, and CARD/BANK/TAX/ERP payment webhook profile handoff verification, requires `VerificationCompletedAt` to be the same as or later than `VerificationStartedAt`, and does not claim native processor API support.
- Operations handoff package evidence is generated as `.osmu-run/latest-operations-handoff-package.json` with `result=passed` from the target environment through `scripts/write-operations-handoff-package.ps1` or `.github/workflows/manual-operations-handoff-package.yml`; it confirms runbook, troubleshooting, rollback, support escalation, known gaps, commercial approval, and target evidence references, requires `HandoffCompletedAt` to be the same as or later than `HandoffStartedAt`, and stores no secret values.
- Operations readiness finalizer report is generated as `.osmu-run/latest-operations-readiness-finalize.json` and the underlying operations readiness result is `ready`; operations readiness includes the secret/certificate rotation target evidence check, commercial integration target evidence check, commercial approval target evidence check, enterprise auth target smoke evidence check, and operations handoff package target evidence check.
- Commercial approval evidence is generated as `.osmu-run/latest-commercial-approval-evidence.json` with `result=passed` through `scripts/write-commercial-approval-evidence.ps1` or `.github/workflows/manual-commercial-approval-evidence.yml`; it records final pricing, terms, support SLA, license agreement, legal approval, pilot contract boundary references, and no-secret confirmation without publishing prices, legal terms, contracts, customer data, or license keys.

## Current Status

- Commercial positioning: drafted.
- Pilot packaging: drafted.
- License model: drafted.
- Pricing tiers: drafted.
- Data-flow operations analytics: detailed/daily/materialized rollup surfaces plus long-term monthly aggregate JSON/CSV and monthly aggregate store refresh/read/export are implemented for internal operators. This is not AWS billing parity and still needs partitioning or a dedicated external time-series repository before high-volume commercial operations.
- Chargeback preview: API, persistent pricing policy, ADMIN-only pricing policy proposal/internal approval, commercial price-list approval reference, Admin billing panel, data-flow daily rollup chargeback trend/CSV export, scoped threshold alerts, scoped notification payload preview, scoped notification outbox/history with adapter result retry state and configured generic webhook/Slack/EMAIL SMTP relay send, private/local webhook URL and SMTP relay host blocking, outbound payload size caps, optional generic notification/payment webhook HMAC signature headers, adapter retry worker dry-run/run controls for notification/payment adapter retry, scoped preview CSV export, draft invoice CSV export, ADMIN-only draft invoice persistence/internal approval, final invoice/payment state workflow, payment provider handoff outbox/history with configured generic/CARD/BANK/TAX/ERP webhook profile handoff send and adapter result retry state, native payment provider adapter SPI/composite dispatch, ADMIN-only payment provider adapter readiness for generic/CARD/BANK/TAX/ERP profiles, commercial integration evidence writer/workflow, commercial approval evidence writer/workflow, and operations handoff package evidence writer/workflow implemented; concrete native card/bank/tax/ERP provider API adapters, target secret/certificate rotation `result=passed` evidence, target commercial integration `result=passed` evidence, target commercial approval `result=passed` evidence, and target operations handoff package `result=passed` evidence remain pending.
- Enterprise auth plan: implemented as local-only plan/readiness API plus OIDC claim preview/audit, admin-approved JIT provisioning, authorization URL start, callback validation for existing local users, LDAP bind/search adapter for existing local users, a guarded enterprise auth smoke evidence helper, and a manual GitHub Actions smoke workflow. Real target directory smoke result is pending.
- Final legal/commercial approval: evidence writer implemented; target `result=passed` approval evidence pending.
