import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const sourceFiles = [
  './HomeView.vue',
  './LoginView.vue',
  '../components/admin/AccessKeyPanel.vue',
  '../components/admin/AdminPage.vue',
  '../components/admin/BillingChargebackPanel.vue',
  '../components/admin/BucketMetadataPanel.vue',
  '../components/admin/BucketPermissionsPanel.vue',
  '../components/admin/IdentityAdminPanel.vue',
  '../components/admin/LifecycleRulesPanel.vue',
  '../components/admin/ObjectSharePanel.vue',
  '../components/admin/QuotaPolicyPanel.vue',
  '../components/admin/StorageExpansionPanel.vue',
  '../components/audit/AuditPage.vue',
  '../components/dashboard/DashboardPage.vue',
  '../components/dashboard/DashboardActivityPanel.vue',
  '../components/dashboard/DashboardQuotaPanel.vue',
  '../components/dashboard/DashboardSharePanel.vue',
  '../components/developer/DeveloperPage.vue',
  '../components/objects/ObjectPage.vue',
  '../components/storage/StoragePage.vue',
  '../assets/main.css',
  '../router/index.js',
  '../utils/accessKeys.js',
]
const dashboardSource = sourceFiles
  .map((path) => readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8'))
  .join('\n')

test('HomeView exposes stable selectors for browser E2E flows', () => {
  const requiredTestIds = [
    'status-list',
    'login-form',
    'login-id-input',
    'login-password-input',
    'login-password-toggle',
    'login-auto-login-checkbox',
    'login-remember-id-checkbox',
    'login-role-admin',
    'login-role-developer',
    'login-mode-admin',
    'login-mode-developer',
    'login-info-alert',
    'login-submit-button',
    'refresh-button',
    'logout-button',
    'error-alert',
    'admin-action-remediation-panel',
    'admin-action-remediation-title',
    'admin-action-remediation-detail',
    'admin-action-remediation-code',
    'admin-action-remediation-steps',
    'admin-action-remediation-primary',
    'busy-alert',
    'status-alert',
    'metrics-grid',
    'dashboard-storage-backend-status',
    'dashboard-config-panel',
    'dashboard-edit-mode-toggle',
    'dashboard-view-mode-summary',
    'dashboard-loading-state',
    'dashboard-error-state',
    'dashboard-retry-button',
    'dashboard-empty-state',
    'dashboard-widget-reset-button',
    'dashboard-layout-sync',
    'dashboard-layout-preset-select',
    'dashboard-layout-preset-apply-button',
    'dashboard-layout-preset-delete-button',
    'dashboard-layout-preset-name-input',
    'dashboard-layout-preset-description-input',
    'dashboard-layout-preset-save-button',
    'dashboard-layout-preset-update-button',
    'dashboard-layout-preset-export-button',
    'dashboard-layout-preset-import-label',
    'dashboard-layout-preset-import-input',
    'dashboard-layout-preset-bundle-export-button',
    'dashboard-layout-preset-bundle-import-label',
    'dashboard-layout-preset-bundle-import-input',
    'dashboard-layout-default-panel',
    'dashboard-layout-default-form',
    'dashboard-layout-default-target-type',
    'dashboard-layout-default-target-id',
    'dashboard-layout-default-preset-id',
    'dashboard-layout-default-save-button',
    'dashboard-layout-default-list',
    'dashboard-layout-default-delete-button',
    'dashboard-widget-select',
    'dashboard-widget-add-button',
    'dashboard-widget-catalog',
    'dashboard-widget-catalog-button',
    'dashboard-widget-sections',
    'dashboard-widget-list',
    'dashboard-widget-drag-handle',
    'dashboard-widget-move-up-button',
    'dashboard-widget-move-down-button',
    'dashboard-widget-size-button',
    'dashboard-widget-section-control',
    'dashboard-widget-section-select',
    'dashboard-widget-section-toggle-button',
    'dashboard-widget-section-move-up-button',
    'dashboard-widget-section-move-down-button',
    'dashboard-widget-access-mode',
    'dashboard-widget-option-control',
    'dashboard-widget-option-select',
    'dashboard-widget-toggle-button',
    'dashboard-widget-remove-button',
    'dashboard-data-flow-ops',
    'data-flow-monitoring-panel',
    'data-flow-filter-form',
    'data-flow-filter-from',
    'data-flow-filter-to',
    'data-flow-filter-bucket',
    'data-flow-filter-actor',
    'data-flow-filter-source',
    'data-flow-filter-operation',
    'data-flow-filter-status',
    'data-flow-filter-limit',
    'data-flow-filter-months',
    'data-flow-filter-monthly-materialized',
    'data-flow-refresh-button',
    'data-flow-export-button',
    'data-flow-daily-rollup-export-button',
    'data-flow-daily-rollup-materialize-button',
    'data-flow-daily-rollup-materialized-load-button',
    'data-flow-daily-rollup-materialized-export-button',
    'data-flow-monthly-rollup-load-button',
    'data-flow-monthly-rollup-export-button',
    'data-flow-monthly-rollup-materialize-button',
    'data-flow-monthly-rollup-materialized-load-button',
    'data-flow-monthly-rollup-materialized-export-button',
    'data-flow-retention-panel',
    'data-flow-retention-event-days',
    'data-flow-retention-rollup-days',
    'data-flow-retention-monthly-rollup-days',
    'data-flow-retention-deleted',
    'data-flow-retention-failed',
    'data-flow-retention-refresh-button',
    'data-flow-retention-run-button',
    'data-flow-storage-panel',
    'data-flow-storage-status',
    'data-flow-storage-rows',
    'data-flow-storage-window',
    'data-flow-reset-button',
    'data-flow-total-bytes',
    'data-flow-failed-cancelled',
    'data-flow-trend-chart',
    'data-flow-daily-rollup',
    'data-flow-daily-rollup-row',
    'data-flow-daily-rollup-bytes',
    'data-flow-monthly-rollup',
    'data-flow-monthly-rollup-row',
    'data-flow-monthly-rollup-bytes',
    'data-flow-top-buckets',
    'data-flow-recent-events',
    'backup-status-panel',
    'backup-restore-evidence',
    'dashboard-activity-panel',
    'dashboard-share-panel',
    'dashboard-quota-panel',
    'dashboard-readiness-panel',
    'dashboard-readiness-refresh-button',
    'readiness-operations-summary',
    'readiness-source-summary',
    'readiness-source-pending-categories',
    'readiness-evidence-plan-summary',
    'readiness-evidence-plan-actions',
    'readiness-evidence-plan-command-copy-button',
    'readiness-evidence-plan-dispatch-link',
    'readiness-evidence-invocation-item-summary',
    'readiness-evidence-invocation-summary',
    'readiness-evidence-invocation-actions',
    'readiness-evidence-invocation-command-copy-button',
    'readiness-workflow-run-id-item-summary',
    'readiness-workflow-run-id-summary',
    'readiness-workflow-run-id-action-orders',
    'readiness-workflow-run-id-json-directory',
    'readiness-workflow-run-id-security-finalizer',
    'readiness-workflow-run-id-security-finalizer-note',
    'readiness-workflow-run-id-json-directory-command-copy-button',
    'readiness-workflow-run-id-github-api-command-copy-button',
    'readiness-workflow-run-id-json-path',
    'readiness-workflow-run-id-actions',
    'readiness-workflow-run-id-query-copy-button',
    'readiness-workflow-run-id-runs-link',
    'readiness-workflow-run-id-artifact-plan-command-copy-button',
    'readiness-workflow-run-id-security-command-copy-button',
    'readiness-artifact-collection-item-summary',
    'readiness-artifact-collection-summary',
    'readiness-artifact-collection-action-orders',
    'readiness-artifact-collection-actions',
    'readiness-artifact-collection-security-missing-inputs',
    'readiness-artifact-collection-security-inputs',
    'readiness-artifact-finalizer-command-copy-button',
    'readiness-artifact-local-import-command-copy-button',
    'readiness-artifact-download-command-copy-button',
    'readiness-artifact-minio-cors-note',
    'readiness-artifact-minio-cors-note-copy-button',
    'readiness-evidence-handoff-item-summary',
    'readiness-evidence-handoff-summary',
    'readiness-evidence-handoff-command-copy-button',
    'readiness-evidence-handoff-next-note',
    'readiness-evidence-handoff-scope-summary',
    'readiness-evidence-handoff-run-id-query',
    'readiness-evidence-handoff-post-dispatch-commands',
    'readiness-evidence-handoff-post-dispatch-command-copy-button',
    'readiness-evidence-handoff-dispatch-link',
    'readiness-evidence-handoff-stages',
    'readiness-evidence-handoff-stage-command-copy-button',
    'readiness-dispatch-preflight-template-dispatch-link',
    'readiness-dispatch-preflight-workflow-dispatch-link',
    'readiness-data-flow-storage-plan-item-summary',
    'readiness-data-flow-storage-plan-summary',
    'readiness-data-flow-query-plan-evidence-summary',
    'readiness-data-flow-query-plan-evidence-detail',
    'readiness-data-flow-query-plan-failed-checks',
    'readiness-data-flow-storage-plan-checks',
    'readiness-storage-telemetry-item-summary',
    'readiness-storage-telemetry-summary',
    'readiness-support-escalation-handoff-summary',
    'readiness-support-escalation-handoff-review-window',
    'readiness-support-escalation-handoff-evidence-refs',
    'readiness-support-escalation-handoff-documents',
    'readiness-support-escalation-handoff-confirmations',
    'readiness-support-escalation-handoff-checks',
    'readiness-convergence-item-summary',
    'readiness-convergence-summary',
    'readiness-convergence-handoff-freshness',
    'readiness-convergence-run-id-query',
    'readiness-convergence-command-copy-button',
    'readiness-convergence-commands',
    'readiness-convergence-command-list-copy-button',
    'readiness-convergence-dispatch-link',
    'readiness-operations-filter-button',
    'dashboard-access-key-total',
    'dashboard-access-key-risk',
    'execution-log-retention-panel',
    'execution-log-retention-pending',
    'execution-log-retention-run-button',
    'storage-expansion-dashboard-panel',
    'storage-expansion-dashboard-open',
    'storage-expansion-dashboard-issues',
    'storage-expansion-dashboard-list',
    'storage-expansion-dashboard-executions',
    'readiness-category-filter',
    'readiness-severity-filter',
    'bucket-panel',
    'bucket-create-form',
    'bucket-name-input',
    'bucket-quota-input',
    'bucket-owner-type-select',
    'bucket-create-button',
    'bucket-table',
    'bucket-row-name',
    'bucket-row-usage',
    'bucket-row-object-count',
    'bucket-sync-button',
    'bucket-delete-button',
    'storage-profile-panel',
    'storage-profile-select',
    'storage-profile-reason-input',
    'storage-profile-request-button',
    'storage-profile-request-table',
    'storage-profile-request-row',
    'storage-profile-request-status',
    'object-panel',
    'object-empty-state',
    'object-filter-form',
    'object-prefix-input',
    'object-prefix-breadcrumb',
    'object-prefix-breadcrumb-button',
    'object-prefix-row',
    'object-prefix-open-button',
    'object-search-input',
    'object-tag-filter-input',
    'object-list-limit-select',
    'object-search-button',
    'object-next-button',
    'object-download-button',
    'object-upload-form',
    'object-key-input',
    'object-tags-input',
    'object-tag-form',
    'object-tag-key-input',
    'object-tag-value-input',
    'object-tag-save-button',
    'object-tag-reset-button',
    'object-tag-edit-button',
    'object-file-input',
    'object-upload-button',
    'object-upload-cancel-button',
    'object-upload-pause-button',
    'object-upload-retry-button',
    'object-upload-progress',
    'object-storage-remediation-panel',
    'object-storage-remediation-title',
    'object-storage-remediation-code',
    'object-storage-remediation-steps',
    'object-presigned-upload-url-button',
    'object-presigned-upload-complete-button',
    'object-presigned-url',
    'object-multipart-resume-panel',
    'object-multipart-resume-row',
    'object-multipart-resume-button',
    'object-multipart-resume-delete-button',
    'object-table',
    'developer-page',
    'developer-onboarding-panel',
    'developer-onboarding-progress',
    'developer-onboarding-step',
    'developer-s3-endpoint-panel',
    'developer-s3-endpoint',
    'developer-s3-region',
    'developer-s3-signature',
    'developer-s3-virtual-host',
    'developer-selected-bucket',
    'developer-client-snippets-panel',
    'developer-client-aws-cli',
    'developer-client-s3fs',
    'developer-client-goofys',
    'developer-sdk-javascript',
    'developer-sdk-python',
    'developer-sdk-java',
    'developer-client-compatibility-panel',
    'developer-client-compatibility-region',
    'developer-client-compatibility-row',
    'developer-client-compatibility-status',
    'access-key-panel',
    'access-key-form',
    'access-key-name-input',
    'access-key-expires-at-input',
    'access-key-bucket-select',
    'access-key-permission-read',
    'access-key-permission-write',
    'access-key-permission-delete',
    'access-key-permission-admin',
    'access-key-scope-add-button',
    'access-key-create-button',
    'access-key-scope-rule',
    'access-key-scope-list',
    'access-key-scope-remove-button',
    'access-key-secret-warning',
    'access-key-secret-box',
    'access-key-filter-row',
    'access-key-usage-analysis',
    'access-key-usage-total',
    'access-key-usage-used-keys',
    'access-key-usage-latest',
    'access-key-usage-top-key',
    'access-key-filter-all',
    'access-key-filter-active',
    'access-key-filter-expired',
    'access-key-filter-expiring',
    'access-key-filter-unused',
    'access-key-filter-inactive',
    'access-key-filter-empty',
    'access-key-cleanup-row',
    'access-key-cleanup-summary',
    'access-key-cleanup-export-button',
    'access-key-cleanup-button',
    'access-key-cleanup-preview',
    'access-key-cleanup-candidate',
    'access-key-cleanup-candidate-checkbox',
    'access-key-list',
    'access-key-expires-at',
    'access-key-rotation-grace',
    'access-key-last-used',
    'access-key-usage-count',
    'access-key-action-hint',
    'access-key-rotate-button',
    'access-key-delete-button',
    'object-detail-button',
    'object-detail-panel',
    'object-metadata-sync-status',
    'object-metadata-row-state',
    'object-share-link-button',
    'object-share-link-url',
    'object-share-link-password-input',
    'object-share-link-ip-allowlist-input',
    'object-share-link-panel',
    'object-share-link-cleanup-button',
    'object-share-policy-panel',
    'object-share-policy-form',
    'object-share-policy-require-password',
    'object-share-policy-require-ip',
    'object-share-policy-max-expiry',
    'object-share-policy-max-downloads',
    'object-share-policy-save-button',
    'object-share-analytics-panel',
    'object-share-analytics-refresh-button',
    'object-share-analytics-filter-form',
    'object-share-analytics-bucket-filter',
    'object-share-analytics-status-filter',
    'object-share-analytics-limit-filter',
    'object-share-analytics-metrics',
    'object-share-analytics-list',
    'bucket-lifecycle-panel',
    'bucket-lifecycle-load-button',
    'bucket-lifecycle-save-button',
    'bucket-lifecycle-delete-button',
    'bucket-lifecycle-textarea',
    'bucket-lifecycle-rule-count',
    'bucket-lifecycle-saved-count',
    'bucket-tags-panel',
    'bucket-tags-load-button',
    'bucket-tags-save-button',
    'bucket-tags-delete-button',
    'bucket-tags-input',
    'bucket-tags-count',
    'bucket-tags-saved-count',
    'admin-bucket-empty-state',
    'admin-role-empty-state',
    'admin-role-restricted-panel-list',
    'admin-approval-workflow-panel',
    'admin-approval-workflow-metrics',
    'admin-approval-workflow-list',
    'admin-approval-workflow-item-title',
    'admin-approval-profile-approve-button',
    'admin-approval-profile-reject-button',
    'admin-approval-profile-apply-button',
    'admin-approval-expansion-approve-button',
    'admin-approval-expansion-plan-button',
    'admin-approval-expansion-apply-button',
    'admin-approval-expansion-reject-button',
    'admin-storage-profile-panel',
    'admin-storage-profile-request-table',
    'admin-storage-profile-request-row',
    'admin-storage-profile-request-status',
    'admin-storage-profile-approve-button',
    'admin-storage-profile-reject-button',
    'admin-storage-profile-apply-button',
    'storage-profile-admin-note-input',
    'admin-security-audit-policy-panel',
    'admin-security-audit-open-audit-link',
    'admin-security-policy-metrics',
    'admin-security-policy-list',
    'admin-security-policy-row',
    'admin-security-policy-row-title',
    'admin-security-policy-row-status',
    'quota-policy-panel',
    'quota-policy-form',
    'quota-policy-target-type',
    'quota-policy-target-search',
    'quota-policy-target-id',
    'quota-policy-quota-input',
    'quota-policy-reason-input',
    'quota-policy-save-button',
    'quota-policy-cancel-edit-button',
    'quota-policy-edit-button',
    'quota-policy-history-list',
    'billing-chargeback-panel',
    'chargeback-scan-count',
    'chargeback-filter-form',
    'chargeback-filter-from',
    'chargeback-filter-to',
    'chargeback-currency-input',
    'chargeback-storage-rate-input',
    'chargeback-ingress-rate-input',
    'chargeback-egress-rate-input',
    'chargeback-internal-rate-input',
    'chargeback-operation-rate-input',
    'chargeback-warning-threshold-input',
    'chargeback-critical-threshold-input',
    'chargeback-notification-channel-input',
    'chargeback-notification-target-input',
    'chargeback-event-limit-input',
    'chargeback-refresh-button',
    'chargeback-reset-button',
    'chargeback-export-button',
    'chargeback-daily-rollup-export-button',
    'chargeback-invoice-draft-export-button',
    'chargeback-invoice-draft-save-button',
    'chargeback-notification-queue-button',
    'chargeback-save-policy-button',
    'billing-pricing-policy-proposal-button',
    'chargeback-metrics',
    'chargeback-total-cost',
    'chargeback-total-used',
    'chargeback-total-operations',
    'chargeback-rate-list',
    'chargeback-daily-rollup-metrics',
    'chargeback-daily-rollup-count',
    'chargeback-daily-rollup-total',
    'chargeback-daily-rollup-source',
    'chargeback-daily-rollup-list',
    'chargeback-daily-rollup-row',
    'billing-pricing-policy-proposal-metrics',
    'billing-pricing-policy-proposal-count',
    'billing-pricing-policy-proposal-status',
    'billing-pricing-policy-proposal-updated',
    'billing-pricing-policy-proposal-list',
    'billing-pricing-policy-proposal-row',
    'billing-pricing-policy-proposal-approve-button',
    'billing-pricing-policy-price-list-approve-button',
    'chargeback-alert-metrics',
    'chargeback-alert-count',
    'chargeback-warning-count',
    'chargeback-critical-count',
    'chargeback-alert-list',
    'chargeback-alert-row',
    'chargeback-notification-metrics',
    'chargeback-payment-provider-input',
    'chargeback-payment-target-input',
    'chargeback-notification-count',
    'chargeback-notification-channel',
    'chargeback-notification-mode',
    'chargeback-notification-list',
    'chargeback-notification-row',
    'chargeback-notification-outbox-metrics',
    'chargeback-notification-outbox-count',
    'chargeback-notification-outbox-status',
    'chargeback-notification-outbox-updated',
    'chargeback-notification-outbox-list',
    'chargeback-notification-outbox-row',
    'chargeback-notification-adapter-send-button',
    'chargeback-notification-adapter-block-button',
    'chargeback-notification-adapter-retry-button',
    'chargeback-adapter-retry-worker-metrics',
    'chargeback-adapter-retry-worker-notifications',
    'chargeback-adapter-retry-worker-payments',
    'chargeback-adapter-retry-worker-updated',
    'chargeback-adapter-retry-worker-refresh-button',
    'chargeback-adapter-retry-worker-run-button',
    'chargeback-adapter-retry-worker-list',
    'chargeback-adapter-retry-worker-row',
    'chargeback-invoice-draft-metrics',
    'chargeback-invoice-draft-count',
    'chargeback-invoice-draft-status',
    'chargeback-invoice-draft-updated',
    'chargeback-invoice-draft-list',
    'chargeback-invoice-draft-row',
    'chargeback-invoice-draft-approve-button',
    'chargeback-invoice-draft-finalize-button',
    'chargeback-final-invoice-metrics',
    'chargeback-final-invoice-count',
    'chargeback-final-invoice-status',
    'chargeback-final-invoice-payment-status',
    'chargeback-final-invoice-list',
    'chargeback-final-invoice-row',
    'chargeback-final-invoice-payment-request-button',
    'chargeback-payment-handoff-button',
    'chargeback-final-invoice-payment-record-button',
    'chargeback-payment-handoff-metrics',
    'chargeback-payment-handoff-count',
    'chargeback-payment-handoff-status',
    'chargeback-payment-handoff-provider',
    'chargeback-payment-adapter-readiness-metrics',
    'chargeback-payment-adapter-profile-count',
    'chargeback-payment-adapter-webhook-ready-count',
    'chargeback-payment-adapter-native-status',
    'chargeback-payment-adapter-readiness-list',
    'chargeback-payment-adapter-readiness-row',
    'chargeback-payment-handoff-list',
    'chargeback-payment-handoff-row',
    'chargeback-payment-handoff-adapter-send-button',
    'chargeback-payment-handoff-adapter-block-button',
    'chargeback-payment-handoff-adapter-retry-button',
    'chargeback-organization-table',
    'chargeback-organization-row',
    'storage-expansion-panel',
    'storage-expansion-form',
    'storage-expansion-capacity-input',
    'storage-expansion-server-count-input',
    'storage-expansion-volumes-input',
    'storage-expansion-reason-input',
    'storage-expansion-create-button',
    'storage-expansion-runner-preflight-panel',
    'storage-expansion-runner-preflight-refresh-button',
    'storage-expansion-runner-preflight-list',
    'storage-expansion-runner-preflight-remediation',
    'storage-expansion-list',
    'storage-expansion-apply-evidence-input',
    'storage-expansion-preview-button',
    'storage-expansion-execution-plan-button',
    'storage-expansion-gitops-plan-button',
    'storage-expansion-execution-history-button',
    'storage-expansion-preview-panel',
    'storage-expansion-tenant-yaml',
    'storage-expansion-helm-yaml',
    'storage-expansion-download-tenant-button',
    'storage-expansion-download-helm-button',
    'storage-expansion-download-bundle-button',
    'storage-expansion-execution-plan-panel',
    'storage-expansion-execution-digest',
    'storage-expansion-preflight-list',
    'storage-expansion-execution-commands',
    'storage-expansion-dry-run-type-select',
    'storage-expansion-dry-run-result-select',
    'storage-expansion-dry-run-url-input',
    'storage-expansion-dry-run-notes-input',
    'storage-expansion-dry-run-record-button',
    'storage-expansion-dry-run-runner-button',
    'storage-expansion-apply-run-type-select',
    'storage-expansion-apply-runner-button',
    'storage-expansion-dry-run-output-input',
    'storage-expansion-gitops-plan-panel',
    'storage-expansion-gitops-branch',
    'storage-expansion-gitops-commit',
    'storage-expansion-gitops-files',
    'storage-expansion-gitops-review-list',
    'storage-expansion-gitops-pr-body',
    'storage-expansion-gitops-pr-url-input',
    'storage-expansion-gitops-merge-sha-input',
    'storage-expansion-gitops-pipeline-url-input',
    'storage-expansion-gitops-notes-input',
    'storage-expansion-gitops-pr-record-button',
    'storage-expansion-gitops-pr-runner-button',
    'storage-expansion-gitops-bundle-download-button',
    'storage-expansion-execution-history-panel',
    'storage-expansion-execution-record-form',
    'storage-expansion-execution-request-id-input',
    'storage-expansion-execution-type-select',
    'storage-expansion-execution-result-select',
    'storage-expansion-execution-command-input',
    'storage-expansion-execution-artifact-input',
    'storage-expansion-execution-url-input',
    'storage-expansion-execution-notes-input',
    'storage-expansion-rollback-type-select',
    'storage-expansion-rollback-revision-input',
    'storage-expansion-rollback-target-input',
    'storage-expansion-rollback-runner-button',
    'storage-expansion-execution-output-input',
    'storage-expansion-execution-record-button',
    'storage-expansion-execution-history-list',
    'storage-expansion-execution-failure-reason',
    'storage-expansion-execution-apply-button',
    'storage-expansion-approve-button',
    'storage-expansion-apply-button',
    'storage-expansion-reject-button',
    'audit-panel',
    'audit-empty-state',
    'audit-filter-form',
    'audit-event-type-input',
    'audit-actor-id-input',
    'audit-request-id-input',
    'audit-target-type-input',
    'audit-target-id-input',
    'audit-result-select',
    'audit-from-input',
    'audit-to-input',
    'audit-limit-input',
    'audit-search-button',
    'audit-export-button',
    'audit-reset-button',
    'audit-list',
    'audit-entry',
    'audit-next-button',
    'confirm-backdrop',
    'confirm-dialog',
    'confirm-cancel-button',
    'confirm-submit-button',
  ]

  for (const testId of requiredTestIds) {
    assert.match(dashboardSource, new RegExp(`data-testid="${testId}"`), `Missing data-testid="${testId}"`)
  }

  assert.match(dashboardSource, /:data-testid="part\.match \? 'object-key-match' : undefined"/)
  assert.match(dashboardSource, /:data-testid="`bucket-row-\$\{bucket\.name\}`"/)
  assert.match(dashboardSource, /:data-testid="`dashboard-widget-\$\{widget\.id\}`"/)
  assert.match(dashboardSource, /:data-testid="`dashboard-widget-config-\$\{widget\.id\}`"/)
  assert.match(dashboardSource, /:data-testid="`dashboard-widget-section-\$\{section\.id\}`"/)
  assert.match(dashboardSource, /:data-testid="`dashboard-widget-category-\$\{categoryTestId\(group\.category\)\}`"/)
  assert.match(dashboardSource, /uploadState = reactive\(\{[\s\S]*errorCode: ''[\s\S]*errorStatus: 0[\s\S]*requestId: ''/)
  assert.match(dashboardSource, /uploadStorageRemediation/)
  assert.match(dashboardSource, /STORAGE_ERROR/)
  assert.match(dashboardSource, /object-storage-remediation-panel/)
  assert.match(dashboardSource, /availableDashboardWidgetGroups/)
  assert.match(dashboardSource, /visibleDashboardWidgetSections/)
  assert.match(dashboardSource, /addDashboardWidgetById/)
  assert.match(dashboardSource, /id: 'runtime'/)
  assert.match(dashboardSource, /id: 'readiness'/)
  assert.match(dashboardSource, /id: 'access-keys'/)
  assert.match(dashboardSource, /id: 'identity'/)
  assert.match(dashboardSource, /id: 'lifecycle'/)
  assert.match(dashboardSource, /widget\.id === 'access-keys'/)
  assert.match(dashboardSource, /summarizeAccessKeys/)
  assert.match(dashboardSource, /widget\.id === 'identity'/)
  assert.match(dashboardSource, /widget\.id === 'lifecycle'/)
  assert.match(dashboardSource, /id: 'execution-retention', title: 'Execution Log Retention'/)
  assert.match(dashboardSource, /widget\.id === 'execution-retention'/)
  assert.match(dashboardSource, /id: 'storage-expansion', title: 'Storage Expansion'/)
  assert.match(dashboardSource, /widget\.id === 'storage-expansion'/)
  assert.match(dashboardSource, /getDashboardLayout/)
  assert.match(dashboardSource, /getDashboardLayoutPresets/)
  assert.match(dashboardSource, /saveDashboardLayout/)
  assert.match(dashboardSource, /applyDashboardLayoutPreset/)
  assert.match(dashboardSource, /createDashboardLayoutPreset/)
  assert.match(dashboardSource, /updateDashboardLayoutPreset/)
  assert.match(dashboardSource, /exportDashboardLayoutPreset/)
  assert.match(dashboardSource, /importDashboardLayoutPreset/)
  assert.match(dashboardSource, /exportDashboardLayoutPresetBundle/)
  assert.match(dashboardSource, /importDashboardLayoutPresetBundle/)
  assert.match(dashboardSource, /deleteDashboardLayoutPreset/)
  assert.match(dashboardSource, /getDashboardLayoutDefaults/)
  assert.match(dashboardSource, /saveDashboardLayoutDefault/)
  assert.match(dashboardSource, /deleteDashboardLayoutDefault/)
  assert.match(dashboardSource, /deleteDashboardLayout/)
  assert.match(dashboardSource, /dashboardLayoutSyncLabel/)
  assert.match(dashboardSource, /dashboardEditMode/)
  assert.match(dashboardSource, /dashboardLoadState/)
  assert.match(dashboardSource, /toggleDashboardEditMode/)
  assert.match(dashboardSource, /retry-dashboard-load/)
  assert.match(dashboardSource, /DASHBOARD_LAYOUT_SCHEMA_VERSION/)
  assert.match(dashboardSource, /dashboardLayoutPresets/)
  assert.match(dashboardSource, /dashboardLayoutDefaults/)
  assert.match(dashboardSource, /dashboardLayoutDefaultForm/)
  assert.match(dashboardSource, /handleApplyDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleCreateDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleUpdateDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleExportDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleImportDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleExportDashboardLayoutPresetBundle/)
  assert.match(dashboardSource, /handleImportDashboardLayoutPresetBundle/)
  assert.match(dashboardSource, /handleDeleteDashboardLayoutPreset/)
  assert.match(dashboardSource, /handleSaveDashboardLayoutDefault/)
  assert.match(dashboardSource, /handleDeleteDashboardLayoutDefault/)
  assert.match(dashboardSource, /DEFAULT_PRESET/)
  assert.match(dashboardSource, /normalizeDashboardPresetImportPayload/)
  assert.match(dashboardSource, /normalizeDashboardPresetBundleImportPayload/)
  assert.match(dashboardSource, /sanitizeDashboardWidgets/)
  assert.match(dashboardSource, /dashboardWidgetCatalogForCurrentRole/)
  assert.match(dashboardSource, /dashboardWidgetAllowedRoles\(widget\)\.includes\(role\)/)
  assert.match(dashboardSource, /!dashboardWidgetCatalogForRole\.value\.some\(\(widget\) => widget\.id === dashboardWidgetToAdd\.value\)/)
  assert.match(dashboardSource, /sanitizeDashboardWidgetOptions/)
  assert.match(dashboardSource, /dashboardWidgetSizeLabel/)
  assert.match(dashboardSource, /dashboardWidgetToneLabel/)
  assert.match(dashboardSource, /dashboardWidgetRefreshIntervals/)
  assert.match(dashboardSource, /dashboardWidgetRefreshIntervalLabel/)
  assert.match(dashboardSource, /dashboardWidgetAllowedRoles/)
  assert.match(dashboardSource, /dashboardWidgetAccessMode/)
  assert.match(dashboardSource, /dashboardWidgetAccessLabel/)
  assert.match(dashboardSource, /dashboardWidgetConfigOptions/)
  assert.match(dashboardSource, /dashboardWidgetOptionValue/)
  assert.match(dashboardSource, /dashboardAutoRefreshIntervalMs/)
  assert.match(dashboardSource, /refreshDashboardAutoData/)
  assert.match(dashboardSource, /refreshInterval/)
  assert.match(dashboardSource, /dashboardWidgetSectionLabel/)
  assert.match(dashboardSource, /sanitizeDashboardSections/)
  assert.match(dashboardSource, /dashboardSectionCollapsed/)
  assert.match(dashboardSource, /toggleDashboardSection/)
  assert.match(dashboardSource, /updateDashboardWidgetSection/)
  assert.match(dashboardSource, /moveDashboardWidgetSection/)
  assert.match(dashboardSource, /updateDashboardWidgetOption/)
  assert.match(dashboardSource, /toggleDashboardWidgetSize/)
  assert.match(dashboardSource, /startDashboardWidgetDrag/)
  assert.match(dashboardSource, /dropDashboardWidget/)
  assert.match(dashboardSource, /reorderDashboardWidget/)
  assert.match(dashboardSource, /is-drop-target/)
  assert.match(dashboardSource, /draggable/)
  assert.match(dashboardSource, /dashboard-widget-wide/)
  assert.match(dashboardSource, /dashboard-widget-tone-focus/)
  assert.match(dashboardSource, /dashboard-widget-tone-muted/)
  assert.match(dashboardSource, /runtimeReadinessLabel/)
  assert.match(dashboardSource, /dashboardReadiness/)
  assert.match(dashboardSource, /targetPanel/)
  assert.match(dashboardSource, /generatedAt/)
  assert.match(dashboardSource, /Last Check/)
  assert.match(dashboardSource, /readiness-category/)
  assert.match(dashboardSource, /readinessCategoryFilter/)
  assert.match(dashboardSource, /readinessCategoryOptions/)
  assert.match(dashboardSource, /readinessSeverityFilter/)
  assert.match(dashboardSource, /readinessSeverityOptions/)
  assert.match(dashboardSource, /visibleReadinessItems/)
  assert.doesNotMatch(dashboardSource, /visibleReadinessItems\.slice\(0, 6\)/)
  assert.match(dashboardSource, /visibleReadinessItems\.length === 0/)
  assert.match(dashboardSource, /item\.actionLabel \|\|/)
  assert.match(dashboardSource, /operationsReadinessItems/)
  assert.match(dashboardSource, /operationsReadinessPrimaryMessage/)
  assert.match(dashboardSource, /operationsEvidencePlanItem/)
  assert.match(dashboardSource, /operationsEvidenceInvocationItem/)
  assert.match(dashboardSource, /operationsInvocationUnblockPlanItem/)
  assert.match(dashboardSource, /operationsDispatchPreflightItem/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanItem/)
  assert.match(dashboardSource, /operationsArtifactCollectionPlanItem/)
  assert.match(dashboardSource, /operationsReadinessArtifactImportItem/)
  assert.match(dashboardSource, /operationsReadinessFinalizeItem/)
  assert.match(dashboardSource, /operationsEvidenceHandoffItem/)
  assert.match(dashboardSource, /operationsHandoffPackageItem/)
  assert.match(dashboardSource, /dataFlowStoragePlanItem/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetItem/)
  assert.match(dashboardSource, /operationsReadinessConvergenceItem/)
  assert.match(dashboardSource, /operationsReadinessConvergence\.finalizerGapCount/)
  assert.match(dashboardSource, /kubernetesOperationsReportSyncItem/)
  assert.match(dashboardSource, /operationsEvidencePlanActions/)
  assert.doesNotMatch(dashboardSource, /operationsEvidencePlanActions\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsEvidencePlanSourceSummaryText/)
  assert.match(dashboardSource, /operationsEvidencePlanRemediationCoverageText/)
  assert.match(dashboardSource, /sourceTotalCount/)
  assert.match(dashboardSource, /sourcePendingRemediationActionCount/)
  assert.match(dashboardSource, /operationsEvidencePlanSummaryText/)
  assert.match(dashboardSource, /operationsEvidencePlanPendingCategorySummaryText/)
  assert.match(dashboardSource, /readiness-evidence-plan-source-summary/)
  assert.match(dashboardSource, /readiness-evidence-plan-remediation-coverage/)
  assert.match(dashboardSource, /readiness-evidence-plan-pending-categories/)
  assert.match(dashboardSource, /operationsReadinessSummary/)
  assert.match(dashboardSource, /readiness-evidence-plan-action-summary/)
  assert.match(dashboardSource, /operationsEvidenceInvocationSourceSummaryText/)
  assert.match(dashboardSource, /operationsEvidenceInvocationActionOrderSummary/)
  assert.match(dashboardSource, /readiness-evidence-invocation-action-orders/)
  assert.match(dashboardSource, /readiness-evidence-invocation-source-summary/)
  assert.match(dashboardSource, /operationsInvocationUnblockSourceSummaryText/)
  assert.match(dashboardSource, /readiness-invocation-unblock-source-summary/)
  assert.match(dashboardSource, /operationsEvidenceInvocation/)
  assert.match(dashboardSource, /invalidPlaceholders/)
  assert.match(dashboardSource, /operationsEvidenceInvocationActions/)
  assert.doesNotMatch(dashboardSource, /operationsEvidenceInvocationActions\.slice\(0, 3\)/)
  assert.match(dashboardSource, /\{\{ action\.order \}\}\. \{\{ action\.name \}\} - \{\{ action\.status \|\| 'planned' \}\}/)
  assert.match(dashboardSource, /operationsInvocationUnblockPlan/)
  assert.match(dashboardSource, /operationsInvocationUnblockActions/)
  assert.doesNotMatch(dashboardSource, /operationsInvocationUnblockActions\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsInvocationUnblockGroupRows/)
  assert.match(dashboardSource, /readiness-invocation-unblock-groups/)
  assert.match(dashboardSource, /confirmationGroupCount/)
  assert.match(dashboardSource, /requiredInputGroupCount/)
  assert.match(dashboardSource, /requiredInputGroups/)
  assert.match(dashboardSource, /operationsDispatchPreflight/)
  assert.match(dashboardSource, /unsafeInputCount/)
  assert.match(dashboardSource, /invalidInputCount/)
  assert.match(dashboardSource, /validValue/)
  assert.match(dashboardSource, /operationsDispatchPreflightSelectedOrderSummary/)
  assert.match(dashboardSource, /operationsDispatchPreflightReadyOrderSummary/)
  assert.match(dashboardSource, /operationsDispatchPreflightBlockedOrderSummary/)
  assert.match(dashboardSource, /readySubsetPlanCommand/)
  assert.match(dashboardSource, /readySubsetExecuteCommand/)
  assert.match(dashboardSource, /apiExecuteCommand/)
  assert.match(dashboardSource, /readySubsetApiExecuteCommand/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-ready-subset-api-execute-command-copy-button/)
  assert.match(dashboardSource, /operationsDispatchPreflightSourceSummary/)
  assert.match(dashboardSource, /formatOperationsSourceCounts\(preflight\)/)
  assert.match(dashboardSource, /sourcePassedCount/)
  assert.match(dashboardSource, /preflight\.githubRepository/)
  assert.match(dashboardSource, /preflight\.githubRef/)
  assert.match(dashboardSource, /operationsDispatchPreflightGitHubCliSummary/)
  assert.match(dashboardSource, /operationsDispatchPreflightGitRefSafety/)
  assert.match(dashboardSource, /operationsDispatchPreflightGitRefSafetySummary/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-git-ref-safety/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-git-ref-note/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-git-ref-push-command-copy-button/)
  assert.match(dashboardSource, /suggestedPushCommand/)
  assert.match(dashboardSource, /githubCliPath/)
  assert.match(dashboardSource, /githubRepository/)
  assert.match(dashboardSource, /dispatchUrl/)
  assert.match(dashboardSource, /:href="template\.dispatchUrl"/)
  assert.match(dashboardSource, /:href="workflow\.dispatchUrl"/)
  assert.match(dashboardSource, /target="_blank"/)
  assert.match(dashboardSource, /rel="noreferrer"/)
  assert.match(dashboardSource, /operationsDispatchPreflightChecks/)
  assert.doesNotMatch(dashboardSource, /operationsDispatchPreflightChecks\.slice\(0, 4\)/)
  assert.match(dashboardSource, /operationsDispatchPreflightInputs/)
  assert.doesNotMatch(dashboardSource, /operationsDispatchPreflightInputs\.slice\(0, 4\)/)
  assert.match(dashboardSource, /operationsDispatchPreflightInputTemplates/)
  assert.match(dashboardSource, /readyToDispatch/)
  assert.match(dashboardSource, /workflowInputNames/)
  assert.match(dashboardSource, /missingInputParameters/)
  assert.match(dashboardSource, /unsafeInputCount/)
  assert.match(dashboardSource, /invalidInputCount/)
  assert.match(dashboardSource, /operationsDispatchPreflightWorkflowFiles/)
  assert.doesNotMatch(dashboardSource, /operationsDispatchPreflightWorkflowFiles\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlan/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanSourceSummary/)
  assert.match(dashboardSource, /formatOperationsSourceCounts\(plan\)/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanTargetSummary/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanActionOrderSummary/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanJsonDirectorySummary/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanSecurityFinalizerSummary/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanSecurityFinalizerNote/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanSecurityFinalizerHints/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanSecurityFinalizerHintSummary/)
  assert.match(dashboardSource, /securityEvidenceFinalizerRunIdInputs/)
  assert.match(dashboardSource, /securityEvidenceFinalizerRunIdInputHints/)
  assert.match(dashboardSource, /sourceSelected/)
  assert.match(dashboardSource, /supplementalForSecurityFinalizer/)
  assert.match(dashboardSource, /securityEvidenceFinalizerMissingRunIdInputs/)
  assert.match(dashboardSource, /securityEvidenceFinalizerDependencyNote/)
  assert.match(dashboardSource, /runListJsonDirectoryCommand/)
  assert.match(dashboardSource, /githubApiRunListCommand/)
  assert.match(dashboardSource, /runListJsonPath/)
  assert.match(dashboardSource, /readiness-workflow-run-id-json-directory/)
  assert.match(dashboardSource, /readiness-workflow-run-id-security-finalizer/)
  assert.match(dashboardSource, /readiness-workflow-run-id-security-finalizer-note/)
  assert.match(dashboardSource, /readiness-workflow-run-id-security-finalizer-hints/)
  assert.match(dashboardSource, /readiness-workflow-run-id-json-directory-command-copy-button/)
  assert.match(dashboardSource, /readiness-workflow-run-id-json-path/)
  assert.doesNotMatch(dashboardSource, /mojibake_sentinel_never_present/)
  assert.match(dashboardSource, /operationsWorkflowRunIdPlanWorkflows/)
  assert.doesNotMatch(dashboardSource, /operationsWorkflowRunIdPlanWorkflows\.slice\(0, 3\)/)
  assert.match(dashboardSource, /workflow\.runsUrl/)
  assert.match(dashboardSource, /:href="workflow\.runsUrl"/)
  assert.match(dashboardSource, /selectedActionOrders/)
  assert.match(dashboardSource, /workflow\?\.actionOrders/)
  assert.match(dashboardSource, /workflow\.primaryActionOrder/)
  assert.match(dashboardSource, /workflow\?\.actionStatuses/)
  assert.match(dashboardSource, /operationsArtifactCollectionPlan/)
  assert.match(dashboardSource, /operationsArtifactCollectionPlanSourceSummary/)
  assert.match(dashboardSource, /operationsArtifactCollectionPlanActionOrderSummary/)
  assert.match(dashboardSource, /readySecuritySourceArtifactCount/)
  assert.match(dashboardSource, /missingSecuritySourceArtifactCount/)
  assert.match(dashboardSource, /securityEvidenceFinalizerReady/)
  assert.match(dashboardSource, /securityEvidenceFinalizerInputs/)
  assert.match(dashboardSource, /securityEvidenceFinalizerMissingRunIdInputs/)
  assert.match(dashboardSource, /operationsArtifactCollectionSecurityInputs/)
  assert.match(dashboardSource, /formatArtifactCollectionSecurityInputMeta/)
  assert.match(dashboardSource, /sourceSummary: plan\?\.sourceSummary/)
  assert.match(dashboardSource, /operationsArtifactCollectionArtifacts/)
  assert.match(dashboardSource, /operationsReadinessArtifactImport/)
  assert.match(dashboardSource, /operationsReadinessArtifactImportEntries/)
  assert.match(dashboardSource, /operationsReadinessFinalize/)
  assert.match(dashboardSource, /operationsReadinessFinalizeCommands/)
  assert.doesNotMatch(dashboardSource, /operationsReadinessFinalizeCommands\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsReadinessFinalizeSteps/)
  assert.doesNotMatch(dashboardSource, /operationsReadinessFinalizeSteps\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsReadinessFinalizeGaps/)
  assert.match(dashboardSource, /operationsReadinessFinalizeContextSummary/)
  assert.match(dashboardSource, /operationsReadinessFinalizeSelectedStepSummary/)
  assert.match(dashboardSource, /operationsReadinessFinalizePathSummary/)
  assert.match(dashboardSource, /operationsEvidenceHandoff/)
  assert.match(dashboardSource, /formatOperationsReadinessCounts/)
  assert.match(dashboardSource, /operationsEvidenceHandoffNextStep/)
  assert.match(dashboardSource, /operationsEvidenceHandoffNextStep\.note/)
  assert.match(dashboardSource, /operationsEvidenceHandoffCurrentBottleneck/)
  assert.match(dashboardSource, /readiness-evidence-handoff-current-bottleneck/)
  assert.match(dashboardSource, /operationsEvidenceHandoffNextStepDispatchUrls/)
  assert.match(dashboardSource, /operationsEvidenceHandoffStages/)
  assert.match(dashboardSource, /operationsEvidenceHandoffBrowserDispatchChecklist/)
  assert.match(dashboardSource, /readiness-evidence-handoff-browser-checklist/)
  assert.match(dashboardSource, /readiness-evidence-handoff-browser-dispatch-link/)
  assert.match(dashboardSource, /readiness-evidence-handoff-browser-runs-link/)
  assert.match(dashboardSource, /readiness-evidence-handoff-browser-command-copy-button/)
  assert.match(dashboardSource, /formatEvidenceHandoffBrowserChecklistMeta/)
  assert.match(dashboardSource, /securityFinalizerDependencyNote/)
  assert.match(dashboardSource, /securityFinalizerMissingRunIdInputs/)
  assert.match(dashboardSource, /browserDispatchChecklistCount/)
  assert.match(dashboardSource, /browserDispatchChecklist: Array\.isArray\(handoff\?\.browserDispatchChecklist\)/)
  assert.match(dashboardSource, /operationsEvidenceHandoffSecurityFinalizerHints/)
  assert.match(dashboardSource, /operationsEvidenceHandoffSecurityFinalizerHintSummary/)
  assert.match(dashboardSource, /readiness-evidence-handoff-security-finalizer-hints/)
  assert.match(dashboardSource, /formatSecurityFinalizerRunIdHintSummary/)
  assert.match(dashboardSource, /securityEvidenceFinalizerRunIdInputHintCount/)
  assert.match(dashboardSource, /securityEvidenceFinalizerRunIdInputHints/)
  assert.match(dashboardSource, /operationsEvidenceHandoffPostDispatchCommands/)
  assert.match(dashboardSource, /readiness-evidence-handoff-post-dispatch-commands/)
  assert.match(dashboardSource, /readiness-evidence-handoff-post-dispatch-command-copy-button/)
  assert.match(dashboardSource, /\{\{ stage\.name \}\} - \{\{ formatEvidenceHandoffStageState\(stage\) \}\}/)
  assert.doesNotMatch(dashboardSource, /\uC9CC/)
  assert.match(dashboardSource, /operationsEvidenceHandoffDispatchSummary/)
  assert.match(dashboardSource, /operationsEvidenceHandoffReadinessSummary/)
  assert.match(dashboardSource, /readiness-evidence-handoff-readiness-summary/)
  assert.match(dashboardSource, /operationsEvidenceHandoffScopeSummary/)
  assert.match(dashboardSource, /operationsEvidenceHandoffRunIdQuerySummary/)
  assert.match(dashboardSource, /readiness-evidence-handoff-run-id-query/)
  assert.match(dashboardSource, /operationsEvidenceHandoffInputFreeReviewSummary/)
  assert.match(dashboardSource, /readiness-evidence-handoff-input-free-review/)
  assert.match(dashboardSource, /workflowRunIdPlanQueryExecutedCount/)
  assert.match(dashboardSource, /workflowRunIdPlanQuerySucceededCount/)
  assert.match(dashboardSource, /workflowRunIdPlanCandidateCount/)
  assert.match(dashboardSource, /inputFreeBlockedReviewReportExists/)
  assert.match(dashboardSource, /inputFreeBlockedReviewReportActionOrders/)
  assert.match(dashboardSource, /invocationSelectedActionOrders/)
  assert.match(dashboardSource, /dispatchPreflightSelectedActionOrders/)
  assert.match(dashboardSource, /dispatchPreflightScopeMismatch/)
  assert.match(dashboardSource, /workflowRunIdPlanActionOrders/)
  assert.match(dashboardSource, /artifactCollectionActionOrders/)
  assert.match(dashboardSource, /workflowRunIdPlanStale/)
  assert.match(dashboardSource, /artifactCollectionScopeMismatch/)
  assert.match(dashboardSource, /readiness-evidence-handoff-next-dispatch-link/)
  assert.match(dashboardSource, /readiness-evidence-handoff-stale/)
  assert.match(dashboardSource, /staleReportCount/)
  assert.match(dashboardSource, /operationsEvidenceHandoffDispatchWorkflows/)
  assert.doesNotMatch(dashboardSource, /operationsEvidenceHandoffDispatchWorkflows\.slice\(0, 6\)/)
  assert.match(dashboardSource, /dispatchGithubRepository/)
  assert.match(dashboardSource, /formatEvidenceHandoffDispatchWorkflowMeta/)
  assert.match(dashboardSource, /workflow\?\.dispatchUrl/)
  assert.match(dashboardSource, /readyDispatchActionOrders/)
  assert.match(dashboardSource, /blockedDispatchActionOrders/)
  assert.match(dashboardSource, /readyDispatchWorkflows/)
  assert.match(dashboardSource, /blockedDispatchWorkflows/)
  assert.match(dashboardSource, /operationsHandoffPackage/)
  assert.match(dashboardSource, /operationsHandoffPackageChecks/)
  assert.doesNotMatch(dashboardSource, /operationsHandoffPackageChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsHandoffPackageEvidenceRefSummary/)
  assert.match(dashboardSource, /operationsHandoffPackageReadinessSnapshot/)
  assert.match(dashboardSource, /operationsHandoffPackageConvergenceSnapshot/)
  assert.match(dashboardSource, /handoffPostDispatchCommandCount/)
  assert.match(dashboardSource, /finalizer gap invalid/)
  assert.match(dashboardSource, /sync ready invalid/)
  assert.match(dashboardSource, /operationsHandoffPackageDataFlowStoragePlanSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-data-flow-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageDataFlowStoragePlanCandidateDecision/)
  assert.match(dashboardSource, /readiness-handoff-package-data-flow-candidate-decision/)
  assert.match(dashboardSource, /readiness-handoff-package-data-flow-candidate-next-action/)
  assert.match(dashboardSource, /operationsHandoffPackageDataFlowQueryRetentionBudgetSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-data-flow-query-retention-budget-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-data-flow-transition-runbook-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageSecretRotationSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-secret-rotation-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageCommercialIntegrationSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-commercial-integration-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageCommercialApprovalSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-commercial-approval-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageChargebackCloseoutSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-chargeback-closeout-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageEnterpriseAuthSmokeSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-enterprise-auth-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageEnterpriseAuthJitRollbackSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-enterprise-auth-jit-rollback-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageMonitoringThresholdSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-monitoring-threshold-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageClusterNetworkAccessReviewSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-cluster-network-snapshot-summary/)
  assert.match(dashboardSource, /operationsHandoffPackageHelmValuesHardeningSnapshot/)
  assert.match(dashboardSource, /readiness-handoff-package-helm-values-snapshot-summary/)
  assert.match(dashboardSource, /storageExpansionFinalize/)
  assert.match(dashboardSource, /storageExpansionFinalizeSteps/)
  assert.doesNotMatch(dashboardSource, /storageExpansionFinalizeSteps\.slice\(0, 4\)/)
  assert.match(dashboardSource, /storageExpansionFinalizeGaps/)
  assert.doesNotMatch(dashboardSource, /storageExpansionFinalizeGaps\.slice\(0, 3\)/)
  assert.match(dashboardSource, /storageExpansionFinalizeEvidenceSummary/)
  assert.match(dashboardSource, /storageExpansionFinalizeWindowSummary/)
  assert.match(dashboardSource, /kubernetesHaDrReadiness/)
  assert.match(dashboardSource, /kubernetesHaDrInputSummary/)
  assert.match(dashboardSource, /kubernetesHaDrChecks/)
  assert.doesNotMatch(dashboardSource, /kubernetesHaDrChecks\.slice\(0, 5\)/)
  assert.match(dashboardSource, /kubernetesDrFinalize/)
  assert.match(dashboardSource, /kubernetesDrFinalizeCommands/)
  assert.match(dashboardSource, /kubernetesDrFinalizeCommandSummary/)
  assert.match(dashboardSource, /kubernetesDrFinalizeWindowSummary/)
  assert.match(dashboardSource, /kubernetesDrFinalizeOptionSummary/)
  assert.match(dashboardSource, /kubernetesDrFinalizeSteps/)
  assert.doesNotMatch(dashboardSource, /kubernetesDrFinalizeSteps\.slice\(0, 4\)/)
  assert.match(dashboardSource, /kubernetesDrFinalizeGaps/)
  assert.doesNotMatch(dashboardSource, /kubernetesDrFinalizeGaps\.slice\(0, 3\)/)
  assert.match(dashboardSource, /iamRbacEvidence/)
  assert.match(dashboardSource, /iamRbacEvidenceCommands/)
  assert.match(dashboardSource, /iamRbacEvidenceSteps/)
  assert.doesNotMatch(dashboardSource, /iamRbacEvidenceSteps\.slice\(0, 4\)/)
  assert.match(dashboardSource, /iamRbacEvidenceGaps/)
  assert.doesNotMatch(dashboardSource, /iamRbacEvidenceGaps\.slice\(0, 3\)/)
  assert.match(dashboardSource, /iamRbacEvidenceCommandSummary/)
  assert.match(dashboardSource, /iamRbacEvidenceWindowSummary/)
  assert.match(dashboardSource, /iamRbacEvidenceRunCommandSummary/)
  assert.match(dashboardSource, /securityEvidence/)
  assert.match(dashboardSource, /securityEvidenceChecks/)
  assert.match(dashboardSource, /securityEvidenceImageSummary/)
  assert.match(dashboardSource, /securityEvidenceSignatureSummary/)
  assert.match(dashboardSource, /securityEvidenceContainerSummary/)
  assert.match(dashboardSource, /securityEvidenceSourceSummary/)
  assert.match(dashboardSource, /securityEvidencePromotedSummary/)
  assert.match(dashboardSource, /secretRotationEvidence/)
  assert.match(dashboardSource, /secretRotationEvidenceRefSummary/)
  assert.match(dashboardSource, /secretRotationWindowSummary/)
  assert.match(dashboardSource, /secretRotationConfirmationSummary/)
  assert.match(dashboardSource, /secretRotationEvidenceRotations/)
  assert.match(dashboardSource, /secretRotationEvidenceChecks/)
  assert.doesNotMatch(dashboardSource, /secretRotationEvidenceRotations\.slice\(0, 4\)/)
  assert.doesNotMatch(dashboardSource, /secretRotationEvidenceChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /commercialIntegrationEvidence/)
  assert.match(dashboardSource, /commercialIntegrationAdapterSummary/)
  assert.match(dashboardSource, /commercialIntegrationEvidenceChecks/)
  assert.doesNotMatch(dashboardSource, /commercialIntegrationEvidenceChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /commercialApprovalEvidence/)
  assert.match(dashboardSource, /commercialApprovalEvidenceRefSummary/)
  assert.match(dashboardSource, /commercialApprovalConfirmationSummary/)
  assert.match(dashboardSource, /commercialApprovalEvidenceChecks/)
  assert.doesNotMatch(dashboardSource, /commercialApprovalEvidenceChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /enterpriseAuthSmokeEvidence/)
  assert.match(dashboardSource, /enterpriseAuthSmokeInputSummary/)
  assert.match(dashboardSource, /enterpriseAuthSmokeScopeOutSummary/)
  assert.match(dashboardSource, /enterpriseAuthSmokeEvidenceChecks/)
  assert.doesNotMatch(dashboardSource, /enterpriseAuthSmokeEvidenceChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackEvidence/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackSmoke/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackRefSummary/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackConfirmationSummary/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackChecks/)
  assert.doesNotMatch(dashboardSource, /enterpriseAuthJitRollbackChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /minioBucketCorsVerification/)
  assert.match(dashboardSource, /minioBucketCorsVerificationItem/)
  assert.match(dashboardSource, /minioBucketCorsChecks/)
  assert.match(dashboardSource, /minioBucketCorsExposeSummary/)
  assert.match(dashboardSource, /minioBucketCorsAllowedHeadersSummary/)
  assert.match(dashboardSource, /minioBucketCorsMaxAgeSummary/)
  assert.match(dashboardSource, /minioBucketCorsOperatorCommands/)
  assert.match(dashboardSource, /dataFlowStoragePlan/)
  assert.match(dashboardSource, /dataFlowStoragePlanCandidateDecision/)
  assert.match(dashboardSource, /readiness-data-flow-storage-plan-candidate-decision/)
  assert.match(dashboardSource, /candidateDecision\.requiresMariaDbQueryEvidence/)
  assert.match(dashboardSource, /targetStoreEvidenceConfirmed/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudget/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetObservedMaxSeconds/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetConfirmationSummary/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetChecks/)
  assert.match(dashboardSource, /dataFlowQueryPlanEvidence/)
  assert.match(dashboardSource, /dataFlowQueryPlanFailedChecks/)
  assert.match(dashboardSource, /dataFlowStoragePlanChecks/)
  assert.match(dashboardSource, /targetP95QueryLatencyMs/)
  assert.match(dashboardSource, /dataFlowStorageTransitionRunbook/)
  assert.match(dashboardSource, /normalizeDataFlowStorageTransitionRunbook/)
  assert.match(dashboardSource, /readiness-data-flow-storage-transition-runbook-summary/)
  assert.match(dashboardSource, /readiness-data-flow-storage-transition-runbook-confirmations/)
  assert.match(dashboardSource, /readiness-data-flow-storage-transition-runbook-checks/)
  assert.doesNotMatch(dashboardSource, /dataFlowStorageTransitionRunbookChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /storageBackendTelemetryEvidence/)
  assert.match(dashboardSource, /storageBackendTelemetryEvidence\.onlineServerCount/)
  assert.match(dashboardSource, /storageBackendTelemetryEvidence\.freeBytes/)
  assert.match(dashboardSource, /storageBackendTelemetryEvidence\.capacityKnown/)
  assert.match(dashboardSource, /monitoringThresholdEvidence/)
  assert.match(dashboardSource, /thresholdMappingComplete/)
  assert.match(dashboardSource, /alertTargetCoverageComplete/)
  assert.match(dashboardSource, /routeCoverageComplete/)
  assert.match(dashboardSource, /grafanaPanelCoverageComplete/)
  assert.match(dashboardSource, /tuningEvidenceCoverageComplete/)
  assert.match(dashboardSource, /monitoringThresholdEvidenceRefSummary/)
  assert.match(dashboardSource, /monitoringThresholdReviewWindowSummary/)
  assert.match(dashboardSource, /monitoringThresholdRouteSummary/)
  assert.match(dashboardSource, /monitoringThresholdMissingAlertSummary/)
  assert.match(dashboardSource, /monitoringThresholdConfirmationSummary/)
  assert.match(dashboardSource, /monitoringThresholdEvidenceChecks/)
  assert.doesNotMatch(dashboardSource, /monitoringThresholdEvidenceChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewEvidence/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewWindowSummary/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewEvidenceRefSummary/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewStaticSummary/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewConfirmationSummary/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewChecks/)
  assert.doesNotMatch(dashboardSource, /clusterNetworkAccessReviewChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /helmValuesHardeningEvidence/)
  assert.match(dashboardSource, /helmValuesHardeningWindowSummary/)
  assert.match(dashboardSource, /helmValuesHardeningEvidenceRefSummary/)
  assert.match(dashboardSource, /helmValuesHardeningStaticSummary/)
  assert.match(dashboardSource, /helmValuesHardeningConfirmationSummary/)
  assert.match(dashboardSource, /helmValuesHardeningChecks/)
  assert.doesNotMatch(dashboardSource, /helmValuesHardeningChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /readiness-cluster-network-access-review-summary/)
  assert.match(dashboardSource, /readiness-cluster-network-access-review-static-snapshot/)
  assert.match(dashboardSource, /readiness-cluster-network-access-review-checks/)
  assert.match(dashboardSource, /readiness-helm-values-hardening-summary/)
  assert.match(dashboardSource, /readiness-helm-values-hardening-static-snapshot/)
  assert.match(dashboardSource, /readiness-helm-values-hardening-checks/)
  assert.match(dashboardSource, /supportEscalationHandoffEvidence/)
  assert.match(dashboardSource, /supportEscalationHandoffReviewWindowSummary/)
  assert.match(dashboardSource, /supportEscalationHandoffEvidenceRefSummary/)
  assert.match(dashboardSource, /supportEscalationHandoffDocumentSummary/)
  assert.match(dashboardSource, /supportEscalationHandoffConfirmationSummary/)
  assert.match(dashboardSource, /supportEscalationHandoffChecks/)
  assert.doesNotMatch(dashboardSource, /supportEscalationHandoffChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /normalizeDataFlowStoragePlan/)
  assert.match(dashboardSource, /normalizeDataFlowQueryRetentionBudget/)
  assert.match(dashboardSource, /normalizeStorageBackendTelemetryEvidence/)
  assert.match(dashboardSource, /normalizeMonitoringThresholdEvidence/)
  assert.match(dashboardSource, /normalizeHardeningEvidence/)
  assert.match(dashboardSource, /normalizeSupportEscalationHandoffEvidence/)
  assert.match(dashboardSource, /normalizeMinioBucketCorsVerification/)
  assert.match(dashboardSource, /readiness-data-flow-storage-plan-summary/)
  assert.match(dashboardSource, /readiness-data-flow-query-retention-budget-summary/)
  assert.match(dashboardSource, /readiness-data-flow-query-retention-budget-checks/)
  assert.match(dashboardSource, /readiness-data-flow-query-plan-evidence-summary/)
  assert.match(dashboardSource, /readiness-data-flow-query-plan-failed-checks/)
  assert.doesNotMatch(dashboardSource, /dataFlowStoragePlanChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /readiness-storage-telemetry-summary/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-source/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-confirmations/)
  assert.match(dashboardSource, /readiness-dispatch-preflight-selected-orders/)
  assert.match(dashboardSource, /readiness-workflow-run-id-source/)
  assert.match(dashboardSource, /readiness-workflow-run-id-target/)
  assert.match(dashboardSource, /readiness-artifact-collection-source/)
  assert.match(dashboardSource, /readiness-artifact-collection-security-command/)
  assert.match(dashboardSource, /readiness-artifact-collection-security-inputs/)
  assert.match(dashboardSource, /readiness-artifact-security-finalizer-command-copy-button/)
  assert.match(dashboardSource, /readiness-artifact-import-summary/)
  assert.match(dashboardSource, /readiness-artifact-import-entries/)
  assert.match(dashboardSource, /readiness-artifact-import-output/)
  assert.match(dashboardSource, /readiness-finalizer-summary/)
  assert.match(dashboardSource, /readiness-finalizer-context/)
  assert.match(dashboardSource, /readiness-finalizer-selected-steps/)
  assert.match(dashboardSource, /readiness-finalizer-paths/)
  assert.match(dashboardSource, /readiness-finalizer-commands/)
  assert.match(dashboardSource, /readiness-finalizer-command-copy-button/)
  assert.match(dashboardSource, /readiness-finalizer-steps/)
  assert.match(dashboardSource, /readiness-storage-expansion-finalize-window/)
  assert.match(dashboardSource, /readiness-kubernetes-ha-dr-inputs/)
  assert.match(dashboardSource, /readiness-kubernetes-dr-finalize-window/)
  assert.match(dashboardSource, /readiness-kubernetes-dr-finalize-options/)
  assert.match(dashboardSource, /readiness-kubernetes-dr-finalize-commands/)
  assert.match(dashboardSource, /readiness-iam-rbac-evidence-window/)
  assert.match(dashboardSource, /readiness-iam-rbac-evidence-run-commands/)
  assert.match(dashboardSource, /readiness-security-evidence-mode/)
  assert.match(dashboardSource, /readiness-security-evidence-signatures/)
  assert.match(dashboardSource, /readiness-security-evidence-source/)
  assert.match(dashboardSource, /readiness-security-evidence-promoted/)
  assert.match(dashboardSource, /readiness-secret-rotation-window/)
  assert.match(dashboardSource, /readiness-secret-rotation-confirmations/)
  assert.match(dashboardSource, /readiness-commercial-integration-adapters/)
  assert.match(dashboardSource, /readiness-commercial-approval-confirmations/)
  assert.match(dashboardSource, /readiness-enterprise-auth-smoke-api-base/)
  assert.match(dashboardSource, /readiness-enterprise-auth-smoke-inputs/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-evidence-summary/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-mapping-status/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-review-window/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-targets-path/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-routes/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-missing-alerts/)
  assert.match(dashboardSource, /readiness-monitoring-threshold-confirmations/)
  assert.match(dashboardSource, /readiness-minio-bucket-cors-summary/)
  assert.match(dashboardSource, /getDataFlowDailyRollup/)
  assert.match(dashboardSource, /getDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /getDataFlowStorageStatus/)
  assert.match(dashboardSource, /getStorageBackendStatus/)
  assert.match(dashboardSource, /defaultStorageBackendStatus/)
  assert.match(dashboardSource, /applyStorageBackendStatus/)
  assert.match(dashboardSource, /storageBackendStatus/)
  assert.match(dashboardSource, /directMetricTotalBytes/)
  assert.match(dashboardSource, /directMetricFreeBytes/)
  assert.match(dashboardSource, /directStorageMetricsStatus/)
  assert.match(dashboardSource, /storageBackendCapacityLabel/)
  assert.match(dashboardSource, /used from direct metrics/)
  assert.match(dashboardSource, /used from telemetry evidence/)
  assert.match(dashboardSource, /metadata used/)
  assert.match(dashboardSource, /getMaterializedDataFlowDailyRollup/)
  assert.match(dashboardSource, /getMaterializedDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /downloadDataFlowDailyRollupCsv/)
  assert.match(dashboardSource, /downloadDataFlowMonthlyRollupCsv/)
  assert.match(dashboardSource, /downloadMaterializedDataFlowDailyRollupCsv/)
  assert.match(dashboardSource, /downloadMaterializedDataFlowMonthlyRollupCsv/)
  assert.match(dashboardSource, /materializeDataFlowDailyRollup/)
  assert.match(dashboardSource, /materializeDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /handleExportDataFlowDailyRollupCsv/)
  assert.match(dashboardSource, /handleLoadDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /handleExportDataFlowMonthlyRollupCsv/)
  assert.match(dashboardSource, /handleMaterializeDataFlowDailyRollup/)
  assert.match(dashboardSource, /handleLoadMaterializedDataFlowDailyRollup/)
  assert.match(dashboardSource, /handleExportMaterializedDataFlowDailyRollupCsv/)
  assert.match(dashboardSource, /handleMaterializeDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /handleLoadMaterializedDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /handleExportMaterializedDataFlowMonthlyRollupCsv/)
  assert.match(dashboardSource, /defaultDataFlowDailyRollup/)
  assert.match(dashboardSource, /defaultDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /defaultDataFlowStorageStatus/)
  assert.match(dashboardSource, /applyDataFlowDailyRollup/)
  assert.match(dashboardSource, /applyDataFlowMonthlyRollup/)
  assert.match(dashboardSource, /applyDataFlowStorageStatus/)
  assert.match(dashboardSource, /chargebackPaymentProviderAdapterReadiness/)
  assert.match(dashboardSource, /getChargebackPaymentProviderAdapterReadiness/)
  assert.match(dashboardSource, /defaultChargebackPaymentProviderAdapterReadiness/)
  assert.match(dashboardSource, /normalizeChargebackPaymentProviderAdapterProfile/)
  assert.match(dashboardSource, /applyChargebackPaymentProviderAdapterReadiness/)
  assert.match(dashboardSource, /finalizerGapCount/)
  assert.match(dashboardSource, /operationsReadinessConvergence/)
  assert.match(dashboardSource, /operationsReadinessConvergenceBottleneck/)
  assert.match(dashboardSource, /operationsReadinessConvergenceDependencyNotes/)
  assert.match(dashboardSource, /handoffBrowserDispatchDependencyNotes/)
  assert.match(dashboardSource, /operationsReadinessConvergenceSecurityFinalizerHintSummary/)
  assert.match(dashboardSource, /readiness-convergence-security-finalizer-hints/)
  assert.match(dashboardSource, /handoffSecurityEvidenceFinalizerRunIdInputHintCount/)
  assert.match(dashboardSource, /handoffSecurityEvidenceFinalizerRunIdInputHints/)
  assert.match(dashboardSource, /operationsReadinessConvergenceReadinessSummary/)
  assert.match(dashboardSource, /readiness-convergence-readiness-summary/)
  assert.match(dashboardSource, /operationsReadinessConvergenceHandoffFreshness/)
  assert.match(dashboardSource, /operationsReadinessConvergenceRunIdQuerySummary/)
  assert.match(dashboardSource, /readiness-convergence-run-id-query/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanQueryExecutedCount/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanQuerySucceededCount/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanCandidateCount/)
  assert.match(dashboardSource, /handoffStale/)
  assert.match(dashboardSource, /handoffTimestamp/)
  assert.match(dashboardSource, /readinessTimestamp/)
  assert.match(dashboardSource, /bottleneck\.note/)
  assert.doesNotMatch(dashboardSource, /operationsEvidenceHandoffStages\.slice\(0, 3\)/)
  assert.doesNotMatch(dashboardSource, /operationsReadinessConvergenceCommands\.slice\(0, 3\)/)
  assert.match(dashboardSource, /operationsReadinessConvergenceCommands/)
  assert.match(dashboardSource, /handoffPostDispatchCommands/)
  assert.match(dashboardSource, /operationsReadinessConvergenceBottleneckDispatchUrls/)
  assert.match(dashboardSource, /convergenceCommandDispatchUrls/)
  assert.match(dashboardSource, /command\?\.dispatchUrls/)
  assert.match(dashboardSource, /readiness-convergence-bottleneck-dispatch-link/)
  assert.match(dashboardSource, /readiness-convergence-dispatch-link/)
  assert.match(dashboardSource, /command\.note/)
  assert.match(dashboardSource, /kubernetesReportSyncWorkflowCommand/)
  assert.match(dashboardSource, /kubernetesReportSyncWorkflowNote/)
  assert.match(dashboardSource, /kubernetesReportSyncReady/)
  assert.match(dashboardSource, /kubernetesReportSyncStale/)
  assert.match(dashboardSource, /kubernetesReportSyncTimestamp/)
  assert.match(dashboardSource, /kubernetesReportSyncFreshnessReason/)
  assert.match(dashboardSource, /readiness-convergence-sync-freshness/)
  assert.match(dashboardSource, /kubernetesOperationsReportSync/)
  assert.match(dashboardSource, /kubernetesOperationsReportSyncChecks/)
  assert.doesNotMatch(dashboardSource, /kubernetesOperationsReportSyncChecks\.slice\(0, 3\)/)
  assert.match(dashboardSource, /dataFlowStorageTransitionRunbookConfigMapKey/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetConfigMapKey/)
  assert.match(dashboardSource, /publishDataFlowQueryRetentionBudgetToConfigMap/)
  assert.match(dashboardSource, /readiness-kubernetes-report-sync-query-retention-budget-summary/)
  assert.match(dashboardSource, /readiness-kubernetes-report-sync-runbook-summary/)
  assert.match(dashboardSource, /evidencePlanActionCommand/)
  assert.match(dashboardSource, /action\?\.command/)
  assert.match(dashboardSource, /readiness-evidence-plan-dispatch-link/)
  assert.match(dashboardSource, /:href="action\.dispatchUrl"/)
  assert.match(dashboardSource, /formatEvidencePlanActionMeta/)
  assert.match(dashboardSource, /currentDetail/)
  assert.match(dashboardSource, /formatEvidenceInvocationActionMeta/)
  assert.match(dashboardSource, /formatInvocationBlockReasons/)
  assert.match(dashboardSource, /formatInvocationUnblockConfirmationMeta/)
  assert.match(dashboardSource, /formatInvocationUnblockActionMeta/)
  assert.match(dashboardSource, /formatInvocationUnblockInputs/)
  assert.match(dashboardSource, /formatDispatchPreflightSecrets/)
  assert.match(dashboardSource, /formatDispatchPreflightInputMeta/)
  assert.match(dashboardSource, /workflow inputs/)
  assert.match(dashboardSource, /operationsDispatchPreflightInputTemplates/)
  assert.doesNotMatch(dashboardSource, /operationsDispatchPreflightInputTemplates\.slice\(0, 3\)/)
  assert.match(dashboardSource, /formatDispatchPreflightTemplateMeta/)
  assert.match(dashboardSource, /formatDispatchPreflightWorkflowMeta/)
  assert.match(dashboardSource, /formatWorkflowRunIdMeta/)
  assert.match(dashboardSource, /formatArtifactCollectionMeta/)
  assert.match(dashboardSource, /formatDataFlowQueryPlanFailedCheckMeta/)
  assert.match(dashboardSource, /formatArtifactImportEntryMeta/)
  assert.match(dashboardSource, /formatReadinessFinalizeCommandMeta/)
  assert.match(dashboardSource, /formatReadinessFinalizeStepMeta/)
  assert.match(dashboardSource, /formatEvidenceHandoffStageMeta/)
  assert.match(dashboardSource, /stage\?\.note/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsEvidencePlan/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsEvidenceInvocation/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsInvocationUnblockPlan/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsDispatchPreflight/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsWorkflowRunIdPlan/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsArtifactCollectionPlan/)
  assert.match(dashboardSource, /securitySourceArtifactCount/)
  assert.match(dashboardSource, /securityEvidenceFinalizerInputs: Array\.isArray\(plan\?\.securityEvidenceFinalizerInputs\)/)
  assert.match(dashboardSource, /dataFlowStoragePlanInputNote/)
  assert.match(dashboardSource, /dataFlowQueryRetentionBudgetInputNote/)
  assert.match(dashboardSource, /readiness-artifact-data-flow-query-retention-budget-note/)
  assert.match(dashboardSource, /dataFlowStorageTransitionRunbookInputNote/)
  assert.match(dashboardSource, /minioBucketCorsInputNote/)
  assert.match(dashboardSource, /readiness-artifact-data-flow-runbook-note/)
  assert.match(dashboardSource, /readiness-artifact-minio-cors-note/)
  assert.doesNotMatch(dashboardSource, /operationsArtifactCollectionArtifacts\.slice\(0, 3\)/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsReadinessArtifactImport/)
  assert.doesNotMatch(dashboardSource, /operationsReadinessArtifactImportEntries\.slice\(0, 4\)/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsReadinessFinalize/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsEvidenceHandoff/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsHandoffPackage/)
  assert.match(dashboardSource, /dashboardReadiness\.storageExpansionFinalize/)
  assert.match(dashboardSource, /dashboardReadiness\.kubernetesHaDrReadiness/)
  assert.match(dashboardSource, /dashboardReadiness\.kubernetesDrFinalize/)
  assert.match(dashboardSource, /dashboardReadiness\.iamRbacEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.securityEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.secretRotationEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.commercialIntegrationEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.commercialApprovalEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.enterpriseAuthSmokeEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.enterpriseAuthJitRollbackEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.dataFlowStoragePlan/)
  assert.match(dashboardSource, /dashboardReadiness\.dataFlowQueryRetentionBudget/)
  assert.match(dashboardSource, /dashboardReadiness\.storageBackendTelemetryEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.monitoringThresholdEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.clusterNetworkAccessReviewEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.helmValuesHardeningEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.supportEscalationHandoffEvidence/)
  assert.match(dashboardSource, /dashboardReadiness\.minioBucketCorsVerification/)
  assert.match(dashboardSource, /dashboardReadiness\.operationsReadinessConvergence/)
  assert.match(dashboardSource, /dashboardReadiness\.kubernetesOperationsReportSync/)
  assert.match(dashboardSource, /finalizerFailedCount/)
  assert.match(dashboardSource, /normalizeOperationsEvidencePlan/)
  assert.match(dashboardSource, /normalizeOperationsEvidencePlanSummary/)
  assert.match(dashboardSource, /normalizeOperationsEvidencePlanCategoryCounts/)
  assert.match(dashboardSource, /normalizeOperationsReadinessRemediations/)
  assert.match(dashboardSource, /pendingCategoryCounts: normalizeOperationsEvidencePlanCategoryCounts/)
  assert.match(dashboardSource, /sourcePendingRemediationCount: Number\(plan\?\.sourcePendingRemediationCount \|\| 0\)/)
  assert.match(dashboardSource, /sourcePendingRemediationCoverageReady: Boolean\(plan\?\.sourcePendingRemediationCoverageReady\)/)
  assert.match(dashboardSource, /pendingRemediationCount: Number\(summary\?\.pendingRemediationCount \|\| 0\)/)
  assert.match(dashboardSource, /pendingRemediations: normalizeOperationsReadinessRemediations/)
  assert.match(dashboardSource, /normalizeOperationsEvidenceInvocation/)
  assert.match(dashboardSource, /selectedActionOrders: Array\.isArray\(invocation\?\.selectedActionOrders\)/)
  assert.match(dashboardSource, /normalizeOperationsInvocationUnblockPlan/)
  assert.match(dashboardSource, /confirmationGroups: Array\.isArray\(plan\?\.confirmationGroups\)/)
  assert.match(dashboardSource, /requiredInputGroups: Array\.isArray\(plan\?\.requiredInputGroups\)/)
  assert.match(dashboardSource, /normalizeOperationsDispatchPreflight/)
  assert.match(dashboardSource, /normalizeDispatchPreflightGitRefSafety/)
  assert.match(dashboardSource, /gitRefSafety: normalizeDispatchPreflightGitRefSafety/)
  assert.match(dashboardSource, /normalizeOperationsWorkflowRunIdInputs/)
  assert.match(dashboardSource, /normalizeOperationsWorkflowRunIdPlan/)
  assert.match(dashboardSource, /normalizeOperationsArtifactCollectionPlan/)
  assert.match(dashboardSource, /normalizeOperationsReadinessArtifactImport/)
  assert.match(dashboardSource, /normalizeOperationsReadinessFinalize/)
  assert.match(dashboardSource, /normalizeOperationsHandoffPackage/)
  assert.match(dashboardSource, /chargebackCloseoutSnapshot: report\?\.chargebackCloseoutSnapshot/)
  assert.match(dashboardSource, /enterpriseAuthJitRollbackSnapshot: normalizeEnterpriseAuthJitRollbackEvidence/)
  assert.match(dashboardSource, /clusterNetworkAccessReviewSnapshot: normalizeHardeningEvidence/)
  assert.match(dashboardSource, /helmValuesHardeningSnapshot: normalizeHardeningEvidence/)
  assert.match(dashboardSource, /normalizeStorageExpansionFinalize/)
  assert.match(dashboardSource, /normalizeKubernetesHaDrReadiness/)
  assert.match(dashboardSource, /normalizeKubernetesDrFinalize/)
  assert.match(dashboardSource, /normalizeIamRbacEvidence/)
  assert.match(dashboardSource, /normalizeSecurityEvidence/)
  assert.match(dashboardSource, /normalizeSecretRotationEvidence/)
  assert.match(dashboardSource, /normalizeCommercialIntegrationEvidence/)
  assert.match(dashboardSource, /normalizeCommercialApprovalEvidence/)
  assert.match(dashboardSource, /normalizeEnterpriseAuthSmokeEvidence/)
  assert.match(dashboardSource, /normalizeOperationsEvidenceHandoff/)
  assert.match(dashboardSource, /dispatchUrls: Array\.isArray\(nextStep\.dispatchUrls\)/)
  assert.match(dashboardSource, /currentBottleneck: \{/)
  assert.match(dashboardSource, /currentBottleneck = handoff\?\.currentBottleneck \|\| nextStep/)
  assert.match(dashboardSource, /workflowRunIdPlanActionOrders: Array\.isArray\(handoff\?\.workflowRunIdPlanActionOrders\)/)
  assert.match(dashboardSource, /workflowRunIdPlanQueryExecuted: Boolean\(handoff\?\.workflowRunIdPlanQueryExecuted\)/)
  assert.match(dashboardSource, /workflowRunIdPlanQueryMode: handoff\?\.workflowRunIdPlanQueryMode/)
  assert.match(dashboardSource, /workflowRunIdPlanGithubApiUnauthenticated: Boolean\(handoff\?\.workflowRunIdPlanGithubApiUnauthenticated\)/)
  assert.match(dashboardSource, /inputFreeBlockedReviewReportExists: Boolean\(handoff\?\.inputFreeBlockedReviewReportExists\)/)
  assert.match(dashboardSource, /workflowRunIdPlanScopeMismatch: Boolean\(handoff\?\.workflowRunIdPlanScopeMismatch\)/)
  assert.match(dashboardSource, /artifactCollectionStale: Boolean\(handoff\?\.artifactCollectionStale\)/)
  assert.match(dashboardSource, /securityEvidenceFinalizerRunIdInputHints: normalizeOperationsWorkflowRunIdInputs\(handoff\?\.securityEvidenceFinalizerRunIdInputHints\)/)
  assert.match(dashboardSource, /readinessPassedCount: Number\(handoff\?\.readinessPassedCount \|\| 0\)/)
  assert.match(dashboardSource, /artifactCollectionScopeMismatch: Boolean\(handoff\?\.artifactCollectionScopeMismatch\)/)
  assert.match(dashboardSource, /normalizeOperationsReadinessConvergence/)
  assert.match(dashboardSource, /readinessPassedCount: Number\(report\?\.readinessPassedCount \|\| 0\)/)
  assert.match(dashboardSource, /handoffTimestampSource/)
  assert.match(dashboardSource, /handoffSecurityEvidenceFinalizerRunIdInputHints: normalizeOperationsWorkflowRunIdInputs\(report\?\.handoffSecurityEvidenceFinalizerRunIdInputHints\)/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanQueryExecuted: Boolean\(report\?\.handoffWorkflowRunIdPlanQueryExecuted\)/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanQueryMode: report\?\.handoffWorkflowRunIdPlanQueryMode/)
  assert.match(dashboardSource, /handoffWorkflowRunIdPlanGithubApiUnauthenticated: Boolean\(report\?\.handoffWorkflowRunIdPlanGithubApiUnauthenticated\)/)
  assert.match(dashboardSource, /handoffInputFreeBlockedReviewReportExists: Boolean\(report\?\.handoffInputFreeBlockedReviewReportExists\)/)
  assert.match(dashboardSource, /operationsReadinessConvergenceInputFreeReviewSummary/)
  assert.match(dashboardSource, /readiness-convergence-input-free-review/)
  assert.match(dashboardSource, /readinessTimestampSource/)
  assert.match(dashboardSource, /normalizeKubernetesOperationsReportSync/)
  assert.match(dashboardSource, /OPERATIONS_EVIDENCE_PLAN/)
  assert.match(dashboardSource, /OPERATIONS_EVIDENCE_PLAN_INVOCATION/)
  assert.match(dashboardSource, /OPERATIONS_INVOCATION_UNBLOCK_PLAN/)
  assert.match(dashboardSource, /OPERATIONS_DISPATCH_PREFLIGHT/)
  assert.match(dashboardSource, /OPERATIONS_WORKFLOW_RUN_ID_PLAN/)
  assert.match(dashboardSource, /OPERATIONS_ARTIFACT_COLLECTION_PLAN/)
  assert.match(dashboardSource, /OPERATIONS_READINESS_ARTIFACT_IMPORT/)
  assert.match(dashboardSource, /OPERATIONS_READINESS_FINALIZER/)
  assert.match(dashboardSource, /OPERATIONS_EVIDENCE_HANDOFF/)
  assert.match(dashboardSource, /OPERATIONS_HANDOFF_PACKAGE/)
  assert.match(dashboardSource, /OPERATIONS_READINESS_CONVERGENCE/)
  assert.match(dashboardSource, /KUBERNETES_OPERATIONS_REPORT_SYNC/)
  assert.match(dashboardSource, /MINIO_BUCKET_CORS_VERIFICATION/)
  assert.match(dashboardSource, /hasReadinessRemediation/)
  assert.match(dashboardSource, /copyReadinessRemediationCommand/)
  assert.match(dashboardSource, /fallbackCopyText/)
  assert.match(dashboardSource, /readiness-source-pending-remediations/)
  assert.match(dashboardSource, /operationsReadinessPendingRemediationSummaryText/)
  assert.match(dashboardSource, /readiness-remediation/)
  assert.match(dashboardSource, /readiness-remediation-copy-button/)
  assert.match(dashboardSource, /readiness-remediation-workflow-copy-button/)
  assert.match(dashboardSource, /item\.remediationCommand/)
  assert.match(dashboardSource, /item\.remediationWorkflow/)
  assert.match(dashboardSource, /item\.remediationWorkflowCommand/)
  assert.match(dashboardSource, /item\.evidencePath/)
  assert.match(dashboardSource, /update-readiness-category-filter', 'OPERATIONS'/)
  assert.match(dashboardSource, /item\.category/)
  assert.match(dashboardSource, /focusPanel/)
  assert.match(dashboardSource, /handleRefreshDashboardReadiness/)
  assert.match(dashboardSource, /getDashboardReadiness/)
  assert.match(dashboardSource, /id="admin-access-keys"/)
  assert.match(dashboardSource, /id="admin-quota-policies"/)
  assert.match(dashboardSource, /id="admin-storage-expansion"/)
  assert.match(dashboardSource, /getStorageExpansionRequests/)
  assert.match(dashboardSource, /createStorageExpansionRequest/)
  assert.match(dashboardSource, /getStorageExpansionRequestManifest/)
  assert.match(dashboardSource, /downloadStorageExpansionManifestArtifact/)
  assert.match(dashboardSource, /createStorageExpansionExecutionPlan/)
  assert.match(dashboardSource, /recordStorageExpansionDryRunExecution/)
  assert.match(dashboardSource, /runStorageExpansionDryRunExecution/)
  assert.match(dashboardSource, /runStorageExpansionApplyExecution/)
  assert.match(dashboardSource, /runStorageExpansionRollbackExecution/)
  assert.match(dashboardSource, /getStorageExpansionExecutionLogRetentionStatus/)
  assert.match(dashboardSource, /runStorageExpansionExecutionLogRetention/)
  assert.match(dashboardSource, /runStorageExpansionGitOpsPrExecution/)
  assert.match(dashboardSource, /createStorageExpansionGitOpsPlan/)
  assert.match(dashboardSource, /recordStorageExpansionGitOpsPrExecution/)
  assert.match(dashboardSource, /downloadStorageExpansionGitOpsArtifactBundle/)
  assert.match(dashboardSource, /getStorageExpansionExecutions/)
  assert.match(dashboardSource, /createStorageExpansionExecutionRecord/)
  assert.match(dashboardSource, /applyStorageExpansionExecutionRecord/)
  assert.match(dashboardSource, /updateStorageExpansionRequestStatus/)
  assert.match(dashboardSource, /storageExpansionApplyEvidence/)
  assert.match(dashboardSource, /storageExpansionExecutionPlan/)
  assert.match(dashboardSource, /storageExpansionGitOpsPlan/)
  assert.match(dashboardSource, /storageExpansionExecutionForm/)
  assert.match(dashboardSource, /storageExpansionExecutions/)
  assert.match(dashboardSource, /storageExpansionSummary/)
  assert.match(dashboardSource, /:storage-expansion-requests="storageExpansionRequests"/)
  assert.match(dashboardSource, /:storage-expansion-executions="storageExpansionExecutions"/)
  assert.match(dashboardSource, /getStorageExpansionSummary/)
  assert.match(dashboardSource, /storageExpansionRunnerPreflight/)
  assert.match(dashboardSource, /getStorageExpansionRunnerPreflight/)
  assert.match(dashboardSource, /check\.remediation/)
  assert.match(dashboardSource, /path: '\/login'/)
  assert.match(dashboardSource, /path: '\/developer'/)
  assert.match(dashboardSource, /createWebHistory/)
  assert.match(dashboardSource, /return '\/admin'/)
  assert.match(dashboardSource, /adminLandingPathForRole/)
  assert.match(dashboardSource, /defaultLandingPathForRole/)
  assert.match(dashboardSource, /rotateAccessKey/)
  assert.match(dashboardSource, /handleRotateAccessKey/)
  assert.match(dashboardSource, /rotation grace period/)
  assert.match(dashboardSource, /expiresAt: localDateTimeToIso\(accessKeyForm\.expiresAt\) \|\| null/)
  assert.match(dashboardSource, /filterAccessKeys/)
  assert.match(dashboardSource, /accessKeyOperationalAction/)
  assert.match(dashboardSource, /accessKeyCleanupCandidates/)
  assert.match(dashboardSource, /accessKeyCleanupCandidateIds/)
  assert.match(dashboardSource, /buildAccessKeyCleanupExport/)
  assert.match(dashboardSource, /selectedCleanupCandidateIds/)
  assert.match(dashboardSource, /cleanupSelection/)
  assert.match(dashboardSource, /handleBulkDisableAccessKeys/)
  assert.match(dashboardSource, /bulkDisableAccessKeys/)
  assert.match(dashboardSource, /roles: \['ADMIN', 'ORG_ADMIN', 'AUDITOR', 'USER'\]/)
  assert.match(dashboardSource, /roles: \['ADMIN', 'AUDITOR'\]/)
  assert.match(dashboardSource, /value="AUDITOR"/)
  assert.match(dashboardSource, /const isAuditor = auth\.isAuditor/)
  assert.match(dashboardSource, /const canUseAuditTools = auth\.canUseAuditTools/)
  assert.match(dashboardSource, /<ObjectSharePanel\s+v-if="isAdmin"/)
  assert.match(dashboardSource, /<QuotaPolicyPanel\s+v-if="isAdmin"/)
  assert.match(dashboardSource, /<StorageExpansionPanel\s+v-if="isAdmin"/)
  assert.match(dashboardSource, /<LifecycleRulesPanel\s+v-if="isAdmin"/)
  assert.match(dashboardSource, /<IdentityAdminPanel\s+v-if="canUseAdminTools"/)
  assert.match(dashboardSource, /getTeams/)
  assert.match(dashboardSource, /getEnterpriseAuthPlan/)
  assert.match(dashboardSource, /createTeam/)
  assert.match(dashboardSource, /deleteTeam/)
  assert.match(dashboardSource, /const teams = ref\(\[\]\)/)
  assert.match(dashboardSource, /const teamForm = reactive\(\{/)
  assert.match(dashboardSource, /:teams="teams"/)
  assert.match(dashboardSource, /:team-form="teamForm"/)
  assert.match(dashboardSource, /@create-team="handleCreateTeam"/)
  assert.match(dashboardSource, /@delete-team="handleDeleteTeam"/)
  assert.match(dashboardSource, /value="TEAM"/)
  assert.match(dashboardSource, /bucketPermissionForm\.subjectType === 'TEAM'/)
  assert.match(dashboardSource, /approvalWorkflowItems/)
  assert.match(dashboardSource, /approvalWorkflowCounts/)
  assert.match(dashboardSource, /storageProfileRequests[\s\S]*PENDING/)
  assert.match(dashboardSource, /storageExpansionRequests[\s\S]*PLANNED/)
  assert.match(dashboardSource, /:audit-logs="auditLogs"/)
  assert.match(dashboardSource, /securityPolicyRows/)
  assert.match(dashboardSource, /Enterprise auth plan/)
  assert.match(dashboardSource, /enterpriseAuthPlan/)
  assert.match(dashboardSource, /osmu_roles/)
  assert.match(dashboardSource, /accessKeyReviewCount/)
  assert.match(dashboardSource, /Share link protection/)
  assert.match(dashboardSource, /Audit page supports event/)
  assert.match(dashboardSource, /visibleNavigationItems/)
  assert.match(dashboardSource, /canAccessNavigationItem/)
  assert.match(dashboardSource, /auth\.startAuthSync\(handleSessionExpired\)/)
  assert.match(dashboardSource, /function handleSessionExpired\(\)/)
  assert.match(dashboardSource, /router\.replace\(\{/)
  assert.match(dashboardSource, /redirect: currentRoute\.fullPath \|\| '\/dashboard'/)
  assert.match(dashboardSource, /reason: 'session-expired'/)
  assert.match(dashboardSource, /consumeSessionNoticeReason/)
  assert.match(dashboardSource, /sessionNoticeMessage\(route\.query\.reason\)/)
  assert.match(dashboardSource, /session-invalid/)
  assert.match(dashboardSource, /loginForm\.mode === 'developer' \|\| role === 'USER'/)
  assert.match(dashboardSource, /return '\/developer'/)
  assert.match(dashboardSource, /getS3ClientConfig/)
  assert.match(dashboardSource, /s3ClientConfig/)
  assert.match(dashboardSource, /aws --endpoint-url/)
  assert.match(dashboardSource, /s3fs .* use_path_request_style/)
  assert.match(dashboardSource, /goofys --endpoint/)
  assert.match(dashboardSource, /Last used:/)
  assert.match(dashboardSource, /Rotation grace:/)
  assert.match(dashboardSource, /Old secret allowed until/)
  assert.match(dashboardSource, /Total S3 uses/)
  assert.match(dashboardSource, /S3 uses:/)
  assert.match(dashboardSource, /analyzeAccessKeyUsage/)
  assert.match(dashboardSource, /login-auto-login-checkbox/)
  assert.match(dashboardSource, /login-remember-id-checkbox/)
  assert.match(dashboardSource, /login-password-toggle/)
  assert.match(dashboardSource, /loginForm\.mode/)
  assert.match(dashboardSource, /admin/)
  assert.match(dashboardSource, /developer/)
  assert.match(dashboardSource, /session-expired/)
  assert.match(dashboardSource, /RAID 0-9/)
  assert.match(dashboardSource, /JBOD/)
  assert.match(dashboardSource, /IAM User/)
  assert.match(dashboardSource, /API Key/)
  assert.match(dashboardSource, /s3cmd/)
  assert.match(dashboardSource, /developerOnboardingSteps/)
  assert.match(dashboardSource, /developerOnboardingSteps/)
  assert.match(dashboardSource, /developerOnboardingProgress/)
  assert.match(dashboardSource, /clientCompatibilityRows/)
  assert.match(dashboardSource, /Real S3 client matrix/)
  assert.match(dashboardSource, /clientCompatibilityRows/)
  assert.match(dashboardSource, /MinIO Client/)
  assert.match(dashboardSource, /s3cmd/)
  assert.match(dashboardSource, /Secret Key/)
  assert.match(dashboardSource, /bucket scope/)
  assert.match(dashboardSource, /Disable expired/)
  assert.match(dashboardSource, /Review stale/)
  assert.match(dashboardSource, /Bulk disable/)
  assert.match(dashboardSource, /Export preview/)
  assert.match(dashboardSource, /cleanup candidates/)
  assert.match(dashboardSource, /recentStorageExpansionExecutions/)
  assert.match(dashboardSource, /executionFailureReason/)
  assert.match(dashboardSource, /gitOpsFailureReasonLabels/)
  assert.match(dashboardSource, /BRANCH_PROTECTION/)
  assert.match(dashboardSource, /appliedEvidence/)
  assert.match(dashboardSource, /handleCreateStorageExpansionRequest/)
  assert.match(dashboardSource, /handlePreviewStorageExpansionManifest/)
  assert.match(dashboardSource, /handleDownloadStorageExpansionManifest/)
  assert.match(dashboardSource, /handleCreateStorageExpansionExecutionPlan/)
  assert.match(dashboardSource, /handleRecordStorageExpansionDryRunExecution/)
  assert.match(dashboardSource, /handleRunStorageExpansionDryRunExecution/)
  assert.match(dashboardSource, /handleRunStorageExpansionApplyExecution/)
  assert.match(dashboardSource, /handleRunStorageExpansionRollbackExecution/)
  assert.match(dashboardSource, /handleRunStorageExpansionExecutionLogRetention/)
  assert.match(dashboardSource, /handleRunStorageExpansionGitOpsPrExecution/)
  assert.match(dashboardSource, /handleCreateStorageExpansionGitOpsPlan/)
  assert.match(dashboardSource, /handleRecordStorageExpansionGitOpsPrExecution/)
  assert.match(dashboardSource, /handleDownloadStorageExpansionGitOpsBundle/)
  assert.match(dashboardSource, /handleLoadStorageExpansionExecutions/)
  assert.match(dashboardSource, /handleCreateStorageExpansionExecutionRecord/)
  assert.match(dashboardSource, /handleApplyStorageExpansionFromExecution/)
  assert.match(dashboardSource, /handleUpdateStorageExpansionStatus/)
  assert.match(dashboardSource, /adminActionRemediation/)
  assert.match(dashboardSource, /handleAdminRemediationPrimary/)
  assert.match(dashboardSource, /AUTHENTICATION_REQUIRED/)
  assert.match(dashboardSource, /AUTHORIZATION_FAILED/)
  assert.match(dashboardSource, /VALIDATION_ERROR/)
  assert.match(dashboardSource, /CONFLICT/)
  assert.match(dashboardSource, /loadStorageExpansionRequests/)
  assert.match(dashboardSource, /id="storage-buckets"/)
  assert.match(dashboardSource, /:data-testid="`readiness-item-\$\{item\.code\}`"/)
  assert.match(dashboardSource, /openReadinessTarget/)
  assert.match(dashboardSource, /@pause-upload="handlePauseUpload"/)
  assert.match(dashboardSource, /preserveSessionOnAbort:\s*\(\) => uploadAbortMode\.value === 'pause'/)
  assert.match(dashboardSource, /function handlePauseUpload\(\)/)
  assert.match(dashboardSource, /Multipart upload paused\. Resume from pending multipart\./)
  assert.match(dashboardSource, /const pendingSessions = pendingMultipartUploads\.value/)
  assert.match(dashboardSource, /title: 'Multipart resume/)
  assert.match(dashboardSource, /handleRevokeObjectShareLink/)
  assert.match(dashboardSource, /handleCleanupObjectShareLinks/)
  assert.match(dashboardSource, /title: 'Bucket lifecycle/)
  assert.match(dashboardSource, /title: 'Bucket tags/)
  assert.match(dashboardSource, /const parsedTags = validateBucketTagInput\(bucketTags\.content\)/)
  assert.match(dashboardSource, /tagPairsToMap\(parsedTags\.tags\)/)
})
