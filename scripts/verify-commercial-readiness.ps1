param(
    [string] $CommercialReadinessPath = ".\dev-docs\commercial-readiness.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedPath = Resolve-ProjectPath $CommercialReadinessPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Commercial readiness draft missing: $resolvedPath"
}

$content = Get-Content -Raw -LiteralPath $resolvedPath

Assert-Contains $content "private S3-compatible object storage platform" "Commercial readiness draft"
Assert-Contains $content "streaming/media teams" "Commercial readiness draft"
Assert-Contains $content "Current sellable state: local lightweight demo only." "Commercial readiness draft"
Assert-Contains $content "durable pilot and production sale remain NO-GO" "Commercial readiness draft"
Assert-Contains $content "annual B2B subscription per deployed environment" "Commercial readiness draft"
Assert-Contains $content "time-limited pilot license" "Commercial readiness draft"
Assert-Contains $content "stored capacity tier" "Commercial readiness draft"
Assert-Contains $content "Do not add hard runtime lockouts before product/legal review." "Commercial readiness draft"
Assert-Contains $content "Final prices: pending market validation and legal/commercial approval." "Commercial readiness draft"
Assert-Contains $content 'Internal chargeback preview and invoice workflow:' "Commercial readiness draft"
Assert-Contains $content 'GET /api/admin/billing/chargeback-daily-rollup' "Commercial readiness draft"
Assert-Contains $content 'GET /api/admin/billing/chargeback-daily-rollup/export.csv' "Commercial readiness draft"
Assert-Contains $content 'data-flow daily rollup chargeback trend' "Commercial readiness draft"
Assert-Contains $content 'POST /api/admin/billing/chargeback-adapter-retry-worker/run' "Commercial readiness draft"
Assert-Contains $content 'GET /api/admin/billing/payment-provider-adapter-readiness' "Commercial readiness draft"
Assert-Contains $content 'configured generic webhook/Slack/EMAIL SMTP relay send, private/local webhook and SMTP relay host blocking, outbound payload size caps, optional generic notification/payment webhook HMAC signature headers' "Commercial readiness draft"
Assert-Contains $content 'payment provider handoff outbox/history with adapter retry state and configured generic/CARD/BANK/TAX/ERP webhook profile handoff send' "Commercial readiness draft"
Assert-Contains $content 'ADMIN-only payment provider adapter readiness' "Commercial readiness draft"
Assert-Contains $content 'native payment provider adapter SPI/composite dispatch' "Commercial readiness draft"
Assert-Contains $content 'concrete card/bank/tax/ERP native processor implementations and raw provider response storage remain out of scope.' "Commercial readiness draft"
Assert-Contains $content "Docker/MariaDB/MinIO integration gate passes." "Commercial readiness draft"
Assert-Contains $content 'Real S3 client gate passes with AWS CLI, boto3, AWS SDK JavaScript, AWS SDK Java via `OSMU_AWS_SDK_JAVA_CLASSPATH`, host MinIO Client, or Dockerized MinIO Client.' "Commercial readiness draft"
Assert-Contains $content "Browser E2E gate passes." "Commercial readiness draft"
Assert-Contains $content 'Container security evidence JSON is generated as `.osmu-run/latest-container-security-evidence.json`.' "Commercial readiness draft"
Assert-Contains $content "Container security evidence records backend/frontend SBOM SHA256 hashes." "Commercial readiness draft"
Assert-Contains $content 'Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.' "Commercial readiness draft"
Assert-Contains $content 'Image signing evidence JSON is generated as `.osmu-run/latest-image-signing-evidence.json`.' "Commercial readiness draft"
Assert-Contains $content 'Image signing evidence records backend/frontend `sha256:` image digests.' "Commercial readiness draft"
Assert-Contains $content 'Security evidence finalizer report is generated as `.osmu-run/latest-security-evidence-finalize.json` from non-synthetic CI artifacts through `.github/workflows/security-evidence-finalizer-ci.yml`.' "Commercial readiness draft"
Assert-Contains $content 'IAM/RBAC finalizer report is generated as `.osmu-run/latest-iam-rbac-finalize.json`; backend focused RBAC tests and live `kubectl auth can-i` evidence from `.github/workflows/iam-rbac-finalizer-ci.yml` are attached for production pilots.' "Commercial readiness draft"
Assert-Contains $content 'Kubernetes HA/DR readiness report is generated as `.osmu-run/latest-kubernetes-ha-dr-readiness.json` from the target namespace through `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` or the operations readiness finalizer.' "Commercial readiness draft"
Assert-Contains $content 'Secret/certificate rotation evidence is generated as `.osmu-run/latest-secret-rotation-evidence.json` with `result=passed` from the target environment through `scripts/write-secret-rotation-evidence.ps1` or `.github/workflows/manual-secret-rotation-evidence.yml`; the evidence stores external references and booleans only, never secret values.' "Commercial readiness draft"
Assert-Contains $content 'Enterprise auth target smoke evidence is generated as `.osmu-run/latest-enterprise-auth-smoke.json` with `result=passed` from the customer or pilot IdP/directory through `scripts/write-enterprise-auth-smoke-plan.ps1` or `.github/workflows/enterprise-auth-smoke-ci.yml`; token or credential-like OIDC claim/JIT JSON input fields are rejected before request execution, decoded workflow input files are deleted before artifact upload, and if enterprise auth is contractually deferred, the same helper records `result=scope-out` with `-ConfirmScopeOut`, a non-secret approval reference, and a non-secret reason.' "Commercial readiness draft"
Assert-Contains $content 'Operations readiness artifact import report is generated as `.osmu-run/latest-operations-readiness-artifact-import.json` when evidence is assembled from prior workflow or manual evidence artifacts, including storage backend telemetry, secret rotation, commercial integration, commercial approval, enterprise auth `result=passed` smoke or `result=scope-out` evidence, and operations handoff package evidence when provided.' "Commercial readiness draft"
Assert-Contains $content 'Commercial integration evidence is generated as `.osmu-run/latest-commercial-integration-evidence.json` with `result=passed` from the target environment through `scripts/write-commercial-integration-evidence.ps1` or `.github/workflows/manual-commercial-integration-evidence.yml`; it covers configured notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, CARD/BANK/TAX/ERP payment webhook profile handoff verification, and a sanitized snapshot from `GET /api/admin/billing/payment-provider-adapter-readiness`, requires `VerificationCompletedAt` to be the same as or later than `VerificationStartedAt`, rejects raw provider responses, endpoint URLs, and customer payment fields in the snapshot, deletes decoded workflow snapshot input before artifact upload, and does not claim or require native processor API support.' "Commercial readiness draft"
Assert-Contains $content 'Commercial approval evidence is generated as `.osmu-run/latest-commercial-approval-evidence.json` with `result=passed` through `scripts/write-commercial-approval-evidence.ps1` or `.github/workflows/manual-commercial-approval-evidence.yml`; it records final pricing, terms, support SLA, license agreement, legal approval, pilot contract boundary references, and a sanitized `GET /api/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED` snapshot showing product-side commercial price-list approval state, rejects raw contract/customer/license/payment/raw price table fields in that snapshot, deletes decoded workflow snapshot input before artifact upload, and does not publish prices, legal terms, contracts, customer data, or license keys.' "Commercial readiness draft"
Assert-Contains $content 'Operations handoff package evidence is generated as `.osmu-run/latest-operations-handoff-package.json` with `result=passed` from the target environment through `scripts/write-operations-handoff-package.ps1` or `.github/workflows/manual-operations-handoff-package.yml`; it confirms runbook, troubleshooting, rollback, support escalation, known gaps, commercial approval, and target evidence references, rejects raw remediation/provider/customer/contract/license/payment fields in supplied operations readiness/convergence snapshots before reducing sanitized snapshots to result/count/sync summary fields when required, requires `HandoffCompletedAt` to be the same as or later than `HandoffStartedAt`, and stores no secret values or raw remediation/provider/customer data.' "Commercial readiness draft"
Assert-Contains $content 'Operations readiness finalizer report is generated as `.osmu-run/latest-operations-readiness-finalize.json` and the underlying operations readiness result is `ready`; operations readiness includes the storage backend telemetry target evidence check, secret/certificate rotation target evidence check, commercial integration target evidence check, commercial approval target evidence check, enterprise auth target smoke evidence check, and operations handoff package target evidence check.' "Commercial readiness draft"
Assert-Contains $content '- Chargeback preview: API, persistent pricing policy' "Commercial readiness draft"
Assert-Contains $content 'optional generic notification/payment webhook HMAC signature headers, adapter retry worker dry-run/run controls for notification/payment adapter retry' "Commercial readiness draft"
Assert-Contains $content 'payment provider handoff outbox/history with configured generic/CARD/BANK/TAX/ERP webhook profile handoff send and adapter result retry state' "Commercial readiness draft"
Assert-Contains $content 'commercial integration evidence writer' "Commercial readiness draft"
Assert-Contains $content 'commercial approval evidence writer' "Commercial readiness draft"
Assert-Contains $content 'operations handoff package evidence writer/workflow implemented' "Commercial readiness draft"
Assert-Contains $content 'concrete native card/bank/tax/ERP provider API adapters, target secret/certificate rotation `result=passed` evidence, target commercial integration `result=passed` evidence, target commercial approval `result=passed` evidence, and target operations handoff package `result=passed` evidence remain pending.' "Commercial readiness draft"
Assert-Contains $content 'Final legal/commercial approval: evidence writer implemented; target `result=passed` approval evidence pending.' "Commercial readiness draft"

Write-Host "Commercial readiness draft verified."
Write-Host "Commercial readiness: $resolvedPath"
