param(
    [string] $DrillPath = ".\dev-docs\backup-restore-drill.md",
    [string] $BackupRecoveryPath = ".\dev-docs\backup-recovery.md",
    [string] $DeploymentStrategyPath = ".\dev-docs\deployment-strategy.md",
    [string] $BackupLocalDemoScriptPath = ".\scripts\backup-local-demo.ps1",
    [string] $RestoreLocalDemoScriptPath = ".\scripts\restore-local-demo.ps1",
    [string] $RunLocalDrillScriptPath = ".\scripts\run-local-backup-restore-drill.ps1",
    [string] $RunKubernetesBackupDrillScriptPath = ".\scripts\run-kubernetes-backup-drill.ps1",
    [string] $PrepareKubernetesRestoreNamespaceScriptPath = ".\scripts\prepare-kubernetes-restore-namespace.ps1",
    [string] $VerifyKubernetesBackupArtifactsScriptPath = ".\scripts\verify-kubernetes-backup-artifacts.ps1",
    [string] $RunKubernetesRestoreDrillScriptPath = ".\scripts\run-kubernetes-restore-drill.ps1",
    [string] $RunKubernetesDrDrillScriptPath = ".\scripts\run-kubernetes-dr-drill.ps1",
    [string] $BootstrapKubernetesDrBucketScriptPath = ".\scripts\bootstrap-kubernetes-dr-bucket.ps1",
    [string] $VerifyKubernetesDrBucketImmutabilityScriptPath = ".\scripts\verify-kubernetes-dr-bucket-immutability.ps1",
    [string] $TransferKubernetesBackupArtifactsScriptPath = ".\scripts\transfer-kubernetes-backup-artifacts.ps1",
    [string] $VerifyKubernetesRestoreSmokeScriptPath = ".\scripts\verify-kubernetes-restore-smoke.ps1",
    [string] $WriteKubernetesDrEvidenceRequestScriptPath = ".\scripts\write-kubernetes-dr-evidence-request.ps1",
    [string] $FinalizeKubernetesDrDrillScriptPath = ".\scripts\finalize-kubernetes-dr-drill.ps1"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Read-RequiredFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    Assert-True (Test-Path -LiteralPath $resolved) "$label not found: $resolved"
    $content = Read-Utf8Text $resolved
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

$drill = Read-RequiredFile $DrillPath "Backup restore drill"
Assert-Contains $drill "MariaDB metadata backup and restore." "Backup restore drill"
Assert-Contains $drill "MinIO bucket/object backup and restore." "Backup restore drill"
Assert-Contains $drill "MVP pilot RPO: 24 hours." "Backup restore drill"
Assert-Contains $drill "MVP pilot RTO: 4 hours" "Backup restore drill"
Assert-Contains $drill "Do not copy secret values" "Backup restore drill"
Assert-Contains $drill "Drill Runbook" "Backup restore drill"
Assert-Contains $drill "Restore MariaDB metadata." "Backup restore drill"
Assert-Contains $drill "Restore MinIO bucket/object data." "Backup restore drill"
Assert-Contains $drill "verify-s3-client-smoke.ps1" "Backup restore drill"
Assert-Contains $drill "Evidence API" "Backup restore drill"
Assert-Contains $drill "POST /api/admin/backup/restore-drill-evidence" "Backup restore drill"
Assert-Contains $drill "latestRestoreDrillEvidence" "Backup restore drill"
Assert-Contains $drill "Local Demo Automation" "Backup restore drill"
Assert-Contains $drill "backup-local-demo.ps1" "Backup restore drill"
Assert-Contains $drill "restore-local-demo.ps1" "Backup restore drill"
Assert-Contains $drill "run-local-backup-restore-drill.ps1" "Backup restore drill"
Assert-Contains $drill "run-kubernetes-backup-drill.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-backup-drill.json" "Backup restore drill"
Assert-Contains $drill "prepare-kubernetes-restore-namespace.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-restore-namespace.json" "Backup restore drill"
Assert-Contains $drill "verify-kubernetes-backup-artifacts.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-backup-artifacts.json" "Backup restore drill"
Assert-Contains $drill "metadata.sql.sha256" "Backup restore drill"
Assert-Contains $drill "run-kubernetes-restore-drill.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-restore-drill.json" "Backup restore drill"
Assert-Contains $drill "run-kubernetes-dr-drill.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-dr-drill.json" "Backup restore drill"
Assert-Contains $drill "bootstrap-kubernetes-dr-bucket.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-dr-bucket-bootstrap.json" "Backup restore drill"
Assert-Contains $drill "verify-kubernetes-dr-bucket-immutability.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-dr-bucket-immutability.json" "Backup restore drill"
Assert-Contains $drill "transfer-kubernetes-backup-artifacts.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-backup-artifact-transfer.json" "Backup restore drill"
Assert-Contains $drill "osmu-dr-transfer-secret" "Backup restore drill"
Assert-Contains $drill "verify-kubernetes-restore-smoke.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-restore-smoke.json" "Backup restore drill"
Assert-Contains $drill "write-kubernetes-dr-evidence-request.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-dr-evidence-request.json" "Backup restore drill"
Assert-Contains $drill "finalize-kubernetes-dr-drill.ps1" "Backup restore drill"
Assert-Contains $drill "latest-kubernetes-dr-finalize.json" "Backup restore drill"
Assert-Contains $drill "ConfirmSuccessfulRestore" "Backup restore drill"
Assert-Contains $drill "PostRestoreSmokeVerified" "Backup restore drill"
Assert-Contains $drill "osmu-restore-drill" "Backup restore drill"
Assert-Contains $drill "Acceptance Criteria" "Backup restore drill"
Assert-Contains $drill "Full production durable restore execution still requires Docker/MariaDB/MinIO" "Backup restore drill"

$backupRecovery = Read-RequiredFile $BackupRecoveryPath "Backup recovery"
Assert-Contains $backupRecovery "backup-restore-drill.md" "Backup recovery"

$deploymentStrategy = Read-RequiredFile $DeploymentStrategyPath "Deployment strategy"
Assert-Contains $deploymentStrategy "backup-restore-drill.md" "Deployment strategy"

$backupScript = Read-RequiredFile $BackupLocalDemoScriptPath "Local backup script"
Assert-Contains $backupScript "mariadb-dump" "Local backup script"
Assert-Contains $backupScript "mc mirror --overwrite local /backup/minio" "Local backup script"
Assert-Contains $backupScript "backup-manifest.json" "Local backup script"
Assert-Contains $backupScript "Secret values are not copied" "Local backup script"

$restoreScript = Read-RequiredFile $RestoreLocalDemoScriptPath "Local restore script"
Assert-Contains $restoreScript "-ConfirmRestore" "Local restore script"
Assert-Contains $restoreScript "mc mirror " "Local restore script"
Assert-Contains $restoreScript "restore-drill-evidence" "Local restore script"
Assert-Contains $restoreScript "Secret values are not copied" "Local restore script"

$runScript = Read-RequiredFile $RunLocalDrillScriptPath "Local backup restore drill script"
Assert-Contains $runScript "backup-local-demo.ps1" "Local backup restore drill script"
Assert-Contains $runScript "restore-local-demo.ps1" "Local backup restore drill script"
Assert-Contains $runScript "-ConfirmRestore" "Local backup restore drill script"

$runKubernetesScript = Read-RequiredFile $RunKubernetesBackupDrillScriptPath "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript '"create", "job"' "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript "--from=cronjob" "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript "osmu-mariadb-backup" "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript "osmu-minio-backup" "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript "latest-kubernetes-backup-drill.json" "Kubernetes backup drill script"
Assert-Contains $runKubernetesScript "PlanOnly" "Kubernetes backup drill script"

$prepareKubernetesRestoreNamespaceScript = Read-RequiredFile $PrepareKubernetesRestoreNamespaceScriptPath "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "ServerDryRunOnly" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "Apply" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "PlanOnly" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "osmu-restore-drill" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "latest-kubernetes-restore-namespace.json" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "namespace.yaml" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "backup.yaml" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "osmu-secret" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "osmu-backup-data" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "/spec/suspend" "Kubernetes restore namespace preparation script"
Assert-Contains $prepareKubernetesRestoreNamespaceScript "Secret values are not copied" "Kubernetes restore namespace preparation script"

$verifyKubernetesBackupArtifactsScript = Read-RequiredFile $VerifyKubernetesBackupArtifactsScriptPath "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "osmu-backup-artifact-preflight" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "latest-kubernetes-backup-artifacts.json" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "metadata.sql" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "metadata.sql.sha256" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "OSMU_BACKUP_ARTIFACT_PREFLIGHT_RESULT=passed" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "OSMU_BACKUP_ARTIFACT_OBJECT_COUNT" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "readOnly: true" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "AllowEmptyMinio" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "ServerDryRunOnly" "Kubernetes backup artifact preflight script"
Assert-Contains $verifyKubernetesBackupArtifactsScript "Secret values are not copied" "Kubernetes backup artifact preflight script"

$runKubernetesRestoreScript = Read-RequiredFile $RunKubernetesRestoreDrillScriptPath "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "ConfirmRestore" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "ServerDryRunOnly" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "AllowSourceNamespaceRestore" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "osmu-restore-drill" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "latest-kubernetes-restore-drill.json" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "restore-from-backup.example.yaml" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "osmu-backup-data" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "YYYYMMDDTHHMMSSZ" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "--dry-run=server" "Kubernetes restore drill script"
Assert-Contains $runKubernetesRestoreScript "Secret values are not copied" "Kubernetes restore drill script"

$runKubernetesDrDrillScript = Read-RequiredFile $RunKubernetesDrDrillScriptPath "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "run-kubernetes-backup-drill.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "prepare-kubernetes-restore-namespace.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "verify-kubernetes-backup-artifacts.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "run-kubernetes-restore-drill.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "latest-kubernetes-dr-drill.json" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "RunBackupDrill" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "BootstrapDrBucket" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "bootstrap-kubernetes-dr-bucket.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "latest-kubernetes-dr-bucket-bootstrap.json" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "DrBucketBootstrapRetentionMode" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "DrBucketBootstrapRetentionDuration" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "SkipDrBucketCreate" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "VerifyDrBucketImmutability" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "verify-kubernetes-dr-bucket-immutability.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "latest-kubernetes-dr-bucket-immutability.json" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "DrBucketRequiredRetentionMode" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferArtifacts" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "transfer-kubernetes-backup-artifacts.ps1" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "latest-kubernetes-backup-artifact-transfer.json" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferActiveDeadlineSeconds" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferTtlSecondsAfterFinished" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferCpuRequest" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferMemoryRequest" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferCpuLimit" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "TransferMemoryLimit" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "ServerDryRunOnly" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "ConfirmRestore" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "Backup artifacts must already be copied or snapshotted" "Kubernetes DR drill script"
Assert-Contains $runKubernetesDrDrillScript "Secret values are not copied" "Kubernetes DR drill script"

$bootstrapKubernetesDrBucketScript = Read-RequiredFile $BootstrapKubernetesDrBucketScriptPath "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "osmu-dr-transfer-secret" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "DR_S3_ENDPOINT" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "DR_S3_ACCESS_KEY" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "DR_S3_SECRET_KEY" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "DR_S3_BUCKET" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "mc mb --ignore-existing --with-lock" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "mc version enable" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "mc retention set --default" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "mc version info" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "mc retention info" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "OSMU_DR_BUCKET_BOOTSTRAP_RESULT=passed" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "RetentionMode" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "RetentionDuration" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "SkipBucketCreate" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "readOnlyRootFilesystem: true" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "automountServiceAccountToken: false" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "activeDeadlineSeconds: __ACTIVE_DEADLINE_SECONDS__" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "ttlSecondsAfterFinished: __TTL_SECONDS_AFTER_FINISHED__" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "resources:" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "latest-kubernetes-dr-bucket-bootstrap.json" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "Secret values are not copied" "Kubernetes DR bucket bootstrap script"
Assert-Contains $bootstrapKubernetesDrBucketScript "PlanOnly" "Kubernetes DR bucket bootstrap script"

$verifyKubernetesDrBucketImmutabilityScript = Read-RequiredFile $VerifyKubernetesDrBucketImmutabilityScriptPath "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "osmu-dr-transfer-secret" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "DR_S3_ENDPOINT" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "DR_S3_ACCESS_KEY" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "DR_S3_SECRET_KEY" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "DR_S3_BUCKET" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "mc version info" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "mc retention info" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "OSMU_DR_BUCKET_IMMUTABILITY_RESULT=passed" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "RequiredRetentionMode" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "GOVERNANCE_OR_COMPLIANCE" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "COMPLIANCE" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "readOnlyRootFilesystem: true" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "automountServiceAccountToken: false" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "activeDeadlineSeconds: __ACTIVE_DEADLINE_SECONDS__" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "ttlSecondsAfterFinished: __TTL_SECONDS_AFTER_FINISHED__" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "resources:" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "latest-kubernetes-dr-bucket-immutability.json" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "Secret values are not copied" "Kubernetes DR bucket immutability script"
Assert-Contains $verifyKubernetesDrBucketImmutabilityScript "PlanOnly" "Kubernetes DR bucket immutability script"

$transferKubernetesBackupArtifactsScript = Read-RequiredFile $TransferKubernetesBackupArtifactsScriptPath "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "ExportImport" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "osmu-dr-transfer-secret" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "DR_S3_ENDPOINT" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "DR_S3_ACCESS_KEY" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "DR_S3_SECRET_KEY" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "DR_S3_BUCKET" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "osmu-dr-transfer-egress" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "OSMU_BACKUP_TRANSFER_EXPORT_RESULT=passed" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "OSMU_BACKUP_TRANSFER_IMPORT_RESULT=passed" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "automountServiceAccountToken: false" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "allowPrivilegeEscalation: false" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "readOnlyRootFilesystem: true" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "MC_CONFIG_DIR" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "emptyDir: {}" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "activeDeadlineSeconds: __ACTIVE_DEADLINE_SECONDS__" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "ttlSecondsAfterFinished: __TTL_SECONDS_AFTER_FINISHED__" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "resources:" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "CpuRequest" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "MemoryRequest" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "CpuLimit" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "MemoryLimit" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "__BACKUP_READ_ONLY__" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript '$backupReadOnly = if ($Direction -eq "export") { "true" } else { "false" }' "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "latest-kubernetes-backup-artifact-transfer.json" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "Secret values are not copied" "Kubernetes backup artifact transfer script"
Assert-Contains $transferKubernetesBackupArtifactsScript "PlanOnly" "Kubernetes backup artifact transfer script"

$verifyKubernetesRestoreSmokeScript = Read-RequiredFile $VerifyKubernetesRestoreSmokeScriptPath "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "latest-kubernetes-restore-smoke.json" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "RunS3ClientSmoke" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "verify-s3-client-smoke.ps1" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "apiSmokePassed" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "s3ClientSmoke" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "Secret values are not written" "Kubernetes restore smoke script"
Assert-Contains $verifyKubernetesRestoreSmokeScript "PlanOnly" "Kubernetes restore smoke script"

$writeKubernetesDrEvidenceRequestScript = Read-RequiredFile $WriteKubernetesDrEvidenceRequestScriptPath "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "restore-drill-evidence" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "ConfirmSuccessfulRestore" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "PostRestoreSmokeVerified" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "SmokeEvidencePath" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "DrBucketBootstrapEvidencePath" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "DrBucketImmutabilityEvidencePath" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "Submit" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-dr-drill.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-backup-artifacts.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-dr-bucket-bootstrap.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-dr-bucket-immutability.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-restore-smoke.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "latest-kubernetes-dr-evidence-request.json" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "OSMU_BACKUP_ARTIFACT_OBJECT_COUNT" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "External DR bucket bootstrap did not pass." "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "External DR bucket immutability preflight did not pass." "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "required DR bucket bootstrap/immutability evidence" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "AUTO" "Kubernetes DR evidence request script"
Assert-Contains $writeKubernetesDrEvidenceRequestScript "SUCCESS requires" "Kubernetes DR evidence request script"

$finalizeKubernetesDrDrillScript = Read-RequiredFile $FinalizeKubernetesDrDrillScriptPath "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "run-kubernetes-dr-drill.ps1" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "verify-kubernetes-restore-smoke.ps1" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "write-kubernetes-dr-evidence-request.ps1" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "latest-kubernetes-dr-finalize.json" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "latest-kubernetes-dr-finalize.md" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "Mask-Arguments" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "<secret>" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "BootstrapDrBucket" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "VerifyDrBucketImmutability" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "TransferArtifacts" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "RunS3ClientSmoke" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "SubmitEvidence" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "PlanOnly" "Kubernetes DR finalize script"
Assert-Contains $finalizeKubernetesDrDrillScript "secretPolicy" "Kubernetes DR finalize script"

Write-Host "Backup restore drill draft verified."
Write-Host "Drill: $(Resolve-ProjectPath $DrillPath)"
