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
Assert-Contains $content 'Internal chargeback preview: `GET/PUT /api/admin/billing/pricing-policy`, `GET /api/admin/billing/chargeback-preview`, `GET /api/admin/billing/chargeback-alerts`, `GET /api/admin/billing/chargeback-alert-notifications/preview`, `GET/POST /api/admin/billing/chargeback-alert-notifications/outbox`, `GET/POST /api/admin/billing/chargeback-invoice-drafts`, `POST /api/admin/billing/chargeback-invoice-drafts/{invoiceId}/approve`, `GET /api/admin/billing/chargeback-preview/export.csv`, `GET /api/admin/billing/chargeback-invoice-draft/export.csv`, and the Admin billing panel can model organization storage, ingress, egress, internal copy, operation costs, warning/critical threshold alerts, scoped notification payload preview, scoped notification outbox/history, scoped CSV export, draft invoice CSV export, and ADMIN-only draft invoice persistence/internal approval from current usage and data-flow events; this is not a final legal invoice, payment request, or approved commercial price list, and outbox records do not send external notifications until delivery adapters are configured.' "Commercial readiness draft"
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
Assert-Contains $content 'Enterprise auth target smoke evidence is generated as `.osmu-run/latest-enterprise-auth-smoke.json` with `result=passed` from the customer or pilot IdP/directory through `scripts/write-enterprise-auth-smoke-plan.ps1` or `.github/workflows/enterprise-auth-smoke-ci.yml`, or the enterprise auth scope is explicitly deferred in the pilot contract.' "Commercial readiness draft"
Assert-Contains $content 'Operations readiness artifact import report is generated as `.osmu-run/latest-operations-readiness-artifact-import.json` when evidence is assembled from prior workflow artifacts, including enterprise auth smoke evidence when provided.' "Commercial readiness draft"
Assert-Contains $content 'Operations readiness finalizer report is generated as `.osmu-run/latest-operations-readiness-finalize.json` and the underlying operations readiness result is `ready`; operations readiness includes the enterprise auth target smoke evidence check.' "Commercial readiness draft"
Assert-Contains $content '- Chargeback preview: API, persistent pricing policy, Admin billing panel, scoped threshold alerts, scoped notification payload preview, scoped notification outbox/history, scoped preview CSV export, draft invoice CSV export, and ADMIN-only draft invoice persistence/internal approval implemented; legal final invoice/payment workflow, approved pricing workflow, actual external notification delivery adapters, retry worker, and secret storage remain pending.' "Commercial readiness draft"
Assert-Contains $content "Final legal/commercial approval: pending." "Commercial readiness draft"

Write-Host "Commercial readiness draft verified."
Write-Host "Commercial readiness: $resolvedPath"
