param(
    [string] $OutputDirectory = ".\.osmu-run\operations-readiness-artifact-import-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Write-JsonEvidence([string] $Path, [hashtable] $Data) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

function New-PassedOperationsHandoffPackageSnapshots(
    [string] $ConvergenceSourceReportResult = "ready",
    [object] $FinalizerFailedCount = 0,
    [object] $FinalizerGapCount = 0,
    [object] $KubernetesReportSyncReady = $true
) {
    return [ordered]@{
        readiness = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            passedCount = 42
            pendingCount = 0
            checkCount = 42
        }
        convergence = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            readinessResult = "ready"
            readinessSummary = "passed=42 pending=0"
            finalizerResult = "ready"
            finalizerReadinessResult = "ready"
            finalizerFailedCount = $FinalizerFailedCount
            finalizerGapCount = $FinalizerGapCount
            kubernetesReportSyncReady = $KubernetesReportSyncReady
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncSourceReportResult = $ConvergenceSourceReportResult
        }
    }
}

function New-PassedOperationsHandoffPackageEvidenceRefs {
    return [ordered]@{
        changeApproval = "CAB-2026-06-22"
        deployment = "deploy/2026-06-22"
        operationsReadiness = "evidence/operations-readiness.json"
        operationsConvergence = "evidence/operations-convergence.json"
        dataFlowStoragePlan = "evidence/data-flow-storage-plan.json"
        dataFlowStorageTransitionRunbook = "evidence/data-flow-storage-transition-runbook.json"
        secretRotation = "evidence/secret-rotation.json"
        commercialIntegration = "evidence/commercial-integration.json"
        commercialApproval = "evidence/commercial-approval.json"
        enterpriseAuth = "evidence/enterprise-auth-smoke.json"
        backupRestore = "evidence/backup-restore.json"
        haDr = "evidence/ha-dr.json"
        monitoring = "evidence/monitoring-threshold.json"
        security = "evidence/security.json"
        iamRbac = "evidence/iam-rbac.json"
        runbookReview = "review/runbook"
        troubleshootingReview = "review/troubleshooting"
        supportEscalation = "support/escalation"
        supportSla = "support/sla"
        knownGaps = "review/known-gaps"
    }
}

function New-PassedOperationsHandoffPackageConfirmations {
    return [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}

function New-PassedOperationsHandoffPackageTargetSnapshots {
    return [ordered]@{
        dataFlowStoragePlan = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            candidateStore = "EXTERNAL_TIME_SERIES"
            checkCount = 8
            passedCount = 8
            pendingCount = 0
            queryPlanEvidencePassed = $true
        }
        dataFlowStorageTransitionRunbook = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            candidateStore = "EXTERNAL_TIME_SERIES"
            failureCount = 0
            checkCount = 8
            confirmationsValid = $true
        }
        secretRotation = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            confirmationsValid = $true
            coreRequiredCount = 5
            coreRotatedCount = 5
            failureCount = 0
            plannedCount = 0
            checkCount = 9
        }
        commercialIntegration = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            countsValid = $true
            integrationCount = 4
            verifiedCount = 4
            requiredCount = 4
            requiredVerifiedCount = 4
            failureCount = 0
            plannedCount = 0
            paymentProviderAdapterReadinessReviewed = $true
            paymentProviderAdapterReadinessReviewedValid = $true
        }
        commercialApproval = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            countsValid = $true
            passedCount = 14
            failureCount = 0
            checkCount = 14
            pricingPolicyProposalCommercialApproved = $true
            pricingPolicyProposalCommercialApprovedValid = $true
            pricingPolicyProposalCommercialApprovedCount = 1
            pricingPolicyProposalApprovedPriceListCount = 1
        }
        enterpriseAuthSmoke = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "scope-out"
            passed = $false
            scopeOutAccepted = $true
            scopeOutAcceptedValid = $true
            countsValid = $true
            passCount = 3
            failCount = 0
            blockedCount = 0
            plannedCount = 0
        }
        monitoringThreshold = [ordered]@{
            provided = $true
            parsed = $true
            validFormatVersion = $true
            result = "passed"
            passed = $true
            complete = $true
            requiredAlertCount = 4
            mappedAlertCount = 4
            missingAlertCount = 0
            routeCount = 2
            grafanaPanelCount = 4
            tuningEvidenceCount = 4
            alertTargetCoverageComplete = $true
            routeCoverageComplete = $true
            grafanaPanelCoverageComplete = $true
            tuningEvidenceCoverageComplete = $true
            thresholdMappingComplete = $true
            failureCount = 0
            checkCount = 10
        }
    }
}

function New-PassedOperationsHandoffPackageChecks {
    $ids = @(
        "environment-name",
        "target-cluster",
        "operator",
        "handoff-started-at",
        "handoff-completed-at",
        "handoff-window-order",
        "change-approval-ref",
        "no-secret-values-confirmed",
        "runbook-reviewed",
        "troubleshooting-reviewed",
        "rollback-reviewed",
        "support-escalation-reviewed",
        "known-gaps-accepted",
        "operations-readiness-evidence",
        "operations-convergence-evidence",
        "operations-readiness-snapshot-ready",
        "operations-convergence-snapshot-ready",
        "data-flow-storage-plan-evidence",
        "data-flow-storage-plan-snapshot-passed",
        "data-flow-storage-plan-reviewed",
        "data-flow-storage-transition-runbook-evidence",
        "data-flow-storage-transition-runbook-snapshot-passed",
        "data-flow-storage-transition-runbook-reviewed",
        "secret-rotation-evidence",
        "secret-rotation-snapshot-passed",
        "secret-rotation-snapshot-reviewed",
        "commercial-integration-evidence",
        "commercial-integration-snapshot-passed",
        "commercial-integration-snapshot-reviewed",
        "commercial-approval-evidence",
        "commercial-approval-snapshot-passed",
        "commercial-approval-snapshot-reviewed",
        "enterprise-auth-evidence",
        "enterprise-auth-smoke-snapshot-accepted",
        "enterprise-auth-smoke-snapshot-reviewed",
        "backup-restore-evidence",
        "ha-dr-evidence",
        "monitoring-evidence",
        "monitoring-threshold-snapshot-passed",
        "monitoring-threshold-reviewed",
        "security-evidence",
        "iam-rbac-evidence"
    )
    return @($ids | ForEach-Object {
        [ordered]@{
            id = $_
            name = $_
            status = "PASS"
            passed = $true
            detail = "verified"
            evidenceRef = "self-test"
        }
    })
}

function New-PassedOperationsHandoffPackageSummary([int] $CheckCount) {
    return [ordered]@{
        passedCount = $CheckCount
        failureCount = 0
        plannedCount = 0
        checkCount = $CheckCount
        operationsReadinessSnapshotResult = "ready"
        operationsConvergenceSnapshotResult = "ready"
        operationsConvergenceFinalizerFailedCount = 0
        operationsConvergenceFinalizerGapCount = 0
        operationsConvergenceKubernetesReportSyncReady = $true
        operationsConvergenceKubernetesReportSyncSourceReportResult = "ready"
        dataFlowStoragePlanSnapshotResult = "passed"
        dataFlowStorageTransitionRunbookSnapshotResult = "passed"
        secretRotationSnapshotResult = "passed"
        commercialIntegrationSnapshotResult = "passed"
        commercialApprovalSnapshotResult = "passed"
        enterpriseAuthSmokeSnapshotResult = "scope-out"
        monitoringThresholdSnapshotResult = "passed"
    }
}

function New-PassedMonitoringThresholdChecks {
    $ids = @(
        "environment-name",
        "target-cluster",
        "operator",
        "review-started-at",
        "review-completed-at",
        "review-window-order",
        "change-approval-ref",
        "threshold-targets-file-exists",
        "threshold-targets-format",
        "threshold-alert-targets-complete",
        "alertmanager-routes-mapped",
        "grafana-panels-mapped",
        "target-tuning-evidence-fields",
        "prometheus-rules-evidence-ref",
        "grafana-dashboard-evidence-ref",
        "alertmanager-route-evidence-ref",
        "target-baseline-evidence-ref",
        "incident-routing-evidence-ref",
        "prometheus-rules-loaded-confirmed",
        "grafana-dashboard-imported-confirmed",
        "alertmanager-routes-reviewed-confirmed",
        "target-baselines-reviewed-confirmed",
        "incident-routing-reviewed-confirmed",
        "no-secret-values-confirmed"
    )
    return @($ids | ForEach-Object {
        [ordered]@{
            id = $_
            name = $_
            status = "PASS"
            passed = $true
            detail = "verified"
        }
    })
}

function New-MinioBucketCorsChecks([bool] $Passed = $true) {
    $required = @(
        "cors-xml-parse",
        "cors-rule",
        "allowed-origin",
        "allowed-methods",
        "allowed-headers",
        "expose-headers",
        "max-age",
        "raw-cors-policy"
    )
    return @($required | ForEach-Object {
        [ordered]@{
            id = $_
            name = $_
            status = if ($Passed) { "PASS" } else { "FAIL" }
            passed = $Passed
            detail = "verified"
        }
    })
}

function New-MinioBucketCorsVerification([bool] $Passed = $true, [object] $FailureCount = 0, [bool] $RawCorsXmlStored = $false) {
    return [ordered]@{
        formatVersion = "osmu.minio-bucket-cors-verification.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        result = if ($Passed) { "passed" } else { "failed" }
        source = [ordered]@{
            mode = "cors-xml-path"
            bucketName = "uploads"
            minioAlias = "osmu-minio"
            sourceRef = ".osmu-run/minio-bucket-cors.xml"
            executeRequested = $false
            mcTimeoutSeconds = 30
            rawCorsXmlStored = $RawCorsXmlStored
        }
        expected = [ordered]@{
            allowedOrigins = @("http://localhost:5173")
            methods = @("GET", "PUT", "POST", "DELETE", "HEAD")
            allowedHeaders = @("*")
            exposeHeaders = @("ETag", "x-amz-request-id", "x-amz-id-2", "x-amz-version-id")
            maxAgeSeconds = 3000
        }
        summary = [ordered]@{
            ruleCount = 1
            exposedHeaderCount = 4
            failureCount = $FailureCount
            plannedCount = 0
        }
        cors = [ordered]@{
            ruleCount = 1
            allowedOrigins = @("http://localhost:5173")
            allowedMethods = @("DELETE", "GET", "HEAD", "POST", "PUT")
            allowedHeaders = @("*")
            exposeHeaders = @("ETag", "x-amz-id-2", "x-amz-request-id", "x-amz-version-id")
            maxAgeSeconds = @(3000)
            rules = @(
                [ordered]@{
                    allowedOrigins = @("http://localhost:5173")
                    allowedMethods = @("DELETE", "GET", "HEAD", "POST", "PUT")
                    allowedHeaders = @("*")
                    exposeHeaders = @("ETag", "x-amz-id-2", "x-amz-request-id", "x-amz-version-id")
                    maxAgeSeconds = @(3000)
                }
            )
        }
        checks = New-MinioBucketCorsChecks -Passed $Passed
        decisionRule = "MinIO bucket CORS verification passes when browser upload headers are exposed."
        scopePolicy = "This evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work, and it does not store raw CORS XML, credentials, bearer tokens, private keys, MinIO root credentials, or object data."
        operatorCommands = [ordered]@{
            collectWithMc = "mc cors info <alias>/<bucket> > .\.osmu-run\minio-bucket-cors.xml"
            verifyFromFile = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-minio-bucket-cors.ps1 -CorsXmlPath .\.osmu-run\minio-bucket-cors.xml -FailIfNotPassed"
            collectAndVerify = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed"
        }
    }
}

function New-PassedDataFlowStorageTransitionRunbookChecks {
    $ids = @(
        "environment-name",
        "target-cluster",
        "operator",
        "review-started-at",
        "review-completed-at",
        "review-window-order",
        "change-approval-ref",
        "data-flow-storage-plan-evidence-ref",
        "data-flow-storage-plan-passed",
        "backfill-evidence-ref",
        "dual-write-or-partition-toggle-evidence-ref",
        "rollback-evidence-ref",
        "reconciliation-evidence-ref",
        "dashboard-cutover-evidence-ref",
        "retention-dry-run-evidence-ref",
        "backfill-rehearsed-confirmed",
        "dual-write-or-partition-toggle-reviewed-confirmed",
        "rollback-rehearsed-confirmed",
        "reconciliation-passed-confirmed",
        "dashboard-cutover-reviewed-confirmed",
        "retention-dry-run-reviewed-confirmed",
        "no-object-keys-in-aggregates-confirmed",
        "no-secret-values-confirmed"
    )
    return @($ids | ForEach-Object {
        [ordered]@{
            id = $_
            name = $_
            status = "PASS"
            passed = $true
            detail = "verified"
        }
    })
}

function New-PassedStorageExpansionFinalize(
    [object] $FailedCount = 0,
    [bool] $SkipRbacGap = $false
) {
    $gaps = @(
        "Backend dry-run runner was not executed.",
        "Backend apply runner was not executed.",
        "Storage backend telemetry evidence was not recorded by the finalizer."
    )
    if ($SkipRbacGap) {
        $gaps = @("RBAC authorization evidence was skipped.") + $gaps
    }

    return [ordered]@{
        formatVersion = "osmu.storage-expansion-finalize.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:01:00Z"
        result = "passed"
        namespace = "osmu"
        tenantName = "osmu-minio"
        manifestPath = "C:\evidence\minio-tenant-pool-expansion.example.yaml"
        kubectlPath = "kubectl"
        powerShellCommand = "pwsh"
        serviceAccount = "osmu-storage-expansion-runner"
        impersonateRunner = $true
        backend = [ordered]@{
            apiBase = ""
            requestId = 0
            runDryRunRunner = $false
            dryRunType = "KUBECTL_DIFF"
            runApply = $false
            applyType = "KUBECTL_APPLY"
            confirmApply = $false
        }
        storageBackendTelemetry = [ordered]@{
            runEvidence = $false
            executeRequested = $false
            adminInfoJsonPath = ""
            environmentName = ""
            targetCluster = ""
            operatorName = ""
            minioAlias = ""
            evidenceRef = ""
            jsonOutputPath = ""
            markdownOutputPath = ""
        }
        evidence = [ordered]@{
            rbacAuth = "C:\evidence\latest-storage-expansion-rbac-auth.json"
            serverDryRun = "C:\evidence\latest-storage-expansion-server-dry-run.json"
            storageBackendTelemetry = ""
            report = "C:\evidence\latest-storage-expansion-finalize.json"
            summary = "C:\evidence\latest-storage-expansion-finalize.md"
        }
        failedCount = $FailedCount
        gaps = $gaps
        steps = @(
            [ordered]@{
                name = "Storage Expansion RBAC auth evidence"
                command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1"
                result = "passed"
                exitCode = 0
                output = "Storage Expansion RBAC auth check passed."
                notes = ""
            },
            [ordered]@{
                name = "Storage Expansion server-side dry-run evidence"
                command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -ImpersonateRunner"
                result = "passed"
                exitCode = 0
                output = "Storage Expansion server-side dry-run passed."
                notes = ""
            }
        )
        secretPolicy = "Secret values, bearer tokens, and raw MinIO admin info are not written to storage expansion finalizer evidence."
    }
}

function New-PassedStorageExpansionRbacAuth {
    return [ordered]@{
        generatedAt = "2026-06-22T00:00:00Z"
        namespace = "osmu"
        serviceAccount = "osmu-storage-expansion-runner"
        subject = "system:serviceaccount:osmu:osmu-storage-expansion-runner"
        kubectlPath = "kubectl"
        expectedAllowedCount = 7
        expectedDeniedCount = 9
        passed = $true
        failedCount = 0
        results = @(
            [ordered]@{ id = "tenant-get"; expectedAllowed = $true; actualAllowed = $true; passed = $true; command = "kubectl auth can-i get tenants.minio.min.io/osmu-minio"; exitCode = 0; output = "yes" },
            [ordered]@{ id = "tenant-patch"; expectedAllowed = $true; actualAllowed = $true; passed = $true; command = "kubectl auth can-i patch tenants.minio.min.io/osmu-minio"; exitCode = 0; output = "yes" },
            [ordered]@{ id = "tenant-update"; expectedAllowed = $true; actualAllowed = $true; passed = $true; command = "kubectl auth can-i update tenants.minio.min.io/osmu-minio"; exitCode = 0; output = "yes" },
            [ordered]@{ id = "statefulset-get"; expectedAllowed = $true; actualAllowed = $true; passed = $true; command = "kubectl auth can-i get statefulsets.apps/osmu-minio"; exitCode = 0; output = "yes" },
            [ordered]@{ id = "secret-get-denied"; expectedAllowed = $false; actualAllowed = $false; passed = $true; command = "kubectl auth can-i get secrets/osmu-secret"; exitCode = 0; output = "no" },
            [ordered]@{ id = "pod-exec-denied"; expectedAllowed = $false; actualAllowed = $false; passed = $true; command = "kubectl auth can-i create pods --subresource=exec"; exitCode = 0; output = "no" }
        )
    }
}

function New-PassedStorageExpansionServerDryRun(
    [object] $ImpersonateRunner = $true
) {
    return [ordered]@{
        generatedAt = "2026-06-22T00:00:00Z"
        namespace = "osmu"
        tenantName = "osmu-minio"
        manifestPath = "C:\evidence\minio-tenant-pool-expansion.example.yaml"
        manifestSha256 = "5555555555555555555555555555555555555555555555555555555555555555"
        effectiveManifestSha256 = "6666666666666666666666666666666666666666666666666666666666666666"
        kubectlPath = "kubectl"
        impersonateRunner = $ImpersonateRunner
        serviceAccount = "osmu-storage-expansion-runner"
        subject = "system:serviceaccount:osmu:osmu-storage-expansion-runner"
        passed = $true
        failedCount = 0
        results = @(
            [ordered]@{ id = "tenant-crd-present"; command = "kubectl get crd tenants.minio.min.io -o name"; exitCode = 0; output = "customresourcedefinition.apiextensions.k8s.io/tenants.minio.min.io"; passed = $true },
            [ordered]@{ id = "existing-tenant-present"; command = "kubectl --as=system:serviceaccount:osmu:osmu-storage-expansion-runner -n osmu get tenants.minio.min.io osmu-minio -o name"; exitCode = 0; output = "tenant.minio.min.io/osmu-minio"; passed = $true },
            [ordered]@{ id = "server-side-dry-run"; command = "kubectl --as=system:serviceaccount:osmu:osmu-storage-expansion-runner -n osmu apply --server-side --dry-run=server -f C:\evidence\manifest.yaml"; exitCode = 0; output = "tenant.minio.min.io/osmu-minio serverside-applied (server dry run)"; passed = $true }
        )
    }
}

function New-PassedKubernetesHaDrReadiness {
    $checkNames = @(
        @("deployment-osmu-backend-ready", "ha", "desired=2 ready=2 available=2 minimum=2 topologySpread=True"),
        @("deployment-osmu-frontend-ready", "ha", "desired=2 ready=2 available=2 minimum=2 topologySpread=True"),
        @("statefulset-osmu-mariadb-ready", "ha", "desired=1 ready=1 current=1"),
        @("statefulset-osmu-minio-ready", "ha", "desired=4 ready=4 current=4"),
        @("pdb-osmu-backend-effective", "ha", "minAvailable=1 currentHealthy=2 desiredHealthy=1 disruptionsAllowed=1 expectedDisruptionsAllowedAtLeast=1"),
        @("pdb-osmu-frontend-effective", "ha", "minAvailable=1 currentHealthy=2 desiredHealthy=1 disruptionsAllowed=1 expectedDisruptionsAllowedAtLeast=1"),
        @("pdb-osmu-mariadb-effective", "ha", "minAvailable=1 currentHealthy=1 desiredHealthy=1 disruptionsAllowed=0 expectedDisruptionsAllowedAtLeast=0"),
        @("pdb-osmu-minio-effective", "ha", "minAvailable=1 currentHealthy=4 desiredHealthy=1 disruptionsAllowed=3 expectedDisruptionsAllowedAtLeast=0"),
        @("pvc-osmu-backup-data-bound", "dr", "phase=Bound storage=10Gi"),
        @("cronjob-osmu-mariadb-backup-scheduled", "dr", "schedule=0 2 * * * concurrencyPolicy=Forbid suspend=False"),
        @("cronjob-osmu-minio-backup-scheduled", "dr", "schedule=15 2 * * * concurrencyPolicy=Forbid suspend=False"),
        @("restore-job-server-dry-run", "dr", "kubectl apply --server-side --dry-run=server for restore Job example.")
    )

    $checks = foreach ($check in $checkNames) {
        [ordered]@{
            name = $check[0]
            category = $check[1]
            passed = $true
            summary = $check[2]
            command = "kubectl -n osmu get evidence-for-$($check[0]) -o json"
            exitCode = 0
            output = ""
        }
    }

    return [ordered]@{
        formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        namespace = "osmu"
        kubectlPath = "kubectl"
        restoreManifestPath = "C:\evidence\restore-from-backup.example.yaml"
        result = "passed"
        failureCount = 0
        checks = $checks
    }
}

function New-ReadyKubernetesDrFinalize(
    [string] $BackupTimestamp = "20260622T010203Z",
    [string] $Result = "ready",
    [string] $Status = "kubernetes-dr-finalize-verified",
    [bool] $ConfirmRestore = $true
) {
    return [ordered]@{
        formatVersion = "osmu.kubernetes-dr-finalize.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:20:00Z"
        result = $Result
        status = $Status
        sourceNamespace = "osmu"
        restoreNamespace = "osmu-restore-drill"
        runId = "20260622010203"
        backupTimestamp = $BackupTimestamp
        powerShellCommand = "pwsh"
        serverDryRunOnly = $false
        confirmRestore = $ConfirmRestore
        runBackupDrill = $false
        bootstrapDrBucket = $true
        verifyDrBucketImmutability = $true
        transferArtifacts = $true
        runRestoreSmoke = $true
        writeEvidenceRequest = $true
        submitEvidence = $true
        apiBase = "https://restore-api.example.com/api"
        adminLoginId = "admin"
        adminPasswordProvided = $true
        expectedBucketName = "restored-bucket"
        expectedObjectKey = "restored-object.txt"
        runS3ClientSmoke = $true
        requireS3Client = $false
        paths = [ordered]@{
            drDrillEvidence = "C:\evidence\latest-kubernetes-dr-drill.json"
            restoreSmokeEvidence = "C:\evidence\latest-kubernetes-restore-smoke.json"
            drEvidenceRequest = "C:\evidence\latest-kubernetes-dr-evidence-request.json"
            report = "C:\evidence\latest-kubernetes-dr-finalize.json"
            summary = "C:\evidence\latest-kubernetes-dr-finalize.md"
        }
        commands = @(
            [ordered]@{ name = "Kubernetes DR drill wrapper"; script = ".\scripts\run-kubernetes-dr-drill.ps1"; arguments = @("-ConfirmRestore"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -ConfirmRestore" },
            [ordered]@{ name = "Kubernetes restore smoke"; script = ".\scripts\verify-kubernetes-restore-smoke.ps1"; arguments = @("-RunS3ClientSmoke"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -RunS3ClientSmoke" },
            [ordered]@{ name = "Kubernetes DR evidence request"; script = ".\scripts\write-kubernetes-dr-evidence-request.ps1"; arguments = @("-Submit"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -Submit -AdminPassword <secret>" }
        )
        steps = @(
            [ordered]@{ name = "Kubernetes DR drill wrapper"; script = ".\scripts\run-kubernetes-dr-drill.ps1"; arguments = @("-ConfirmRestore"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -ConfirmRestore"; result = "passed"; exitCode = 0; output = "Kubernetes DR drill passed."; notes = "" },
            [ordered]@{ name = "Kubernetes restore smoke"; script = ".\scripts\verify-kubernetes-restore-smoke.ps1"; arguments = @("-RunS3ClientSmoke"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -RunS3ClientSmoke"; result = "passed"; exitCode = 0; output = "Restore smoke passed."; notes = "" },
            [ordered]@{ name = "Kubernetes DR evidence request"; script = ".\scripts\write-kubernetes-dr-evidence-request.ps1"; arguments = @("-Submit"); command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -Submit -AdminPassword <secret>"; result = "passed"; exitCode = 0; output = "DR evidence request submitted."; notes = "" }
        )
        gaps = @()
        secretPolicy = "Admin password and DR secret values are not written to this finalize report; displayed commands mask -AdminPassword."
    }
}

function New-PassedIamRbacFinalize(
    [string] $Status = "iam-rbac-static-passed",
    [object] $FailedCount = 0,
    [bool] $RunBackendPolicyTests = $false,
    [bool] $RunKubernetesLiveAuth = $false,
    [bool] $OmitKubernetesStep = $false
) {
    $commands = @(
        [ordered]@{
            name = "IAM/RBAC matrix verifier"
            executable = "pwsh"
            arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\scripts\verify-iam-rbac-matrix.ps1")
            workingDirectory = "C:\project\object-storage-osmu"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-matrix.ps1"
        },
        [ordered]@{
            name = "Kubernetes RBAC matrix verifier"
            executable = "pwsh"
            arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\scripts\verify-kubernetes-rbac-matrix.ps1")
            workingDirectory = "C:\project\object-storage-osmu"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-rbac-matrix.ps1"
        }
    )
    $steps = @(
        [ordered]@{
            name = "IAM/RBAC matrix verifier"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-matrix.ps1"
            workingDirectory = "C:\project\object-storage-osmu"
            result = "passed"
            exitCode = 0
            output = "IAM/RBAC matrix verified."
            notes = ""
        }
    )
    if (-not $OmitKubernetesStep) {
        $steps += [ordered]@{
            name = "Kubernetes RBAC matrix verifier"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-rbac-matrix.ps1"
            workingDirectory = "C:\project\object-storage-osmu"
            result = "passed"
            exitCode = 0
            output = "Kubernetes RBAC matrix verified."
            notes = ""
        }
    }
    if ($RunBackendPolicyTests) {
        $commands += [ordered]@{
            name = "Backend focused RBAC tests"
            executable = ".\gradlew.bat"
            arguments = @("test", "--tests", "com.example.osmu.auth.AdminRbacPolicyTest")
            workingDirectory = "C:\project\object-storage-osmu\osmu-backend"
            command = ".\gradlew.bat test --tests com.example.osmu.auth.AdminRbacPolicyTest"
        }
        $steps += [ordered]@{
            name = "Backend focused RBAC tests"
            command = ".\gradlew.bat test --tests com.example.osmu.auth.AdminRbacPolicyTest"
            workingDirectory = "C:\project\object-storage-osmu\osmu-backend"
            result = "passed"
            exitCode = 0
            output = "BUILD SUCCESSFUL"
            notes = ""
        }
    }
    if ($RunKubernetesLiveAuth) {
        $commands += [ordered]@{
            name = "Storage expansion live RBAC auth"
            executable = "pwsh"
            arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\scripts\verify-storage-expansion-rbac-auth.ps1")
            workingDirectory = "C:\project\object-storage-osmu"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1"
        }
        $steps += [ordered]@{
            name = "Storage expansion live RBAC auth"
            command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1"
            workingDirectory = "C:\project\object-storage-osmu"
            result = "passed"
            exitCode = 0
            output = "Storage Expansion RBAC auth check passed."
            notes = ""
        }
    }

    return [ordered]@{
        formatVersion = "osmu.iam-rbac-finalize.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:01:00Z"
        result = "passed"
        status = $Status
        namespace = "osmu"
        serviceAccount = "osmu-storage-expansion-runner"
        powerShellCommand = "pwsh"
        gradleCommand = ".\gradlew.bat"
        runBackendPolicyTests = $RunBackendPolicyTests
        runKubernetesLiveAuth = $RunKubernetesLiveAuth
        commands = $commands
        steps = $steps
        failedCount = $FailedCount
        gaps = @(
            "Backend focused RBAC JUnit tests were not selected.",
            "Live kubectl auth can-i evidence was not selected."
        )
        decisionRule = "IAM/RBAC finalization passes when the application IAM/RBAC matrix and Kubernetes RBAC matrix verifiers pass. Backend focused tests and live kubectl auth can-i evidence are optional stronger evidence selected by flags."
        secretPolicy = "IAM/RBAC finalizer does not read or write passwords, API keys, kubeconfig contents, bearer tokens, or object storage credentials."
    }
}

function New-PassedSecurityEvidenceFinalizer(
    [object] $FailureCount = 0,
    [object] $AllowSyntheticEvidence = $false
) {
    return [ordered]@{
        formatVersion = "osmu.security-evidence-finalize.v1"
        result = "passed"
        failureCount = $FailureCount
        allowSyntheticEvidence = $AllowSyntheticEvidence
        inputs = [ordered]@{
            imageSigningEvidence = "C:\evidence\latest-image-signing-evidence.json"
            containerSecurityEvidence = "C:\evidence\latest-container-security-evidence.json"
        }
        promoted = [ordered]@{
            imageSigningEvidence = "C:\evidence\latest-image-signing-evidence.json"
            containerSecurityEvidence = "C:\evidence\latest-container-security-evidence.json"
            actions = @(
                "promoted image signing evidence to C:\evidence\latest-image-signing-evidence.json",
                "promoted container security evidence to C:\evidence\latest-container-security-evidence.json"
            )
        }
        source = [ordered]@{
            imageSigningRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/123456"
            containerSecurityRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/123457"
            containerSecurityArtifactName = "container-security-1234567890abcdef1234567890abcdef12345678"
        }
        images = [ordered]@{
            backendVersionRef = "ghcr.io/osmu/object-storage-osmu-backend:v1.2.3"
            backendShaRef = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
            frontendVersionRef = "ghcr.io/osmu/object-storage-osmu-frontend:v1.2.3"
            frontendShaRef = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
            backendDigest = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
            frontendDigest = "sha256:2222222222222222222222222222222222222222222222222222222222222222"
            backendImage = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
            frontendImage = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
        }
        checks = @(
            [ordered]@{
                name = "image signing evidence result"
                passed = $true
                status = "PASS"
                detail = "result=passed"
                evidencePath = "C:\evidence\latest-image-signing-evidence.json"
            },
            [ordered]@{
                name = "container security evidence result"
                passed = $true
                status = "PASS"
                detail = "result=passed"
                evidencePath = "C:\evidence\latest-container-security-evidence.json"
            }
        )
        decisionRule = "Security evidence finalization passes only when image signing evidence and container scan/SBOM evidence are present, parsed, passed, non-synthetic by default, and promotable to the standard latest evidence paths."
        secretPolicy = "Finalizer copies and summarizes existing evidence JSON only; it does not read or write registry auth material, signing keys, kubeconfig, or application secrets."
    }
}

function Write-TextEvidence([string] $Path, [string] $Content) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Content | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

function New-ScopeOutEnterpriseAuthEvidence(
    [object] $Accepted = $true,
    [object[]] $Checks = @(
        @{ id = "enterprise-auth-scope-out-confirmed"; name = "Enterprise auth commercial scope-out confirmed"; category = "enterprise-auth"; endpoint = "commercial approval"; status = "PASS"; detail = "ConfirmScopeOut=True."; requiredInputs = @("ConfirmScopeOut") },
        @{ id = "enterprise-auth-scope-out-ref"; name = "Enterprise auth scope-out approval reference recorded"; category = "enterprise-auth"; endpoint = "commercial approval"; status = "PASS"; detail = "scopeOutRef=pilot-contract-enterprise-auth-deferred-20260620."; requiredInputs = @("ScopeOutRef") },
        @{ id = "enterprise-auth-scope-out-reason"; name = "Enterprise auth scope-out reason recorded"; category = "enterprise-auth"; endpoint = "commercial approval"; status = "PASS"; detail = "scopeOutReason=Pilot phase uses local password login."; requiredInputs = @("ScopeOutReason") }
    )
) {
    return @{
        formatVersion = "osmu.enterprise-auth-smoke.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        result = "scope-out"
        executionMode = "scope-out"
        apiBase = ""
        requireOidc = $false
        requireLdap = $false
        requireAuditEvents = $false
        scopeOut = @{
            confirmed = $true
            reference = "pilot-contract-enterprise-auth-deferred-20260620"
            reason = "Pilot phase uses local password login."
            accepted = $Accepted
        }
        inputs = @{
            adminLoginId = ""
            adminPasswordProvided = $false
            oidcCallbackCodeProvided = $false
            oidcCallbackStateProvided = $false
            oidcClaimPreviewJsonPathProvided = $false
            oidcJitProvisionJsonPathProvided = $false
            confirmJitProvision = $false
            ldapLoginIdProvided = $false
            ldapPasswordProvided = $false
            expectedEmailProvided = $false
        }
        summary = @{
            passCount = 3
            failCount = 0
            blockedCount = 0
            plannedCount = 0
            skippedCount = 0
        }
        checks = @($Checks)
        decisionRule = "Paid/production pilot requires result=passed from the target IdP/directory, or result=scope-out with an explicit non-secret commercial approval reference and reason. Default plan-only and scope-out modes perform no HTTP requests."
        secretPolicy = "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, raw OIDC claim JSON, and credential-like scope-out references are never written to this evidence; token or credential-like OIDC claim/JIT JSON input fields are rejected before request execution."
    }
}

function New-PassedEnterpriseAuthEvidence(
    [object] $FailCount = 0
) {
    return @{
        formatVersion = "osmu.enterprise-auth-smoke.v1"
        generatedAt = "2026-06-22T00:00:00Z"
        result = "passed"
        executionMode = "execute"
        apiBase = "https://osmu.example.test"
        requireOidc = $true
        requireLdap = $true
        requireAuditEvents = $true
        scopeOut = @{
            confirmed = $false
            reference = ""
            reason = ""
            accepted = $false
        }
        inputs = @{
            adminLoginId = "admin"
            adminPasswordProvided = $true
            oidcCallbackCodeProvided = $true
            oidcCallbackStateProvided = $true
            oidcClaimPreviewJsonPathProvided = $true
            oidcJitProvisionJsonPathProvided = $false
            confirmJitProvision = $false
            ldapLoginIdProvided = $true
            ldapPasswordProvided = $true
            expectedEmailProvided = $true
        }
        summary = @{
            passCount = 6
            failCount = $FailCount
            blockedCount = 0
            plannedCount = 0
            skippedCount = 0
        }
        checks = @(
            @{ id = "admin-login"; name = "Admin login for enterprise auth evidence"; category = "auth"; endpoint = "POST /api/auth/login"; status = "PASS"; detail = "Admin access token acquired in memory only."; requiredInputs = @() },
            @{ id = "enterprise-auth-plan"; name = "Enterprise auth plan API"; category = "enterprise-auth"; endpoint = "GET /api/admin/security/enterprise-auth-plan"; status = "PASS"; detail = "Plan returned. activeLoginMode=LOCAL_PASSWORD."; requiredInputs = @() },
            @{ id = "oidc-authorize"; name = "OIDC authorization request start"; category = "oidc"; endpoint = "GET /api/auth/oidc/authorize"; status = "PASS"; detail = "Authorization request produced URL, state, nonce, and PKCE challenge."; requiredInputs = @() },
            @{ id = "oidc-callback"; name = "OIDC callback login for existing local user"; category = "oidc"; endpoint = "GET /api/auth/oidc/callback"; status = "PASS"; detail = "OIDC callback issued OSMU tokens; tokens kept in memory only."; requiredInputs = @() },
            @{ id = "ldap-login"; name = "LDAP bind/search login for existing local user"; category = "ldap"; endpoint = "POST /api/auth/ldap/login"; status = "PASS"; detail = "LDAP login issued OSMU tokens; LDAP password and tokens are not stored."; requiredInputs = @() },
            @{ id = "audit-log-LOGIN_LDAP"; name = "Enterprise auth audit evidence: LOGIN_LDAP"; category = "audit"; endpoint = "GET /api/admin/audit-logs?eventType=LOGIN_LDAP"; status = "PASS"; detail = "Found recent audit entries for LOGIN_LDAP."; requiredInputs = @() }
        )
        decisionRule = "Paid/production pilot requires result=passed from the target IdP/directory, or result=scope-out with an explicit non-secret commercial approval reference and reason. Default plan-only and scope-out modes perform no HTTP requests."
        secretPolicy = "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, raw OIDC claim JSON, and credential-like scope-out references are never written to this evidence; token or credential-like OIDC claim/JIT JSON input fields are rejected before request execution."
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$sourceRoot = Join-Path $resolvedOutputDirectory "source"
$promotedRoot = Join-Path $resolvedOutputDirectory "promoted"
$invalidRoot = Join-Path $resolvedOutputDirectory "invalid-source"
$weakStorageExpansionRoot = Join-Path $resolvedOutputDirectory "weak-storage-expansion-source"
$weakKubernetesDrRoot = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-source"
$weakKubernetesDrStepsRoot = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-steps-source"
$weakIamRbacRoot = Join-Path $resolvedOutputDirectory "weak-iam-rbac-source"
$weakIamRbacStatusRoot = Join-Path $resolvedOutputDirectory "weak-iam-rbac-status-source"
$weakSecurityFinalizerRoot = Join-Path $resolvedOutputDirectory "weak-security-finalizer-source"
$weakImageSigningRoot = Join-Path $resolvedOutputDirectory "weak-image-signing-source"
$weakImageSigningRefsRoot = Join-Path $resolvedOutputDirectory "weak-image-signing-refs-source"
$weakContainerSecurityRoot = Join-Path $resolvedOutputDirectory "weak-container-security-source"
$weakContainerSecuritySbomRoot = Join-Path $resolvedOutputDirectory "weak-container-security-sbom-source"
$weakStorageBackendTelemetryRoot = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-source"
$weakStorageBackendTelemetryChecksRoot = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-checks-source"
$unsafeStorageBackendTelemetryRoot = Join-Path $resolvedOutputDirectory "unsafe-storage-backend-telemetry-source"
$unsafeMinioBucketCorsRoot = Join-Path $resolvedOutputDirectory "unsafe-minio-bucket-cors-source"
$weakKubernetesOperationsReportSyncRoot = Join-Path $resolvedOutputDirectory "weak-kubernetes-operations-report-sync-source"
$stringCountKubernetesOperationsReportSyncRoot = Join-Path $resolvedOutputDirectory "string-count-kubernetes-operations-report-sync-source"
$nonReadyKubernetesOperationsReportSyncRoot = Join-Path $resolvedOutputDirectory "non-ready-kubernetes-operations-report-sync-source"
$invalidDataFlowRoot = Join-Path $resolvedOutputDirectory "invalid-data-flow-source"
$unsafeDataFlowRoot = Join-Path $resolvedOutputDirectory "unsafe-data-flow-source"
$unsafeDataFlowRunbookRoot = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-source"
$weakDataFlowRunbookRoot = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-source"
$stringBoolDataFlowRunbookRoot = Join-Path $resolvedOutputDirectory "string-bool-data-flow-runbook-source"
$weakDataFlowRunbookChecksRoot = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-checks-source"
$weakDirectDataFlowStoragePlanRoot = Join-Path $resolvedOutputDirectory "weak-direct-data-flow-storage-plan-source"
$stringCountDirectDataFlowStoragePlanRoot = Join-Path $resolvedOutputDirectory "string-count-direct-data-flow-storage-plan-source"
$unsafeMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-source"
$stringBoolMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-source"
$stringCountMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-source"
$missingCountMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-source"
$weakMonitoringThresholdChecksRoot = Join-Path $resolvedOutputDirectory "weak-monitoring-threshold-checks-source"
$weakSecretRotationRoot = Join-Path $resolvedOutputDirectory "weak-secret-rotation-source"
$weakSecretRotationChecksRoot = Join-Path $resolvedOutputDirectory "weak-secret-rotation-checks-source"
$weakCommercialIntegrationRoot = Join-Path $resolvedOutputDirectory "weak-commercial-integration-source"
$weakCommercialIntegrationChecksRoot = Join-Path $resolvedOutputDirectory "weak-commercial-integration-checks-source"
$weakCommercialApprovalRoot = Join-Path $resolvedOutputDirectory "weak-commercial-approval-source"
$weakCommercialApprovalChecksRoot = Join-Path $resolvedOutputDirectory "weak-commercial-approval-checks-source"
$invalidEnterpriseAuthRoot = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-source"
$stringCountEnterpriseAuthRoot = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-source"
$weakEnterpriseAuthChecksRoot = Join-Path $resolvedOutputDirectory "weak-enterprise-auth-checks-source"
$staleOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-source"
$badConvergenceOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-source"
$stringBoolOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-source"
$missingCountOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-source"
$weakTargetOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "weak-target-operations-handoff-package-source"

$storageSource = Join-Path $sourceRoot "storage-expansion"
$haDrSource = Join-Path $sourceRoot "ha-dr-readiness"
$kubernetesDrSource = Join-Path $sourceRoot "kubernetes-dr"
$iamSource = Join-Path $sourceRoot "iam-rbac"
$securitySource = Join-Path $sourceRoot "security-evidence"
$storageBackendTelemetrySource = Join-Path $sourceRoot "storage-backend-telemetry"
$minioBucketCorsSource = Join-Path $sourceRoot "minio-bucket-cors"
$monitoringThresholdSource = Join-Path $sourceRoot "monitoring-threshold"
$secretRotationSource = Join-Path $sourceRoot "secret-rotation"
$commercialIntegrationSource = Join-Path $sourceRoot "commercial-integration"
$commercialApprovalSource = Join-Path $sourceRoot "commercial-approval"
$enterpriseAuthSource = Join-Path $sourceRoot "enterprise-auth"
$operationsHandoffPackageSource = Join-Path $sourceRoot "operations-handoff-package"
$kubernetesOperationsReportSyncSource = Join-Path $sourceRoot "kubernetes-operations-report-sync"
$directDataFlowStoragePlanSource = Join-Path $sourceRoot "data-flow-storage-plan"
$dataFlowStorageTransitionRunbookSource = Join-Path $sourceRoot "data-flow-storage-transition-runbook"

Write-JsonEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.json") (New-PassedStorageExpansionFinalize)
Write-TextEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.md") "# Storage expansion"
Write-JsonEvidence (Join-Path $storageSource "latest-storage-expansion-rbac-auth.json") (New-PassedStorageExpansionRbacAuth)
Write-JsonEvidence (Join-Path $storageSource "latest-storage-expansion-server-dry-run.json") (New-PassedStorageExpansionServerDryRun)
Write-JsonEvidence (Join-Path $haDrSource "latest-kubernetes-ha-dr-readiness.json") (New-PassedKubernetesHaDrReadiness)
Write-JsonEvidence (Join-Path $kubernetesDrSource "nested\latest-kubernetes-dr-finalize.json") (New-ReadyKubernetesDrFinalize)
Write-TextEvidence (Join-Path $kubernetesDrSource "latest-kubernetes-dr-finalize.md") "# Kubernetes DR"
Write-JsonEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.json") (New-PassedIamRbacFinalize)
Write-TextEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.md") "# IAM/RBAC"
Write-JsonEvidence (Join-Path $securitySource "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer)
Write-JsonEvidence (Join-Path $securitySource "latest-image-signing-evidence.json") @{
    formatVersion = "osmu.image-signing-evidence.v1"
    result = "passed"
    failureCount = 0
    version = "v1.2.3"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/123456"
    issuer = "https://token.actions.githubusercontent.com"
    signingMode = "keyless-github-actions-oidc"
    backend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-backend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
        digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    frontend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-frontend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
        digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222"
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    checks = @()
    secretPolicy = "Evidence contains public image references, workflow URL, digests, and signature verification flags only."
}
Write-JsonEvidence (Join-Path $securitySource "latest-container-security-evidence.json") @{
    formatVersion = "osmu.container-security-evidence.v1"
    result = "passed"
    failureCount = 0
    backendImage = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
    frontendImage = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/123457"
    artifactName = "container-security-1234567890abcdef1234567890abcdef12345678"
    scans = @{
        severity = "CRITICAL,HIGH"
        ignoreUnfixed = $true
        backendScanPassed = $true
        frontendScanPassed = $true
    }
    sbom = @{
        format = "SPDX JSON"
        backend = @{
            label = "backend"
            valid = $true
            spdxVersion = "SPDX-2.3"
            packageCount = 42
            byteSize = 4096
            sha256 = "3333333333333333333333333333333333333333333333333333333333333333"
        }
        frontend = @{
            label = "frontend"
            valid = $true
            spdxVersion = "SPDX-2.3"
            packageCount = 84
            byteSize = 8192
            sha256 = "4444444444444444444444444444444444444444444444444444444444444444"
        }
    }
    checks = @()
    secretPolicy = "Evidence contains image names, SBOM metadata, workflow URL, and scan pass flags only."
}
Write-JsonEvidence (Join-Path $storageBackendTelemetrySource "latest-storage-backend-telemetry.json") @{
    formatVersion = "osmu.storage-backend-telemetry.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    source = @{
        mode = "admin-info-json-path"
        minioAlias = "target-minio"
        evidenceRef = "mc-admin-info-run-20260621"
        sourceRef = "artifact://mc-admin-info-run-20260621/minio-admin-info.json"
        adminInfoJsonSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        rawAdminInfoStored = $false
    }
    summary = @{
        poolCount = 1
        serverCount = 2
        onlineServerCount = 2
        offlineServerCount = 0
        driveCount = 4
        capacityKnown = $true
        totalBytes = 1024
        usedBytes = 256
        freeBytes = 768
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true },
        @{ id = "target-cluster"; status = "PASS"; passed = $true },
        @{ id = "operator"; status = "PASS"; passed = $true },
        @{ id = "evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "admin-info-json-parse"; status = "PASS"; passed = $true },
        @{ id = "server-telemetry"; status = "PASS"; passed = $true },
        @{ id = "pool-telemetry"; status = "PASS"; passed = $true },
        @{ id = "drive-telemetry"; status = "PASS"; passed = $true },
        @{ id = "server-health"; status = "PASS"; passed = $true },
        @{ id = "capacity-telemetry"; status = "PASS"; passed = $true },
        @{ id = "raw-admin-info-policy"; status = "PASS"; passed = $true }
    )
    decisionRule = "Storage backend telemetry evidence passes when target environment, cluster, operator, external evidence reference, MinIO admin-info JSON parsing, pool/server/drive summaries, online server state, and capacity totals are all present."
    scopePolicy = "This evidence captures MinIO pool/node operations telemetry for OSMU storage readiness. It is not AWS S3 parity work, and it does not store raw admin info, credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
}
Write-TextEvidence (Join-Path $storageBackendTelemetrySource "latest-storage-backend-telemetry.md") "# Storage backend telemetry"
Write-JsonEvidence (Join-Path $minioBucketCorsSource "latest-minio-bucket-cors-verification.json") (New-MinioBucketCorsVerification)
Write-TextEvidence (Join-Path $minioBucketCorsSource "latest-minio-bucket-cors-verification.md") "# OSMU MinIO Bucket CORS Verification`n`nThis evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work."
$passedMonitoringThresholdChecks = New-PassedMonitoringThresholdChecks
Write-JsonEvidence (Join-Path $monitoringThresholdSource "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    evidenceRef = "monitoring-threshold-evidence-20260622"
    reviewWindow = @{
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:15:00Z"
    }
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
        alertTargetCoverageComplete = $true
        routeCoverageComplete = $true
        grafanaPanelCoverageComplete = $true
        tuningEvidenceCoverageComplete = $true
        thresholdMappingComplete = $true
    }
    evidenceRefs = @{
        changeApproval = "CHG-2026-MONITORING"
        prometheusRules = "prometheus-rules-loaded-20260622"
        grafanaDashboard = "grafana-dashboard-imported-20260622"
        alertmanagerRoute = "alertmanager-routes-reviewed-20260622"
        targetBaseline = "tenant-baseline-reviewed-20260622"
        incidentRouting = "incident-routing-reviewed-20260622"
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
    summary = @{
        failureCount = 0
        checkCount = $passedMonitoringThresholdChecks.Count
    }
    checks = $passedMonitoringThresholdChecks
}
Write-TextEvidence (Join-Path $monitoringThresholdSource "latest-monitoring-threshold-evidence.md") "# Monitoring threshold"
Write-JsonEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    rotationWindow = @{
        startedAt = "2026-06-20T00:00:00Z"
        completedAt = "2026-06-20T00:30:00Z"
    }
    evidenceRefs = @{
        changeApproval = "secret-rotation-20260620"
        secretManagerAudit = "vault-audit-20260620"
        workloadRestart = "rollout-20260620"
        smoke = "smoke-20260620"
        artifactLeakReview = "leak-review-20260620"
        accessKeyEncryptionDecision = "access-key-decision-20260620"
    }
    confirmations = @{
        noSecretValues = $true
        workloadRestart = $true
        smokePassed = $true
        artifactLeakReview = $true
        requireAllCoreSecrets = $false
    }
    rotations = @(
        @{ id = "admin-password"; core = $true; rotated = $true },
        @{ id = "jwt-signing-secret"; core = $true; rotated = $true },
        @{ id = "database-credentials"; core = $true; rotated = $true },
        @{ id = "minio-root-credentials"; core = $true; rotated = $true },
        @{ id = "tls-certificate"; core = $true; rotated = $true }
    )
    summary = @{
        rotatedCount = 5
        coreRotatedCount = 5
        coreRequiredCount = 5
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true },
        @{ id = "target-cluster"; status = "PASS"; passed = $true },
        @{ id = "operator"; status = "PASS"; passed = $true },
        @{ id = "rotation-started-at"; status = "PASS"; passed = $true },
        @{ id = "rotation-completed-at"; status = "PASS"; passed = $true },
        @{ id = "rotation-window-order"; status = "PASS"; passed = $true },
        @{ id = "change-approval-ref"; status = "PASS"; passed = $true },
        @{ id = "secret-manager-evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "workload-restart-evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "smoke-evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "artifact-leak-review-evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "no-secret-values-confirmed"; status = "PASS"; passed = $true },
        @{ id = "workload-restart-confirmed"; status = "PASS"; passed = $true },
        @{ id = "smoke-passed-confirmed"; status = "PASS"; passed = $true },
        @{ id = "artifact-leak-review-confirmed"; status = "PASS"; passed = $true },
        @{ id = "core-secret-rotation-coverage"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B readiness requires result=passed from the target environment after core secret/certificate rotation, workload restart, post-rotation smoke, and artifact leak review are confirmed."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain password values, API keys, private keys, bearer tokens, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
}
Write-TextEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.md") "# Secret rotation"
Write-JsonEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    verificationWindow = @{
        startedAt = "2026-06-20T00:30:00Z"
        completedAt = "2026-06-20T01:00:00Z"
    }
    evidenceRefs = @{
        changeApproval = "commercial-integration-20260620"
        paymentProviderAdapterReadiness = "payment-adapter-readiness-20260620"
        adapterRetryWorker = "adapter-retry-20260620"
        payloadReview = "payload-review-20260620"
        privateNetworkBlocking = "private-block-20260620"
        hmacSignature = "hmac-review-20260620"
    }
    confirmations = @{
        noSecretValues = $true
        noRawProviderResponses = $true
        payloadSizeCaps = $true
        privateNetworkBlocking = $true
        hmacSignatureHeaders = $true
        paymentProviderAdapterReadinessReviewed = $true
        adapterRetryWorkerRun = $true
        requireAllImplementedAdapters = $true
        requirePaymentProviderAdapterReadinessReview = $true
    }
    integrations = @(
        @{ id = "notification-webhook"; required = $true; verified = $true; evidenceRef = "notification-webhook-20260620" },
        @{ id = "notification-slack"; required = $true; verified = $true; evidenceRef = "slack-webhook-20260620" },
        @{ id = "notification-email-smtp"; required = $true; verified = $true; evidenceRef = "email-smtp-20260620" },
        @{ id = "payment-generic-webhook"; required = $true; verified = $true; evidenceRef = "payment-generic-20260620" },
        @{ id = "payment-card-profile"; required = $true; verified = $true; evidenceRef = "payment-card-20260620" },
        @{ id = "payment-bank-profile"; required = $true; verified = $true; evidenceRef = "payment-bank-20260620" },
        @{ id = "payment-tax-profile"; required = $true; verified = $true; evidenceRef = "payment-tax-20260620" },
        @{ id = "payment-erp-profile"; required = $true; verified = $true; evidenceRef = "payment-erp-20260620" }
    )
    paymentProviderAdapterReadiness = @{
        required = $true
        reviewed = $true
        evidenceRef = "payment-adapter-readiness-run-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            validMode = $true
            status = "WEBHOOK_PROFILE_READY"
            nativeApiSupported = $false
            nativeApiReady = $false
            profileCount = 5
            webhookReadyProfileCount = 5
            nativeApiReadyProfileCount = 0
            countsValid = $true
            booleansValid = $true
            profiles = @(
                @{ providerProfile = "GENERIC"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "CARD"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "BANK"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "TAX"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "ERP"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
            )
        }
    }
    summary = @{
        integrationCount = 8
        verifiedCount = 8
        requiredCount = 8
        requiredVerifiedCount = 8
        paymentProviderAdapterReadinessReviewed = $true
        paymentProviderAdapterReadinessStatus = "WEBHOOK_PROFILE_READY"
        paymentProviderAdapterWebhookReadyProfileCount = 5
        paymentProviderAdapterNativeReadyProfileCount = 0
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true },
        @{ id = "target-cluster"; status = "PASS"; passed = $true },
        @{ id = "operator"; status = "PASS"; passed = $true },
        @{ id = "verification-started-at"; status = "PASS"; passed = $true },
        @{ id = "verification-completed-at"; status = "PASS"; passed = $true },
        @{ id = "verification-window-order"; status = "PASS"; passed = $true },
        @{ id = "change-approval-ref"; status = "PASS"; passed = $true },
        @{ id = "no-secret-values-confirmed"; status = "PASS"; passed = $true },
        @{ id = "no-raw-provider-responses-confirmed"; status = "PASS"; passed = $true },
        @{ id = "payload-size-caps-confirmed"; status = "PASS"; passed = $true },
        @{ id = "private-network-blocking-confirmed"; status = "PASS"; passed = $true },
        @{ id = "hmac-signature-confirmed"; status = "PASS"; passed = $true },
        @{ id = "adapter-retry-worker-confirmed"; status = "PASS"; passed = $true },
        @{ id = "payment-provider-adapter-readiness-snapshot"; status = "PASS"; passed = $true },
        @{ id = "payment-provider-adapter-readiness-counts-typed"; status = "PASS"; passed = $true },
        @{ id = "payment-provider-adapter-readiness-booleans-typed"; status = "PASS"; passed = $true },
        @{ id = "payment-provider-adapter-readiness-profile-coverage"; status = "PASS"; passed = $true },
        @{ id = "payment-provider-adapter-readiness-reviewed"; status = "PASS"; passed = $true },
        @{ id = "integration-notification-webhook"; status = "PASS"; passed = $true },
        @{ id = "integration-notification-slack"; status = "PASS"; passed = $true },
        @{ id = "integration-notification-email-smtp"; status = "PASS"; passed = $true },
        @{ id = "integration-payment-generic-webhook"; status = "PASS"; passed = $true },
        @{ id = "integration-payment-card-profile"; status = "PASS"; passed = $true },
        @{ id = "integration-payment-bank-profile"; status = "PASS"; passed = $true },
        @{ id = "integration-payment-tax-profile"; status = "PASS"; passed = $true },
        @{ id = "integration-payment-erp-profile"; status = "PASS"; passed = $true },
        @{ id = "required-integration-coverage"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B commercial integration readiness requires result=passed from the target environment for every required notification/payment handoff adapter profile, payment-provider adapter readiness review, adapter retry worker evidence, payload cap check, private/local endpoint blocking check, HMAC signature review, no-secret confirmation, and no-raw-provider-response confirmation."
    scopePolicy = "This evidence covers configured webhook/Slack/EMAIL SMTP relay, generic/CARD/BANK/TAX/ERP payment webhook profile handoff verification, and the sanitized payment-provider adapter readiness snapshot. It does not claim or require native card, bank, tax invoice, or ERP processor API support."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain webhook URLs with credentials, SMTP passwords, payment provider credentials, signing secrets, bearer tokens, private keys, raw provider responses, or customer payment data."
}
Write-TextEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.md") "# Commercial integration"
Write-JsonEvidence (Join-Path $commercialApprovalSource "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    productVersion = "v0.1.0-rc.1"
    approvedBy = "commercial-review-board"
    approvedAt = "2026-06-20T03:00:00Z"
    evidenceRefs = @{
        approval = "commercial-approval-board-20260620"
        pricing = "pricing-approval-20260620"
        terms = "terms-approval-20260620"
        supportSla = "support-sla-approval-20260620"
        licenseAgreement = "license-agreement-approval-20260620"
        legal = "legal-approval-20260620"
        pilotContract = "pilot-contract-template-20260620"
        pricingPolicyProposal = "pricing-policy-proposal-commercial-approval-20260620"
        notes = "commercial-readiness-review-20260620"
    }
    confirmations = @{
        pricingApproved = $true
        termsApproved = $true
        supportSlaApproved = $true
        licenseApproved = $true
        legalApproved = $true
        pricingPolicyProposalCommercialApproval = $true
        requirePricingPolicyProposalApprovalSnapshot = $true
        noSecretValues = $true
    }
    pricingPolicyProposalApproval = @{
        required = $true
        reviewed = $true
        evidenceRef = "pricing-policy-proposal-commercial-approval-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            proposalCount = 2
            approvedPriceListCount = 1
            commercialApprovedCount = 1
            approvalFlagsValid = $true
            proposals = @(
                @{
                    id = 101
                    status = "PRICE_LIST_APPROVED"
                    approvedPriceList = $true
                    commercialApprovalReference = "commercial-approval-board-20260620"
                    commercialApprovedAt = "2026-06-20T05:10:00Z"
                }
            )
        }
    }
    summary = @{
        passedCount = 14
        failureCount = 0
        checkCount = 14
        pricingPolicyProposalCommercialApproved = $true
        pricingPolicyProposalCommercialApprovedCount = 1
        pricingPolicyProposalApprovedPriceListCount = 1
        pricingPolicyProposalApprovalFlagsValid = $true
    }
    checks = @(
        @{ id = "product-version"; status = "PASS"; passed = $true },
        @{ id = "approval-ref"; status = "PASS"; passed = $true },
        @{ id = "approved-by"; status = "PASS"; passed = $true },
        @{ id = "approved-at"; status = "PASS"; passed = $true },
        @{ id = "pricing-approved"; status = "PASS"; passed = $true },
        @{ id = "terms-approved"; status = "PASS"; passed = $true },
        @{ id = "support-sla-approved"; status = "PASS"; passed = $true },
        @{ id = "license-agreement-approved"; status = "PASS"; passed = $true },
        @{ id = "legal-approval-confirmed"; status = "PASS"; passed = $true },
        @{ id = "pilot-contract-boundary-recorded"; status = "PASS"; passed = $true },
        @{ id = "no-secret-values-confirmed"; status = "PASS"; passed = $true },
        @{ id = "pricing-policy-proposal-snapshot"; status = "PASS"; passed = $true },
        @{ id = "pricing-policy-proposal-approval-fields-typed"; status = "PASS"; passed = $true },
        @{ id = "pricing-policy-proposal-commercial-approved"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B sale commercial approval requires result=passed, final pricing approval, final terms approval, support SLA approval, license agreement approval, legal approval, a pilot contract boundary reference, required billing pricing policy proposal commercial approval evidence, and no-secret confirmation."
    scopePolicy = "This evidence records commercial/legal approval references and sanitized billing pricing policy proposal approval status only. It does not publish prices, legal terms, contracts, customer data, or native payment processor credentials."
    secretPolicy = "Evidence stores only product version, approver identity, timestamps, booleans, sanitized pricing proposal status/reference metadata, and external approval references; it must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, raw price tables, or raw contract text."
}
Write-TextEvidence (Join-Path $commercialApprovalSource "latest-commercial-approval-evidence.md") "# Commercial approval"
Write-JsonEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.json") (New-ScopeOutEnterpriseAuthEvidence)
Write-TextEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.md") "# Enterprise auth smoke"
$passedOperationsHandoffPackageChecks = New-PassedOperationsHandoffPackageChecks
Write-JsonEvidence (Join-Path $operationsHandoffPackageSource "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    evidenceRefs = (New-PassedOperationsHandoffPackageEvidenceRefs)
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    summary = (New-PassedOperationsHandoffPackageSummary -CheckCount $passedOperationsHandoffPackageChecks.Count)
    checks = $passedOperationsHandoffPackageChecks
}
Write-TextEvidence (Join-Path $operationsHandoffPackageSource "latest-operations-handoff-package.md") "# Operations handoff package"
$passedDataFlowRunbookChecks = New-PassedDataFlowStorageTransitionRunbookChecks
Write-JsonEvidence (Join-Path $dataFlowStorageTransitionRunbookSource "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    evidenceRef = "data-flow-storage-transition-runbook-20260622"
    reviewWindow = @{
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:20:00Z"
    }
    dataFlowStoragePlanSnapshot = @{
        formatVersion = "osmu.data-flow-storage-plan.v1"
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    evidenceRefs = @{
        changeApproval = "CHG-2026-DATA-FLOW-RUNBOOK"
        dataFlowStoragePlan = "data-flow-storage-plan-passed-20260622"
        backfill = "backfill-rehearsal-20260622"
        dualWriteOrPartitionToggle = "dual-write-toggle-review-20260622"
        rollback = "rollback-rehearsal-20260622"
        reconciliation = "reconciliation-20260622"
        dashboardCutover = "dashboard-cutover-20260622"
        retentionDryRun = "retention-dry-run-20260622"
    }
    summary = @{
        failureCount = 0
        checkCount = $passedDataFlowRunbookChecks.Count
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    checks = $passedDataFlowRunbookChecks
}
Write-TextEvidence (Join-Path $dataFlowStorageTransitionRunbookSource "latest-data-flow-storage-transition-runbook-evidence.md") "# Data-flow storage transition runbook"
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
    sourceReportFormatVersion = "osmu.operations-readiness-convergence.v1"
    sourceReportResult = "ready"
    sourceReportBytes = 2048
    sourceReportSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-plan.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "planned"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-server-dry-run.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "server-dry-run-passed"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
    queryPlanEvidence = @{
        provided = $false
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $false
        result = ""
        mode = ""
        checkCount = 0
        passedCount = 0
        failedCount = 0
        failedChecks = @()
        detail = "No MariaDB query plan evidence JSON supplied."
    }
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    evidenceRef = "data-flow-storage-transition-runbook-20260622"
    reviewWindow = @{
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:20:00Z"
    }
    dataFlowStoragePlanSnapshot = @{
        formatVersion = "osmu.data-flow-storage-plan.v1"
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    evidenceRefs = @{
        changeApproval = "CHG-2026-DATA-FLOW-RUNBOOK"
        dataFlowStoragePlan = "data-flow-storage-plan-passed-20260622"
        backfill = "backfill-rehearsal-20260622"
        dualWriteOrPartitionToggle = "dual-write-toggle-review-20260622"
        rollback = "rollback-rehearsal-20260622"
        reconciliation = "reconciliation-20260622"
        dashboardCutover = "dashboard-cutover-20260622"
        retentionDryRun = "retention-dry-run-20260622"
    }
    summary = @{
        failureCount = 0
        checkCount = $passedDataFlowRunbookChecks.Count
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    checks = $passedDataFlowRunbookChecks
    topFailedChecks = @()
}

$importScript = Resolve-ProjectPath ".\scripts\import-operations-readiness-artifacts.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
    -StorageExpansionArtifactPath $storageSource `
    -HaDrReadinessArtifactPath $haDrSource `
    -KubernetesDrArtifactPath $kubernetesDrSource `
    -IamRbacArtifactPath $iamSource `
    -SecurityEvidenceArtifactPath $securitySource `
    -StorageBackendTelemetryArtifactPath $storageBackendTelemetrySource `
    -MinioBucketCorsArtifactPath $minioBucketCorsSource `
    -MonitoringThresholdArtifactPath $monitoringThresholdSource `
    -SecretRotationArtifactPath $secretRotationSource `
    -CommercialIntegrationArtifactPath $commercialIntegrationSource `
    -CommercialApprovalArtifactPath $commercialApprovalSource `
    -EnterpriseAuthArtifactPath $enterpriseAuthSource `
    -OperationsHandoffPackageArtifactPath $operationsHandoffPackageSource `
    -DataFlowStorageTransitionRunbookArtifactPath $dataFlowStorageTransitionRunbookSource `
    -KubernetesOperationsReportSyncArtifactPath $kubernetesOperationsReportSyncSource `
    -OutputDirectory $promotedRoot `
    -JsonOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json") `
    -MarkdownOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.md") | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "import-operations-readiness-artifacts.ps1 failed with exit code $LASTEXITCODE."
}

$reportPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json"
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert-True ($report.formatVersion -eq "osmu.operations-readiness-artifact-import.v1") "Unexpected import report formatVersion."
Assert-True ($report.result -eq "passed") "Expected import report result=passed."
Assert-True ($report.status -eq "artifact-imported") "Expected import report status=artifact-imported."
Assert-True ($report.importedCount -ge 19) "Expected imported evidence files."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-finalize.json")) "Promoted storage expansion evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-rbac-auth.json")) "Promoted storage expansion RBAC evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-server-dry-run.json")) "Promoted storage expansion server dry-run evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-ha-dr-readiness.json")) "Promoted HA/DR readiness evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-dr-finalize.json")) "Promoted Kubernetes DR evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-iam-rbac-finalize.json")) "Promoted IAM/RBAC evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-security-evidence-finalize.json")) "Promoted security finalizer evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-image-signing-evidence.json")) "Promoted image signing evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-container-security-evidence.json")) "Promoted container security evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.json")) "Promoted storage backend telemetry evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.md")) "Promoted storage backend telemetry markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-minio-bucket-cors-verification.json")) "Promoted MinIO bucket CORS verification missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-minio-bucket-cors-verification.md")) "Promoted MinIO bucket CORS verification markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.json")) "Promoted monitoring threshold evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.md")) "Promoted monitoring threshold markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.json")) "Promoted secret rotation evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.md")) "Promoted secret rotation markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.json")) "Promoted commercial integration evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.md")) "Promoted commercial integration markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.json")) "Promoted commercial approval evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.md")) "Promoted commercial approval markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-enterprise-auth-smoke.json")) "Promoted enterprise auth smoke evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.json")) "Promoted operations handoff package evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.md")) "Promoted operations handoff package markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json")) "Promoted data-flow storage transition runbook evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.md")) "Promoted data-flow storage transition runbook markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-operations-report-sync.json")) "Promoted Kubernetes operations report sync evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-plan.json")) "Promoted data-flow storage plan evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json")) "Promoted data-flow storage transition runbook evidence missing."
$promotedImageSigning = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-image-signing-evidence.json") | ConvertFrom-Json
$promotedContainerSecurity = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-container-security-evidence.json") | ConvertFrom-Json
$promotedStorageExpansion = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-finalize.json") | ConvertFrom-Json
$promotedHaDrReadiness = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-ha-dr-readiness.json") | ConvertFrom-Json
$promotedKubernetesDrFinalize = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-dr-finalize.json") | ConvertFrom-Json
$promotedIamRbac = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-iam-rbac-finalize.json") | ConvertFrom-Json
$promotedCommercialApproval = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.json") | ConvertFrom-Json
$promotedStorageBackendTelemetry = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.json") | ConvertFrom-Json
$promotedMinioBucketCors = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-minio-bucket-cors-verification.json") | ConvertFrom-Json
$promotedMonitoringThreshold = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.json") | ConvertFrom-Json
$promotedSecretRotation = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.json") | ConvertFrom-Json
$promotedCommercialIntegration = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.json") | ConvertFrom-Json
Assert-True ($promotedImageSigning.backend.versionSignatureVerified -eq $true -and $promotedImageSigning.frontend.shaSignatureVerified -eq $true) "Promoted image signing evidence should preserve signature verification flags."
Assert-True ($promotedContainerSecurity.scans.backendScanPassed -eq $true -and $promotedContainerSecurity.sbom.backend.valid -eq $true) "Promoted container security evidence should preserve scan and SBOM flags."
Assert-True ($promotedStorageExpansion.impersonateRunner -eq $true -and $promotedStorageExpansion.failedCount -eq 0) "Promoted storage expansion finalizer should preserve typed runner and failure fields."
Assert-True ($promotedHaDrReadiness.failureCount -eq 0 -and @($promotedHaDrReadiness.checks).Count -ge 12) "Promoted HA/DR readiness evidence should preserve typed check summary."
Assert-True ($promotedKubernetesDrFinalize.confirmRestore -eq $true -and $promotedKubernetesDrFinalize.serverDryRunOnly -eq $false) "Promoted Kubernetes DR finalizer should preserve confirmed restore flags."
Assert-True ($promotedIamRbac.status -eq "iam-rbac-static-passed" -and $promotedIamRbac.failedCount -eq 0) "Promoted IAM/RBAC finalizer should preserve strict status and failed count."
Assert-True ($promotedStorageBackendTelemetry.result -eq "passed") "Promoted storage backend telemetry evidence should preserve result=passed."
Assert-True ($promotedStorageBackendTelemetry.source.rawAdminInfoStored -eq $false) "Promoted storage backend telemetry evidence should preserve rawAdminInfoStored=false."
Assert-True ($promotedMinioBucketCors.result -eq "passed") "Promoted MinIO bucket CORS evidence should preserve result=passed."
Assert-True ($promotedMinioBucketCors.source.rawCorsXmlStored -eq $false) "Promoted MinIO bucket CORS evidence should preserve rawCorsXmlStored=false."
$storageExpansionEntry = @($report.entries | Where-Object { $_.group -eq "storage-expansion" -and $_.fileName -eq "latest-storage-expansion-finalize.json" })
Assert-True ($storageExpansionEntry.Count -eq 1) "Storage expansion finalizer import entry missing."
Assert-True (([string] $storageExpansionEntry[0].detail).Contains("stepCount=2")) "Storage expansion finalizer import entry should include strict step validation detail."
$storageExpansionRbacEntry = @($report.entries | Where-Object { $_.group -eq "storage-expansion" -and $_.fileName -eq "latest-storage-expansion-rbac-auth.json" })
Assert-True ($storageExpansionRbacEntry.Count -eq 1) "Storage expansion RBAC import entry missing."
Assert-True (([string] $storageExpansionRbacEntry[0].detail).Contains("allowed=7") -and ([string] $storageExpansionRbacEntry[0].detail).Contains("denied=9")) "Storage expansion RBAC import entry should include allow/deny validation detail."
$storageExpansionServerDryRunEntry = @($report.entries | Where-Object { $_.group -eq "storage-expansion" -and $_.fileName -eq "latest-storage-expansion-server-dry-run.json" })
Assert-True ($storageExpansionServerDryRunEntry.Count -eq 1) "Storage expansion server dry-run import entry missing."
Assert-True (([string] $storageExpansionServerDryRunEntry[0].detail).Contains("manifestSha256=")) "Storage expansion server dry-run import entry should include manifest hash validation detail."
$haDrReadinessEntry = @($report.entries | Where-Object { $_.group -eq "ha-dr-readiness" -and $_.fileName -eq "latest-kubernetes-ha-dr-readiness.json" })
Assert-True ($haDrReadinessEntry.Count -eq 1) "HA/DR readiness import entry missing."
Assert-True (([string] $haDrReadinessEntry[0].detail).Contains("checkCount=12")) "HA/DR readiness import entry should include strict check validation detail."
$kubernetesDrEntry = @($report.entries | Where-Object { $_.group -eq "kubernetes-dr" -and $_.fileName -eq "latest-kubernetes-dr-finalize.json" })
Assert-True ($kubernetesDrEntry.Count -eq 1) "Kubernetes DR finalizer import entry missing."
Assert-True (([string] $kubernetesDrEntry[0].detail).Contains("kubernetes-dr-finalize-verified") -and ([string] $kubernetesDrEntry[0].detail).Contains("commandCount=3") -and ([string] $kubernetesDrEntry[0].detail).Contains("stepCount=3") -and ([string] $kubernetesDrEntry[0].detail).Contains("backupTimestamp=20260622T010203Z")) "Kubernetes DR finalizer import entry should include strict ready command, step, and timestamp validation detail."
$iamRbacEntry = @($report.entries | Where-Object { $_.group -eq "iam-rbac" -and $_.fileName -eq "latest-iam-rbac-finalize.json" })
Assert-True ($iamRbacEntry.Count -eq 1) "IAM/RBAC finalizer import entry missing."
Assert-True (([string] $iamRbacEntry[0].detail).Contains("iam-rbac-static-passed") -and ([string] $iamRbacEntry[0].detail).Contains("stepCount=2")) "IAM/RBAC finalizer import entry should include strict status and step validation detail."
$imageSigningEntry = @($report.entries | Where-Object { $_.group -eq "security-evidence" -and $_.fileName -eq "latest-image-signing-evidence.json" })
Assert-True ($imageSigningEntry.Count -eq 1) "Image signing import entry missing."
Assert-True (([string] $imageSigningEntry[0].detail).Contains("version=v1.2.3") -and ([string] $imageSigningEntry[0].detail).Contains("signingMode=keyless-github-actions-oidc") -and ([string] $imageSigningEntry[0].detail).Contains("backendDigest=sha256:")) "Image signing import entry should include version, signing mode, and digest validation detail."
$containerSecurityEntry = @($report.entries | Where-Object { $_.group -eq "security-evidence" -and $_.fileName -eq "latest-container-security-evidence.json" })
Assert-True ($containerSecurityEntry.Count -eq 1) "Container security import entry missing."
Assert-True (([string] $containerSecurityEntry[0].detail).Contains("commitSha=1234567890abcdef1234567890abcdef12345678") -and ([string] $containerSecurityEntry[0].detail).Contains("backendPackages=42")) "Container security import entry should include commit and SBOM package validation detail."
$storageBackendTelemetryEntry = @($report.entries | Where-Object { $_.group -eq "storage-backend-telemetry" -and $_.fileName -eq "latest-storage-backend-telemetry.json" })
Assert-True ($storageBackendTelemetryEntry.Count -eq 1) "Storage backend telemetry import entry missing."
Assert-True (([string] $storageBackendTelemetryEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $storageBackendTelemetryEntry[0].detail).Contains("servers=2/2") -and ([string] $storageBackendTelemetryEntry[0].detail).Contains("checkCount=11")) "Storage backend telemetry import entry should include strict target metadata and telemetry validation detail."
$minioBucketCorsEntry = @($report.entries | Where-Object { $_.group -eq "minio-bucket-cors" -and $_.fileName -eq "latest-minio-bucket-cors-verification.json" })
Assert-True ($minioBucketCorsEntry.Count -eq 1) "MinIO bucket CORS import entry missing."
Assert-True (([string] $minioBucketCorsEntry[0].detail).Contains("bucket=uploads") -and ([string] $minioBucketCorsEntry[0].detail).Contains("rawCorsXmlStored=False")) "MinIO bucket CORS import entry should include bucket and no-raw-XML validation detail."
Assert-True ($promotedMonitoringThreshold.result -eq "passed") "Promoted monitoring threshold evidence should preserve result=passed."
Assert-True ($promotedMonitoringThreshold.confirmations.noSecretValues) "Promoted monitoring threshold evidence should preserve no-secret confirmation."
$monitoringThresholdEntry = @($report.entries | Where-Object { $_.group -eq "monitoring-threshold" -and $_.fileName -eq "latest-monitoring-threshold-evidence.json" })
Assert-True ($monitoringThresholdEntry.Count -eq 1) "Monitoring threshold import entry missing."
Assert-True (([string] $monitoringThresholdEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $monitoringThresholdEntry[0].detail).Contains("requiredAlerts=11") -and ([string] $monitoringThresholdEntry[0].detail).Contains("checkRows=24")) "Monitoring threshold import entry should include strict target metadata and check row validation detail."
Assert-True ($promotedSecretRotation.result -eq "passed") "Promoted secret rotation evidence should preserve result=passed."
Assert-True ($promotedCommercialIntegration.result -eq "passed") "Promoted commercial integration evidence should preserve result=passed."
Assert-True ($promotedCommercialApproval.result -eq "passed") "Promoted commercial approval evidence should preserve result=passed."
$secretRotationEntry = @($report.entries | Where-Object { $_.group -eq "secret-rotation" -and $_.fileName -eq "latest-secret-rotation-evidence.json" })
Assert-True ($secretRotationEntry.Count -eq 1) "Secret rotation import entry missing."
Assert-True (([string] $secretRotationEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $secretRotationEntry[0].detail).Contains("coreRotated=5/5") -and ([string] $secretRotationEntry[0].detail).Contains("checkCount=16")) "Secret rotation import entry should include target metadata and core rotation validation detail."
$commercialIntegrationEntry = @($report.entries | Where-Object { $_.group -eq "commercial-integration" -and $_.fileName -eq "latest-commercial-integration-evidence.json" })
Assert-True ($commercialIntegrationEntry.Count -eq 1) "Commercial integration import entry missing."
Assert-True (([string] $commercialIntegrationEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $commercialIntegrationEntry[0].detail).Contains("requiredVerified=8/8") -and ([string] $commercialIntegrationEntry[0].detail).Contains("checkCount=27")) "Commercial integration import entry should include target metadata and required adapter validation detail."
$commercialApprovalEntry = @($report.entries | Where-Object { $_.group -eq "commercial-approval" -and $_.fileName -eq "latest-commercial-approval-evidence.json" })
Assert-True ($commercialApprovalEntry.Count -eq 1) "Commercial approval import entry missing."
Assert-True (([string] $commercialApprovalEntry[0].detail).Contains("productVersion=v0.1.0-rc.1") -and ([string] $commercialApprovalEntry[0].detail).Contains("commercialApproved=1") -and ([string] $commercialApprovalEntry[0].detail).Contains("checkCount=14")) "Commercial approval import entry should include target approval metadata and validation detail."
$promotedEnterpriseAuth = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-enterprise-auth-smoke.json") | ConvertFrom-Json
Assert-True ($promotedEnterpriseAuth.result -eq "scope-out") "Promoted enterprise auth scope-out evidence should be preserved."
$enterpriseAuthImportEntry = @($report.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($enterpriseAuthImportEntry.Count -eq 1) "Enterprise auth import entry missing."
Assert-True (([string] $enterpriseAuthImportEntry[0].detail).Contains("executionMode=scope-out") -and ([string] $enterpriseAuthImportEntry[0].detail).Contains("accepted=true") -and ([string] $enterpriseAuthImportEntry[0].detail).Contains("passCount=3")) "Enterprise auth import entry should document strict scope-out acceptance."
$promotedOperationsHandoffPackage = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.json") | ConvertFrom-Json
Assert-True ($promotedOperationsHandoffPackage.result -eq "passed") "Promoted operations handoff package evidence should preserve result=passed."
Assert-True ($promotedOperationsHandoffPackage.confirmations.noSecretValues) "Promoted operations handoff package should preserve no-secret confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.secretRotationSnapshotReviewed) "Promoted operations handoff package should preserve secret rotation snapshot review confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.commercialApprovalSnapshotReviewed) "Promoted operations handoff package should preserve commercial approval snapshot review confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.enterpriseAuthSmokeSnapshotReviewed) "Promoted operations handoff package should preserve enterprise auth smoke snapshot review confirmation."
$operationsHandoffPackageEntry = @($report.entries | Where-Object { $_.group -eq "operations-handoff-package" -and $_.fileName -eq "latest-operations-handoff-package.json" })
Assert-True ($operationsHandoffPackageEntry.Count -eq 1) "Operations handoff package import entry missing."
Assert-True (([string] $operationsHandoffPackageEntry[0].detail).Contains("requiredConfirmations=17") -and ([string] $operationsHandoffPackageEntry[0].detail).Contains("sourceReportResult=ready") -and ([string] $operationsHandoffPackageEntry[0].detail).Contains("targetSnapshots=7/7")) "Operations handoff package import entry should include required confirmation, strict snapshot validation, and target snapshot validation detail."
$promotedDataFlowRunbook = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json") | ConvertFrom-Json
Assert-True ($promotedDataFlowRunbook.result -eq "passed") "Promoted data-flow storage transition runbook evidence should preserve result=passed."
Assert-True ($promotedDataFlowRunbook.dataFlowStoragePlanSnapshot.result -eq "passed") "Promoted data-flow storage transition runbook evidence should preserve passed storage plan snapshot."
$promotedKubernetesOperationsReportSync = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-operations-report-sync.json") | ConvertFrom-Json
Assert-True ($promotedKubernetesOperationsReportSync.result -eq "applied") "Promoted Kubernetes operations report sync evidence should preserve result=applied."
Assert-True ($promotedKubernetesOperationsReportSync.sourceReportResult -eq "ready") "Promoted Kubernetes operations report sync evidence should preserve ready source report."
$kubernetesOperationsReportSyncEntry = @($report.entries | Where-Object { $_.group -eq "kubernetes-operations-report-sync" -and $_.fileName -eq "latest-kubernetes-operations-report-sync.json" })
Assert-True ($kubernetesOperationsReportSyncEntry.Count -eq 1) "Kubernetes operations report sync import entry missing."
Assert-True (([string] $kubernetesOperationsReportSyncEntry[0].detail).Contains("failedCount=0") -and ([string] $kubernetesOperationsReportSyncEntry[0].detail).Contains("sourceReportResult=ready")) "Kubernetes operations report sync import entry should include strict sync validation detail."
$dataFlowRunbookEntry = @($report.entries | Where-Object { $_.group -eq "data-flow-storage-transition-runbook" -and $_.fileName -eq "latest-data-flow-storage-transition-runbook-evidence.json" })
Assert-True ($dataFlowRunbookEntry.Count -eq 1) "Data-flow storage transition runbook import entry missing."
Assert-True (([string] $dataFlowRunbookEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $dataFlowRunbookEntry[0].detail).Contains("storagePlanResult=passed") -and ([string] $dataFlowRunbookEntry[0].detail).Contains("checkRows=23")) "Data-flow storage transition runbook import entry should include target metadata, storage plan, and check row validation detail."
$kubernetesSyncRunbookEntry = @($report.entries | Where-Object { $_.group -eq "kubernetes-operations-report-sync" -and $_.fileName -eq "latest-data-flow-storage-transition-runbook-evidence.json" })
Assert-True ($kubernetesSyncRunbookEntry.Count -eq 1) "Kubernetes sync data-flow storage transition runbook import entry missing."
Assert-True (([string] $kubernetesSyncRunbookEntry[0].detail).Contains("targetCluster=osmu-prod") -and ([string] $kubernetesSyncRunbookEntry[0].detail).Contains("storagePlanResult=passed") -and ([string] $kubernetesSyncRunbookEntry[0].detail).Contains("checkRows=23")) "Kubernetes sync runbook import entry should include target metadata, storage plan, and check row validation detail."
$monitoringThresholdEntry = @($report.entries | Where-Object { $_.group -eq "monitoring-threshold" -and $_.fileName -eq "latest-monitoring-threshold-evidence.json" })
Assert-True ($monitoringThresholdEntry.Count -eq 1) "Monitoring threshold import entry missing."
Assert-True (([string] $monitoringThresholdEntry[0].detail).Contains("requiredAlerts=11")) "Monitoring threshold import entry should include threshold mapping validation detail."
$promotedDataFlowStoragePlan = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-plan.json") | ConvertFrom-Json
Assert-True ($promotedDataFlowStoragePlan.formatVersion -eq "osmu.data-flow-storage-plan.v1") "Promoted data-flow storage plan evidence should preserve formatVersion."
Assert-True ($promotedDataFlowStoragePlan.candidateStore -eq "MARIADB_PARTITION") "Promoted data-flow storage plan evidence should preserve candidateStore."
Assert-True ($promotedDataFlowStoragePlan.queryPlanEvidence.expectedFormatVersion -eq "osmu.mariadb-query-plan-evidence.v1") "Promoted data-flow storage plan evidence should preserve query plan expected format."

Write-JsonEvidence (Join-Path $weakStorageExpansionRoot "latest-storage-expansion-finalize.json") (New-PassedStorageExpansionFinalize -SkipRbacGap $true)
Write-TextEvidence (Join-Path $weakStorageExpansionRoot "latest-storage-expansion-finalize.md") "# Weak storage expansion"
Write-JsonEvidence (Join-Path $weakStorageExpansionRoot "latest-storage-expansion-rbac-auth.json") (New-PassedStorageExpansionRbacAuth)
Write-JsonEvidence (Join-Path $weakStorageExpansionRoot "latest-storage-expansion-server-dry-run.json") (New-PassedStorageExpansionServerDryRun)
$weakStorageExpansionOutput = Join-Path $resolvedOutputDirectory "weak-storage-expansion-promoted"
$weakStorageExpansionJson = Join-Path $resolvedOutputDirectory "weak-storage-expansion-import.json"
$weakStorageExpansionMarkdown = Join-Path $resolvedOutputDirectory "weak-storage-expansion-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakStorageExpansionOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -StorageExpansionArtifactPath $weakStorageExpansionRoot `
        -OutputDirectory $weakStorageExpansionOutput `
        -JsonOutputPath $weakStorageExpansionJson `
        -MarkdownOutputPath $weakStorageExpansionMarkdown 2>&1
    $weakStorageExpansionExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakStorageExpansionExitCode -ne 0) "Storage expansion finalizer with skipped RBAC gap should fail import."
Assert-True (Test-Path -LiteralPath $weakStorageExpansionJson) "Weak storage expansion import report should still be written."
$weakStorageExpansionReport = Get-Content -Raw -LiteralPath $weakStorageExpansionJson | ConvertFrom-Json
Assert-True ($weakStorageExpansionReport.result -eq "failed") "Weak storage expansion import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakStorageExpansionOutput "latest-storage-expansion-finalize.json"))) "Weak storage expansion evidence must not be promoted."
Assert-True (($weakStorageExpansionReport.entries | ConvertTo-Json -Depth 8).Contains("RBAC authorization evidence was skipped")) "Weak storage expansion report should describe skipped RBAC evidence."

Write-JsonEvidence (Join-Path $invalidRoot "latest-kubernetes-ha-dr-readiness.json") @{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    result = "failed"
}
$invalidOutput = Join-Path $resolvedOutputDirectory "invalid-promoted"
$invalidJson = Join-Path $resolvedOutputDirectory "invalid-import.json"
$invalidMarkdown = Join-Path $resolvedOutputDirectory "invalid-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -HaDrReadinessArtifactPath $invalidRoot `
        -OutputDirectory $invalidOutput `
        -JsonOutputPath $invalidJson `
        -MarkdownOutputPath $invalidMarkdown 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Invalid HA/DR evidence import should fail."
Assert-True (Test-Path -LiteralPath $invalidJson) "Invalid import report should still be written."
$invalidReport = Get-Content -Raw -LiteralPath $invalidJson | ConvertFrom-Json
Assert-True ($invalidReport.result -eq "failed") "Invalid import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidOutput "latest-kubernetes-ha-dr-readiness.json"))) "Invalid evidence must not be promoted."

Write-JsonEvidence (Join-Path $weakKubernetesDrRoot "latest-kubernetes-dr-finalize.json") (New-ReadyKubernetesDrFinalize -BackupTimestamp "YYYYMMDDTHHMMSSZ")
Write-TextEvidence (Join-Path $weakKubernetesDrRoot "latest-kubernetes-dr-finalize.md") "# Weak Kubernetes DR"
$weakKubernetesDrOutput = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-promoted"
$weakKubernetesDrJson = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-import.json"
$weakKubernetesDrMarkdown = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakKubernetesDrOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesDrArtifactPath $weakKubernetesDrRoot `
        -OutputDirectory $weakKubernetesDrOutput `
        -JsonOutputPath $weakKubernetesDrJson `
        -MarkdownOutputPath $weakKubernetesDrMarkdown 2>&1
    $weakKubernetesDrExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakKubernetesDrExitCode -ne 0) "Kubernetes DR finalizer with placeholder timestamp should fail import."
Assert-True (Test-Path -LiteralPath $weakKubernetesDrJson) "Weak Kubernetes DR import report should still be written."
$weakKubernetesDrReport = Get-Content -Raw -LiteralPath $weakKubernetesDrJson | ConvertFrom-Json
Assert-True ($weakKubernetesDrReport.result -eq "failed") "Weak Kubernetes DR import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakKubernetesDrOutput "latest-kubernetes-dr-finalize.json"))) "Weak Kubernetes DR evidence must not be promoted."
Assert-True (($weakKubernetesDrReport.entries | ConvertTo-Json -Depth 8).Contains("backupTimestamp=YYYYMMDDTHHMMSSZ")) "Weak Kubernetes DR report should describe placeholder backup timestamp."

$weakKubernetesDrStepsEvidence = New-ReadyKubernetesDrFinalize
$weakKubernetesDrStepsEvidence["steps"] = @($weakKubernetesDrStepsEvidence["steps"]) + [ordered]@{
    name = "Unexpected Kubernetes DR cleanup"
    script = ".\scripts\cleanup-kubernetes-dr-drill.ps1"
    arguments = @()
    command = "pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-kubernetes-dr-drill.ps1"
    result = "failed"
    exitCode = 1
    output = "cleanup failed"
    notes = "failed extra finalizer step must not be ignored"
}
Write-JsonEvidence (Join-Path $weakKubernetesDrStepsRoot "latest-kubernetes-dr-finalize.json") $weakKubernetesDrStepsEvidence
Write-TextEvidence (Join-Path $weakKubernetesDrStepsRoot "latest-kubernetes-dr-finalize.md") "# Weak Kubernetes DR steps"
$weakKubernetesDrStepsOutput = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-steps-promoted"
$weakKubernetesDrStepsJson = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-steps-import.json"
$weakKubernetesDrStepsMarkdown = Join-Path $resolvedOutputDirectory "weak-kubernetes-dr-steps-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakKubernetesDrStepsOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesDrArtifactPath $weakKubernetesDrStepsRoot `
        -OutputDirectory $weakKubernetesDrStepsOutput `
        -JsonOutputPath $weakKubernetesDrStepsJson `
        -MarkdownOutputPath $weakKubernetesDrStepsMarkdown 2>&1
    $weakKubernetesDrStepsExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakKubernetesDrStepsExitCode -ne 0) "Kubernetes DR finalizer with a failed extra step should fail import."
Assert-True (Test-Path -LiteralPath $weakKubernetesDrStepsJson) "Weak Kubernetes DR steps import report should still be written."
$weakKubernetesDrStepsReport = Get-Content -Raw -LiteralPath $weakKubernetesDrStepsJson | ConvertFrom-Json
Assert-True ($weakKubernetesDrStepsReport.result -eq "failed") "Weak Kubernetes DR steps import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakKubernetesDrStepsOutput "latest-kubernetes-dr-finalize.json"))) "Weak Kubernetes DR steps evidence must not be promoted."
Assert-True (($weakKubernetesDrStepsReport.entries | ConvertTo-Json -Depth 8).Contains("steps.Unexpected Kubernetes DR cleanup result=failed exitCode=1")) "Weak Kubernetes DR steps report should describe the failed extra step."

Write-JsonEvidence (Join-Path $weakIamRbacRoot "latest-iam-rbac-finalize.json") (New-PassedIamRbacFinalize -OmitKubernetesStep $true)
Write-TextEvidence (Join-Path $weakIamRbacRoot "latest-iam-rbac-finalize.md") "# Weak IAM/RBAC"
$weakIamRbacOutput = Join-Path $resolvedOutputDirectory "weak-iam-rbac-promoted"
$weakIamRbacJson = Join-Path $resolvedOutputDirectory "weak-iam-rbac-import.json"
$weakIamRbacMarkdown = Join-Path $resolvedOutputDirectory "weak-iam-rbac-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakIamRbacOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -IamRbacArtifactPath $weakIamRbacRoot `
        -OutputDirectory $weakIamRbacOutput `
        -JsonOutputPath $weakIamRbacJson `
        -MarkdownOutputPath $weakIamRbacMarkdown 2>&1
    $weakIamRbacExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakIamRbacExitCode -ne 0) "IAM/RBAC finalizer without Kubernetes verifier step should fail import."
Assert-True (Test-Path -LiteralPath $weakIamRbacJson) "Weak IAM/RBAC import report should still be written."
$weakIamRbacReport = Get-Content -Raw -LiteralPath $weakIamRbacJson | ConvertFrom-Json
Assert-True ($weakIamRbacReport.result -eq "failed") "Weak IAM/RBAC import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakIamRbacOutput "latest-iam-rbac-finalize.json"))) "Weak IAM/RBAC evidence must not be promoted."
Assert-True (($weakIamRbacReport.entries | ConvertTo-Json -Depth 8).Contains("steps.Kubernetes RBAC matrix verifier missing")) "Weak IAM/RBAC report should describe missing Kubernetes verifier step."

Write-JsonEvidence (Join-Path $weakIamRbacStatusRoot "latest-iam-rbac-finalize.json") (New-PassedIamRbacFinalize -Status "iam-rbac-static-passed" -RunBackendPolicyTests $true)
Write-TextEvidence (Join-Path $weakIamRbacStatusRoot "latest-iam-rbac-finalize.md") "# Weak IAM/RBAC Status"
$weakIamRbacStatusOutput = Join-Path $resolvedOutputDirectory "weak-iam-rbac-status-promoted"
$weakIamRbacStatusJson = Join-Path $resolvedOutputDirectory "weak-iam-rbac-status-import.json"
$weakIamRbacStatusMarkdown = Join-Path $resolvedOutputDirectory "weak-iam-rbac-status-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakIamRbacStatusOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -IamRbacArtifactPath $weakIamRbacStatusRoot `
        -OutputDirectory $weakIamRbacStatusOutput `
        -JsonOutputPath $weakIamRbacStatusJson `
        -MarkdownOutputPath $weakIamRbacStatusMarkdown 2>&1
    $weakIamRbacStatusExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakIamRbacStatusExitCode -ne 0) "IAM/RBAC finalizer with mismatched status and backend flag should fail import."
Assert-True (Test-Path -LiteralPath $weakIamRbacStatusJson) "Weak IAM/RBAC status import report should still be written."
$weakIamRbacStatusReport = Get-Content -Raw -LiteralPath $weakIamRbacStatusJson | ConvertFrom-Json
Assert-True ($weakIamRbacStatusReport.result -eq "failed") "Weak IAM/RBAC status import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakIamRbacStatusOutput "latest-iam-rbac-finalize.json"))) "Weak IAM/RBAC status evidence must not be promoted."
Assert-True (($weakIamRbacStatusReport.entries | ConvertTo-Json -Depth 8).Contains("status=iam-rbac-static-passed expected=iam-rbac-backend-passed")) "Weak IAM/RBAC status report should describe status/flag mismatch."

Write-JsonEvidence (Join-Path $weakSecurityFinalizerRoot "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer -AllowSyntheticEvidence $true)
Copy-Item -LiteralPath (Join-Path $securitySource "latest-image-signing-evidence.json") -Destination (Join-Path $weakSecurityFinalizerRoot "latest-image-signing-evidence.json") -Force
Copy-Item -LiteralPath (Join-Path $securitySource "latest-container-security-evidence.json") -Destination (Join-Path $weakSecurityFinalizerRoot "latest-container-security-evidence.json") -Force
$weakSecurityFinalizerOutput = Join-Path $resolvedOutputDirectory "weak-security-finalizer-promoted"
$weakSecurityFinalizerJson = Join-Path $resolvedOutputDirectory "weak-security-finalizer-import.json"
$weakSecurityFinalizerMarkdown = Join-Path $resolvedOutputDirectory "weak-security-finalizer-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakSecurityFinalizerOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecurityEvidenceArtifactPath $weakSecurityFinalizerRoot `
        -OutputDirectory $weakSecurityFinalizerOutput `
        -JsonOutputPath $weakSecurityFinalizerJson `
        -MarkdownOutputPath $weakSecurityFinalizerMarkdown 2>&1
    $weakSecurityFinalizerExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakSecurityFinalizerExitCode -ne 0) "Security finalizer allowing synthetic evidence should fail import."
Assert-True (Test-Path -LiteralPath $weakSecurityFinalizerJson) "Weak security finalizer import report should still be written."
$weakSecurityFinalizerReport = Get-Content -Raw -LiteralPath $weakSecurityFinalizerJson | ConvertFrom-Json
Assert-True ($weakSecurityFinalizerReport.result -eq "failed") "Weak security finalizer import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakSecurityFinalizerOutput "latest-security-evidence-finalize.json"))) "Weak security finalizer evidence must not be promoted."
Assert-True (($weakSecurityFinalizerReport.entries | ConvertTo-Json -Depth 8).Contains("allowSyntheticEvidence=True expected boolean false")) "Weak security finalizer report should describe synthetic evidence flag."

Write-JsonEvidence (Join-Path $weakImageSigningRoot "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer)
Write-JsonEvidence (Join-Path $weakImageSigningRoot "latest-image-signing-evidence.json") @{
    formatVersion = "osmu.image-signing-evidence.v1"
    result = "passed"
    failureCount = 0
    version = "v1.2.3"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/223456"
    issuer = "https://token.actions.githubusercontent.com"
    signingMode = "keyless-github-actions-oidc"
    backend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-backend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
        digest = ""
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    frontend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-frontend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
        digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222"
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    secretPolicy = "Evidence contains public image references only."
}
Copy-Item -LiteralPath (Join-Path $securitySource "latest-container-security-evidence.json") -Destination (Join-Path $weakImageSigningRoot "latest-container-security-evidence.json") -Force
$weakImageSigningOutput = Join-Path $resolvedOutputDirectory "weak-image-signing-promoted"
$weakImageSigningJson = Join-Path $resolvedOutputDirectory "weak-image-signing-import.json"
$weakImageSigningMarkdown = Join-Path $resolvedOutputDirectory "weak-image-signing-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakImageSigningOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecurityEvidenceArtifactPath $weakImageSigningRoot `
        -OutputDirectory $weakImageSigningOutput `
        -JsonOutputPath $weakImageSigningJson `
        -MarkdownOutputPath $weakImageSigningMarkdown 2>&1
    $weakImageSigningExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakImageSigningExitCode -ne 0) "Image signing evidence without digest should fail import."
Assert-True (Test-Path -LiteralPath $weakImageSigningJson) "Weak image signing import report should still be written."
$weakImageSigningReport = Get-Content -Raw -LiteralPath $weakImageSigningJson | ConvertFrom-Json
Assert-True ($weakImageSigningReport.result -eq "failed") "Weak image signing import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakImageSigningOutput "latest-image-signing-evidence.json"))) "Weak image signing evidence must not be promoted."
Assert-True (($weakImageSigningReport.entries | ConvertTo-Json -Depth 8).Contains("backend.digest=")) "Weak image signing report should describe missing digest."

Write-JsonEvidence (Join-Path $weakImageSigningRefsRoot "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer)
Write-JsonEvidence (Join-Path $weakImageSigningRefsRoot "latest-image-signing-evidence.json") @{
    formatVersion = "osmu.image-signing-evidence.v1"
    result = "passed"
    failureCount = 0
    version = "v1.2.3"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/223458"
    issuer = "https://token.actions.githubusercontent.com"
    signingMode = "keyless-github-actions-oidc"
    backend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-backend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-backend:v1.2.2"
        digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    frontend = @{
        versionRef = "ghcr.io/osmu/object-storage-osmu-frontend:v1.2.3"
        shaRef = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
        digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222"
        versionSignatureVerified = $true
        shaSignatureVerified = $true
    }
    secretPolicy = "Evidence contains public image references only."
}
Copy-Item -LiteralPath (Join-Path $securitySource "latest-container-security-evidence.json") -Destination (Join-Path $weakImageSigningRefsRoot "latest-container-security-evidence.json") -Force
$weakImageSigningRefsOutput = Join-Path $resolvedOutputDirectory "weak-image-signing-refs-promoted"
$weakImageSigningRefsJson = Join-Path $resolvedOutputDirectory "weak-image-signing-refs-import.json"
$weakImageSigningRefsMarkdown = Join-Path $resolvedOutputDirectory "weak-image-signing-refs-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakImageSigningRefsOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecurityEvidenceArtifactPath $weakImageSigningRefsRoot `
        -OutputDirectory $weakImageSigningRefsOutput `
        -JsonOutputPath $weakImageSigningRefsJson `
        -MarkdownOutputPath $weakImageSigningRefsMarkdown 2>&1
    $weakImageSigningRefsExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakImageSigningRefsExitCode -ne 0) "Image signing evidence with mismatched SHA ref should fail import."
Assert-True (Test-Path -LiteralPath $weakImageSigningRefsJson) "Weak image signing refs import report should still be written."
$weakImageSigningRefsReport = Get-Content -Raw -LiteralPath $weakImageSigningRefsJson | ConvertFrom-Json
Assert-True ($weakImageSigningRefsReport.result -eq "failed") "Weak image signing refs import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakImageSigningRefsOutput "latest-image-signing-evidence.json"))) "Weak image signing refs evidence must not be promoted."
Assert-True (($weakImageSigningRefsReport.entries | ConvertTo-Json -Depth 8).Contains("backend.shaRef=ghcr.io/osmu/object-storage-osmu-backend:v1.2.2 expected tag 1234567890abcdef1234567890abcdef12345678")) "Weak image signing refs report should describe mismatched SHA ref."

Write-JsonEvidence (Join-Path $weakContainerSecurityRoot "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer)
Copy-Item -LiteralPath (Join-Path $securitySource "latest-image-signing-evidence.json") -Destination (Join-Path $weakContainerSecurityRoot "latest-image-signing-evidence.json") -Force
Write-JsonEvidence (Join-Path $weakContainerSecurityRoot "latest-container-security-evidence.json") @{
    formatVersion = "osmu.container-security-evidence.v1"
    result = "passed"
    failureCount = 0
    backendImage = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
    frontendImage = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/223457"
    artifactName = "container-security-1234567890abcdef1234567890abcdef12345678"
    scans = @{
        severity = "CRITICAL,HIGH"
        ignoreUnfixed = $true
        backendScanPassed = "true"
        frontendScanPassed = $true
    }
    sbom = @{
        format = "SPDX JSON"
        backend = @{
            label = "backend"
            valid = $true
            spdxVersion = "SPDX-2.3"
            packageCount = 42
            byteSize = 4096
            sha256 = "3333333333333333333333333333333333333333333333333333333333333333"
        }
        frontend = @{
            label = "frontend"
            valid = $true
            spdxVersion = "SPDX-2.3"
            packageCount = 84
            byteSize = 8192
            sha256 = "4444444444444444444444444444444444444444444444444444444444444444"
        }
    }
    secretPolicy = "Evidence contains image names and SBOM metadata only."
}
$weakContainerSecurityOutput = Join-Path $resolvedOutputDirectory "weak-container-security-promoted"
$weakContainerSecurityJson = Join-Path $resolvedOutputDirectory "weak-container-security-import.json"
$weakContainerSecurityMarkdown = Join-Path $resolvedOutputDirectory "weak-container-security-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakContainerSecurityOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecurityEvidenceArtifactPath $weakContainerSecurityRoot `
        -OutputDirectory $weakContainerSecurityOutput `
        -JsonOutputPath $weakContainerSecurityJson `
        -MarkdownOutputPath $weakContainerSecurityMarkdown 2>&1
    $weakContainerSecurityExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakContainerSecurityExitCode -ne 0) "Container security evidence with string scan flag should fail import."
Assert-True (Test-Path -LiteralPath $weakContainerSecurityJson) "Weak container security import report should still be written."
$weakContainerSecurityReport = Get-Content -Raw -LiteralPath $weakContainerSecurityJson | ConvertFrom-Json
Assert-True ($weakContainerSecurityReport.result -eq "failed") "Weak container security import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakContainerSecurityOutput "latest-container-security-evidence.json"))) "Weak container security evidence must not be promoted."
Assert-True (($weakContainerSecurityReport.entries | ConvertTo-Json -Depth 8).Contains("scans.backendScanPassed=true expected boolean true")) "Weak container security report should describe invalid typed scan flag."

Write-JsonEvidence (Join-Path $weakContainerSecuritySbomRoot "latest-security-evidence-finalize.json") (New-PassedSecurityEvidenceFinalizer)
Copy-Item -LiteralPath (Join-Path $securitySource "latest-image-signing-evidence.json") -Destination (Join-Path $weakContainerSecuritySbomRoot "latest-image-signing-evidence.json") -Force
Write-JsonEvidence (Join-Path $weakContainerSecuritySbomRoot "latest-container-security-evidence.json") @{
    formatVersion = "osmu.container-security-evidence.v1"
    result = "passed"
    failureCount = 0
    backendImage = "ghcr.io/osmu/object-storage-osmu-backend:1234567890abcdef1234567890abcdef12345678"
    frontendImage = "ghcr.io/osmu/object-storage-osmu-frontend:1234567890abcdef1234567890abcdef12345678"
    commitSha = "1234567890abcdef1234567890abcdef12345678"
    sourceRunUrl = "https://github.com/osmu/object-storage-osmu/actions/runs/223459"
    artifactName = "container-security-1234567890abcdef1234567890abcdef12345678"
    scans = @{
        severity = "CRITICAL,HIGH"
        ignoreUnfixed = $true
        backendScanPassed = $true
        frontendScanPassed = $true
    }
    sbom = @{
        format = "SPDX JSON"
        backend = @{
            label = "backend"
            valid = $true
            spdxVersion = ""
            packageCount = 42
            byteSize = 4096
            sha256 = "3333333333333333333333333333333333333333333333333333333333333333"
        }
        frontend = @{
            label = "frontend"
            valid = $true
            spdxVersion = "SPDX-2.3"
            packageCount = 84
            byteSize = 8192
            sha256 = "4444444444444444444444444444444444444444444444444444444444444444"
        }
    }
    secretPolicy = "Evidence contains image names and SBOM metadata only."
}
$weakContainerSecuritySbomOutput = Join-Path $resolvedOutputDirectory "weak-container-security-sbom-promoted"
$weakContainerSecuritySbomJson = Join-Path $resolvedOutputDirectory "weak-container-security-sbom-import.json"
$weakContainerSecuritySbomMarkdown = Join-Path $resolvedOutputDirectory "weak-container-security-sbom-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakContainerSecuritySbomOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecurityEvidenceArtifactPath $weakContainerSecuritySbomRoot `
        -OutputDirectory $weakContainerSecuritySbomOutput `
        -JsonOutputPath $weakContainerSecuritySbomJson `
        -MarkdownOutputPath $weakContainerSecuritySbomMarkdown 2>&1
    $weakContainerSecuritySbomExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakContainerSecuritySbomExitCode -ne 0) "Container security evidence with weak SBOM metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakContainerSecuritySbomJson) "Weak container security SBOM import report should still be written."
$weakContainerSecuritySbomReport = Get-Content -Raw -LiteralPath $weakContainerSecuritySbomJson | ConvertFrom-Json
Assert-True ($weakContainerSecuritySbomReport.result -eq "failed") "Weak container security SBOM import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakContainerSecuritySbomOutput "latest-container-security-evidence.json"))) "Weak container security SBOM evidence must not be promoted."
Assert-True (($weakContainerSecuritySbomReport.entries | ConvertTo-Json -Depth 8).Contains("sbom.backend.spdxVersion= expected SPDX-*")) "Weak container security SBOM report should describe invalid SPDX metadata."

Write-JsonEvidence (Join-Path $weakStorageBackendTelemetryRoot "latest-storage-backend-telemetry.json") @{
    formatVersion = "osmu.storage-backend-telemetry.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    decisionRule = "Storage backend telemetry evidence passes when target metadata and MinIO admin info summaries are present."
    scopePolicy = "This evidence captures MinIO operations telemetry for OSMU storage readiness, not AWS S3 parity work."
}
$weakStorageBackendTelemetryOutput = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-promoted"
$weakStorageBackendTelemetryJson = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-import.json"
$weakStorageBackendTelemetryMarkdown = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakStorageBackendTelemetryOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -StorageBackendTelemetryArtifactPath $weakStorageBackendTelemetryRoot `
        -OutputDirectory $weakStorageBackendTelemetryOutput `
        -JsonOutputPath $weakStorageBackendTelemetryJson `
        -MarkdownOutputPath $weakStorageBackendTelemetryMarkdown 2>&1
    $weakStorageBackendTelemetryExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakStorageBackendTelemetryExitCode -ne 0) "Storage backend telemetry without required target metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakStorageBackendTelemetryJson) "Weak storage backend telemetry import report should still be written."
$weakStorageBackendTelemetryReport = Get-Content -Raw -LiteralPath $weakStorageBackendTelemetryJson | ConvertFrom-Json
Assert-True ($weakStorageBackendTelemetryReport.result -eq "failed") "Weak storage backend telemetry import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakStorageBackendTelemetryOutput "latest-storage-backend-telemetry.json"))) "Weak storage backend telemetry evidence must not be promoted."
$weakStorageBackendTelemetryEntry = @($weakStorageBackendTelemetryReport.entries | Where-Object { $_.group -eq "storage-backend-telemetry" -and $_.fileName -eq "latest-storage-backend-telemetry.json" })
Assert-True ($weakStorageBackendTelemetryEntry.Count -eq 1) "Weak storage backend telemetry failed entry missing."
Assert-True (([string] $weakStorageBackendTelemetryEntry[0].detail).Contains("environmentName missing")) "Weak storage backend telemetry report should describe missing target environment metadata."

Write-JsonEvidence (Join-Path $weakStorageBackendTelemetryChecksRoot "latest-storage-backend-telemetry.json") @{
    formatVersion = "osmu.storage-backend-telemetry.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    source = @{
        mode = "admin-info-json-path"
        minioAlias = "target-minio"
        evidenceRef = "mc-admin-info-run-20260621"
        sourceRef = "artifact://mc-admin-info-run-20260621/minio-admin-info.json"
        adminInfoJsonSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        rawAdminInfoStored = $false
    }
    summary = @{
        poolCount = 1
        serverCount = 1
        onlineServerCount = 1
        offlineServerCount = 0
        driveCount = 1
        capacityKnown = $true
        totalBytes = 1024
        usedBytes = 256
        freeBytes = 768
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true }
    )
    decisionRule = "Storage backend telemetry evidence passes when target environment, cluster, operator, external evidence reference, MinIO admin-info JSON parsing, pool/server/drive summaries, online server state, and capacity totals are all present."
    scopePolicy = "This evidence captures MinIO pool/node operations telemetry for OSMU storage readiness. It is not AWS S3 parity work, and it does not store raw admin info, credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
}
$weakStorageBackendTelemetryChecksOutput = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-checks-promoted"
$weakStorageBackendTelemetryChecksJson = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-checks-import.json"
$weakStorageBackendTelemetryChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-storage-backend-telemetry-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakStorageBackendTelemetryChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -StorageBackendTelemetryArtifactPath $weakStorageBackendTelemetryChecksRoot `
        -OutputDirectory $weakStorageBackendTelemetryChecksOutput `
        -JsonOutputPath $weakStorageBackendTelemetryChecksJson `
        -MarkdownOutputPath $weakStorageBackendTelemetryChecksMarkdown 2>&1
    $weakStorageBackendTelemetryChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakStorageBackendTelemetryChecksExitCode -ne 0) "Storage backend telemetry without complete check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakStorageBackendTelemetryChecksJson) "Weak storage backend telemetry checks import report should still be written."
$weakStorageBackendTelemetryChecksReport = Get-Content -Raw -LiteralPath $weakStorageBackendTelemetryChecksJson | ConvertFrom-Json
Assert-True ($weakStorageBackendTelemetryChecksReport.result -eq "failed") "Weak storage backend telemetry checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakStorageBackendTelemetryChecksOutput "latest-storage-backend-telemetry.json"))) "Weak storage backend telemetry checks evidence must not be promoted."
Assert-True (($weakStorageBackendTelemetryChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.target-cluster missing")) "Weak storage backend telemetry checks report should describe missing target check row."

Write-JsonEvidence (Join-Path $unsafeStorageBackendTelemetryRoot "latest-storage-backend-telemetry.json") @{
    formatVersion = "osmu.storage-backend-telemetry.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    source = @{
        mode = "admin-info-json-path"
        minioAlias = "target-minio"
        evidenceRef = "mc-admin-info-run-20260621"
        sourceRef = "artifact://mc-admin-info-run-20260621/minio-admin-info.json"
        adminInfoJsonSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        rawAdminInfoStored = $false
    }
    summary = @{
        poolCount = 1
        serverCount = 1
        onlineServerCount = 1
        offlineServerCount = 0
        driveCount = 1
        capacityKnown = $true
        totalBytes = 1024
        usedBytes = 256
        freeBytes = 768
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true },
        @{ id = "target-cluster"; status = "PASS"; passed = $true },
        @{ id = "operator"; status = "PASS"; passed = $true },
        @{ id = "evidence-ref"; status = "PASS"; passed = $true },
        @{ id = "admin-info-json-parse"; status = "PASS"; passed = $true },
        @{ id = "server-telemetry"; status = "PASS"; passed = $true },
        @{ id = "pool-telemetry"; status = "PASS"; passed = $true },
        @{ id = "drive-telemetry"; status = "PASS"; passed = $true },
        @{ id = "server-health"; status = "PASS"; passed = $true },
        @{ id = "capacity-telemetry"; status = "PASS"; passed = $true },
        @{ id = "raw-admin-info-policy"; status = "PASS"; passed = $true }
    )
    decisionRule = "Storage backend telemetry evidence passes when target environment, cluster, operator, external evidence reference, MinIO admin-info JSON parsing, pool/server/drive summaries, online server state, and capacity totals are all present."
    scopePolicy = "This evidence captures MinIO pool/node operations telemetry for OSMU storage readiness. It is not AWS S3 parity work, and it does not store raw admin info, credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
    secretKey = "password=super-secret"
}
$unsafeStorageBackendTelemetryOutput = Join-Path $resolvedOutputDirectory "unsafe-storage-backend-telemetry-promoted"
$unsafeStorageBackendTelemetryJson = Join-Path $resolvedOutputDirectory "unsafe-storage-backend-telemetry-import.json"
$unsafeStorageBackendTelemetryMarkdown = Join-Path $resolvedOutputDirectory "unsafe-storage-backend-telemetry-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeStorageBackendTelemetryOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -StorageBackendTelemetryArtifactPath $unsafeStorageBackendTelemetryRoot `
        -OutputDirectory $unsafeStorageBackendTelemetryOutput `
        -JsonOutputPath $unsafeStorageBackendTelemetryJson `
        -MarkdownOutputPath $unsafeStorageBackendTelemetryMarkdown 2>&1
    $unsafeStorageBackendTelemetryExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeStorageBackendTelemetryExitCode -ne 0) "Storage backend telemetry with raw credential-shaped content should fail import."
Assert-True (Test-Path -LiteralPath $unsafeStorageBackendTelemetryJson) "Unsafe storage backend telemetry import report should still be written."
$unsafeStorageBackendTelemetryReport = Get-Content -Raw -LiteralPath $unsafeStorageBackendTelemetryJson | ConvertFrom-Json
Assert-True ($unsafeStorageBackendTelemetryReport.result -eq "failed") "Unsafe storage backend telemetry import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeStorageBackendTelemetryOutput "latest-storage-backend-telemetry.json"))) "Unsafe storage backend telemetry evidence must not be promoted."
Assert-True (($unsafeStorageBackendTelemetryReport.entries | ConvertTo-Json -Depth 8).Contains("credential-shaped content")) "Unsafe storage backend telemetry report should describe credential-shaped content."

$unsafeMinioBucketCors = New-MinioBucketCorsVerification -RawCorsXmlStored $true
$unsafeMinioBucketCors["rawCorsXml"] = "<CORSConfiguration><CORSRule><ExposeHeader>ETag</ExposeHeader></CORSRule></CORSConfiguration>"
Write-JsonEvidence (Join-Path $unsafeMinioBucketCorsRoot "latest-minio-bucket-cors-verification.json") $unsafeMinioBucketCors
Write-TextEvidence (Join-Path $unsafeMinioBucketCorsRoot "latest-minio-bucket-cors-verification.md") "# CORS`n`n<CORSConfiguration><CORSRule /></CORSConfiguration>"
$unsafeMinioBucketCorsOutput = Join-Path $resolvedOutputDirectory "unsafe-minio-bucket-cors-promoted"
$unsafeMinioBucketCorsJson = Join-Path $resolvedOutputDirectory "unsafe-minio-bucket-cors-import.json"
$unsafeMinioBucketCorsMarkdown = Join-Path $resolvedOutputDirectory "unsafe-minio-bucket-cors-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeMinioBucketCorsOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MinioBucketCorsArtifactPath $unsafeMinioBucketCorsRoot `
        -OutputDirectory $unsafeMinioBucketCorsOutput `
        -JsonOutputPath $unsafeMinioBucketCorsJson `
        -MarkdownOutputPath $unsafeMinioBucketCorsMarkdown 2>&1
    $unsafeMinioBucketCorsExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeMinioBucketCorsExitCode -ne 0) "MinIO bucket CORS verification with raw XML content should fail import."
Assert-True (Test-Path -LiteralPath $unsafeMinioBucketCorsJson) "Unsafe MinIO bucket CORS import report should still be written."
$unsafeMinioBucketCorsReport = Get-Content -Raw -LiteralPath $unsafeMinioBucketCorsJson | ConvertFrom-Json
Assert-True ($unsafeMinioBucketCorsReport.result -eq "failed") "Unsafe MinIO bucket CORS import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeMinioBucketCorsOutput "latest-minio-bucket-cors-verification.json"))) "Unsafe MinIO bucket CORS evidence must not be promoted."
Assert-True (($unsafeMinioBucketCorsReport.entries | ConvertTo-Json -Depth 8).Contains("raw CORS XML")) "Unsafe MinIO bucket CORS report should describe raw CORS XML."

Write-JsonEvidence (Join-Path $weakKubernetesOperationsReportSyncRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
}
$weakKubernetesOperationsReportSyncOutput = Join-Path $resolvedOutputDirectory "weak-kubernetes-operations-report-sync-promoted"
$weakKubernetesOperationsReportSyncJson = Join-Path $resolvedOutputDirectory "weak-kubernetes-operations-report-sync-import.json"
$weakKubernetesOperationsReportSyncMarkdown = Join-Path $resolvedOutputDirectory "weak-kubernetes-operations-report-sync-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakKubernetesOperationsReportSyncOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $weakKubernetesOperationsReportSyncRoot `
        -OutputDirectory $weakKubernetesOperationsReportSyncOutput `
        -JsonOutputPath $weakKubernetesOperationsReportSyncJson `
        -MarkdownOutputPath $weakKubernetesOperationsReportSyncMarkdown 2>&1
    $weakKubernetesOperationsReportSyncExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakKubernetesOperationsReportSyncExitCode -ne 0) "Kubernetes operations report sync without ready source metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakKubernetesOperationsReportSyncJson) "Weak Kubernetes operations report sync import report should still be written."
$weakKubernetesOperationsReportSyncReport = Get-Content -Raw -LiteralPath $weakKubernetesOperationsReportSyncJson | ConvertFrom-Json
Assert-True ($weakKubernetesOperationsReportSyncReport.result -eq "failed") "Weak Kubernetes operations report sync import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakKubernetesOperationsReportSyncOutput "latest-kubernetes-operations-report-sync.json"))) "Weak Kubernetes operations report sync evidence must not be promoted."
Assert-True (($weakKubernetesOperationsReportSyncReport.entries | ConvertTo-Json -Depth 8).Contains("sourceReportFormatVersion=")) "Weak Kubernetes operations report sync report should describe missing source report format."

Write-JsonEvidence (Join-Path $stringCountKubernetesOperationsReportSyncRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = "0"
    sourceReportFormatVersion = "osmu.operations-readiness-convergence.v1"
    sourceReportResult = "ready"
    sourceReportBytes = 2048
    sourceReportSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
$stringCountKubernetesOperationsReportSyncOutput = Join-Path $resolvedOutputDirectory "string-count-kubernetes-operations-report-sync-promoted"
$stringCountKubernetesOperationsReportSyncJson = Join-Path $resolvedOutputDirectory "string-count-kubernetes-operations-report-sync-import.json"
$stringCountKubernetesOperationsReportSyncMarkdown = Join-Path $resolvedOutputDirectory "string-count-kubernetes-operations-report-sync-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountKubernetesOperationsReportSyncOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $stringCountKubernetesOperationsReportSyncRoot `
        -OutputDirectory $stringCountKubernetesOperationsReportSyncOutput `
        -JsonOutputPath $stringCountKubernetesOperationsReportSyncJson `
        -MarkdownOutputPath $stringCountKubernetesOperationsReportSyncMarkdown 2>&1
    $stringCountKubernetesOperationsReportSyncExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountKubernetesOperationsReportSyncExitCode -ne 0) "Kubernetes operations report sync with string failedCount should fail import."
Assert-True (Test-Path -LiteralPath $stringCountKubernetesOperationsReportSyncJson) "String-count Kubernetes operations report sync import report should still be written."
$stringCountKubernetesOperationsReportSyncReport = Get-Content -Raw -LiteralPath $stringCountKubernetesOperationsReportSyncJson | ConvertFrom-Json
Assert-True ($stringCountKubernetesOperationsReportSyncReport.result -eq "failed") "String-count Kubernetes operations report sync import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountKubernetesOperationsReportSyncOutput "latest-kubernetes-operations-report-sync.json"))) "String-count Kubernetes operations report sync evidence must not be promoted."
Assert-True (($stringCountKubernetesOperationsReportSyncReport.entries | ConvertTo-Json -Depth 8).Contains("failedCount=0(valid=False)")) "String-count Kubernetes operations report sync report should describe invalid typed failed count."

Write-JsonEvidence (Join-Path $nonReadyKubernetesOperationsReportSyncRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
    sourceReportFormatVersion = "osmu.operations-readiness-convergence.v1"
    sourceReportResult = "action-required"
    sourceReportBytes = 2048
    sourceReportSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
$nonReadyKubernetesOperationsReportSyncOutput = Join-Path $resolvedOutputDirectory "non-ready-kubernetes-operations-report-sync-promoted"
$nonReadyKubernetesOperationsReportSyncJson = Join-Path $resolvedOutputDirectory "non-ready-kubernetes-operations-report-sync-import.json"
$nonReadyKubernetesOperationsReportSyncMarkdown = Join-Path $resolvedOutputDirectory "non-ready-kubernetes-operations-report-sync-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $nonReadyKubernetesOperationsReportSyncOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $nonReadyKubernetesOperationsReportSyncRoot `
        -OutputDirectory $nonReadyKubernetesOperationsReportSyncOutput `
        -JsonOutputPath $nonReadyKubernetesOperationsReportSyncJson `
        -MarkdownOutputPath $nonReadyKubernetesOperationsReportSyncMarkdown 2>&1
    $nonReadyKubernetesOperationsReportSyncExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($nonReadyKubernetesOperationsReportSyncExitCode -ne 0) "Kubernetes operations report sync with non-ready source report should fail import."
Assert-True (Test-Path -LiteralPath $nonReadyKubernetesOperationsReportSyncJson) "Non-ready Kubernetes operations report sync import report should still be written."
$nonReadyKubernetesOperationsReportSyncReport = Get-Content -Raw -LiteralPath $nonReadyKubernetesOperationsReportSyncJson | ConvertFrom-Json
Assert-True ($nonReadyKubernetesOperationsReportSyncReport.result -eq "failed") "Non-ready Kubernetes operations report sync import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $nonReadyKubernetesOperationsReportSyncOutput "latest-kubernetes-operations-report-sync.json"))) "Non-ready Kubernetes operations report sync evidence must not be promoted."
Assert-True (($nonReadyKubernetesOperationsReportSyncReport.entries | ConvertTo-Json -Depth 8).Contains("sourceReportResult=action-required")) "Non-ready Kubernetes operations report sync report should describe non-ready source report."

Write-JsonEvidence (Join-Path $invalidDataFlowRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
    sourceReportFormatVersion = "osmu.operations-readiness-convergence.v1"
    sourceReportResult = "ready"
    sourceReportBytes = 2048
    sourceReportSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
Write-JsonEvidence (Join-Path $invalidDataFlowRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
}
$invalidDataFlowOutput = Join-Path $resolvedOutputDirectory "invalid-data-flow-promoted"
$invalidDataFlowJson = Join-Path $resolvedOutputDirectory "invalid-data-flow-import.json"
$invalidDataFlowMarkdown = Join-Path $resolvedOutputDirectory "invalid-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $invalidDataFlowRoot `
        -OutputDirectory $invalidDataFlowOutput `
        -JsonOutputPath $invalidDataFlowJson `
        -MarkdownOutputPath $invalidDataFlowMarkdown 2>&1
    $invalidDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidDataFlowExitCode -ne 0) "Data-flow storage plan without required query plan summary should fail import."
Assert-True (Test-Path -LiteralPath $invalidDataFlowJson) "Invalid data-flow import report should still be written."
$invalidDataFlowReport = Get-Content -Raw -LiteralPath $invalidDataFlowJson | ConvertFrom-Json
Assert-True ($invalidDataFlowReport.result -eq "failed") "Invalid data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidDataFlowOutput "latest-data-flow-storage-plan.json"))) "Invalid data-flow storage plan must not be promoted."
Assert-True (($invalidDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("requires queryPlanEvidence summary")) "Invalid data-flow report should describe missing query plan summary."

Write-JsonEvidence (Join-Path $unsafeDataFlowRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
    sourceReportFormatVersion = "osmu.operations-readiness-convergence.v1"
    sourceReportResult = "ready"
    sourceReportBytes = 2048
    sourceReportSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
Write-JsonEvidence (Join-Path $unsafeDataFlowRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
    queryPlanEvidence = @{
        provided = $true
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        result = "passed"
        failedCount = 0
        rawSql = "SELECT id FROM data_flow_events"
    }
}
$unsafeDataFlowOutput = Join-Path $resolvedOutputDirectory "unsafe-data-flow-promoted"
$unsafeDataFlowJson = Join-Path $resolvedOutputDirectory "unsafe-data-flow-import.json"
$unsafeDataFlowMarkdown = Join-Path $resolvedOutputDirectory "unsafe-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $unsafeDataFlowRoot `
        -OutputDirectory $unsafeDataFlowOutput `
        -JsonOutputPath $unsafeDataFlowJson `
        -MarkdownOutputPath $unsafeDataFlowMarkdown 2>&1
    $unsafeDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowExitCode -ne 0) "Data-flow storage plan with unsafe query plan summary should fail import."
Assert-True (Test-Path -LiteralPath $unsafeDataFlowJson) "Unsafe data-flow import report should still be written."
$unsafeDataFlowReport = Get-Content -Raw -LiteralPath $unsafeDataFlowJson | ConvertFrom-Json
Assert-True ($unsafeDataFlowReport.result -eq "failed") "Unsafe data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeDataFlowOutput "latest-data-flow-storage-plan.json"))) "Unsafe data-flow storage plan must not be promoted."
Assert-True (($unsafeDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("raw SQL")) "Unsafe data-flow report should describe sanitized summary failure."

Write-JsonEvidence (Join-Path $unsafeDataFlowRunbookRoot "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    rawSql = "SELECT id FROM data_flow_events"
}
$unsafeDataFlowRunbookOutput = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-promoted"
$unsafeDataFlowRunbookJson = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-import.json"
$unsafeDataFlowRunbookMarkdown = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowRunbookOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStorageTransitionRunbookArtifactPath $unsafeDataFlowRunbookRoot `
        -OutputDirectory $unsafeDataFlowRunbookOutput `
        -JsonOutputPath $unsafeDataFlowRunbookJson `
        -MarkdownOutputPath $unsafeDataFlowRunbookMarkdown 2>&1
    $unsafeDataFlowRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowRunbookExitCode -ne 0) "Data-flow storage transition runbook with unsafe raw SQL should fail import."
Assert-True (Test-Path -LiteralPath $unsafeDataFlowRunbookJson) "Unsafe data-flow runbook import report should still be written."
$unsafeDataFlowRunbookReport = Get-Content -Raw -LiteralPath $unsafeDataFlowRunbookJson | ConvertFrom-Json
Assert-True ($unsafeDataFlowRunbookReport.result -eq "failed") "Unsafe data-flow runbook import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeDataFlowRunbookOutput "latest-data-flow-storage-transition-runbook-evidence.json"))) "Unsafe data-flow storage transition runbook must not be promoted."
Assert-True (($unsafeDataFlowRunbookReport.entries | ConvertTo-Json -Depth 8).Contains("raw SQL")) "Unsafe data-flow runbook report should describe sanitized summary failure."

Write-JsonEvidence (Join-Path $weakDataFlowRunbookRoot "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    summary = @{
        failureCount = "0"
        checkCount = 8
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
}
$weakDataFlowRunbookOutput = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-promoted"
$weakDataFlowRunbookJson = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-import.json"
$weakDataFlowRunbookMarkdown = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakDataFlowRunbookOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStorageTransitionRunbookArtifactPath $weakDataFlowRunbookRoot `
        -OutputDirectory $weakDataFlowRunbookOutput `
        -JsonOutputPath $weakDataFlowRunbookJson `
        -MarkdownOutputPath $weakDataFlowRunbookMarkdown 2>&1
    $weakDataFlowRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakDataFlowRunbookExitCode -ne 0) "Data-flow storage transition runbook with string failureCount should fail import."
Assert-True (Test-Path -LiteralPath $weakDataFlowRunbookJson) "Weak data-flow runbook import report should still be written."
$weakDataFlowRunbookReport = Get-Content -Raw -LiteralPath $weakDataFlowRunbookJson | ConvertFrom-Json
Assert-True ($weakDataFlowRunbookReport.result -eq "failed") "Weak data-flow runbook import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakDataFlowRunbookOutput "latest-data-flow-storage-transition-runbook-evidence.json"))) "Weak data-flow storage transition runbook must not be promoted."
Assert-True (($weakDataFlowRunbookReport.entries | ConvertTo-Json -Depth 8).Contains("failureCount=0(valid=False)")) "Weak data-flow runbook report should describe invalid typed failure count."

Write-JsonEvidence (Join-Path $stringBoolDataFlowRunbookRoot "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    summary = @{
        failureCount = 0
        checkCount = 8
    }
    confirmations = @{
        backfillRehearsed = "true"
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
}
$stringBoolDataFlowRunbookOutput = Join-Path $resolvedOutputDirectory "string-bool-data-flow-runbook-promoted"
$stringBoolDataFlowRunbookJson = Join-Path $resolvedOutputDirectory "string-bool-data-flow-runbook-import.json"
$stringBoolDataFlowRunbookMarkdown = Join-Path $resolvedOutputDirectory "string-bool-data-flow-runbook-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolDataFlowRunbookOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStorageTransitionRunbookArtifactPath $stringBoolDataFlowRunbookRoot `
        -OutputDirectory $stringBoolDataFlowRunbookOutput `
        -JsonOutputPath $stringBoolDataFlowRunbookJson `
        -MarkdownOutputPath $stringBoolDataFlowRunbookMarkdown 2>&1
    $stringBoolDataFlowRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolDataFlowRunbookExitCode -ne 0) "Data-flow storage transition runbook with string confirmation should fail import."
Assert-True (Test-Path -LiteralPath $stringBoolDataFlowRunbookJson) "String-bool data-flow runbook import report should still be written."
$stringBoolDataFlowRunbookReport = Get-Content -Raw -LiteralPath $stringBoolDataFlowRunbookJson | ConvertFrom-Json
Assert-True ($stringBoolDataFlowRunbookReport.result -eq "failed") "String-bool data-flow runbook import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringBoolDataFlowRunbookOutput "latest-data-flow-storage-transition-runbook-evidence.json"))) "String-bool data-flow storage transition runbook must not be promoted."
Assert-True (($stringBoolDataFlowRunbookReport.entries | ConvertTo-Json -Depth 8).Contains("confirmation backfillRehearsed=true expected boolean true")) "String-bool data-flow runbook report should describe invalid typed confirmation."

$weakDataFlowRunbookChecks = @((New-PassedDataFlowStorageTransitionRunbookChecks) | Where-Object { $_.id -ne "rollback-rehearsed-confirmed" })
Write-JsonEvidence (Join-Path $weakDataFlowRunbookChecksRoot "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    evidenceRef = "data-flow-storage-transition-runbook-20260622"
    reviewWindow = @{
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:20:00Z"
    }
    dataFlowStoragePlanSnapshot = @{
        formatVersion = "osmu.data-flow-storage-plan.v1"
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        pendingCount = 0
        checkCount = 10
        queryPlanEvidenceResult = "passed"
    }
    evidenceRefs = @{
        changeApproval = "CHG-2026-DATA-FLOW-RUNBOOK"
        dataFlowStoragePlan = "data-flow-storage-plan-passed-20260622"
        backfill = "backfill-rehearsal-20260622"
        dualWriteOrPartitionToggle = "dual-write-toggle-review-20260622"
        rollback = "rollback-rehearsal-20260622"
        reconciliation = "reconciliation-20260622"
        dashboardCutover = "dashboard-cutover-20260622"
        retentionDryRun = "retention-dry-run-20260622"
    }
    summary = @{
        failureCount = 0
        checkCount = $weakDataFlowRunbookChecks.Count
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    checks = $weakDataFlowRunbookChecks
}
$weakDataFlowRunbookChecksOutput = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-checks-promoted"
$weakDataFlowRunbookChecksJson = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-checks-import.json"
$weakDataFlowRunbookChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-data-flow-runbook-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakDataFlowRunbookChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStorageTransitionRunbookArtifactPath $weakDataFlowRunbookChecksRoot `
        -OutputDirectory $weakDataFlowRunbookChecksOutput `
        -JsonOutputPath $weakDataFlowRunbookChecksJson `
        -MarkdownOutputPath $weakDataFlowRunbookChecksMarkdown 2>&1
    $weakDataFlowRunbookChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakDataFlowRunbookChecksExitCode -ne 0) "Data-flow storage transition runbook without complete PASS check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakDataFlowRunbookChecksJson) "Weak data-flow runbook checks import report should still be written."
$weakDataFlowRunbookChecksReport = Get-Content -Raw -LiteralPath $weakDataFlowRunbookChecksJson | ConvertFrom-Json
Assert-True ($weakDataFlowRunbookChecksReport.result -eq "failed") "Weak data-flow runbook checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakDataFlowRunbookChecksOutput "latest-data-flow-storage-transition-runbook-evidence.json"))) "Weak data-flow storage transition runbook checks evidence must not be promoted."
Assert-True (($weakDataFlowRunbookChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.rollback-rehearsed-confirmed missing PASS")) "Weak data-flow runbook checks report should describe missing PASS check row."

Write-JsonEvidence (Join-Path $unsafeMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    webhookSecret = "password=super-secret"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$unsafeMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-promoted"
$unsafeMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-import.json"
$unsafeMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $unsafeMonitoringThresholdRoot `
        -OutputDirectory $unsafeMonitoringThresholdOutput `
        -JsonOutputPath $unsafeMonitoringThresholdJson `
        -MarkdownOutputPath $unsafeMonitoringThresholdMarkdown 2>&1
    $unsafeMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with credential-shaped content should fail import."
Assert-True (Test-Path -LiteralPath $unsafeMonitoringThresholdJson) "Unsafe monitoring threshold import report should still be written."
$unsafeMonitoringThresholdReport = Get-Content -Raw -LiteralPath $unsafeMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($unsafeMonitoringThresholdReport.result -eq "failed") "Unsafe monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "Unsafe monitoring threshold evidence must not be promoted."
Assert-True (($unsafeMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("credential-shaped content")) "Unsafe monitoring threshold report should describe credential-shaped content."

Write-JsonEvidence (Join-Path $stringBoolMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
        alertTargetCoverageComplete = $true
        routeCoverageComplete = $true
        grafanaPanelCoverageComplete = $true
        tuningEvidenceCoverageComplete = $true
        thresholdMappingComplete = $true
    }
    summary = @{
        failureCount = 0
        checkCount = 24
    }
    confirmations = @{
        prometheusRulesLoaded = "false"
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$stringBoolMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-promoted"
$stringBoolMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-import.json"
$stringBoolMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $stringBoolMonitoringThresholdRoot `
        -OutputDirectory $stringBoolMonitoringThresholdOutput `
        -JsonOutputPath $stringBoolMonitoringThresholdJson `
        -MarkdownOutputPath $stringBoolMonitoringThresholdMarkdown 2>&1
    $stringBoolMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with string confirmation should fail import."
Assert-True (Test-Path -LiteralPath $stringBoolMonitoringThresholdJson) "String-bool monitoring threshold import report should still be written."
$stringBoolMonitoringThresholdReport = Get-Content -Raw -LiteralPath $stringBoolMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($stringBoolMonitoringThresholdReport.result -eq "failed") "String-bool monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringBoolMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "String-bool monitoring threshold evidence must not be promoted."
Assert-True (($stringBoolMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("confirmation prometheusRulesLoaded=false expected boolean true")) "String-bool monitoring threshold report should describe invalid confirmation."

Write-JsonEvidence (Join-Path $stringCountMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = "11"
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
        alertTargetCoverageComplete = $true
        routeCoverageComplete = $true
        grafanaPanelCoverageComplete = $true
        tuningEvidenceCoverageComplete = $true
        thresholdMappingComplete = $true
    }
    summary = @{
        failureCount = 0
        checkCount = 24
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$stringCountMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-promoted"
$stringCountMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-import.json"
$stringCountMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $stringCountMonitoringThresholdRoot `
        -OutputDirectory $stringCountMonitoringThresholdOutput `
        -JsonOutputPath $stringCountMonitoringThresholdJson `
        -MarkdownOutputPath $stringCountMonitoringThresholdMarkdown 2>&1
    $stringCountMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with string count should fail import."
Assert-True (Test-Path -LiteralPath $stringCountMonitoringThresholdJson) "String-count monitoring threshold import report should still be written."
$stringCountMonitoringThresholdReport = Get-Content -Raw -LiteralPath $stringCountMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($stringCountMonitoringThresholdReport.result -eq "failed") "String-count monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "String-count monitoring threshold evidence must not be promoted."
Assert-True (($stringCountMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("requiredAlertCount=11(valid=False) expected integer")) "String-count monitoring threshold report should describe invalid typed count."

Write-JsonEvidence (Join-Path $missingCountMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
    }
    summary = @{
        failureCount = 0
        checkCount = 24
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$missingCountMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-promoted"
$missingCountMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-import.json"
$missingCountMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingCountMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $missingCountMonitoringThresholdRoot `
        -OutputDirectory $missingCountMonitoringThresholdOutput `
        -JsonOutputPath $missingCountMonitoringThresholdJson `
        -MarkdownOutputPath $missingCountMonitoringThresholdMarkdown 2>&1
    $missingCountMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingCountMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with missing count should fail import."
Assert-True (Test-Path -LiteralPath $missingCountMonitoringThresholdJson) "Missing-count monitoring threshold import report should still be written."
$missingCountMonitoringThresholdReport = Get-Content -Raw -LiteralPath $missingCountMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($missingCountMonitoringThresholdReport.result -eq "failed") "Missing-count monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $missingCountMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "Missing-count monitoring threshold evidence must not be promoted."
$missingCountMonitoringThresholdEntry = @($missingCountMonitoringThresholdReport.entries | Where-Object { $_.group -eq "monitoring-threshold" -and $_.fileName -eq "latest-monitoring-threshold-evidence.json" })
Assert-True ($missingCountMonitoringThresholdEntry.Count -eq 1) "Missing-count monitoring threshold failed entry missing."
Assert-True (([string] $missingCountMonitoringThresholdEntry[0].detail).Contains("tuningEvidenceCount=<missing>(valid=False) expected integer")) "Missing-count monitoring threshold report should describe missing typed count."

$weakMonitoringThresholdChecks = @((New-PassedMonitoringThresholdChecks) | Where-Object { $_.id -ne "grafana-panels-mapped" })
Write-JsonEvidence (Join-Path $weakMonitoringThresholdChecksRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    evidenceRef = "monitoring-threshold-evidence-20260622"
    reviewWindow = @{
        startedAt = "2026-06-22T00:00:00Z"
        completedAt = "2026-06-22T00:15:00Z"
    }
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
        alertTargetCoverageComplete = $true
        routeCoverageComplete = $true
        grafanaPanelCoverageComplete = $true
        tuningEvidenceCoverageComplete = $true
        thresholdMappingComplete = $true
    }
    evidenceRefs = @{
        changeApproval = "CHG-2026-MONITORING"
        prometheusRules = "prometheus-rules-loaded-20260622"
        grafanaDashboard = "grafana-dashboard-imported-20260622"
        alertmanagerRoute = "alertmanager-routes-reviewed-20260622"
        targetBaseline = "tenant-baseline-reviewed-20260622"
        incidentRouting = "incident-routing-reviewed-20260622"
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
    summary = @{
        failureCount = 0
        checkCount = $weakMonitoringThresholdChecks.Count
    }
    checks = $weakMonitoringThresholdChecks
}
$weakMonitoringThresholdChecksOutput = Join-Path $resolvedOutputDirectory "weak-monitoring-threshold-checks-promoted"
$weakMonitoringThresholdChecksJson = Join-Path $resolvedOutputDirectory "weak-monitoring-threshold-checks-import.json"
$weakMonitoringThresholdChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-monitoring-threshold-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakMonitoringThresholdChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $weakMonitoringThresholdChecksRoot `
        -OutputDirectory $weakMonitoringThresholdChecksOutput `
        -JsonOutputPath $weakMonitoringThresholdChecksJson `
        -MarkdownOutputPath $weakMonitoringThresholdChecksMarkdown 2>&1
    $weakMonitoringThresholdChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakMonitoringThresholdChecksExitCode -ne 0) "Monitoring threshold evidence without complete PASS check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakMonitoringThresholdChecksJson) "Weak monitoring threshold checks import report should still be written."
$weakMonitoringThresholdChecksReport = Get-Content -Raw -LiteralPath $weakMonitoringThresholdChecksJson | ConvertFrom-Json
Assert-True ($weakMonitoringThresholdChecksReport.result -eq "failed") "Weak monitoring threshold checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakMonitoringThresholdChecksOutput "latest-monitoring-threshold-evidence.json"))) "Weak monitoring threshold checks evidence must not be promoted."
Assert-True (($weakMonitoringThresholdChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.grafana-panels-mapped missing PASS")) "Weak monitoring threshold checks report should describe missing PASS check row."

Write-JsonEvidence (Join-Path $weakSecretRotationRoot "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    decisionRule = "Production/B2B readiness requires passed target secret rotation evidence."
    secretPolicy = "Evidence stores only references and booleans, not secret values."
}
$weakSecretRotationOutput = Join-Path $resolvedOutputDirectory "weak-secret-rotation-promoted"
$weakSecretRotationJson = Join-Path $resolvedOutputDirectory "weak-secret-rotation-import.json"
$weakSecretRotationMarkdown = Join-Path $resolvedOutputDirectory "weak-secret-rotation-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakSecretRotationOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecretRotationArtifactPath $weakSecretRotationRoot `
        -OutputDirectory $weakSecretRotationOutput `
        -JsonOutputPath $weakSecretRotationJson `
        -MarkdownOutputPath $weakSecretRotationMarkdown 2>&1
    $weakSecretRotationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakSecretRotationExitCode -ne 0) "Secret rotation evidence without required target metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakSecretRotationJson) "Weak secret rotation import report should still be written."
$weakSecretRotationReport = Get-Content -Raw -LiteralPath $weakSecretRotationJson | ConvertFrom-Json
Assert-True ($weakSecretRotationReport.result -eq "failed") "Weak secret rotation import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakSecretRotationOutput "latest-secret-rotation-evidence.json"))) "Weak secret rotation evidence must not be promoted."
$weakSecretRotationEntry = @($weakSecretRotationReport.entries | Where-Object { $_.group -eq "secret-rotation" -and $_.fileName -eq "latest-secret-rotation-evidence.json" })
Assert-True ($weakSecretRotationEntry.Count -eq 1) "Weak secret rotation failed entry missing."
Assert-True (([string] $weakSecretRotationEntry[0].detail).Contains("environmentName missing")) "Weak secret rotation report should describe missing target environment metadata."

Write-JsonEvidence (Join-Path $weakSecretRotationChecksRoot "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    rotationWindow = @{
        startedAt = "2026-06-20T00:00:00Z"
        completedAt = "2026-06-20T00:30:00Z"
    }
    evidenceRefs = @{
        changeApproval = "secret-rotation-20260620"
        secretManagerAudit = "vault-audit-20260620"
        workloadRestart = "rollout-20260620"
        smoke = "smoke-20260620"
        artifactLeakReview = "leak-review-20260620"
    }
    confirmations = @{
        noSecretValues = $true
        workloadRestart = $true
        smokePassed = $true
        artifactLeakReview = $true
    }
    rotations = @(
        @{ id = "admin-password"; core = $true; rotated = $true },
        @{ id = "jwt-signing-secret"; core = $true; rotated = $true },
        @{ id = "database-credentials"; core = $true; rotated = $true },
        @{ id = "minio-root-credentials"; core = $true; rotated = $true },
        @{ id = "tls-certificate"; core = $true; rotated = $true }
    )
    summary = @{
        rotatedCount = 5
        coreRotatedCount = 5
        coreRequiredCount = 5
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B readiness requires result=passed from the target environment after core secret/certificate rotation, workload restart, post-rotation smoke, and artifact leak review are confirmed."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain password values, API keys, private keys, bearer tokens, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
}
$weakSecretRotationChecksOutput = Join-Path $resolvedOutputDirectory "weak-secret-rotation-checks-promoted"
$weakSecretRotationChecksJson = Join-Path $resolvedOutputDirectory "weak-secret-rotation-checks-import.json"
$weakSecretRotationChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-secret-rotation-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakSecretRotationChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecretRotationArtifactPath $weakSecretRotationChecksRoot `
        -OutputDirectory $weakSecretRotationChecksOutput `
        -JsonOutputPath $weakSecretRotationChecksJson `
        -MarkdownOutputPath $weakSecretRotationChecksMarkdown 2>&1
    $weakSecretRotationChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakSecretRotationChecksExitCode -ne 0) "Secret rotation evidence without complete check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakSecretRotationChecksJson) "Weak secret rotation checks import report should still be written."
$weakSecretRotationChecksReport = Get-Content -Raw -LiteralPath $weakSecretRotationChecksJson | ConvertFrom-Json
Assert-True ($weakSecretRotationChecksReport.result -eq "failed") "Weak secret rotation checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakSecretRotationChecksOutput "latest-secret-rotation-evidence.json"))) "Weak secret rotation checks evidence must not be promoted."
Assert-True (($weakSecretRotationChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.target-cluster missing")) "Weak secret rotation checks report should describe missing target check row."

Write-JsonEvidence (Join-Path $weakCommercialIntegrationRoot "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    decisionRule = "Production/B2B commercial integration readiness requires passed target evidence."
    scopePolicy = "This evidence covers configured webhook profiles and sanitized payment adapter readiness."
    secretPolicy = "Evidence stores only references and booleans, not raw provider responses or credentials."
}
$weakCommercialIntegrationOutput = Join-Path $resolvedOutputDirectory "weak-commercial-integration-promoted"
$weakCommercialIntegrationJson = Join-Path $resolvedOutputDirectory "weak-commercial-integration-import.json"
$weakCommercialIntegrationMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-integration-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialIntegrationOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialIntegrationArtifactPath $weakCommercialIntegrationRoot `
        -OutputDirectory $weakCommercialIntegrationOutput `
        -JsonOutputPath $weakCommercialIntegrationJson `
        -MarkdownOutputPath $weakCommercialIntegrationMarkdown 2>&1
    $weakCommercialIntegrationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialIntegrationExitCode -ne 0) "Commercial integration evidence without required target metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialIntegrationJson) "Weak commercial integration import report should still be written."
$weakCommercialIntegrationReport = Get-Content -Raw -LiteralPath $weakCommercialIntegrationJson | ConvertFrom-Json
Assert-True ($weakCommercialIntegrationReport.result -eq "failed") "Weak commercial integration import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialIntegrationOutput "latest-commercial-integration-evidence.json"))) "Weak commercial integration evidence must not be promoted."
$weakCommercialIntegrationEntry = @($weakCommercialIntegrationReport.entries | Where-Object { $_.group -eq "commercial-integration" -and $_.fileName -eq "latest-commercial-integration-evidence.json" })
Assert-True ($weakCommercialIntegrationEntry.Count -eq 1) "Weak commercial integration failed entry missing."
Assert-True (([string] $weakCommercialIntegrationEntry[0].detail).Contains("environmentName missing")) "Weak commercial integration report should describe missing target environment metadata."

Write-JsonEvidence (Join-Path $weakCommercialIntegrationChecksRoot "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    environmentName = "prod"
    targetCluster = "osmu-prod"
    operatorName = "ops-owner"
    verificationWindow = @{
        startedAt = "2026-06-20T00:30:00Z"
        completedAt = "2026-06-20T01:00:00Z"
    }
    evidenceRefs = @{
        changeApproval = "commercial-integration-20260620"
        paymentProviderAdapterReadiness = "payment-adapter-readiness-20260620"
        adapterRetryWorker = "adapter-retry-20260620"
        payloadReview = "payload-review-20260620"
        privateNetworkBlocking = "private-block-20260620"
        hmacSignature = "hmac-review-20260620"
    }
    confirmations = @{
        noSecretValues = $true
        noRawProviderResponses = $true
        payloadSizeCaps = $true
        privateNetworkBlocking = $true
        hmacSignatureHeaders = $true
        paymentProviderAdapterReadinessReviewed = $true
        adapterRetryWorkerRun = $true
        requireAllImplementedAdapters = $true
        requirePaymentProviderAdapterReadinessReview = $true
    }
    integrations = @(
        @{ id = "notification-webhook"; required = $true; verified = $true; evidenceRef = "notification-webhook-20260620" },
        @{ id = "notification-slack"; required = $true; verified = $true; evidenceRef = "slack-webhook-20260620" },
        @{ id = "notification-email-smtp"; required = $true; verified = $true; evidenceRef = "email-smtp-20260620" },
        @{ id = "payment-generic-webhook"; required = $true; verified = $true; evidenceRef = "payment-generic-20260620" },
        @{ id = "payment-card-profile"; required = $true; verified = $true; evidenceRef = "payment-card-20260620" },
        @{ id = "payment-bank-profile"; required = $true; verified = $true; evidenceRef = "payment-bank-20260620" },
        @{ id = "payment-tax-profile"; required = $true; verified = $true; evidenceRef = "payment-tax-20260620" },
        @{ id = "payment-erp-profile"; required = $true; verified = $true; evidenceRef = "payment-erp-20260620" }
    )
    paymentProviderAdapterReadiness = @{
        required = $true
        reviewed = $true
        evidenceRef = "payment-adapter-readiness-run-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            validMode = $true
            status = "WEBHOOK_PROFILE_READY"
            nativeApiSupported = $false
            nativeApiReady = $false
            profileCount = 5
            webhookReadyProfileCount = 5
            nativeApiReadyProfileCount = 0
            countsValid = $true
            booleansValid = $true
            profiles = @(
                @{ providerProfile = "GENERIC"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "CARD"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "BANK"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "TAX"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "ERP"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
            )
        }
    }
    summary = @{
        integrationCount = 8
        verifiedCount = 8
        requiredCount = 8
        requiredVerifiedCount = 8
        paymentProviderAdapterReadinessReviewed = $true
        paymentProviderAdapterReadinessStatus = "WEBHOOK_PROFILE_READY"
        paymentProviderAdapterWebhookReadyProfileCount = 5
        paymentProviderAdapterNativeReadyProfileCount = 0
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        @{ id = "environment-name"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B commercial integration readiness requires result=passed from the target environment for every required notification/payment handoff adapter profile, payment-provider adapter readiness review, adapter retry worker evidence, payload cap check, private/local endpoint blocking check, HMAC signature review, no-secret confirmation, and no-raw-provider-response confirmation."
    scopePolicy = "This evidence covers configured webhook/Slack/EMAIL SMTP relay, generic/CARD/BANK/TAX/ERP payment webhook profile handoff verification, and the sanitized payment-provider adapter readiness snapshot. It does not claim or require native card, bank, tax invoice, or ERP processor API support."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain webhook URLs with credentials, SMTP passwords, payment provider credentials, signing secrets, bearer tokens, private keys, raw provider responses, or customer payment data."
}
$weakCommercialIntegrationChecksOutput = Join-Path $resolvedOutputDirectory "weak-commercial-integration-checks-promoted"
$weakCommercialIntegrationChecksJson = Join-Path $resolvedOutputDirectory "weak-commercial-integration-checks-import.json"
$weakCommercialIntegrationChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-integration-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialIntegrationChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialIntegrationArtifactPath $weakCommercialIntegrationChecksRoot `
        -OutputDirectory $weakCommercialIntegrationChecksOutput `
        -JsonOutputPath $weakCommercialIntegrationChecksJson `
        -MarkdownOutputPath $weakCommercialIntegrationChecksMarkdown 2>&1
    $weakCommercialIntegrationChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialIntegrationChecksExitCode -ne 0) "Commercial integration evidence without complete check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialIntegrationChecksJson) "Weak commercial integration checks import report should still be written."
$weakCommercialIntegrationChecksReport = Get-Content -Raw -LiteralPath $weakCommercialIntegrationChecksJson | ConvertFrom-Json
Assert-True ($weakCommercialIntegrationChecksReport.result -eq "failed") "Weak commercial integration checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialIntegrationChecksOutput "latest-commercial-integration-evidence.json"))) "Weak commercial integration checks evidence must not be promoted."
Assert-True (($weakCommercialIntegrationChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.target-cluster missing")) "Weak commercial integration checks report should describe missing target check row."

Write-JsonEvidence (Join-Path $weakCommercialApprovalRoot "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    approvedBy = "commercial-review-board"
    approvedAt = "2026-06-20T03:00:00Z"
    decisionRule = "Production/B2B sale commercial approval requires result=passed."
    scopePolicy = "This evidence records commercial/legal approval references only."
    secretPolicy = "Evidence stores no secret values or raw price tables."
}
$weakCommercialApprovalOutput = Join-Path $resolvedOutputDirectory "weak-commercial-approval-promoted"
$weakCommercialApprovalJson = Join-Path $resolvedOutputDirectory "weak-commercial-approval-import.json"
$weakCommercialApprovalMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-approval-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialApprovalOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialApprovalArtifactPath $weakCommercialApprovalRoot `
        -OutputDirectory $weakCommercialApprovalOutput `
        -JsonOutputPath $weakCommercialApprovalJson `
        -MarkdownOutputPath $weakCommercialApprovalMarkdown 2>&1
    $weakCommercialApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialApprovalExitCode -ne 0) "Commercial approval evidence without required approval metadata should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialApprovalJson) "Weak commercial approval import report should still be written."
$weakCommercialApprovalReport = Get-Content -Raw -LiteralPath $weakCommercialApprovalJson | ConvertFrom-Json
Assert-True ($weakCommercialApprovalReport.result -eq "failed") "Weak commercial approval import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialApprovalOutput "latest-commercial-approval-evidence.json"))) "Weak commercial approval evidence must not be promoted."
$weakCommercialApprovalEntry = @($weakCommercialApprovalReport.entries | Where-Object { $_.group -eq "commercial-approval" -and $_.fileName -eq "latest-commercial-approval-evidence.json" })
Assert-True ($weakCommercialApprovalEntry.Count -eq 1) "Weak commercial approval failed entry missing."
Assert-True (([string] $weakCommercialApprovalEntry[0].detail).Contains("productVersion missing")) "Weak commercial approval report should describe missing product approval metadata."

Write-JsonEvidence (Join-Path $weakCommercialApprovalChecksRoot "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    generatedAt = "2026-06-22T00:00:00Z"
    result = "passed"
    productVersion = "v0.1.0-rc.1"
    approvedBy = "commercial-review-board"
    approvedAt = "2026-06-20T03:00:00Z"
    evidenceRefs = @{
        approval = "commercial-approval-board-20260620"
        pricing = "pricing-approval-20260620"
        terms = "terms-approval-20260620"
        supportSla = "support-sla-approval-20260620"
        licenseAgreement = "license-agreement-approval-20260620"
        legal = "legal-approval-20260620"
        pilotContract = "pilot-contract-template-20260620"
        pricingPolicyProposal = "pricing-policy-proposal-commercial-approval-20260620"
    }
    confirmations = @{
        pricingApproved = $true
        termsApproved = $true
        supportSlaApproved = $true
        licenseApproved = $true
        legalApproved = $true
        pricingPolicyProposalCommercialApproval = $true
        requirePricingPolicyProposalApprovalSnapshot = $true
        noSecretValues = $true
    }
    pricingPolicyProposalApproval = @{
        required = $true
        reviewed = $true
        evidenceRef = "pricing-policy-proposal-commercial-approval-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            proposalCount = 1
            approvedPriceListCount = 1
            commercialApprovedCount = 1
            approvalFlagsValid = $true
            proposals = @(
                @{
                    id = 101
                    status = "PRICE_LIST_APPROVED"
                    approvedPriceList = $true
                    commercialApprovalReference = "commercial-approval-board-20260620"
                    commercialApprovedAt = "2026-06-20T05:10:00Z"
                }
            )
        }
    }
    summary = @{
        passedCount = 14
        failureCount = 0
        checkCount = 14
        pricingPolicyProposalCommercialApproved = $true
        pricingPolicyProposalCommercialApprovedCount = 1
        pricingPolicyProposalApprovedPriceListCount = 1
        pricingPolicyProposalApprovalFlagsValid = $true
    }
    checks = @(
        @{ id = "product-version"; status = "PASS"; passed = $true }
    )
    decisionRule = "Production/B2B sale commercial approval requires result=passed, final pricing approval, final terms approval, support SLA approval, license agreement approval, legal approval, a pilot contract boundary reference, required billing pricing policy proposal commercial approval evidence, and no-secret confirmation."
    scopePolicy = "This evidence records commercial/legal approval references and sanitized billing pricing policy proposal approval status only. It does not publish prices, legal terms, contracts, customer data, or native payment processor credentials."
    secretPolicy = "Evidence stores only product version, approver identity, timestamps, booleans, sanitized pricing proposal status/reference metadata, and external approval references; it must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, raw price tables, or raw contract text."
}
$weakCommercialApprovalChecksOutput = Join-Path $resolvedOutputDirectory "weak-commercial-approval-checks-promoted"
$weakCommercialApprovalChecksJson = Join-Path $resolvedOutputDirectory "weak-commercial-approval-checks-import.json"
$weakCommercialApprovalChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-approval-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialApprovalChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialApprovalArtifactPath $weakCommercialApprovalChecksRoot `
        -OutputDirectory $weakCommercialApprovalChecksOutput `
        -JsonOutputPath $weakCommercialApprovalChecksJson `
        -MarkdownOutputPath $weakCommercialApprovalChecksMarkdown 2>&1
    $weakCommercialApprovalChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialApprovalChecksExitCode -ne 0) "Commercial approval evidence without complete check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialApprovalChecksJson) "Weak commercial approval checks import report should still be written."
$weakCommercialApprovalChecksReport = Get-Content -Raw -LiteralPath $weakCommercialApprovalChecksJson | ConvertFrom-Json
Assert-True ($weakCommercialApprovalChecksReport.result -eq "failed") "Weak commercial approval checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialApprovalChecksOutput "latest-commercial-approval-evidence.json"))) "Weak commercial approval checks evidence must not be promoted."
Assert-True (($weakCommercialApprovalChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.approval-ref missing")) "Weak commercial approval checks report should describe missing approval check row."

Write-JsonEvidence (Join-Path $invalidEnterpriseAuthRoot "latest-enterprise-auth-smoke.json") (New-ScopeOutEnterpriseAuthEvidence -Accepted "false")
$invalidEnterpriseAuthOutput = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-promoted"
$invalidEnterpriseAuthJson = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-import.json"
$invalidEnterpriseAuthMarkdown = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidEnterpriseAuthOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -EnterpriseAuthArtifactPath $invalidEnterpriseAuthRoot `
        -OutputDirectory $invalidEnterpriseAuthOutput `
        -JsonOutputPath $invalidEnterpriseAuthJson `
        -MarkdownOutputPath $invalidEnterpriseAuthMarkdown 2>&1
    $invalidEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidEnterpriseAuthExitCode -ne 0) "Enterprise auth scope-out evidence with string accepted=false should fail import."
Assert-True (Test-Path -LiteralPath $invalidEnterpriseAuthJson) "Invalid enterprise auth import report should still be written."
$invalidEnterpriseAuthReport = Get-Content -Raw -LiteralPath $invalidEnterpriseAuthJson | ConvertFrom-Json
Assert-True ($invalidEnterpriseAuthReport.result -eq "failed") "Invalid enterprise auth import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidEnterpriseAuthOutput "latest-enterprise-auth-smoke.json"))) "Invalid enterprise auth evidence must not be promoted."
$invalidEnterpriseAuthEntry = @($invalidEnterpriseAuthReport.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($invalidEnterpriseAuthEntry.Count -eq 1) "Invalid enterprise auth import entry missing."
Assert-True (([string] $invalidEnterpriseAuthEntry[0].detail).Contains("accepted=false(valid=False)")) "Invalid enterprise auth report should describe invalid accepted value."

Write-JsonEvidence (Join-Path $stringCountEnterpriseAuthRoot "latest-enterprise-auth-smoke.json") (New-PassedEnterpriseAuthEvidence -FailCount "0")
$stringCountEnterpriseAuthOutput = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-promoted"
$stringCountEnterpriseAuthJson = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-import.json"
$stringCountEnterpriseAuthMarkdown = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountEnterpriseAuthOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -EnterpriseAuthArtifactPath $stringCountEnterpriseAuthRoot `
        -OutputDirectory $stringCountEnterpriseAuthOutput `
        -JsonOutputPath $stringCountEnterpriseAuthJson `
        -MarkdownOutputPath $stringCountEnterpriseAuthMarkdown 2>&1
    $stringCountEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountEnterpriseAuthExitCode -ne 0) "Enterprise auth passed evidence with string count should fail import."
Assert-True (Test-Path -LiteralPath $stringCountEnterpriseAuthJson) "String-count enterprise auth import report should still be written."
$stringCountEnterpriseAuthReport = Get-Content -Raw -LiteralPath $stringCountEnterpriseAuthJson | ConvertFrom-Json
Assert-True ($stringCountEnterpriseAuthReport.result -eq "failed") "String-count enterprise auth import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountEnterpriseAuthOutput "latest-enterprise-auth-smoke.json"))) "String-count enterprise auth evidence must not be promoted."
$stringCountEnterpriseAuthEntry = @($stringCountEnterpriseAuthReport.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($stringCountEnterpriseAuthEntry.Count -eq 1) "String-count enterprise auth import entry missing."
Assert-True (([string] $stringCountEnterpriseAuthEntry[0].detail).Contains("failCount=0(valid=False)")) "String-count enterprise auth report should describe invalid typed count."

Write-JsonEvidence (Join-Path $weakEnterpriseAuthChecksRoot "latest-enterprise-auth-smoke.json") (New-ScopeOutEnterpriseAuthEvidence -Checks @(
    @{ id = "enterprise-auth-scope-out-confirmed"; name = "Enterprise auth commercial scope-out confirmed"; category = "enterprise-auth"; endpoint = "commercial approval"; status = "PASS"; detail = "ConfirmScopeOut=True."; requiredInputs = @("ConfirmScopeOut") }
))
$weakEnterpriseAuthChecksOutput = Join-Path $resolvedOutputDirectory "weak-enterprise-auth-checks-promoted"
$weakEnterpriseAuthChecksJson = Join-Path $resolvedOutputDirectory "weak-enterprise-auth-checks-import.json"
$weakEnterpriseAuthChecksMarkdown = Join-Path $resolvedOutputDirectory "weak-enterprise-auth-checks-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakEnterpriseAuthChecksOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -EnterpriseAuthArtifactPath $weakEnterpriseAuthChecksRoot `
        -OutputDirectory $weakEnterpriseAuthChecksOutput `
        -JsonOutputPath $weakEnterpriseAuthChecksJson `
        -MarkdownOutputPath $weakEnterpriseAuthChecksMarkdown 2>&1
    $weakEnterpriseAuthChecksExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakEnterpriseAuthChecksExitCode -ne 0) "Enterprise auth scope-out evidence without complete check rows should fail import."
Assert-True (Test-Path -LiteralPath $weakEnterpriseAuthChecksJson) "Weak enterprise auth checks import report should still be written."
$weakEnterpriseAuthChecksReport = Get-Content -Raw -LiteralPath $weakEnterpriseAuthChecksJson | ConvertFrom-Json
Assert-True ($weakEnterpriseAuthChecksReport.result -eq "failed") "Weak enterprise auth checks import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakEnterpriseAuthChecksOutput "latest-enterprise-auth-smoke.json"))) "Weak enterprise auth checks evidence must not be promoted."
Assert-True (($weakEnterpriseAuthChecksReport.entries | ConvertTo-Json -Depth 8).Contains("checks.enterprise-auth-scope-out-ref missing PASS")) "Weak enterprise auth checks report should describe missing scope-out check row."

Write-JsonEvidence (Join-Path $staleOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    confirmations = [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $false
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}
$staleOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-promoted"
$staleOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-import.json"
$staleOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $staleOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $staleOperationsHandoffPackageRoot `
        -OutputDirectory $staleOperationsHandoffPackageOutput `
        -JsonOutputPath $staleOperationsHandoffPackageJson `
        -MarkdownOutputPath $staleOperationsHandoffPackageMarkdown 2>&1
    $staleOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($staleOperationsHandoffPackageExitCode -ne 0) "Operations handoff package without required review confirmations should fail import."
Assert-True (Test-Path -LiteralPath $staleOperationsHandoffPackageJson) "Stale operations handoff package import report should still be written."
$staleOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $staleOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($staleOperationsHandoffPackageReport.result -eq "failed") "Stale operations handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $staleOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Stale operations handoff package must not be promoted."
Assert-True (($staleOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("commercialApprovalSnapshotReviewed")) "Stale operations handoff package report should describe missing required review confirmation."

Write-JsonEvidence (Join-Path $badConvergenceOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -ConvergenceSourceReportResult "action-required")
    confirmations = [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}
$badConvergenceOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-promoted"
$badConvergenceOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-import.json"
$badConvergenceOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $badConvergenceOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $badConvergenceOperationsHandoffPackageRoot `
        -OutputDirectory $badConvergenceOperationsHandoffPackageOutput `
        -JsonOutputPath $badConvergenceOperationsHandoffPackageJson `
        -MarkdownOutputPath $badConvergenceOperationsHandoffPackageMarkdown 2>&1
    $badConvergenceOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($badConvergenceOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with non-ready convergence source should fail import."
Assert-True (Test-Path -LiteralPath $badConvergenceOperationsHandoffPackageJson) "Bad convergence handoff package import report should still be written."
$badConvergenceOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $badConvergenceOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($badConvergenceOperationsHandoffPackageReport.result -eq "failed") "Bad convergence handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $badConvergenceOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Bad convergence handoff package must not be promoted."
Assert-True (($badConvergenceOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("sourceReportResult=action-required")) "Bad convergence handoff package report should describe non-ready source report result."

Write-JsonEvidence (Join-Path $stringBoolOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -KubernetesReportSyncReady "false")
    confirmations = [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}
$stringBoolOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-promoted"
$stringBoolOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-import.json"
$stringBoolOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $stringBoolOperationsHandoffPackageRoot `
        -OutputDirectory $stringBoolOperationsHandoffPackageOutput `
        -JsonOutputPath $stringBoolOperationsHandoffPackageJson `
        -MarkdownOutputPath $stringBoolOperationsHandoffPackageMarkdown 2>&1
    $stringBoolOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with string sync boolean should fail import."
Assert-True (Test-Path -LiteralPath $stringBoolOperationsHandoffPackageJson) "String-bool handoff package import report should still be written."
$stringBoolOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $stringBoolOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($stringBoolOperationsHandoffPackageReport.result -eq "failed") "String-bool handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringBoolOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "String-bool handoff package must not be promoted."
Assert-True (($stringBoolOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("kubernetesReportSyncReady=false")) "String-bool handoff package report should describe invalid sync ready value."

$missingCountSnapshots = New-PassedOperationsHandoffPackageSnapshots
$missingCountSnapshots["convergence"].Remove("finalizerGapCount")
Write-JsonEvidence (Join-Path $missingCountOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = $missingCountSnapshots
    confirmations = [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}
$missingCountOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-promoted"
$missingCountOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-import.json"
$missingCountOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingCountOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $missingCountOperationsHandoffPackageRoot `
        -OutputDirectory $missingCountOperationsHandoffPackageOutput `
        -JsonOutputPath $missingCountOperationsHandoffPackageJson `
        -MarkdownOutputPath $missingCountOperationsHandoffPackageMarkdown 2>&1
    $missingCountOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingCountOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with missing finalizer gap count should fail import."
Assert-True (Test-Path -LiteralPath $missingCountOperationsHandoffPackageJson) "Missing-count handoff package import report should still be written."
$missingCountOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $missingCountOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($missingCountOperationsHandoffPackageReport.result -eq "failed") "Missing-count handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $missingCountOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Missing-count handoff package must not be promoted."
$missingCountOperationsHandoffPackageEntry = @($missingCountOperationsHandoffPackageReport.entries | Where-Object { $_.group -eq "operations-handoff-package" -and $_.fileName -eq "latest-operations-handoff-package.json" })
Assert-True ($missingCountOperationsHandoffPackageEntry.Count -eq 1) "Missing-count handoff package failed entry missing."
Assert-True (([string] $missingCountOperationsHandoffPackageEntry[0].detail).Contains("finalizerGapCount=<missing>")) "Missing-count handoff package report should describe missing finalizer gap count."

$weakTargetOperationsHandoffChecks = New-PassedOperationsHandoffPackageChecks
$weakTargetOperationsHandoffSnapshots = New-PassedOperationsHandoffPackageTargetSnapshots
$weakTargetOperationsHandoffSnapshots["commercialApproval"]["failureCount"] = 1
Write-JsonEvidence (Join-Path $weakTargetOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    evidenceRefs = (New-PassedOperationsHandoffPackageEvidenceRefs)
    targetEvidenceSnapshots = $weakTargetOperationsHandoffSnapshots
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    summary = (New-PassedOperationsHandoffPackageSummary -CheckCount $weakTargetOperationsHandoffChecks.Count)
    checks = $weakTargetOperationsHandoffChecks
}
$weakTargetOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "weak-target-operations-handoff-package-promoted"
$weakTargetOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "weak-target-operations-handoff-package-import.json"
$weakTargetOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "weak-target-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakTargetOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $weakTargetOperationsHandoffPackageRoot `
        -OutputDirectory $weakTargetOperationsHandoffPackageOutput `
        -JsonOutputPath $weakTargetOperationsHandoffPackageJson `
        -MarkdownOutputPath $weakTargetOperationsHandoffPackageMarkdown 2>&1
    $weakTargetOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakTargetOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with weak target snapshot should fail import."
Assert-True (Test-Path -LiteralPath $weakTargetOperationsHandoffPackageJson) "Weak-target handoff package import report should still be written."
$weakTargetOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $weakTargetOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($weakTargetOperationsHandoffPackageReport.result -eq "failed") "Weak-target handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakTargetOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Weak-target handoff package must not be promoted."
Assert-True (($weakTargetOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("targetEvidenceSnapshots.commercialApproval.failureCount=1")) "Weak-target handoff package report should describe failing commercial approval target snapshot."

Write-JsonEvidence (Join-Path $directDataFlowStoragePlanSource "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "EXTERNAL_TIME_SERIES"
    checkCount = 8
    passedCount = 8
    pendingCount = 0
    queryPlanEvidence = $null
}

Write-JsonEvidence (Join-Path $weakDirectDataFlowStoragePlanRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "EXTERNAL_TIME_SERIES"
    pendingCount = 1
}
$weakDirectDataFlowOutput = Join-Path $resolvedOutputDirectory "weak-direct-data-flow-promoted"
$weakDirectDataFlowJson = Join-Path $resolvedOutputDirectory "weak-direct-data-flow-import.json"
$weakDirectDataFlowMarkdown = Join-Path $resolvedOutputDirectory "weak-direct-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakDirectDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStoragePlanArtifactPath $weakDirectDataFlowStoragePlanRoot `
        -OutputDirectory $weakDirectDataFlowOutput `
        -JsonOutputPath $weakDirectDataFlowJson `
        -MarkdownOutputPath $weakDirectDataFlowMarkdown 2>&1
    $weakDirectDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakDirectDataFlowExitCode -ne 0) "Direct data-flow storage plan with non-passed result should fail import."
Assert-True (Test-Path -LiteralPath $weakDirectDataFlowJson) "Weak direct data-flow import report should still be written."
$weakDirectDataFlowReport = Get-Content -Raw -LiteralPath $weakDirectDataFlowJson | ConvertFrom-Json
Assert-True ($weakDirectDataFlowReport.result -eq "failed") "Weak direct data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakDirectDataFlowOutput "latest-data-flow-storage-plan.json"))) "Weak direct data-flow storage plan must not be promoted."
Assert-True (($weakDirectDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("result=plan-ready-execute-required expected=passed")) "Weak direct data-flow report should describe non-passed result."

Write-JsonEvidence (Join-Path $stringCountDirectDataFlowStoragePlanRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 0
    queryPlanEvidence = @{
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        result = "passed"
        failedCount = "0"
    }
}
$stringCountDirectDataFlowOutput = Join-Path $resolvedOutputDirectory "string-count-direct-data-flow-promoted"
$stringCountDirectDataFlowJson = Join-Path $resolvedOutputDirectory "string-count-direct-data-flow-import.json"
$stringCountDirectDataFlowMarkdown = Join-Path $resolvedOutputDirectory "string-count-direct-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountDirectDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStoragePlanArtifactPath $stringCountDirectDataFlowStoragePlanRoot `
        -OutputDirectory $stringCountDirectDataFlowOutput `
        -JsonOutputPath $stringCountDirectDataFlowJson `
        -MarkdownOutputPath $stringCountDirectDataFlowMarkdown 2>&1
    $stringCountDirectDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountDirectDataFlowExitCode -ne 0) "Direct data-flow storage plan with string query-plan failedCount should fail import."
Assert-True (Test-Path -LiteralPath $stringCountDirectDataFlowJson) "String-count direct data-flow import report should still be written."
$stringCountDirectDataFlowReport = Get-Content -Raw -LiteralPath $stringCountDirectDataFlowJson | ConvertFrom-Json
Assert-True ($stringCountDirectDataFlowReport.result -eq "failed") "String-count direct data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountDirectDataFlowOutput "latest-data-flow-storage-plan.json"))) "String-count direct data-flow storage plan must not be promoted."
Assert-True (($stringCountDirectDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("queryPlanEvidence.failedCount=0(valid=False)")) "String-count direct data-flow report should describe invalid typed query-plan failed count."

$directDataFlowOutput = Join-Path $resolvedOutputDirectory "direct-data-flow-promoted"
$directDataFlowJson = Join-Path $resolvedOutputDirectory "direct-data-flow-import.json"
$directDataFlowMarkdown = Join-Path $resolvedOutputDirectory "direct-data-flow-import.md"
& powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
    -DataFlowStoragePlanArtifactPath $directDataFlowStoragePlanSource `
    -OutputDirectory $directDataFlowOutput `
    -JsonOutputPath $directDataFlowJson `
    -MarkdownOutputPath $directDataFlowMarkdown | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Direct data-flow storage plan import failed with exit code $LASTEXITCODE."
}
$directDataFlowReport = Get-Content -Raw -LiteralPath $directDataFlowJson | ConvertFrom-Json
Assert-True ($directDataFlowReport.result -eq "passed") "Direct data-flow import report should pass."
Assert-True ($directDataFlowReport.selectedGroupCount -eq 1) "Direct data-flow import should select one group."
Assert-True (Test-Path -LiteralPath (Join-Path $directDataFlowOutput "latest-data-flow-storage-plan.json")) "Direct data-flow storage plan must be promoted."
$directDataFlowEntry = @($directDataFlowReport.entries | Where-Object { $_.group -eq "data-flow-storage-plan" -and $_.fileName -eq "latest-data-flow-storage-plan.json" })
Assert-True ($directDataFlowEntry.Count -eq 1) "Direct data-flow import entry missing."
Assert-True (([string] $directDataFlowEntry[0].detail).Contains("candidateStore=EXTERNAL_TIME_SERIES")) "Direct data-flow import entry should include candidate store validation detail."

Write-Host "Operations readiness artifact import verified."
Write-Host "Report: $reportPath"
