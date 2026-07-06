<template>
  <main class="shell">
    <aside class="sidebar">
      <div class="brand-block">
        <p class="eyebrow">Private Object Storage</p>
        <h1>OSMU</h1>
        <p class="summary">기업 내부 파일을 S3 호환 API와 포털로 운영하는 스토리지 콘솔</p>
      </div>

      <section id="status-list" class="status-list" data-testid="status-list">
        <div v-for="item in statusItems" :key="item.label" class="status-row">
          <span>{{ item.label }}</span>
          <strong :class="['status-pill', statusClass(item.value)]">{{ item.value }}</strong>
        </div>
      </section>

      <nav class="side-nav" aria-label="Dashboard sections">
        <RouterLink
          v-for="item in visibleNavigationItems"
          :key="item.page"
          :to="item.to"
          :class="{ active: activePage === item.page }"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <section v-if="session.user" class="session-card" data-testid="session-card">
        <span>Signed in</span>
        <strong>{{ session.user.name || session.user.loginId }}</strong>
        <small>{{ session.user.role }}</small>
      </section>
    </aside>

    <section class="workspace">
      <header id="overview" class="hero-panel">
        <div class="hero-copy">
          <p class="eyebrow">{{ activePageMeta.eyebrow }}</p>
          <h2>{{ activePageMeta.title }}</h2>
          <p>{{ activePageMeta.description }}</p>
        </div>
        <div class="topbar-actions">
          <button data-testid="refresh-button" type="button" class="ghost" @click="refreshAll">새로고침</button>
          <button data-testid="logout-button" v-if="isLoggedIn" type="button" class="danger" @click="handleLogout">
            로그아웃
          </button>
        </div>
      </header>

      <p v-if="errorMessage" class="alert" data-testid="error-alert">
        <span>{{ errorMessage }}</span>
        <small v-if="errorRequestId">Request ID {{ errorRequestId }}</small>
      </p>
      <section
        v-if="adminActionRemediation"
        class="admin-remediation-panel"
        data-testid="admin-action-remediation-panel"
        role="alert"
        aria-live="polite"
      >
        <div class="admin-remediation-copy">
          <p class="eyebrow">Admin remediation</p>
          <h3 data-testid="admin-action-remediation-title">{{ adminActionRemediation.title }}</h3>
          <p data-testid="admin-action-remediation-detail">{{ adminActionRemediation.detail }}</p>
          <small v-if="adminActionErrorLabel" data-testid="admin-action-remediation-code">{{ adminActionErrorLabel }}</small>
        </div>
        <ol data-testid="admin-action-remediation-steps">
          <li v-for="step in adminActionRemediation.steps" :key="step">{{ step }}</li>
        </ol>
        <button
          v-if="adminActionRemediation.action !== 'none'"
          data-testid="admin-action-remediation-primary"
          type="button"
          class="ghost"
          @click="handleAdminRemediationPrimary"
        >
          {{ adminActionRemediation.primaryAction }}
        </button>
      </section>
      <p v-if="isActionPending" class="busy-alert" data-testid="busy-alert" role="status" aria-live="polite">
        요청 처리 중...
      </p>
      <p v-if="statusMessage" class="success-alert" data-testid="status-alert" role="status" aria-live="polite">
        {{ statusMessage }}
      </p>

      <DashboardPage
        v-if="activePage === 'dashboard'"
        :dashboard-widget-to-add="dashboardWidgetToAdd"
        :available-dashboard-widget-options="availableDashboardWidgetOptions"
        :dashboard-layout-presets="dashboardLayoutPresets"
        :dashboard-layout-preset-to-apply="dashboardLayoutPresetToApply"
        :dashboard-layout-preset-form="dashboardLayoutPresetForm"
        :dashboard-layout-defaults="dashboardLayoutDefaults"
        :dashboard-layout-default-form="dashboardLayoutDefaultForm"
        :dashboard-layout-default-target-options="dashboardLayoutDefaultTargetOptions"
        :can-create-dashboard-layout-preset="isAdmin"
        :can-delete-dashboard-layout-preset="canDeleteDashboardLayoutPreset"
        :can-update-dashboard-layout-preset="canUpdateDashboardLayoutPreset"
        :can-export-dashboard-layout-preset="canExportDashboardLayoutPreset"
        :can-import-dashboard-layout-preset="isAdmin"
        :can-export-dashboard-layout-preset-bundle="isAdmin"
        :can-import-dashboard-layout-preset-bundle="isAdmin"
        :can-manage-dashboard-layout-defaults="isAdmin"
        :dashboard-widgets="dashboardWidgets"
        :visible-dashboard-widgets="visibleDashboardWidgets"
        :dashboard-widget-drag-index="dashboardWidgetDragIndex"
        :dashboard-widget-drop-index="dashboardWidgetDropIndex"
        :dashboard-layout-sync-label="dashboardLayoutSyncLabel"
        :dashboard-layout-pending="dashboardLayoutSync.pending"
        :dashboard-edit-mode="dashboardEditMode"
        :dashboard-loading="dashboardLoadState.loading"
        :dashboard-load-error="dashboardLoadState.error"
        :usage-percent="usagePercent"
        :usage="usage"
        :selected-bucket="selectedBucket"
        :object-view-mode="objectViewMode"
        :health="health"
        :storage-backend-status="storageBackendStatus"
        :backup-status="backupStatus"
        :upload-state="uploadState"
        :data-flow-monitoring="dataFlowMonitoring"
        :data-flow-retention="dataFlowRetention"
        :data-flow-storage-status="dataFlowStorageStatus"
        :data-flow-filter="dataFlowFilter"
        :audit-logs="auditLogs"
        :audit-next-cursor="auditNextCursor"
        :object-share-analytics="objectShareAnalytics"
        :dashboard-quota="dashboardQuota"
        :access-keys="accessKeys"
        :users="users"
        :organizations="organizations"
        :lifecycle-rules="lifecycleRules"
        :lifecycle-rule-conflicts="lifecycleRuleConflicts"
        :runtime-readiness-label="runtimeReadinessLabel"
        :dashboard-readiness="dashboardReadiness"
        :readiness-category-filter="readinessCategoryFilter"
        :readiness-category-options="readinessCategoryOptions"
        :readiness-severity-filter="readinessSeverityFilter"
        :readiness-severity-options="readinessSeverityOptions"
        :visible-readiness-items="visibleReadinessItems"
        :next-action-label="nextActionLabel"
        :retention-policy="retentionPolicy"
        :execution-log-retention="executionLogRetention"
        :storage-expansion-summary="storageExpansionSummary"
        :storage-expansion-requests="storageExpansionRequests"
        :storage-expansion-executions="storageExpansionExecutions"
        :bucket-objects-label="bucketObjectsLabel"
        :is-admin="isAdmin"
        :dashboard-widget-title="dashboardWidgetTitle"
        :dashboard-widget-size-label="dashboardWidgetSizeLabel"
        :dashboard-widget-tone="dashboardWidgetTone"
        :dashboard-widget-tone-label="dashboardWidgetToneLabel"
        :dashboard-widget-refresh-interval-label="dashboardWidgetRefreshIntervalLabel"
        :dashboard-widget-access-label="dashboardWidgetAccessLabel"
        :dashboard-widget-config-options="dashboardWidgetConfigOptions"
        :dashboard-widget-option-value="dashboardWidgetOptionValue"
        :dashboard-sections="dashboardSections"
        :dashboard-widget-sections="dashboardWidgetSections"
        :dashboard-widget-section="dashboardWidgetSection"
        :dashboard-section-collapsed="dashboardSectionCollapsed"
        :dashboard-widget-section-label="dashboardWidgetSectionLabel"
        :format-bytes="formatBytes"
        :format-count="formatCount"
        :status-class="statusClass"
        :quota-policy-percent="quotaPolicyPercent"
        :format-date-time="formatDateTime"
        @update-widget-to-add="dashboardWidgetToAdd = $event"
        @update-dashboard-layout-preset="dashboardLayoutPresetToApply = $event"
        @update-dashboard-layout-preset-name="dashboardLayoutPresetForm.name = $event"
        @update-dashboard-layout-preset-description="dashboardLayoutPresetForm.description = $event"
        @update-dashboard-layout-default-target-type="updateDashboardLayoutDefaultTargetType"
        @update-dashboard-layout-default-target-id="dashboardLayoutDefaultForm.targetId = $event"
        @update-dashboard-layout-default-preset-id="dashboardLayoutDefaultForm.presetId = $event"
        @toggle-dashboard-edit-mode="toggleDashboardEditMode"
        @retry-dashboard-load="loadDashboard"
        @reset-dashboard-widgets="resetDashboardWidgets"
        @add-dashboard-widget="addDashboardWidget"
        @add-dashboard-widget-by-id="addDashboardWidgetById"
        @apply-dashboard-layout-preset="handleApplyDashboardLayoutPreset"
        @create-dashboard-layout-preset="handleCreateDashboardLayoutPreset"
        @update-custom-dashboard-layout-preset="handleUpdateDashboardLayoutPreset"
        @delete-dashboard-layout-preset="handleDeleteDashboardLayoutPreset"
        @export-dashboard-layout-preset="handleExportDashboardLayoutPreset"
        @import-dashboard-layout-preset="handleImportDashboardLayoutPreset"
        @export-dashboard-layout-preset-bundle="handleExportDashboardLayoutPresetBundle"
        @import-dashboard-layout-preset-bundle="handleImportDashboardLayoutPresetBundle"
        @save-dashboard-layout-default="handleSaveDashboardLayoutDefault"
        @delete-dashboard-layout-default="handleDeleteDashboardLayoutDefault"
        @move-dashboard-widget="moveDashboardWidget"
        @start-dashboard-widget-drag="startDashboardWidgetDrag"
        @hover-dashboard-widget-drag="hoverDashboardWidgetDrag"
        @drop-dashboard-widget="dropDashboardWidget"
        @end-dashboard-widget-drag="endDashboardWidgetDrag"
        @move-dashboard-widget-section="moveDashboardWidgetSection"
        @toggle-dashboard-section="toggleDashboardSection"
        @toggle-dashboard-widget-size="toggleDashboardWidgetSize"
        @update-dashboard-widget-section="updateDashboardWidgetSection"
        @update-dashboard-widget-option="updateDashboardWidgetOption"
        @toggle-dashboard-widget="toggleDashboardWidget"
        @remove-dashboard-widget="removeDashboardWidget"
        @load-selected-bucket-details="loadSelectedBucketDetails"
        @run-object-retention-purge="handleRunObjectRetentionPurge"
        @run-storage-expansion-execution-log-retention="handleRunStorageExpansionExecutionLogRetention"
        @open-readiness-target="openReadinessTarget"
        @update-readiness-category-filter="readinessCategoryFilter = $event"
        @update-readiness-severity-filter="readinessSeverityFilter = $event"
        @refresh-dashboard-readiness="handleRefreshDashboardReadiness"
        @update-data-flow-filter="updateDataFlowFilter"
        @refresh-data-flow-monitoring="loadDataFlowMonitoring"
        @export-data-flow-csv="handleExportDataFlowCsv"
        @export-data-flow-daily-rollup-csv="handleExportDataFlowDailyRollupCsv"
        @materialize-data-flow-daily-rollup="handleMaterializeDataFlowDailyRollup"
        @load-materialized-data-flow-daily-rollup="handleLoadMaterializedDataFlowDailyRollup"
        @export-materialized-data-flow-daily-rollup-csv="handleExportMaterializedDataFlowDailyRollupCsv"
        @load-data-flow-monthly-rollup="handleLoadDataFlowMonthlyRollup"
        @export-data-flow-monthly-rollup-csv="handleExportDataFlowMonthlyRollupCsv"
        @materialize-data-flow-monthly-rollup="handleMaterializeDataFlowMonthlyRollup"
        @load-materialized-data-flow-monthly-rollup="handleLoadMaterializedDataFlowMonthlyRollup"
        @export-materialized-data-flow-monthly-rollup-csv="handleExportMaterializedDataFlowMonthlyRollupCsv"
        @refresh-data-flow-retention="loadDataFlowRetention"
        @run-data-flow-retention="handleRunDataFlowRetention"
        @reset-data-flow-filter="handleResetDataFlowFilter"
      />

      <StoragePage
        v-if="activePage === 'storage'"
        :buckets="buckets"
        :bucket-rows="bucketRows"
        :bucket-form="bucketForm"
        :can-create-org-bucket="canCreateOrgBucket"
        :is-admin="isAdmin"
        :organizations="organizations"
        :is-logged-in="isLoggedIn"
        :selected-bucket="selectedBucket"
        :storage-profiles="storageProfiles"
        :bucket-storage-profile="bucketStorageProfile"
        :storage-profile-form="storageProfileForm"
        :storage-profile-requests="storageProfileRequests"
        :format-date-time="formatDateTime"
        :status-class="statusClass"
        @create-bucket="handleCreateBucket"
        @select-bucket="selectBucket"
        @sync-bucket="handleSyncBucket"
        @delete-bucket="handleDeleteBucket"
        @create-storage-profile-request="handleCreateStorageProfileRequest"
        @refresh-bucket-storage-profile="loadBucketStorageProfile"
      />

      <ObjectPage
        v-if="activePage === 'objects'"
        :selected-bucket="selectedBucket"
        :object-prefix="objectPrefix"
        :object-search="objectSearch"
        :object-tag-filter="objectTagFilter"
        :object-list-limit="objectListLimit"
        :object-list-limit-options="objectListLimitOptions"
        :object-view-mode="objectViewMode"
        :object-prefix-breadcrumbs="objectPrefixBreadcrumbs"
        :object-form="objectForm"
        :object-tag-form="objectTagForm"
        :upload-state="uploadState"
        :can-submit-upload="canSubmitUpload"
        :can-retry-upload="canRetryUpload"
        :visible-multipart-resume-sessions="visibleMultipartResumeSessions"
        :object-prefixes="objectPrefixes"
        :objects="objects"
        :object-next-cursor="objectNextCursor"
        :object-metadata="objectMetadata"
        :object-metadata-rows="objectMetadataRows"
        :object-share-links="objectShareLinks"
        :share-link-password="shareLinkPassword"
        :share-link-allowed-ip-cidrs="shareLinkAllowedIpCidrs"
        :share-link-url="shareLinkUrl"
        :object-versions="objectVersions"
        :presigned-url="presignedUrl"
        :pending-upload-id="pendingUploadId"
        :format-bytes="formatBytes"
        :format-multipart-resume-status="formatMultipartResumeStatus"
        :is-matching-resume-session="isMatchingResumeSession"
        :format-prefix-name="formatPrefixName"
        :object-key-parts="objectKeyParts"
        :format-date-time="formatDateTime"
        :format-object-tags="formatObjectTags"
        :metadata-status-class="metadataStatusClass"
        :metadata-status-label="metadataStatusLabel"
        @update-object-prefix="objectPrefix = $event"
        @update-object-search="objectSearch = $event"
        @update-object-tag-filter="objectTagFilter = $event"
        @update-object-list-limit="objectListLimit = $event"
        @update-share-link-password="shareLinkPassword = $event"
        @update-share-link-allowed-ip-cidrs="shareLinkAllowedIpCidrs = $event"
        @load-objects="loadObjects"
        @object-prefix-up="handleObjectPrefixUp"
        @reset-object-filter="handleResetObjectFilter"
        @change-object-view-mode="handleObjectViewModeChange"
        @select-object-prefix="handleSelectObjectPrefix"
        @file-change="handleFileChange"
        @upload-object="handleUploadObject"
        @cancel-upload="handleCancelUpload"
        @pause-upload="handlePauseUpload"
        @retry-upload="handleRetryUpload"
        @resume-matching-multipart-upload="handleResumeMatchingMultipartUpload"
        @discard-multipart-resume="handleDiscardMultipartResume"
        @update-object-tags="handleUpdateObjectTags"
        @reset-object-tag-form="handleResetObjectTagForm"
        @open-object-prefix="handleOpenObjectPrefix"
        @download-object="handleDownloadObject"
        @create-presigned-download-url="handleCreatePresignedDownloadUrl"
        @create-presigned-upload-url="handleCreatePresignedUploadUrl"
        @complete-presigned-upload="handleCompletePresignedUpload"
        @start-object-tag-edit="handleStartObjectTagEdit"
        @load-object-metadata="handleLoadObjectMetadata"
        @create-object-share-link="handleCreateObjectShareLink"
        @load-object-versions="handleLoadObjectVersions"
        @delete-object="handleDeleteObject"
        @restore-object="handleRestoreObject"
        @purge-object="handlePurgeObject"
        @load-next-objects="handleLoadNextObjects"
        @close-object-metadata="objectMetadata = null"
        @cleanup-object-share-links="handleCleanupObjectShareLinks"
        @revoke-object-share-link="handleRevokeObjectShareLink"
        @close-object-versions="resetObjectVersions"
        @download-object-version="handleDownloadObjectVersion"
        @restore-object-version="handleRestoreObjectVersion"
        @delete-object-version="handleDeleteObjectVersion"
      />

      <DeveloperPage
        v-if="activePage === 'developer'"
        :access-key-form="accessKeyForm"
        :buckets="buckets"
        :is-logged-in="isLoggedIn"
        :new-secret-key="newSecretKey"
        :access-keys="accessKeys"
        :audit-logs="auditLogs"
        :selected-bucket="selectedBucket"
        :s3-client-config="s3ClientConfig"
        :format-key-scope="formatKeyScope"
        @create-access-key="handleCreateAccessKey"
        @add-access-key-scope="handleAddAccessKeyScope"
        @remove-access-key-scope="handleRemoveAccessKeyScope"
        @rotate-access-key="handleRotateAccessKey"
        @delete-access-key="handleDeleteAccessKey"
        @bulk-disable-access-keys="handleBulkDisableAccessKeys"
      />

      <AdminPage
        v-if="activePage === 'admin'"
        :access-key-form="accessKeyForm"
        :buckets="buckets"
        :is-logged-in="isLoggedIn"
        :new-secret-key="newSecretKey"
        :access-keys="accessKeys"
        :audit-logs="auditLogs"
        :selected-bucket="selectedBucket"
        :can-show-bucket-permissions="canShowBucketPermissions"
        :bucket-permission-form="bucketPermissionForm"
        :users="users"
        :organizations="organizations"
        :teams="teams"
        :team-form="teamForm"
        :bucket-permissions="bucketPermissions"
        :can-use-bucket-lifecycle="canUseBucketLifecycle"
        :bucket-lifecycle-xml="bucketLifecycleXml"
        :can-use-bucket-tags="canUseBucketTags"
        :bucket-tags="bucketTags"
        :is-admin="isAdmin"
        :object-share-policy-form="objectSharePolicyForm"
        :object-share-analytics="objectShareAnalytics"
        :object-share-analytics-filter="objectShareAnalyticsFilter"
        :enterprise-auth-plan="enterpriseAuthPlan"
        :chargeback-options="chargebackOptions"
        :chargeback-preview="chargebackPreview"
        :chargeback-daily-rollup="chargebackDailyRollup"
        :chargeback-alerts="chargebackAlerts"
        :chargeback-alert-notification-preview="chargebackAlertNotificationPreview"
        :chargeback-alert-notification-outbox="chargebackAlertNotificationOutbox"
        :chargeback-invoice-drafts="chargebackInvoiceDrafts"
        :chargeback-final-invoices="chargebackFinalInvoices"
        :chargeback-payment-provider-handoffs="chargebackPaymentProviderHandoffs"
        :chargeback-payment-provider-adapter-readiness="chargebackPaymentProviderAdapterReadiness"
        :chargeback-adapter-retry-worker="chargebackAdapterRetryWorker"
        :billing-pricing-policy="billingPricingPolicy"
        :billing-pricing-policy-proposals="billingPricingPolicyProposals"
        :quota-policy-form="quotaPolicyForm"
        :quota-policy-target-options="quotaPolicyTargetOptions"
        :quota-policies="quotaPolicies"
        :quota-policy-history="quotaPolicyHistory"
        :storage-expansion-form="storageExpansionForm"
        :storage-expansion-requests="storageExpansionRequests"
        :storage-expansion-manifest="storageExpansionManifest"
        :storage-expansion-execution-plan="storageExpansionExecutionPlan"
        :storage-expansion-git-ops-plan="storageExpansionGitOpsPlan"
        :storage-expansion-executions="storageExpansionExecutions"
        :storage-expansion-execution-form="storageExpansionExecutionForm"
        :storage-expansion-apply-evidence="storageExpansionApplyEvidence"
        :storage-expansion-runner-preflight="storageExpansionRunnerPreflight"
        :storage-profile-requests="storageProfileRequests"
        :storage-profile-admin-note="storageProfileAdminNote"
        :lifecycle-rule-form="lifecycleRuleForm"
        :lifecycle-rules="lifecycleRules"
        :lifecycle-rule-preview="lifecycleRulePreview"
        :lifecycle-rule-conflicts="lifecycleRuleConflicts"
        :lifecycle-xml="lifecycleXml"
        :can-use-admin-tools="canUseAdminTools"
        :organization-form="organizationForm"
        :organization-usages="organizationUsages"
        :user-form="userForm"
        :session="session"
        :format-key-scope="formatKeyScope"
        :format-date-time="formatDateTime"
        :format-bytes="formatBytes"
        :status-class="statusClass"
        @create-access-key="handleCreateAccessKey"
        @add-access-key-scope="handleAddAccessKeyScope"
        @remove-access-key-scope="handleRemoveAccessKeyScope"
        @rotate-access-key="handleRotateAccessKey"
        @delete-access-key="handleDeleteAccessKey"
        @bulk-disable-access-keys="handleBulkDisableAccessKeys"
        @grant-bucket-permissions="handleGrantBucketPermissions"
        @revoke-bucket-permission="handleRevokeBucketPermission"
        @load-bucket-lifecycle-xml="loadBucketLifecycleXml"
        @put-bucket-lifecycle-xml="handlePutBucketLifecycleXml"
        @delete-bucket-lifecycle-xml="handleDeleteBucketLifecycleXml"
        @load-bucket-tags="loadBucketTags"
        @put-bucket-tags="handlePutBucketTags"
        @delete-bucket-tags="handleDeleteBucketTags"
        @save-object-share-policy="handleSaveObjectSharePolicy"
        @refresh-object-share-analytics="refreshObjectShareAnalytics"
        @update-chargeback-option="updateChargebackOption"
        @refresh-chargeback-preview="loadChargebackPanel"
        @reset-chargeback-options="handleResetChargebackOptions"
        @save-billing-pricing-policy="handleSaveBillingPricingPolicy"
        @create-billing-pricing-policy-proposal="handleCreateBillingPricingPolicyProposal"
        @approve-billing-pricing-policy-proposal="handleApproveBillingPricingPolicyProposal"
        @approve-billing-pricing-policy-proposal-price-list="handleApproveBillingPricingPolicyProposalPriceList"
        @queue-chargeback-alert-notifications="handleQueueChargebackAlertNotifications"
        @export-chargeback-csv="handleExportChargebackCsv"
        @export-chargeback-daily-rollup-csv="handleExportChargebackDailyRollupCsv"
        @export-chargeback-invoice-draft-csv="handleExportChargebackInvoiceDraftCsv"
        @create-chargeback-invoice-drafts="handleCreateChargebackInvoiceDrafts"
        @approve-chargeback-invoice-draft="handleApproveChargebackInvoiceDraft"
        @finalize-chargeback-invoice-draft="handleFinalizeChargebackInvoiceDraft"
        @request-chargeback-invoice-payment="handleRequestChargebackInvoicePayment"
        @queue-chargeback-payment-provider-handoff="handleQueueChargebackPaymentProviderHandoff"
        @send-chargeback-notification-adapter="handleSendChargebackNotificationAdapter"
        @send-chargeback-payment-provider-adapter="handleSendChargebackPaymentProviderAdapter"
        @record-chargeback-notification-adapter-result="handleRecordChargebackNotificationAdapterResult"
        @record-chargeback-payment-provider-adapter-result="handleRecordChargebackPaymentProviderAdapterResult"
        @refresh-chargeback-adapter-retry-worker="loadChargebackAdapterRetryWorker"
        @run-chargeback-adapter-retry-worker="handleRunChargebackAdapterRetryWorker"
        @record-chargeback-invoice-payment="handleRecordChargebackInvoicePayment"
        @save-quota-policy="handleSaveQuotaPolicy"
        @reset-quota-policy-target="resetQuotaPolicyTarget"
        @reset-quota-policy-form="resetQuotaPolicyForm"
        @edit-quota-policy="editQuotaPolicy"
        @delete-quota-policy="handleDeleteQuotaPolicy"
        @create-storage-expansion-request="handleCreateStorageExpansionRequest"
        @preview-storage-expansion-manifest="handlePreviewStorageExpansionManifest"
        @download-storage-expansion-manifest="handleDownloadStorageExpansionManifest"
        @download-storage-expansion-gitops-bundle="handleDownloadStorageExpansionGitOpsBundle"
        @create-storage-expansion-execution-plan="handleCreateStorageExpansionExecutionPlan"
        @record-storage-expansion-dry-run-execution="handleRecordStorageExpansionDryRunExecution"
        @run-storage-expansion-dry-run-execution="handleRunStorageExpansionDryRunExecution"
        @run-storage-expansion-apply-execution="handleRunStorageExpansionApplyExecution"
        @run-storage-expansion-rollback-execution="handleRunStorageExpansionRollbackExecution"
        @create-storage-expansion-gitops-plan="handleCreateStorageExpansionGitOpsPlan"
        @run-storage-expansion-gitops-pr-execution="handleRunStorageExpansionGitOpsPrExecution"
        @record-storage-expansion-gitops-pr-execution="handleRecordStorageExpansionGitOpsPrExecution"
        @load-storage-expansion-executions="handleLoadStorageExpansionExecutions"
        @create-storage-expansion-execution-record="handleCreateStorageExpansionExecutionRecord"
        @apply-storage-expansion-from-execution="handleApplyStorageExpansionFromExecution"
        @update-storage-expansion-apply-evidence="storageExpansionApplyEvidence = $event"
        @refresh-storage-expansion-runner-preflight="loadStorageExpansionRunnerPreflight"
        @update-storage-expansion-status="handleUpdateStorageExpansionStatus"
        @update-storage-profile-admin-note="storageProfileAdminNote = $event"
        @update-storage-profile-request-status="handleUpdateStorageProfileRequestStatus"
        @apply-storage-profile-request="handleApplyStorageProfileRequest"
        @reset-lifecycle-rule-form="resetLifecycleRuleForm"
        @save-object-lifecycle-rule="handleSaveObjectLifecycleRule"
        @dry-run-object-lifecycle-rule="handleDryRunObjectLifecycleRule"
        @edit-lifecycle-rule="editLifecycleRule"
        @delete-object-lifecycle-rule="handleDeleteObjectLifecycleRule"
        @refresh-lifecycle-rule-conflicts="refreshLifecycleRuleConflicts"
        @export-lifecycle-xml="handleExportLifecycleXml"
        @import-lifecycle-xml="handleImportLifecycleXml"
        @create-organization="handleCreateOrganization"
        @create-team="handleCreateTeam"
        @delete-team="handleDeleteTeam"
        @create-user="handleCreateUser"
        @toggle-user-status="handleToggleUserStatus"
      />

      <AuditPage
        v-if="activePage === 'audit'"
        :is-admin="isAdmin"
        :is-logged-in="isLoggedIn"
        :audit-filter="auditFilter"
        :audit-logs="auditLogs"
        :audit-next-cursor="auditNextCursor"
        @load-audit-logs="handleLoadAuditLogs"
        @export-audit-csv="handleExportAuditCsv"
        @reset-audit-filter="handleResetAuditFilter"
        @load-next-audit-logs="handleLoadNextAuditLogs"
      />
    </section>

    <div
      v-if="confirmDialog.open"
      class="modal-backdrop"
      data-testid="confirm-backdrop"
      role="presentation"
      @click.self="closeConfirmDialog"
    >
      <section class="confirm-modal" data-testid="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="confirm-dialog-title">
        <div>
          <p class="eyebrow">Confirm</p>
          <h3 id="confirm-dialog-title">{{ confirmDialog.title }}</h3>
        </div>
        <p>{{ confirmDialog.message }}</p>
        <div class="modal-actions">
          <button data-testid="confirm-cancel-button" type="button" class="ghost" :disabled="confirmDialog.pending" @click="closeConfirmDialog">
            취소
          </button>
          <button data-testid="confirm-submit-button" type="button" class="danger" :disabled="confirmDialog.pending" @click="handleConfirmDialogAction">
            {{ confirmDialog.pending ? '처리 중' : confirmDialog.confirmLabel }}
          </button>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminPage from '@/components/admin/AdminPage.vue'
import AuditPage from '@/components/audit/AuditPage.vue'
import DashboardPage from '@/components/dashboard/DashboardPage.vue'
import DeveloperPage from '@/components/developer/DeveloperPage.vue'
import ObjectPage from '@/components/objects/ObjectPage.vue'
import StoragePage from '@/components/storage/StoragePage.vue'
import {
  MULTIPART_UPLOAD_THRESHOLD_BYTES,
  approveBillingPricingPolicyProposal,
  approveBillingPricingPolicyProposalPriceList,
  approveChargebackInvoiceDraft,
  applyStorageExpansionExecutionRecord,
  applyStorageProfileRequest,
  applyDashboardLayoutPreset,
  bulkDisableAccessKeys,
  cleanupObjectShareLinks,
  completePresignedUpload,
  createAccessKey,
  createBillingPricingPolicyProposal,
  createBucket,
  createChargebackInvoiceDrafts,
  createDashboardLayoutPreset,
  createObjectShareLink,
  createOrganization,
  createPresignedDownloadUrl,
  createPresignedUploadUrl,
  createTeam,
  createStorageExpansionExecutionRecord,
  createStorageExpansionExecutionPlan,
  createStorageExpansionGitOpsPlan,
  createStorageExpansionRequest,
  createStorageProfileRequest,
  createUser,
  deleteAccessKey,
  deleteBucket,
  deleteBucketLifecycleS3Xml,
  deleteBucketTags,
  deleteDashboardLayout,
  deleteDashboardLayoutDefault,
  deleteDashboardLayoutPreset,
  deleteObject,
  deleteObjectLifecycleRule,
  deleteObjectShareLink,
  deleteObjectVersion,
  deleteTeam,
  deleteQuotaPolicy,
  deleteStoredMultipartUploadSession,
  downloadChargebackDailyRollupCsv,
  downloadChargebackInvoiceDraftCsv,
  downloadChargebackPreviewCsv,
  downloadStorageExpansionGitOpsArtifactBundle,
  downloadStorageExpansionManifestArtifact,
  downloadObject,
  downloadObjectVersion,
  downloadDataFlowDailyRollupCsv,
  downloadMaterializedDataFlowDailyRollupCsv,
  downloadDataFlowMonthlyRollupCsv,
  downloadMaterializedDataFlowMonthlyRollupCsv,
  downloadDataFlowMonitoringCsv,
  dryRunObjectLifecycleRule,
  finalizeChargebackInvoiceDraft,
  exportDashboardLayoutPreset,
  exportDashboardLayoutPresetBundle,
  getAccessKeys,
  getAuditLogs,
  getBackupStatus,
  getBillingPricingPolicy,
  getBillingPricingPolicyProposals,
  getBucketLifecycleS3Xml,
  getBucketPermissions,
  getBucketStorageProfile,
  getBucketTags,
  getBuckets,
  getChargebackAdapterRetryWorkerStatus,
  getChargebackAlertNotificationPreview,
  getChargebackAlertNotificationOutbox,
  getChargebackAlerts,
  getChargebackDailyRollup,
  getChargebackFinalInvoices,
  getChargebackInvoiceDrafts,
  getChargebackPaymentProviderAdapterReadiness,
  getChargebackPaymentProviderHandoffs,
  getDatabaseHealth,
  getDashboardLayout,
  getDashboardLayoutDefaults,
  getDashboardLayoutPresets,
  getDashboardReadiness,
  getDashboardSummary,
  getDashboardWidgetCatalog,
  getDataFlowDailyRollup,
  getDataFlowMonthlyRollup,
  getDataFlowRetentionStatus,
  getDataFlowStorageStatus,
  getMaterializedDataFlowDailyRollup,
  getMaterializedDataFlowMonthlyRollup,
  getDataFlowMonitoring,
  getChargebackPreview,
  getEnterpriseAuthPlan,
  getHealth,
  getObjectLifecycleConflicts,
  getObjectLifecycleRules,
  getObjectLifecycleS3Xml,
  getObjectMetadata,
  getObjectRetentionStatus,
  getObjectShareAnalytics,
  getObjectShareLinks,
  getObjectSharePolicy,
  getObjects,
  getOrganizations,
  getOrganizationUsage,
  getQuotaPolicies,
  getQuotaPolicyHistory,
  getS3ClientConfig,
  getStorageBackendStatus,
  getStorageHealth,
  getStorageExpansionExecutionLogRetentionStatus,
  getStorageExpansionRequestManifest,
  getStorageExpansionExecutions,
  getStorageExpansionRequests,
  getStorageExpansionRunnerPreflight,
  getStorageExpansionSummary,
  getStorageProfiles,
  getStorageProfileRequests,
  getTeams,
  getAdminStorageProfileRequests,
  getUsage,
  getUsers,
  getStoredMultipartUploadSessionForFile,
  getStoredMultipartUploadSessions,
  grantBucketPermissions,
  importDashboardLayoutPreset,
  importDashboardLayoutPresetBundle,
  importObjectLifecycleS3Xml,
  listObjectVersions,
  logout as logoutApi,
  materializeDataFlowDailyRollup,
  materializeDataFlowMonthlyRollup,
  purgeObject,
  putBucketLifecycleS3Xml,
  putBucketTags,
  queueChargebackAlertNotifications,
  queueChargebackPaymentProviderHandoff,
  recordChargebackAlertNotificationAdapterResult,
  recordChargebackInvoicePayment,
  recordChargebackPaymentProviderHandoffAdapterResult,
  requestChargebackInvoicePayment,
  restoreObject,
  restoreObjectVersion,
  revokeBucketPermission,
  recordStorageExpansionDryRunExecution,
  recordStorageExpansionGitOpsPrExecution,
  rotateAccessKey,
  runStorageExpansionApplyExecution,
  runStorageExpansionDryRunExecution,
  runStorageExpansionRollbackExecution,
  runStorageExpansionExecutionLogRetention,
  runDataFlowRetention,
  runChargebackAdapterRetryWorker,
  runStorageExpansionGitOpsPrExecution,
  runObjectRetentionPurge,
  saveDashboardLayoutDefault,
  saveBillingPricingPolicy,
  saveObjectLifecycleRule,
  saveObjectSharePolicy,
  sendChargebackAlertNotificationAdapter,
  sendChargebackPaymentProviderHandoffAdapter,
  saveDashboardLayout,
  saveQuotaPolicy,
  syncBucketUsage,
  updateDashboardLayoutPreset,
  updateObjectTags,
  updateStorageExpansionRequestStatus,
  updateStorageProfileRequestStatus,
  updateUserStatus,
  uploadObject,
  uploadObjectMultipart,
} from '@/services/api'
import { useAuthStore } from '@/stores/auth'
import {
  buildObjectMetadataDetailRows,
  buildObjectPrefixBreadcrumbs,
  formatPrefixName,
  parentObjectPrefix,
  splitObjectKeyBySearch,
} from '@/utils/objectExplorer'
import { buildBucketListRows, summarizeBuckets } from '@/utils/buckets'
import { canStartUpload } from '@/utils/uploads'
import { tagPairsToMap, tagsToInput, validateBucketTagInput, validateObjectTagInput } from '@/utils/tags'

const BYTES_PER_GIB = 1024 * 1024 * 1024
const objectListLimitOptions = [50, 100, 250, 500, 1000]
const DASHBOARD_LAYOUT_SCHEMA_VERSION = 'osmu.dashboard-layout.v1'
const DASHBOARD_WIDGET_STORAGE_KEY = 'osmu.dashboard.widgets.v1'
const DASHBOARD_SECTION_STORAGE_KEY = 'osmu.dashboard.sections.v1'
const navigationItems = [
  { page: 'dashboard', to: '/dashboard', label: 'Dashboard', roles: ['ADMIN', 'ORG_ADMIN', 'AUDITOR', 'USER'] },
  { page: 'storage', to: '/storage', label: 'Storage', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'objects', to: '/objects', label: 'Objects', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'developer', to: '/developer', label: 'Developer', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'admin', to: '/admin', label: 'Admin', roles: ['ADMIN', 'ORG_ADMIN'] },
  { page: 'audit', to: '/audit', label: 'Audit', roles: ['ADMIN', 'AUDITOR'] },
]
const pageMeta = {
  dashboard: {
    eyebrow: 'Operations Dashboard',
    title: '필요한 운영 패널만 골라 보는 대시보드입니다.',
    description: '용량, 상태, 입출력, 요청 현황 같은 팔레트를 추가하고 순서를 바꿔 운영 관점을 직접 구성합니다.',
  },
  storage: {
    eyebrow: 'Storage',
    title: '버킷을 만들고 용량과 소유 범위를 관리합니다.',
    description: '부서 또는 사용자 단위 버킷을 만들고, 동기화와 삭제 같은 스토리지 관리 작업을 수행합니다.',
  },
  objects: {
    eyebrow: 'Objects',
    title: '선택한 버킷 안의 파일을 탐색하고 업로드합니다.',
    description: 'prefix, 검색, 태그 필터로 파일을 찾고 업로드, 다운로드, 공유 링크, 버전 작업을 처리합니다.',
  },
  developer: {
    eyebrow: 'Developer',
    title: 'Access Key와 S3 호환 접속을 관리합니다.',
    description: '개발자는 허용된 버킷 scope로 API Key를 발급하고 S3 호환 경로로 데이터를 저장합니다.',
  },
  admin: {
    eyebrow: 'Admin',
    title: '접근 키, 정책, 조직, 사용자를 관리합니다.',
    description: 'S3 접근 키, 버킷 권한, 라이프사이클, 쿼터, 공유 정책 같은 운영 정책을 한 곳에서 다룹니다.',
  },
  audit: {
    eyebrow: 'Audit',
    title: '요청과 변경 이력을 추적합니다.',
    description: '이벤트 유형, 행위자, 대상, 결과, 요청 ID 기준으로 감사 로그를 조회하고 CSV로 내보냅니다.',
  },
}
const defaultDashboardWidgetCatalog = [
  { id: 'capacity', title: '스토리지 사용률', description: '전체 할당 대비 사용률', category: 'STORAGE', adminOnly: false },
  { id: 'remaining', title: '남은 용량', description: '남은 할당 용량', category: 'STORAGE', adminOnly: false },
  { id: 'buckets', title: '버킷 현황', description: '버킷 수와 선택 상태', category: 'STORAGE', adminOnly: false },
  { id: 'objects', title: '오브젝트 현황', description: '오브젝트 수와 보기 모드', category: 'OBJECTS', adminOnly: false },
  { id: 'health', title: '서비스 상태', description: 'backend/storage/database 상태', category: 'OPERATIONS', adminOnly: false },
  { id: 'runtime', title: '런타임 엔진', description: 'metadata/object/access key runtime', category: 'OPERATIONS', adminOnly: false },
  { id: 'readiness', title: '데모 준비도', description: '배포 준비도 warning/blocker', category: 'OPERATIONS', adminOnly: false },
  { id: 'backup', title: '백업 준비도', description: '백업/복구 RPO/RTO 상태', category: 'OPERATIONS', adminOnly: false },
  { id: 'io', title: '데이터 입출력', description: '트래픽, 업로드/다운로드, 실패/취소 흐름', category: 'OBJECTS', adminOnly: false },
  { id: 'requests', title: '요청/감사 현황', description: '최근 감사 이벤트', category: 'AUDIT', adminOnly: true, allowedRoles: ['ADMIN', 'AUDITOR'], accessMode: 'read-only' },
  { id: 'sharing', title: '공유 링크 현황', description: '공유 링크 운영 지표', category: 'SHARING', adminOnly: true },
  { id: 'quota', title: '쿼터 정책 경보', description: '쿼터 warning/exhausted 지표', category: 'GOVERNANCE', adminOnly: true },
  { id: 'access-keys', title: 'Access Key 운영', description: 'S3 access key 활성 상태', category: 'SECURITY', adminOnly: false },
  { id: 'identity', title: '사용자/조직 현황', description: '사용자와 조직 inventory', category: 'IDENTITY', adminOnly: true },
  { id: 'lifecycle', title: 'Lifecycle 규칙', description: 'lifecycle rule과 conflict', category: 'GOVERNANCE', adminOnly: true },
  { id: 'selected', title: '선택 워크스페이스', description: '선택 bucket과 다음 작업', category: 'WORKSPACE', adminOnly: false },
  { id: 'retention', title: '보존 정책', description: '휴지통 retention 상태', category: 'GOVERNANCE', adminOnly: true },
  { id: 'execution-retention', title: 'Execution Log Retention', description: 'Storage Expansion execution output retention status', category: 'GOVERNANCE', adminOnly: true },
  { id: 'storage-expansion', title: 'Storage Expansion', description: 'Storage expansion request and execution status', category: 'OPERATIONS', adminOnly: true },
]
const dashboardWidgetCatalog = ref([...defaultDashboardWidgetCatalog])
const dashboardWidgetSizes = ['compact', 'normal', 'wide']
const dashboardWidgetSizeLabels = {
  compact: 'Compact',
  normal: 'Normal',
  wide: 'Wide',
}
const dashboardWidgetTones = ['default', 'focus', 'muted']
const dashboardWidgetToneLabels = {
  default: 'Standard',
  focus: 'Focus',
  muted: 'Muted',
}
const dashboardWidgetRefreshIntervals = ['manual', '30s', '60s', '5m', '15m']
const dashboardWidgetRefreshIntervalLabels = {
  manual: 'Manual refresh',
  '30s': '30s refresh',
  '60s': '60s refresh',
  '5m': '5m refresh',
  '15m': '15m refresh',
}
const dashboardWidgetRefreshIntervalMs = {
  '30s': 30_000,
  '60s': 60_000,
  '5m': 300_000,
  '15m': 900_000,
}
const defaultDashboardWidgetConfigOptions = [
  { key: 'tone', label: 'Tone', type: 'select', values: dashboardWidgetTones, defaultValue: 'default' },
  { key: 'refreshInterval', label: 'Refresh', type: 'select', values: dashboardWidgetRefreshIntervals, defaultValue: 'manual' },
]
const dashboardWidgetSections = [
  { id: 'overview', label: 'Overview' },
  { id: 'operations', label: 'Operations' },
  { id: 'governance', label: 'Governance' },
]
const defaultDashboardSections = dashboardWidgetSections.map((section) => ({ id: section.id, collapsed: false }))
const dashboardLayoutDefaultRoleOptions = [
  { id: 'ADMIN', label: 'ADMIN' },
  { id: 'ORG_ADMIN', label: 'ORG_ADMIN' },
  { id: 'AUDITOR', label: 'AUDITOR' },
  { id: 'USER', label: 'USER' },
]
const defaultDashboardWidgets = [
  { id: 'capacity', enabled: true, size: 'normal', section: 'overview' },
  { id: 'health', enabled: true, size: 'normal', section: 'overview' },
  { id: 'runtime', enabled: true, size: 'normal', section: 'overview' },
  { id: 'readiness', enabled: true, size: 'normal', section: 'overview' },
  { id: 'backup', enabled: true, size: 'normal', section: 'operations' },
  { id: 'io', enabled: true, size: 'normal', section: 'operations' },
  { id: 'requests', enabled: true, size: 'normal', section: 'operations' },
  { id: 'sharing', enabled: true, size: 'normal', section: 'governance' },
  { id: 'quota', enabled: true, size: 'normal', section: 'governance' },
  { id: 'access-keys', enabled: true, size: 'normal', section: 'operations' },
  { id: 'lifecycle', enabled: true, size: 'normal', section: 'governance' },
  { id: 'execution-retention', enabled: true, size: 'normal', section: 'governance' },
  { id: 'storage-expansion', enabled: true, size: 'normal', section: 'operations' },
  { id: 'selected', enabled: true, size: 'normal', section: 'overview' },
]
const defaultChargebackOptions = Object.freeze({
  from: '',
  to: '',
  currency: 'USD',
  storageGbMonthRate: '0',
  ingressGbRate: '0',
  egressGbRate: '0',
  internalGbRate: '0',
  operationThousandRate: '0',
  warningAmount: '0',
  criticalAmount: '0',
  notificationChannel: 'WEBHOOK',
  notificationTarget: '',
  paymentProvider: 'MANUAL_AP',
  paymentTargetAccount: '',
  eventScanLimit: 10000,
})
const chargebackRateFields = [
  'storageGbMonthRate',
  'ingressGbRate',
  'egressGbRate',
  'internalGbRate',
  'operationThousandRate',
]

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const session = auth.state
const isLoggedIn = auth.isLoggedIn
const isAdmin = auth.isAdmin
const isOrgAdmin = auth.isOrgAdmin
const isAuditor = auth.isAuditor
const canUseAdminTools = auth.canUseAdminTools
const canUseAuditTools = auth.canUseAuditTools

const health = reactive({
  backend: 'DOWN',
  storage: 'DOWN',
  database: 'DOWN',
  accessKeyProvisioner: 'UNKNOWN',
  metadataEngine: '-',
  storageEngine: '-',
})
const usage = reactive({ totalQuotaBytes: 0, usedBytes: 0, remainingBytes: 0, bucketCount: 0, objectCount: 0 })
const storageBackendStatus = reactive(defaultStorageBackendStatus())
const backupStatus = reactive({
  status: 'UNKNOWN',
  metadataStore: '-',
  objectStore: '-',
  databaseHealthy: false,
  storageHealthy: false,
  rpoTarget: '-',
  rtoTarget: '-',
  runbookAvailable: false,
  restoreDrillExecuted: false,
  lastBackupAt: '',
  lastRestoreDrillAt: '',
  latestRestoreDrillEvidence: null,
  pendingGates: [],
})
const dashboardReadiness = reactive({
  status: 'UNKNOWN',
  runtimeProfile: '-',
  blockerCount: 0,
  warningCount: 0,
  blockers: [],
  warnings: [],
  severitySummaries: [],
  categorySummaries: [],
  items: [],
  operationsReadinessSummary: {
    result: '',
    summary: '',
    reportPath: '',
    generatedAt: '',
    passedCount: 0,
    pendingCount: 0,
    totalCount: 0,
    checkCount: 0,
    pendingCategorySummary: '',
    pendingCategoryCounts: [],
    pendingRemediationCount: 0,
    pendingRemediations: [],
    decisionRule: '',
  },
  operationsEvidencePlan: {
    result: '',
    sourceSummary: '',
    sourceReport: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    sourcePendingRemediationCount: 0,
    sourcePendingRemediationEntryCount: 0,
    sourcePendingRemediationActionCount: 0,
    sourcePendingRemediationMissingActionCount: 0,
    sourcePendingRemediationCoverageReady: false,
    pendingCount: 0,
    actionCount: 0,
    unplannedCount: 0,
    pendingCategorySummary: '',
    pendingCategoryCounts: [],
    actionSummary: {
      totalActions: 0,
      kubernetesLiveActions: 0,
      securityCiActions: 0,
      operatorRemediationActions: 0,
      requiresOperatorApprovalCount: 0,
      requiresKubeconfigSecretCount: 0,
      actionsWithPlaceholdersCount: 0,
      unplannedCheckCount: 0,
    },
    actions: [],
  },
  operationsEvidenceInvocation: {
    result: '',
    sourceSummary: '',
    sourcePlan: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    commandMode: '',
    executionMode: '',
    selectedActionCount: 0,
    selectedActionOrders: [],
    plannedCount: 0,
    blockedCount: 0,
    executedCount: 0,
    failedCount: 0,
    actions: [],
  },
  operationsInvocationUnblockPlan: {
    result: '',
    sourceInvocationReport: '',
    sourceResult: '',
    sourceSummary: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    selectedActionCount: 0,
    plannedCount: 0,
    blockedCount: 0,
    failedCount: 0,
    needsKubeconfigSecretConfirmation: false,
    needsOperatorApprovalConfirmation: false,
    requiredPlaceholderCount: 0,
    ambiguousRepeatedPlaceholderCount: 0,
    confirmationGroupCount: 0,
    requiredInputGroupCount: 0,
    blockedActionOrders: [],
    plannedActionOrders: [],
    confirmedPlanCommand: '',
    blockedOnlyPlanCommand: '',
    plannedOnlyCommand: '',
    decisionRule: '',
    confirmationGroups: [],
    requiredInputGroups: [],
    actions: [],
  },
  operationsDispatchPreflight: {
    result: '',
    sourceUnblockPlan: '',
    sourceResult: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    selectedActionCount: 0,
    selectedActionOrders: [],
    readyActionCount: 0,
    readyActionOrders: [],
    blockedActionCount: 0,
    blockedActionOrders: [],
    needsKubeconfigSecretConfirmation: false,
    needsOperatorApprovalConfirmation: false,
    requiredInputCount: 0,
    missingInputCount: 0,
    ambiguousInputCount: 0,
    unsafeInputCount: 0,
    invalidInputCount: 0,
    failedCheckCount: 0,
    warningCheckCount: 0,
    requiredGitHubSecrets: [],
    githubCliPath: '',
    githubRepository: '',
    githubRef: '',
    gitRefSafety: {
      checked: false,
      status: '',
      githubRef: '',
      currentBranch: '',
      commitSha: '',
      shortCommitSha: '',
      upstreamRef: '',
      upstreamCommitSha: '',
      aheadCount: 0,
      behindCount: 0,
      workingTreeDirty: false,
      githubRefMatchesCurrentBranch: false,
      githubRefLikelyContainsCommit: false,
      suggestedGitHubRef: '',
      suggestedPushCommand: '',
      note: '',
    },
    workflowFiles: [],
    checks: [],
    readyPlanCommand: '',
    executeCommand: '',
    apiExecuteCommand: '',
    readySubsetPlanCommand: '',
    readySubsetExecuteCommand: '',
    readySubsetApiExecuteCommand: '',
    requiredInputs: [],
    inputTemplates: [],
    decisionRule: '',
  },
  operationsWorkflowRunIdPlan: {
    result: '',
    sourceInvocationReport: '',
    invocationResult: '',
    sourceSummary: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    selectedActionOrders: [],
    branch: '',
    githubRepository: '',

    queryMode: '',
    githubApiTokenPresent: false,
    githubApiUnauthenticated: false,
    queryExecuted: false,
    queryExecutedCount: 0,
    queryWorkflowCount: 0,
    querySucceededCount: 0,
    queryErrorCount: 0,
    candidateCount: 0,
    runListJsonDirectory: '',
    runListJsonDirectoryCommand: '',
    githubApiRunListCommand: '',
    githubApiBaseUrl: '',
    runListJsonFilePattern: '',
    runListJsonHandoffNote: '',
    browserWorkflowRunsUrls: [],
    workflowRunIdInputs: [],
    recommendedCommands: [],
    limit: 0,
    workflowCount: 0,
    readyWorkflowCount: 0,
    missingWorkflowCount: 0,
    staleWorkflowCount: 0,
    imageSigningVersion: '',
    commitSha: '',
    artifactCollectionPlanCommand: '',
    securityEvidenceFinalizerCommand: '',
    decisionRule: '',
    workflows: [],
  },
  operationsArtifactCollectionPlan: {
    result: '',
    sourceInvocationReport: '',
    invocationResult: '',
    sourceSummary: '',
    sourcePassedCount: 0,
    sourcePendingCount: 0,
    sourceTotalCount: 0,
    sourceCheckCount: 0,
    selectedActionOrders: [],
    invocationSummary: '',
    artifactCount: 0,
    requiredArtifactCount: 0,
    readyArtifactCount: 0,
    missingRequiredArtifactCount: 0,
    securitySourceArtifactCount: 0,
    readySecuritySourceArtifactCount: 0,
    missingSecuritySourceArtifactCount: 0,
    securityEvidenceFinalizerReady: false,
    securityEvidenceFinalizerInputs: [],
    securityEvidenceFinalizerMissingRunIdInputs: [],
    securityEvidenceFinalizerCommand: '',
    operationsArtifactFinalizerCommand: '',
    dataFlowStoragePlanInputNote: '',
    dataFlowQueryRetentionBudgetInputNote: '',
    dataFlowStorageTransitionRunbookInputNote: '',
    minioBucketCorsInputNote: '',
    localImportCommand: '',
    decisionRule: '',
    artifacts: [],
  },
  operationsReadinessArtifactImport: {
    result: '',
    status: '',
    selectedGroupCount: 0,
    importedCount: 0,
    failedCount: 0,
    outputDirectory: '',
    secretPolicy: '',
    entries: [],
  },
  operationsReadinessFinalize: {
    result: '',
    status: '',
    readinessResult: '',
    readinessSummary: '',
    namespace: '',
    sourceNamespace: '',
    restoreNamespace: '',
    backupTimestamp: '',
    powerShellCommand: '',
    failedCount: 0,
    selectedSteps: {},
    paths: {},
    commands: [],
    steps: [],
    gaps: [],
    secretPolicy: '',
  },
  operationsHandoffPackage: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    passedCount: 0,
    failureCount: 0,
    plannedCount: 0,
    checkCount: 0,
    confirmations: {},
    evidenceRefs: {},
    operationsReadinessSnapshot: {},
    operationsConvergenceSnapshot: {},
    dataFlowStoragePlanSnapshot: {},
    dataFlowQueryRetentionBudgetSnapshot: {},
    dataFlowStorageTransitionRunbookSnapshot: {},
    secretRotationSnapshot: {},
    commercialIntegrationSnapshot: {},
    commercialApprovalSnapshot: {},
    chargebackCloseoutSnapshot: {},
    enterpriseAuthSmokeSnapshot: {},
    enterpriseAuthJitRollbackSnapshot: {},
    monitoringThresholdSnapshot: {},
    clusterNetworkAccessReviewSnapshot: {},
    helmValuesHardeningSnapshot: {},
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  commercialIntegrationEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    integrationCount: 0,
    verifiedCount: 0,
    requiredCount: 0,
    requiredVerifiedCount: 0,
    paymentProviderAdapterReadinessReviewed: false,
    paymentProviderAdapterReadinessStatus: '',
    paymentProviderAdapterWebhookReadyProfileCount: 0,
    paymentProviderAdapterNativeReadyProfileCount: 0,
    failureCount: 0,
    plannedCount: 0,
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  commercialApprovalEvidence: {
    result: '',
    generatedAt: '',
    productVersion: '',
    approvedBy: '',
    approvedAt: '',
    passedCount: 0,
    failureCount: 0,
    checkCount: 0,
    pricingPolicyProposalCommercialApproved: false,
    pricingPolicyProposalCommercialApprovedCount: 0,
    pricingPolicyProposalApprovedPriceListCount: 0,
    confirmations: {},
    evidenceRefs: {},
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  storageExpansionFinalize: {
    result: '',
    generatedAt: '',
    startedAt: '',
    completedAt: '',
    namespace: '',
    tenantName: '',
    serviceAccount: '',
    impersonateRunner: false,
    runBackendDryRunRunner: false,
    runBackendApply: false,
    confirmApply: false,
    runStorageBackendTelemetry: false,
    failedCount: 0,
    evidence: {},
    gaps: [],
    steps: [],
    secretPolicy: '',
  },
  kubernetesHaDrReadiness: {
    result: '',
    generatedAt: '',
    namespace: '',
    kubectlPath: '',
    restoreManifestPath: '',
    failureCount: 0,
    checks: [],
  },
  kubernetesDrFinalize: {
    result: '',
    status: '',
    generatedAt: '',
    startedAt: '',
    completedAt: '',
    sourceNamespace: '',
    restoreNamespace: '',
    backupTimestamp: '',
    serverDryRunOnly: false,
    confirmRestore: false,
    runBackupDrill: false,
    runRestoreSmoke: false,
    writeEvidenceRequest: false,
    submitEvidence: false,
    runS3ClientSmoke: false,
    failedStepCount: 0,
    gaps: [],
    commands: [],
    steps: [],
    secretPolicy: '',
  },
  iamRbacEvidence: {
    result: '',
    status: '',
    generatedAt: '',
    startedAt: '',
    completedAt: '',
    namespace: '',
    serviceAccount: '',
    powerShellCommand: '',
    gradleCommand: '',
    runBackendPolicyTests: false,
    runKubernetesLiveAuth: false,
    failedCount: 0,
    gaps: [],
    commands: [],
    steps: [],
    decisionRule: '',
    secretPolicy: '',
  },
  securityEvidence: {
    result: '',
    generatedAt: '',
    failureCount: 0,
    allowSyntheticEvidence: false,
    inputs: {},
    promoted: {},
    source: {},
    images: {},
    checks: [],
    imageSigning: {
      result: '',
      failureCount: 0,
    },
    containerSecurity: {
      result: '',
      failureCount: 0,
    },
    decisionRule: '',
    secretPolicy: '',
  },
  secretRotationEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    rotationWindow: {},
    evidenceRefs: {},
    confirmations: {},
    rotatedCount: 0,
    coreRotatedCount: 0,
    coreRequiredCount: 0,
    failureCount: 0,
    plannedCount: 0,
    rotations: [],
    checks: [],
    decisionRule: '',
    secretPolicy: '',
  },
  enterpriseAuthSmokeEvidence: {
    result: '',
    generatedAt: '',
    executionMode: '',
    apiBase: '',
    requireOidc: false,
    requireLdap: false,
    requireAuditEvents: false,
    inputs: {},
    scopeOut: {},
    passCount: 0,
    failCount: 0,
    blockedCount: 0,
    plannedCount: 0,
    skippedCount: 0,
    checks: [],
    decisionRule: '',
    secretPolicy: '',
  },
  enterpriseAuthJitRollbackEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    evidenceRef: '',
    reviewWindow: {},
    enterpriseAuthSmokeSnapshot: {},
    evidenceRefs: {},
    confirmations: {},
    failureCount: 0,
    checkCount: 0,
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  dataFlowStoragePlan: {
    result: '',
    recordedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    evidenceRef: '',
    candidateStore: '',
    candidateDecision: {
      decision: '',
      evidenceModel: '',
      requiresMariaDbQueryEvidence: false,
      requiresTargetStoreEvidence: false,
      queryPlanEvidencePassed: false,
      targetStoreEvidenceConfirmed: false,
      nextAction: '',
      safeDataPolicy: '',
    },
    expectedPeakEventsPerDay: 0,
    expectedQueryWindowDays: 0,
    targetP95QueryLatencyMs: 0,
    eventRetentionDays: 0,
    dailyRollupRetentionDays: 0,
    monthlyRollupRetentionMonths: 0,
    checkCount: 0,
    passedCount: 0,
    pendingCount: 0,
    checks: [],
    queryPlanEvidence: {
      provided: false,
      path: '',
      parsed: false,
      formatVersion: '',
      expectedFormatVersion: '',
      validFormatVersion: false,
      result: '',
      mode: '',
      checkCount: 0,
      passedCount: 0,
      failedCount: 0,
      failedChecks: [],
      detail: '',
    },
    scopePolicy: '',
  },
  dataFlowQueryRetentionBudget: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    evidenceRef: '',
    storagePlanResult: '',
    candidateStore: '',
    targetP95QueryLatencyMs: 0,
    observedP95QueryLatencyMs: 0,
    observedP99QueryLatencyMs: 0,
    querySampleCount: 0,
    observedQueryWindowDays: 0,
    retentionBudgetSeconds: 0,
    detailedRetentionObservedSeconds: 0,
    dailyRollupRetentionObservedSeconds: 0,
    monthlyRollupRetentionObservedSeconds: 0,
    detailedRetentionDeletedRows: 0,
    dailyRollupRetentionDeletedRows: 0,
    monthlyRollupRetentionDeletedRows: 0,
    queryLatencyWithinBudget: false,
    retentionJobsWithinBudget: false,
    failureCount: 0,
    checkCount: 0,
    confirmations: {},
    topFailedChecks: [],
    scopePolicy: '',
  },
  dataFlowStorageTransitionRunbook: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    evidenceRef: '',
    storagePlanResult: '',
    candidateStore: '',
    targetP95QueryLatencyMs: 0,
    failureCount: 0,
    checkCount: 0,
    confirmations: {},
    topFailedChecks: [],
    scopePolicy: '',
  },
  storageBackendTelemetryEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    sourceMode: '',
    minioAlias: '',
    evidenceRef: '',
    adminInfoJsonSha256: '',
    rawAdminInfoStored: false,
    poolCount: 0,
    serverCount: 0,
    onlineServerCount: 0,
    offlineServerCount: 0,
    driveCount: 0,
    totalBytes: 0,
    usedBytes: 0,
    freeBytes: 0,
    capacityKnown: false,
    failureCount: 0,
    plannedCount: 0,
    decisionRule: '',
    scopePolicy: '',
  },
  monitoringThresholdEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    evidenceRef: '',
    reviewWindow: {},
    thresholdTargetsPath: '',
    requiredAlertCount: 0,
    mappedAlertCount: 0,
    missingAlerts: [],
    routeCount: 0,
    routes: [],
    grafanaPanelCount: 0,
    tuningEvidenceCount: 0,
    alertTargetCoverageComplete: false,
    routeCoverageComplete: false,
    grafanaPanelCoverageComplete: false,
    tuningEvidenceCoverageComplete: false,
    thresholdMappingComplete: false,
    evidenceRefs: {},
    confirmations: {},
    failureCount: 0,
    checkCount: 0,
    checks: [],
    decisionRule: '',
    secretPolicy: '',
  },
  clusterNetworkAccessReviewEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    reviewWindow: {},
    evidence: {},
    staticSnapshot: {},
    confirmations: {},
    passCount: 0,
    failureCount: 0,
    totalCount: 0,
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  helmValuesHardeningEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    reviewWindow: {},
    evidence: {},
    staticSnapshot: {},
    confirmations: {},
    passCount: 0,
    failureCount: 0,
    totalCount: 0,
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  supportEscalationHandoffEvidence: {
    result: '',
    generatedAt: '',
    environmentName: '',
    targetCluster: '',
    operatorName: '',
    reviewWindow: {},
    evidence: {},
    documentSnapshot: {},
    confirmations: {},
    passCount: 0,
    failureCount: 0,
    totalCount: 0,
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    secretPolicy: '',
  },
  minioBucketCorsVerification: {
    result: '',
    generatedAt: '',
    sourceMode: '',
    bucketName: '',
    minioAlias: '',
    sourceRef: '',
    executeRequested: false,
    rawCorsXmlStored: false,
    ruleCount: 0,
    exposedHeaderCount: 0,
    failureCount: 0,
    plannedCount: 0,
    allowedOrigins: [],
    allowedMethods: [],
    allowedHeaders: [],
    exposeHeaders: [],
    maxAgeSeconds: [],
    checks: [],
    decisionRule: '',
    scopePolicy: '',
    operatorCommands: {
      collectWithMc: '',
      verifyFromFile: '',
      collectAndVerify: '',
    },
  },
  operationsEvidenceHandoff: {
    result: '',
    generatedAt: '',
    nextStep: {
      code: '',
      title: '',
      command: '',
      reason: '',
      note: '',
      dispatchUrls: [],
    },
    currentBottleneck: {
      code: '',
      title: '',
      command: '',
      reason: '',
      note: '',
      dispatchUrls: [],
    },
    stageCount: 0,
    readyStageCount: 0,
    readinessSummary: '',
    readinessPassedCount: 0,
    readinessPendingCount: 0,
    readinessTotalCount: 0,
    readinessCheckCount: 0,
    dispatchPreflightResult: '',
    requiredGitHubSecretCount: 0,
    requiredGitHubSecrets: [],
    requiredGitHubSecretSummaries: [],
    readyDispatchTemplateCount: 0,
    blockedDispatchTemplateCount: 0,
    readyDispatchActionOrders: [],
    blockedDispatchActionOrders: [],
    readyDispatchWorkflows: [],
    blockedDispatchWorkflows: [],
    workflowRunIdPlanQueryMode: '',
    workflowRunIdPlanGithubApiTokenPresent: false,
    workflowRunIdPlanGithubApiUnauthenticated: false,
    workflowRunIdPlanQueryExecuted: false,
    workflowRunIdPlanQueryExecutedCount: 0,
    workflowRunIdPlanQueryWorkflowCount: 0,
    workflowRunIdPlanQuerySucceededCount: 0,
    workflowRunIdPlanQueryErrorCount: 0,
    workflowRunIdPlanCandidateCount: 0,
    inputFreeBlockedReviewReportExists: false,
    inputFreeBlockedReviewReportResult: '',
    inputFreeBlockedReviewReportGeneratedAt: '',
    inputFreeBlockedReviewReportSelectedActionCount: 0,
    inputFreeBlockedReviewReportPlannedCount: 0,
    inputFreeBlockedReviewReportBlockedCount: 0,
    inputFreeBlockedReviewReportFailedCount: 0,
    inputFreeBlockedReviewReportExecutedCount: 0,
    inputFreeBlockedReviewReportActionOrders: [],
    inputFreeBlockedReviewReportStale: false,
    inputFreeBlockedReviewReportScopeMismatch: false,
    inputFreeBlockedActions: [],
    operatorInputValuesProfileReportPath: '',
    operatorInputValuesProfileExists: false,
    operatorInputValuesProfileResult: '',
    operatorInputValuesProfileGeneratedAt: '',
    operatorInputValuesProfileDefaultsUsed: false,
    operatorInputValuesProfileDefaultsSkipped: false,
    operatorInputValuesProfileDefaultsSkipReason: '',
    operatorInputValuesProfileDefaultValueCount: 0,
    operatorInputValuesProfileFilledValueCount: 0,
    operatorInputValuesProfileBlankValueCount: 0,
    operatorInputValuesProfileCommand: '',
    operatorInputValuesCheckCommand: '',
    operatorInputValuesCheckResult: '',
    operatorInputValuesCheckValueCount: 0,
    operatorInputValuesCheckReadyValueCount: 0,
    operatorInputValuesCheckMissingValueCount: 0,
    operatorInputValuesCheckUnsafeValueCount: 0,
    operatorInputValuesCheckInvalidValueCount: 0,
    operatorInputValuesCheckValueReadyActionCount: 0,
    operatorInputValuesCheckNonReadyActionCount: 0,
    operatorInputValuesCheckActionSummaryCount: 0,
    operatorInputValuesCheckNonReadyActionOrders: [],
    operatorInputValuesCheckNonReadyActionSummaries: [],
    browserDispatchChecklistCount: 0,
    browserDispatchChecklist: [],
    blockedActionCount: 0,
    missingWorkflowRunCount: 0,
    missingRequiredArtifactCount: 0,
    failedImportCount: 0,
    finalizerFailedCount: 0,
    finalizerGapCount: 0,
    stages: [],
  },
  operationsReadinessConvergence: {
    result: '',
    generatedAt: '',
    handoffReportPath: '',
    readinessReportPath: '',
    operationsReadinessFinalizeReportPath: '',
    handoffExists: false,
    handoffResult: '',
    readinessExists: false,
    readinessResult: '',
    readinessSummary: '',
    readinessPassedCount: 0,
    readinessPendingCount: 0,
    readinessTotalCount: 0,
    readinessCheckCount: 0,
    finalizerExists: false,
    finalizerResult: '',
    finalizerReadinessResult: '',
    finalizerFailedCount: 0,
    kubernetesOperationsReportSyncReportPath: '',
    kubernetesReportSyncExists: false,
    kubernetesReportSyncResult: '',
    kubernetesReportSyncStale: false,
    kubernetesReportSyncTimestamp: '',
    kubernetesReportSyncTimestampSource: '',
    kubernetesReportSyncFreshnessReason: '',
    kubernetesReportSyncFailedCount: 0,
    kubernetesReportSyncConfigMapName: '',
    kubernetesReportSyncConfigMapKey: '',
    kubernetesReportSyncSourceReportResult: '',
    kubernetesReportSyncWorkflowCommand: '',
    kubernetesReportSyncWorkflowNote: '',
    kubernetesReportSyncReady: false,
    finalizerGapCount: 0,
    stageCount: 0,
    readyStageCount: 0,
    blockedActionCount: 0,
    handoffRequiredGitHubSecretCount: 0,
    handoffRequiredGitHubSecrets: [],
    handoffRequiredGitHubSecretSummaries: [],
    handoffWorkflowRunIdPlanQueryMode: '',
    handoffWorkflowRunIdPlanGithubApiTokenPresent: false,
    handoffWorkflowRunIdPlanGithubApiUnauthenticated: false,
    handoffWorkflowRunIdPlanQueryExecuted: false,
    handoffWorkflowRunIdPlanQueryExecutedCount: 0,
    handoffWorkflowRunIdPlanQueryWorkflowCount: 0,
    handoffWorkflowRunIdPlanQuerySucceededCount: 0,
    handoffWorkflowRunIdPlanQueryErrorCount: 0,
    handoffWorkflowRunIdPlanCandidateCount: 0,
    handoffInputFreeBlockedReviewReportExists: false,
    handoffInputFreeBlockedReviewReportResult: '',
    handoffInputFreeBlockedReviewReportGeneratedAt: '',
    handoffInputFreeBlockedReviewReportSelectedActionCount: 0,
    handoffInputFreeBlockedReviewReportPlannedCount: 0,
    handoffInputFreeBlockedReviewReportBlockedCount: 0,
    handoffInputFreeBlockedReviewReportFailedCount: 0,
    handoffInputFreeBlockedReviewReportExecutedCount: 0,
    handoffInputFreeBlockedReviewReportActionOrders: [],
    handoffInputFreeBlockedReviewReportStale: false,
    handoffInputFreeBlockedReviewReportScopeMismatch: false,
    handoffOperatorInputValuesProfileReportPath: '',
    handoffOperatorInputValuesProfileExists: false,
    handoffOperatorInputValuesProfileResult: '',
    handoffOperatorInputValuesProfileGeneratedAt: '',
    handoffOperatorInputValuesProfileDefaultsUsed: false,
    handoffOperatorInputValuesProfileDefaultsSkipped: false,
    handoffOperatorInputValuesProfileDefaultsSkipReason: '',
    handoffOperatorInputValuesProfileDefaultValueCount: 0,
    handoffOperatorInputValuesProfileFilledValueCount: 0,
    handoffOperatorInputValuesProfileBlankValueCount: 0,
    handoffOperatorInputValuesCheckResult: '',
    handoffOperatorInputValuesCheckValueCount: 0,
    handoffOperatorInputValuesCheckReadyValueCount: 0,
    handoffOperatorInputValuesCheckMissingValueCount: 0,
    handoffOperatorInputValuesCheckUnsafeValueCount: 0,
    handoffOperatorInputValuesCheckInvalidValueCount: 0,
    handoffOperatorInputValuesCheckValueReadyActionCount: 0,
    handoffOperatorInputValuesCheckNonReadyActionCount: 0,
    handoffOperatorInputValuesCheckActionSummaryCount: 0,
    handoffOperatorInputValuesCheckNonReadyActionOrders: [],
    handoffOperatorInputValuesCheckNonReadyActionSummaries: [],
    missingWorkflowRunCount: 0,
    missingRequiredArtifactCount: 0,
    failedImportCount: 0,
    currentBottleneck: {
      code: '',
      title: '',
      reason: '',
      command: '',
    },
    handoffPostDispatchCommands: [],
    recommendedCommands: [],
    decisionRule: '',
    safetyPolicy: '',
  },
  kubernetesOperationsReportSync: {
    result: '',
    generatedAt: '',
    namespace: '',
    configMapName: '',
    configMapKey: '',
    evidenceConfigMapKey: '',
    dataFlowStoragePlanConfigMapKey: '',
    dataFlowStorageTransitionRunbookConfigMapKey: '',
    publishDataFlowStoragePlanToConfigMap: false,
    publishDataFlowStorageTransitionRunbookToConfigMap: false,
    sourceReportPath: '',
    sourceReportFormatVersion: '',
    sourceReportResult: '',
    sourceReportBytes: 0,
    sourceReportSha256: '',
    dataFlowStorageTransitionRunbookResult: '',
    dataFlowStorageTransitionRunbookStoragePlanResult: '',
    dataFlowStorageTransitionRunbookCandidateStore: '',
    dataFlowStorageTransitionRunbookFailureCount: 0,
    dataFlowStorageTransitionRunbookCheckCount: 0,
    dataFlowStorageTransitionRunbookBytes: 0,
    dataFlowStorageTransitionRunbookSha256: '',
    clientDryRunCommand: '',
    serverDryRunCommand: '',
    applyCommand: '',
    checkCount: 0,
    failedCount: 0,
    checks: [],
    safetyPolicy: '',
  },
  generatedAt: '',
})
const dataFlowRetention = reactive(defaultDataFlowRetention())
const dataFlowStorageStatus = reactive(defaultDataFlowStorageStatus())
const retentionPolicy = reactive({
  enabled: false,
  retentionDays: 0,
  batchSize: 0,
  purgedObjectCount: 0,
  failedObjectCount: 0,
  failedRunCount: 0,
  lastPurgedCount: null,
  pending: false,
})
const executionLogRetention = reactive({
  enabled: false,
  retentionDays: 0,
  batchSize: 0,
  pendingOutputCount: 0,
  redactedOutputCount: 0,
  failedRunCount: 0,
  lastRedactedOutputCount: null,
  pending: false,
})

const bucketForm = reactive({ name: '', quotaGb: 100, ownerType: 'USER', ownerId: '' })
const objectForm = reactive({ key: '', tags: '', file: null })
const objectTagForm = reactive({ key: '', tags: '' })
const objectPrefix = ref('')
const objectSearch = ref('')
const objectTagFilter = ref('')
const objectViewMode = ref('active')
const objectListLimit = ref(100)
const objectPrefixes = ref([])
const objectNextCursor = ref('')
const objectMetadata = ref(null)
const objectVersions = reactive({ key: '', items: [], pending: false })
const objectShareLinks = reactive({ key: '', items: [], pending: false })
const objectSharePolicy = reactive({
  requirePassword: false,
  requireIpAllowlist: false,
  maxExpiresSeconds: 604800,
  maxDownloadsLimit: null,
  updatedAt: null,
})
const objectSharePolicyForm = reactive({
  requirePassword: false,
  requireIpAllowlist: false,
  maxExpiresSeconds: 604800,
  maxDownloadsLimit: '',
  pending: false,
})
const objectShareAnalytics = reactive({
  totalLinks: 0,
  activeLinks: 0,
  expiredLinks: 0,
  revokedLinks: 0,
  limitReachedLinks: 0,
  passwordProtectedLinks: 0,
  ipRestrictedLinks: 0,
  totalDownloads: 0,
  lastAccessedAt: null,
  recentLinks: [],
})
const objectShareAnalyticsFilter = reactive({ bucketName: '', status: '', limit: 10 })
const enterpriseAuthPlan = ref(defaultEnterpriseAuthPlan())
const accessKeyForm = reactive({ name: 'local-dev-key', expiresAt: '', scopeBucket: '', scopePermissions: ['READ', 'WRITE', 'DELETE'], scopes: [] })
const bucketPermissionForm = reactive({ subjectType: 'USER', subjectId: '', permissions: ['READ'] })
const userForm = reactive({ loginId: '', email: '', name: '', password: '', role: 'USER', organizationId: '' })
const organizationForm = reactive({ name: '', description: '', defaultQuotaTb: 10 })
const teamForm = reactive({ organizationId: '', name: '', description: '', memberIds: [] })
const quotaPolicyForm = reactive({ targetType: 'USER', targetId: '', targetSearch: '', quotaGb: 100, reason: '', editingKey: '' })
const storageExpansionForm = reactive({ capacityGb: 1024, serverCount: 4, volumesPerServer: 1, reason: '' })
const storageProfileForm = reactive({ requestedProfile: 'STANDARD', reason: '' })
const storageProfileAdminNote = ref('')
const storageExpansionExecutionForm = reactive({
  requestId: '',
  executionType: 'HELM_DIFF',
  result: 'SUCCESS',
  command: '',
  output: '',
  externalUrl: '',
  artifactSha256: '',
  notes: '',
  dryRunType: 'KUBECTL_DIFF',
  dryRunResult: 'SUCCESS',
  dryRunOutput: '',
  dryRunExternalUrl: '',
  dryRunNotes: '',
  applyRunType: 'KUBECTL_APPLY',
  gitOpsPrUrl: '',
  gitOpsMergeSha: '',
  gitOpsPipelineUrl: '',
  gitOpsNotes: '',
  rollbackType: 'HELM_ROLLBACK',
  rollbackHelmRevision: '',
  rollbackKubectlTarget: 'statefulset/osmu-minio',
})
const lifecycleRuleForm = reactive({
  ruleId: '',
  name: '',
  enabled: true,
  priority: 100,
  bucketName: '',
  targetType: 'OBJECT_VERSION',
  prefix: '',
  tags: '',
  retentionDays: 30,
  batchSize: 100,
  pending: false,
})
const dashboardQuota = reactive({
  policyCount: 0,
  warningPolicyCount: 0,
  exhaustedPolicyCount: 0,
  totalQuotaBytes: 0,
  totalUsedBytes: 0,
  totalRemainingBytes: 0,
  topPolicies: [],
})
const lifecycleRuleConflicts = reactive({ ruleCount: 0, conflictCount: 0, conflicts: [], pending: false })
const lifecycleRulePreview = reactive({
  ruleId: '',
  ruleName: '',
  targetType: '',
  candidateCount: 0,
  candidateBytes: 0,
  cutoff: '',
  truncated: false,
  candidates: [],
  pendingRuleId: '',
})
const lifecycleXml = reactive({ content: '', importedCount: null, pending: false })
const bucketLifecycleXml = reactive({ content: '', ruleCount: 0, savedCount: null, pending: false })
const bucketTags = reactive({ content: '', tagCount: 0, savedCount: null, pending: false })
const auditFilter = reactive({ eventType: '', actorId: '', requestId: '', targetType: '', targetId: '', result: '', from: '', to: '', limit: 50 })
const dataFlowFilter = reactive({ from: '', to: '', bucketName: '', actorId: '', source: '', operation: '', status: '', limit: 50, months: 12, monthlyMaterialized: false })
const uploadState = reactive({
  active: false,
  loadedBytes: 0,
  totalBytes: 0,
  percent: 0,
  message: '',
  retryable: false,
  multipart: false,
  errorCode: '',
  errorStatus: 0,
  requestId: '',
})
const dataFlowMonitoring = reactive({
  traffic: {
    uploadedBytes: 0,
    downloadedBytes: 0,
    copiedBytes: 0,
    totalBytes: 0,
    ingressBytes: 0,
    egressBytes: 0,
    internalBytes: 0,
  },
  operations: {
    uploadCount: 0,
    downloadCount: 0,
    copyCount: 0,
    listCount: 0,
    deleteCount: 0,
    cancelCount: 0,
    failureCount: 0,
    totalCount: 0,
  },
  topBuckets: [],
  trendPoints: [],
  recentEvents: [],
  dailyRollup: defaultDataFlowDailyRollup(),
  monthlyRollup: defaultDataFlowMonthlyRollup(),
  generatedAt: '',
})
const confirmDialog = reactive({ open: false, title: '', message: '', confirmLabel: '확인', pending: false, action: null })
const dashboardLayoutSync = reactive({ source: 'LOCAL', updatedAt: '', pending: false })
const dashboardLoadState = reactive({ loading: false, error: '' })
const chargebackOptions = reactive({ ...defaultChargebackOptions })

const buckets = ref([])
const objects = ref([])
const accessKeys = ref([])
const bucketPermissions = ref([])
const users = ref([])
const organizations = ref([])
const organizationUsages = ref([])
const chargebackPreview = ref(defaultChargebackPreview())
const chargebackDailyRollup = ref(defaultChargebackDailyRollup())
const chargebackAlerts = ref(defaultChargebackAlerts())
const chargebackAlertNotificationPreview = ref(defaultChargebackAlertNotificationPreview())
const chargebackAlertNotificationOutbox = ref(defaultChargebackAlertNotificationOutbox())
const chargebackInvoiceDrafts = ref(defaultChargebackInvoiceDrafts())
const chargebackFinalInvoices = ref(defaultChargebackFinalInvoices())
const chargebackPaymentProviderHandoffs = ref(defaultChargebackPaymentProviderHandoffs())
const chargebackPaymentProviderAdapterReadiness = ref(defaultChargebackPaymentProviderAdapterReadiness())
const chargebackAdapterRetryWorker = ref(defaultChargebackAdapterRetryWorker())
const billingPricingPolicy = ref(defaultBillingPricingPolicy())
const billingPricingPolicyProposals = ref(defaultBillingPricingPolicyProposals())
const teams = ref([])
const quotaPolicies = ref([])
const quotaPolicyHistory = ref([])
const storageExpansionRequests = ref([])
const storageProfiles = ref([])
const storageProfileRequests = ref([])
const bucketStorageProfile = ref(null)
const storageExpansionManifest = ref(null)
const storageExpansionExecutionPlan = ref(null)
const storageExpansionGitOpsPlan = ref(null)
const storageExpansionExecutions = ref([])
const storageExpansionApplyEvidence = ref('')
const storageExpansionSummary = reactive({
  requestCount: 0,
  openRequestCount: 0,
  plannedRequestCount: 0,
  approvedRequestCount: 0,
  appliedRequestCount: 0,
  rejectedRequestCount: 0,
  totalRequestedCapacityBytes: 0,
  openRequestedCapacityBytes: 0,
  totalEstimatedUsableCapacityBytes: 0,
  openEstimatedUsableCapacityBytes: 0,
  executionCount: 0,
  successExecutionCount: 0,
  failedExecutionCount: 0,
  skippedExecutionCount: 0,
  timedOutExecutionCount: 0,
  latestRequest: null,
  latestExecution: null,
  recentExecutions: [],
})
const storageExpansionRunnerPreflight = reactive({
  status: 'DISABLED',
  ready: false,
  enabledRunnerCount: 0,
  failedCheckCount: 0,
  checks: [],
})
const s3ClientConfig = reactive({
  endpoint: '',
  region: '',
  signatureVersion: '',
  service: '',
  pathStyleSupported: true,
  virtualHostedStyleEnabled: false,
  virtualHostedStyleDomainSuffixes: [],
})
const lifecycleRules = ref([])
const auditLogs = ref([])
const auditNextCursor = ref('')
const selectedBucket = ref('')
const errorMessage = ref('')
const errorRequestId = ref('')
const errorCode = ref('')
const errorStatus = ref(0)
const statusMessage = ref('')
const actionPendingCount = ref(0)
const newSecretKey = ref('')
const presignedUrl = ref('')
const shareLinkUrl = ref('')
const shareLinkPassword = ref('')
const shareLinkAllowedIpCidrs = ref('')
const pendingUploadId = ref('')
const uploadController = ref(null)
const uploadAbortMode = ref('')
const lastUploadRequest = ref(null)
const pendingMultipartUploads = ref([])
const dashboardWidgets = ref(loadDashboardWidgets())
const dashboardSections = ref(loadDashboardSections())
const dashboardWidgetToAdd = ref('')
const dashboardEditMode = ref(false)
const dashboardLayoutPresets = ref([])
const dashboardLayoutPresetToApply = ref('')
const dashboardLayoutPresetForm = reactive({ name: '', description: '' })
const dashboardLayoutDefaults = ref([])
const dashboardLayoutDefaultForm = reactive({ targetType: 'ROLE', targetId: 'USER', presetId: '' })
const dashboardWidgetDragIndex = ref(-1)
const dashboardWidgetDropIndex = ref(-1)
const readinessCategoryFilter = ref('ALL')
const readinessSeverityFilter = ref('ALL')

const activePage = computed(() => {
  const path = route.path === '/' ? '/dashboard' : route.path
  return navigationItems.find((item) => item.to === path)?.page ?? 'dashboard'
})
const activePageMeta = computed(() => pageMeta[activePage.value] ?? pageMeta.dashboard)
const adminActionErrorLabel = computed(() => {
  if (!errorCode.value && !errorStatus.value) return ''
  if (errorCode.value && errorStatus.value) return `${errorCode.value} / HTTP ${errorStatus.value}`
  return errorCode.value || `HTTP ${errorStatus.value}`
})
const adminActionRemediation = computed(() => {
  if (activePage.value !== 'admin' || !errorMessage.value) return null

  const code = String(errorCode.value || '').toUpperCase()
  const status = Number(errorStatus.value || 0)

  if (status === 401 || code === 'AUTHENTICATION_REQUIRED') {
    return {
      title: '세션 확인 필요',
      detail: '관리자 세션이 만료되어 작업이 중단됐습니다.',
      primaryAction: '다시 로그인',
      action: 'login',
      steps: [
        '현재 입력값을 확인합니다.',
        '다시 로그인한 뒤 같은 관리자 작업을 재시도합니다.',
        '반복되면 Request ID로 인증/감사 로그를 조회합니다.',
      ],
    }
  }

  if (status === 403 || code === 'AUTHORIZATION_FAILED') {
    return {
      title: '권한 확인 필요',
      detail: '현재 role 또는 조직 scope로 이 관리자 작업을 실행할 수 없습니다.',
      primaryAction: '상태 새로고침',
      action: 'refresh',
      steps: [
        '관리자 role과 조직 scope를 확인합니다.',
        'AdminRbacPolicy allowlist와 bucket permission을 함께 점검합니다.',
        '권한 변경 후 최신 상태를 다시 불러옵니다.',
      ],
    }
  }

  if (status === 400 || code === 'VALIDATION_ERROR') {
    return {
      title: '입력값 확인 필요',
      detail: '요청값이 API contract나 현재 상태 전이 조건과 맞지 않습니다.',
      primaryAction: '입력값 수정',
      action: 'none',
      steps: [
        '필수 입력값과 숫자 범위를 확인합니다.',
        '대상 상태가 실행 가능한 단계인지 확인합니다.',
        'Request ID로 validation 실패 원인을 감사 로그와 대조합니다.',
      ],
    }
  }

  if (status === 404 || code === 'NOT_FOUND') {
    return {
      title: '대상 확인 필요',
      detail: '선택한 리소스가 삭제됐거나 현재 scope 밖에 있습니다.',
      primaryAction: '목록 새로고침',
      action: 'refresh',
      steps: [
        '관리자 목록을 다시 불러옵니다.',
        '선택한 bucket, 사용자, 조직, 요청 ID가 아직 존재하는지 확인합니다.',
        '조직 scope가 바뀐 경우 올바른 계정으로 다시 시도합니다.',
      ],
    }
  }

  if (status === 409 || code.includes('CONFLICT')) {
    return {
      title: '상태 충돌 확인 필요',
      detail: '다른 작업이 먼저 반영됐거나 현재 상태에서 실행할 수 없는 요청입니다.',
      primaryAction: '최신 상태 새로고침',
      action: 'refresh',
      steps: [
        '최신 상태를 다시 불러옵니다.',
        '승인, 적용, 비활성화 같은 선행 작업이 이미 끝났는지 확인합니다.',
        '같은 대상을 여러 탭에서 처리 중인지 점검합니다.',
      ],
    }
  }

  return {
    title: '관리자 작업 실패',
    detail: '요청이 완료되지 않았습니다. 상태를 다시 불러온 뒤 같은 작업을 재시도합니다.',
    primaryAction: '상태 새로고침',
    action: 'refresh',
    steps: [
      '최신 서버 상태를 확인합니다.',
      'Request ID로 backend 로그와 감사 로그를 찾습니다.',
      '반복 실패 시 입력값, 권한, 대상 상태를 함께 점검합니다.',
    ],
  }
})
const visibleNavigationItems = computed(() => navigationItems.filter(canAccessNavigationItem))
const statusItems = computed(() => [
  { label: 'Backend', value: health.backend },
  { label: 'Storage', value: health.storage },
  { label: 'Database', value: health.database },
])
const dashboardWidgetCatalogForRole = computed(() => dashboardWidgetCatalogForCurrentRole())
const visibleDashboardWidgets = computed(() => {
  const roleVisibleIds = new Set(dashboardWidgetCatalogForRole.value.map((item) => item.id))
  return dashboardWidgets.value.filter((widget) => widget.enabled && roleVisibleIds.has(widget.id))
})
const dashboardAutoRefreshIntervalMs = computed(() => {
  if (!isLoggedIn.value || activePage.value !== 'dashboard') return 0
  const intervals = visibleDashboardWidgets.value
    .map((widget) => dashboardWidgetRefreshIntervalMs[dashboardWidgetRefreshInterval(widget)] || 0)
    .filter((interval) => interval > 0)
  return intervals.length > 0 ? Math.min(...intervals) : 0
})
const dashboardLayoutSyncLabel = computed(() => {
  if (!isLoggedIn.value) return '이 브라우저에 저장'
  if (dashboardLayoutSync.pending) return '서버 저장 중'
  if (dashboardLayoutSync.source === 'SAVED') return '서버 저장됨'
  if (dashboardLayoutSync.source === 'DEFAULT_PRESET') return '관리자 기본 preset'
  if (dashboardLayoutSync.source === 'DEFAULT') return '기본 구성'
  return '서버 동기화 대기'
})
const availableDashboardWidgetOptions = computed(() => {
  const selected = new Set(dashboardWidgets.value.map((widget) => widget.id))
  return dashboardWidgetCatalogForRole.value.filter((widget) => !selected.has(widget.id))
})
const selectedDashboardLayoutPreset = computed(() => dashboardLayoutPresets.value.find((preset) => preset.id === dashboardLayoutPresetToApply.value))
const canDeleteDashboardLayoutPreset = computed(() => isAdmin.value && Boolean(selectedDashboardLayoutPreset.value?.custom))
const canUpdateDashboardLayoutPreset = computed(() => canDeleteDashboardLayoutPreset.value)
const canExportDashboardLayoutPreset = computed(() => Boolean(selectedDashboardLayoutPreset.value))
const dashboardLayoutDefaultTargetOptions = computed(() => {
  if (dashboardLayoutDefaultForm.targetType === 'ORGANIZATION') {
    return organizations.value.map((organization) => ({ id: String(organization.id), label: `${organization.name} (#${organization.id})` }))
  }
  return dashboardLayoutDefaultRoleOptions
})
const usagePercent = computed(() => {
  if (!usage.totalQuotaBytes) return 0
  return Math.min(100, Math.round((Number(usage.usedBytes || 0) / Number(usage.totalQuotaBytes)) * 100))
})
const canCreateOrgBucket = computed(() => isAdmin.value || (isOrgAdmin.value && Boolean(session.user?.organizationId)))
const selectedBucketRecord = computed(() => buckets.value.find((bucket) => bucket.name === selectedBucket.value))
const bucketRows = computed(() => buildBucketListRows(buckets.value, formatBytes))
const bucketObjectsLabel = computed(() => {
  if (!selectedBucketRecord.value) return 'No bucket'
  return `${selectedBucketRecord.value.objectCount || 0} objects`
})
const isActionPending = computed(() => actionPendingCount.value > 0)
const runtimeReadinessLabel = computed(() => {
  const metadataEngine = String(health.metadataEngine || '').toLowerCase()
  const storageEngine = String(health.storageEngine || '').toLowerCase()
  if (metadataEngine.includes('maria') && storageEngine.includes('minio')) {
    return 'MariaDB + MinIO'
  }
  if (metadataEngine.includes('memory') || storageEngine.includes('memory')) {
    return 'Local demo runtime'
  }
  return `${health.metadataEngine || '-'} + ${health.storageEngine || '-'}`
})
const readinessCategoryOptions = computed(() => [
  {
    category: 'ALL',
    totalCount: dashboardReadiness.items.length,
    blockerCount: dashboardReadiness.blockerCount,
    warningCount: dashboardReadiness.warningCount,
  },
  ...dashboardReadiness.categorySummaries,
])
const readinessSeverityOptions = computed(() => [
  {
    severity: 'ALL',
    totalCount: dashboardReadiness.items.length,
  },
  ...dashboardReadiness.severitySummaries,
])
const visibleReadinessItems = computed(() => {
  return dashboardReadiness.items.filter((item) => {
    const categoryMatches = readinessCategoryFilter.value === 'ALL'
      || (item.category || 'GENERAL') === readinessCategoryFilter.value
    const severityMatches = readinessSeverityFilter.value === 'ALL'
      || (item.severity || 'UNKNOWN') === readinessSeverityFilter.value
    return categoryMatches && severityMatches
  })
})
const nextActionLabel = computed(() => {
  if (!isLoggedIn.value) return '로그인 후 상태를 확인하세요'
  if (!buckets.value.length) return '첫 버킷을 생성하세요'
  if (!selectedBucket.value) return '작업할 버킷을 선택하세요'
  if (!objects.value.length && !objectPrefixes.value.length) return '파일을 업로드하거나 prefix를 확인하세요'
  return '파일 탐색, 공유, 정책 점검을 진행하세요'
})
const canSubmitUpload = computed(() => isLoggedIn.value && Boolean(selectedBucket.value) && Boolean(objectForm.file) && canStartUpload(uploadState))
const canRetryUpload = computed(() => Boolean(lastUploadRequest.value) && uploadState.retryable && canStartUpload(uploadState))
const objectPrefixBreadcrumbs = computed(() => buildObjectPrefixBreadcrumbs(objectPrefix.value))
const matchingMultipartResumeSession = computed(() => {
  if (!selectedBucket.value || !objectForm.file || !objectForm.key) return null
  const pendingSessions = pendingMultipartUploads.value
  const session = getStoredMultipartUploadSessionForFile(selectedBucket.value, objectForm.key, objectForm.file, objectForm.tags)
  if (!session) return null
  return pendingSessions.some((pending) => pending.storageKey === session.storageKey) ? session : null
})
const visibleMultipartResumeSessions = computed(() => pendingMultipartUploads.value
  .filter((session) => !selectedBucket.value || session.bucketName === selectedBucket.value)
  .slice(0, 5))
const canManageSelectedBucket = computed(() => {
  const bucket = selectedBucketRecord.value
  if (!bucket || !session.user) return false
  return isAdmin.value
    || (bucket.ownerType === 'USER' && bucket.ownerId === session.user.id)
    || (bucket.ownerType === 'ORG' && isOrgAdmin.value && bucket.ownerId === session.user.organizationId)
})
const canShowBucketPermissions = computed(() => canManageSelectedBucket.value || bucketPermissions.value.length > 0)
const hasSelectedBucketAdminPermission = computed(() => bucketPermissions.value.some((permission) => permission.permission === 'ADMIN'))
const canUseBucketLifecycle = computed(() => canManageSelectedBucket.value || hasSelectedBucketAdminPermission.value)
const canUseBucketTags = computed(() => canUseBucketLifecycle.value)
const objectMetadataRows = computed(() => buildObjectMetadataDetailRows(objectMetadata.value, {
  formatBytes,
  formatOptionalBytes,
  formatObjectTags,
  formatChecksumMap,
  formatDateTime,
}))
const quotaPolicyAllTargetOptions = computed(() => {
  if (quotaPolicyForm.targetType === 'ORGANIZATION') {
    return organizations.value.map((organization) => ({ id: String(organization.id), label: `${organization.name} (#${organization.id})` }))
  }
  if (quotaPolicyForm.targetType === 'BUCKET') {
    return buckets.value.map((bucket) => ({ id: String(bucket.id), label: `${bucket.name} (#${bucket.id})` }))
  }
  return users.value.map((user) => ({ id: String(user.id), label: `${user.loginId} (#${user.id})` }))
})
const quotaPolicyTargetOptions = computed(() => {
  const query = quotaPolicyForm.targetSearch.trim().toLowerCase()
  if (!query) return quotaPolicyAllTargetOptions.value
  return quotaPolicyAllTargetOptions.value.filter((target) => target.label.toLowerCase().includes(query))
})

function loadDashboardWidgets() {
  if (typeof window === 'undefined') return [...defaultDashboardWidgets]
  try {
    const parsed = JSON.parse(window.localStorage.getItem(DASHBOARD_WIDGET_STORAGE_KEY) || '[]')
    return sanitizeDashboardWidgets(parsed)
  } catch {
    return [...defaultDashboardWidgets]
  }
}

function loadDashboardSections() {
  if (typeof window === 'undefined') return [...defaultDashboardSections]
  try {
    const parsed = JSON.parse(window.localStorage.getItem(DASHBOARD_SECTION_STORAGE_KEY) || '[]')
    return sanitizeDashboardSections(parsed)
  } catch {
    return [...defaultDashboardSections]
  }
}

function sanitizeDashboardWidgets(widgets, fallback = defaultDashboardWidgets) {
  const validIds = new Set(dashboardWidgetCatalogForCurrentRole().map((widget) => widget.id))
  const roleFallback = fallback.filter((widget) => validIds.has(widget.id))
  if (!Array.isArray(widgets)) return [...roleFallback]
  const seen = new Set()
  const sanitized = widgets
    .filter((widget) => widget?.id && validIds.has(widget.id) && !seen.has(widget.id) && seen.add(widget.id))
    .map((widget) => ({
      id: widget.id,
      enabled: widget.enabled !== false,
      size: normalizeDashboardWidgetSize(widget.size),
      section: normalizeDashboardWidgetSection(widget.section),
      options: sanitizeDashboardWidgetOptions(widget.options),
    }))
  return sanitized.length > 0 ? sanitized : [...roleFallback]
}

function dashboardWidgetCatalogForCurrentRole() {
  const role = session.user?.role
  return dashboardWidgetCatalog.value.filter((widget) => dashboardWidgetAllowedRoles(widget).includes(role))
}

function sanitizeDashboardSections(sections, fallback = defaultDashboardSections) {
  const byId = new Map(fallback.map((section) => [section.id, { id: section.id, collapsed: section.collapsed === true }]))
  if (Array.isArray(sections)) {
    for (const section of sections) {
      const id = section?.id
      if (!dashboardWidgetSections.some((item) => item.id === id)) continue
      byId.set(id, { id, collapsed: section.collapsed === true })
    }
  }
  return dashboardWidgetSections
    .map((section) => byId.get(section.id))
    .filter(Boolean)
}

function sanitizeDashboardWidgetCatalog(items) {
  if (!Array.isArray(items)) return [...defaultDashboardWidgetCatalog]
  const seen = new Set()
  const sanitized = items
    .filter((item) => item?.id && !seen.has(item.id) && seen.add(item.id))
    .map((item) => ({
      id: String(item.id),
      title: String(item.title || item.id),
      description: String(item.description || ''),
      category: String(item.category || 'CUSTOM'),
      adminOnly: item.adminOnly === true,
      allowedRoles: Array.isArray(item.allowedRoles) ? item.allowedRoles.map(String) : dashboardWidgetAllowedRoles(item),
      accessMode: String(item.accessMode || dashboardWidgetAccessMode(item)),
      configOptions: Array.isArray(item.configOptions) ? item.configOptions : [],
    }))
  return sanitized.length > 0 ? sanitized : [...defaultDashboardWidgetCatalog]
}

function normalizeDashboardWidgetSize(size) {
  return dashboardWidgetSizes.includes(size) ? size : 'normal'
}

function normalizeDashboardWidgetSection(section) {
  return dashboardWidgetSections.some((item) => item.id === section) ? section : 'overview'
}

function sanitizeDashboardWidgetOptions(options) {
  const tone = options?.tone
  const refreshInterval = options?.refreshInterval || options?.refreshinterval
  return {
    tone: dashboardWidgetTones.includes(tone) ? tone : 'default',
    refreshInterval: dashboardWidgetRefreshIntervals.includes(refreshInterval) ? refreshInterval : 'manual',
  }
}

function persistLocalDashboardWidgets() {
  if (typeof window === 'undefined') return
  window.localStorage.setItem(DASHBOARD_WIDGET_STORAGE_KEY, JSON.stringify(dashboardWidgets.value))
  window.localStorage.setItem(DASHBOARD_SECTION_STORAGE_KEY, JSON.stringify(dashboardSections.value))
}

function persistDashboardWidgets() {
  persistLocalDashboardWidgets()
  if (isLoggedIn.value) {
    void saveDashboardLayoutRemote()
  }
}

function dashboardWidgetTitle(widgetId) {
  return dashboardWidgetCatalog.value.find((widget) => widget.id === widgetId)?.title ?? widgetId
}

function dashboardWidgetCatalogItem(widgetOrId) {
  const id = typeof widgetOrId === 'string' ? widgetOrId : widgetOrId?.id
  return dashboardWidgetCatalog.value.find((widget) => widget.id === id)
}

function dashboardWidgetAllowedRoles(widgetOrId) {
  const item = typeof widgetOrId === 'string' ? dashboardWidgetCatalogItem(widgetOrId) : widgetOrId
  if (Array.isArray(item?.allowedRoles) && item.allowedRoles.length > 0) return item.allowedRoles
  return item?.adminOnly ? ['ADMIN'] : ['ADMIN', 'ORG_ADMIN', 'AUDITOR', 'USER']
}

function dashboardWidgetAccessMode(widgetOrId) {
  const item = typeof widgetOrId === 'string' ? dashboardWidgetCatalogItem(widgetOrId) : widgetOrId
  return item?.accessMode || (item?.adminOnly ? 'admin-only' : 'read-only')
}

function dashboardWidgetAccessLabel(widgetOrId) {
  const mode = dashboardWidgetAccessMode(widgetOrId)
  if (mode === 'admin-only') return 'ADMIN only'
  return 'Read-only'
}

function dashboardWidgetSizeLabel(size) {
  return dashboardWidgetSizeLabels[normalizeDashboardWidgetSize(size)]
}

function dashboardWidgetSection(widget) {
  return normalizeDashboardWidgetSection(widget?.section)
}

function dashboardWidgetSectionLabel(section) {
  const id = typeof section === 'string' ? section : dashboardWidgetSection(section)
  return dashboardWidgetSections.find((item) => item.id === id)?.label ?? id
}

function dashboardSectionCollapsed(sectionId) {
  const id = normalizeDashboardWidgetSection(sectionId)
  return dashboardSections.value.find((section) => section.id === id)?.collapsed === true
}

function dashboardWidgetTone(widget) {
  return sanitizeDashboardWidgetOptions(widget?.options).tone
}

function dashboardWidgetToneLabel(widget) {
  return dashboardWidgetToneLabels[dashboardWidgetTone(widget)]
}

function dashboardWidgetRefreshInterval(widget) {
  return sanitizeDashboardWidgetOptions(widget?.options).refreshInterval
}

function dashboardWidgetRefreshIntervalLabel(widget) {
  return dashboardWidgetRefreshIntervalLabels[dashboardWidgetRefreshInterval(widget)]
}

function dashboardWidgetConfigOptions(widgetId) {
  const options = dashboardWidgetCatalog.value.find((widget) => widget.id === widgetId)?.configOptions
  return Array.isArray(options) && options.length > 0 ? options : defaultDashboardWidgetConfigOptions
}

function dashboardWidgetOptionValue(widget, optionKey) {
  const key = String(optionKey || '')
  if (key === 'tone') return dashboardWidgetTone(widget)
  if (key === 'refreshInterval') return dashboardWidgetRefreshInterval(widget)
  return widget?.options?.[key] ?? ''
}

function nextDashboardWidgetSize(size) {
  const currentIndex = dashboardWidgetSizes.indexOf(normalizeDashboardWidgetSize(size))
  return dashboardWidgetSizes[(currentIndex + 1) % dashboardWidgetSizes.length]
}

function addDashboardWidget() {
  if (!dashboardWidgetToAdd.value) return
  if (!dashboardWidgetCatalogForRole.value.some((widget) => widget.id === dashboardWidgetToAdd.value)) return
  if (dashboardWidgets.value.some((widget) => widget.id === dashboardWidgetToAdd.value)) return
  dashboardWidgets.value = [...dashboardWidgets.value, { id: dashboardWidgetToAdd.value, enabled: true, size: 'normal', section: 'overview', options: { tone: 'default', refreshInterval: 'manual' } }]
  dashboardWidgetToAdd.value = ''
  persistDashboardWidgets()
}

function addDashboardWidgetById(widgetId) {
  const id = String(widgetId || '')
  if (!dashboardWidgetCatalogForRole.value.some((widget) => widget.id === id)) return
  dashboardWidgetToAdd.value = id
  addDashboardWidget()
}

function toggleDashboardWidgetSize(widgetId) {
  dashboardWidgets.value = dashboardWidgets.value.map((widget) => (
    widget.id === widgetId ? { ...widget, size: nextDashboardWidgetSize(widget.size) } : widget
  ))
  persistDashboardWidgets()
}

function updateDashboardWidgetSection(widgetId, section) {
  const nextSection = normalizeDashboardWidgetSection(section)
  dashboardWidgets.value = dashboardWidgets.value.map((widget) => (
    widget.id === widgetId ? { ...widget, section: nextSection } : widget
  ))
  persistDashboardWidgets()
}

function updateDashboardWidgetOption(widgetId, optionKey, optionValue) {
  const rawKey = String(optionKey || '')
  const key = rawKey.toLowerCase() === 'refreshinterval' ? 'refreshInterval' : rawKey
  const value = String(optionValue || '')
  if (key === 'tone' && !dashboardWidgetTones.includes(value)) return
  if (key === 'refreshInterval' && !dashboardWidgetRefreshIntervals.includes(value)) return
  if (!['tone', 'refreshInterval'].includes(key)) return
  dashboardWidgets.value = dashboardWidgets.value.map((widget) => (
    widget.id === widgetId
      ? { ...widget, options: { ...sanitizeDashboardWidgetOptions(widget.options), [key]: value } }
      : widget
  ))
  persistDashboardWidgets()
}

function toggleDashboardWidget(widgetId) {
  dashboardWidgets.value = dashboardWidgets.value.map((widget) => (
    widget.id === widgetId ? { ...widget, enabled: !widget.enabled } : widget
  ))
  persistDashboardWidgets()
}

function removeDashboardWidget(widgetId) {
  dashboardWidgets.value = dashboardWidgets.value.filter((widget) => widget.id !== widgetId)
  persistDashboardWidgets()
}

function reorderDashboardWidget(fromIndex, toIndex) {
  if (fromIndex === toIndex) return false
  if (fromIndex < 0 || toIndex < 0) return false
  if (fromIndex >= dashboardWidgets.value.length || toIndex >= dashboardWidgets.value.length) return false
  const nextWidgets = [...dashboardWidgets.value]
  const [widget] = nextWidgets.splice(fromIndex, 1)
  nextWidgets.splice(toIndex, 0, widget)
  dashboardWidgets.value = nextWidgets
  persistDashboardWidgets()
  return true
}

function moveDashboardWidget(index, direction) {
  reorderDashboardWidget(index, index + direction)
}

function moveDashboardWidgetSection(sectionId, direction) {
  const targetSection = normalizeDashboardWidgetSection(sectionId)
  const sectionIds = []
  const grouped = new Map()
  for (const widget of dashboardWidgets.value) {
    const section = dashboardWidgetSection(widget)
    if (!grouped.has(section)) {
      grouped.set(section, [])
      sectionIds.push(section)
    }
    grouped.get(section).push(widget)
  }
  const fromIndex = sectionIds.indexOf(targetSection)
  const toIndex = fromIndex + direction
  if (fromIndex < 0 || toIndex < 0 || toIndex >= sectionIds.length) return
  const reorderedSectionIds = [...sectionIds]
  const [section] = reorderedSectionIds.splice(fromIndex, 1)
  reorderedSectionIds.splice(toIndex, 0, section)
  dashboardWidgets.value = reorderedSectionIds.flatMap((id) => grouped.get(id) || [])
  persistDashboardWidgets()
}

function toggleDashboardSection(sectionId) {
  const id = normalizeDashboardWidgetSection(sectionId)
  dashboardSections.value = sanitizeDashboardSections(dashboardSections.value).map((section) => (
    section.id === id ? { ...section, collapsed: !section.collapsed } : section
  ))
  persistDashboardWidgets()
}

function startDashboardWidgetDrag(index, event) {
  if (dashboardLayoutSync.pending) return
  dashboardWidgetDragIndex.value = index
  dashboardWidgetDropIndex.value = index
  if (event?.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(index))
  }
}

function hoverDashboardWidgetDrag(index) {
  if (dashboardWidgetDragIndex.value < 0) return
  dashboardWidgetDropIndex.value = index
}

function dropDashboardWidget(index, event) {
  const rawIndex = event?.dataTransfer?.getData('text/plain')
  const parsedIndex = rawIndex ? Number.parseInt(rawIndex, 10) : dashboardWidgetDragIndex.value
  if (Number.isInteger(parsedIndex)) {
    reorderDashboardWidget(parsedIndex, index)
  }
  endDashboardWidgetDrag()
}

function endDashboardWidgetDrag() {
  dashboardWidgetDragIndex.value = -1
  dashboardWidgetDropIndex.value = -1
}

function resetDashboardWidgets() {
  dashboardWidgets.value = [...defaultDashboardWidgets]
  dashboardSections.value = [...defaultDashboardSections]
  dashboardWidgetToAdd.value = ''
  persistLocalDashboardWidgets()
  if (isLoggedIn.value) {
    void resetDashboardLayoutRemote()
  } else {
    dashboardLayoutSync.source = 'LOCAL'
    dashboardLayoutSync.updatedAt = ''
  }
}

function toggleDashboardEditMode() {
  dashboardEditMode.value = !dashboardEditMode.value
}

async function loadDashboardWidgetCatalog() {
  if (!isLoggedIn.value) {
    dashboardWidgetCatalog.value = [...defaultDashboardWidgetCatalog]
    return
  }
  const result = await safeRequest(() => getDashboardWidgetCatalog(), null)
  dashboardWidgetCatalog.value = sanitizeDashboardWidgetCatalog(result?.data)
  dashboardWidgets.value = sanitizeDashboardWidgets(dashboardWidgets.value)
}

async function loadDashboardLayout() {
  if (!isLoggedIn.value) {
    dashboardLayoutSync.source = 'LOCAL'
    dashboardLayoutSync.updatedAt = ''
    return
  }
  const result = await safeRequest(() => getDashboardLayout(), null)
  if (!result?.data) return
  const source = result.data.source || 'DEFAULT'
  dashboardWidgets.value = ['SAVED', 'DEFAULT_PRESET'].includes(source)
    ? sanitizeDashboardWidgets(result.data.widgets)
    : [...defaultDashboardWidgets]
  dashboardSections.value = sanitizeDashboardSections(result.data.sections)
  dashboardWidgetToAdd.value = ''
  dashboardLayoutSync.source = source
  dashboardLayoutSync.updatedAt = result.data.updatedAt || ''
  persistLocalDashboardWidgets()
}

async function loadDashboardLayoutPresets() {
  if (!isLoggedIn.value) {
    dashboardLayoutPresets.value = []
    dashboardLayoutPresetToApply.value = ''
    return
  }
  const result = await safeRequest(() => getDashboardLayoutPresets(), null)
  dashboardLayoutPresets.value = Array.isArray(result?.data) ? result.data : []
  if (!dashboardLayoutPresets.value.some((preset) => preset.id === dashboardLayoutPresetToApply.value)) {
    dashboardLayoutPresetToApply.value = dashboardLayoutPresets.value[0]?.id || ''
  }
  if (!dashboardLayoutDefaultForm.presetId && dashboardLayoutPresets.value.length > 0) {
    dashboardLayoutDefaultForm.presetId = dashboardLayoutPresets.value[0].id
  }
}

async function loadDashboardLayoutDefaults() {
  if (!isAdmin.value) {
    dashboardLayoutDefaults.value = []
    return
  }
  const result = await safeRequest(() => getDashboardLayoutDefaults(), { data: [] })
  dashboardLayoutDefaults.value = Array.isArray(result?.data) ? result.data : []
}

async function loadStorageBackendStatus() {
  if (!canUseAuditTools.value) {
    resetStorageBackendStatus()
    return
  }
  const result = await safeRequest(() => getStorageBackendStatus(), null)
  if (result?.data) {
    applyStorageBackendStatus(result.data)
  }
}

async function saveDashboardLayoutRemote() {
  dashboardLayoutSync.pending = true
  const result = await safeRequest(() => saveDashboardLayout(dashboardWidgets.value, 'main', dashboardSections.value, DASHBOARD_LAYOUT_SCHEMA_VERSION), null)
  dashboardLayoutSync.pending = false
  if (result?.data) {
    dashboardLayoutSync.source = result.data.source || 'SAVED'
    dashboardLayoutSync.updatedAt = result.data.updatedAt || ''
  }
}

async function resetDashboardLayoutRemote() {
  dashboardLayoutSync.pending = true
  try {
    await deleteDashboardLayout()
    const result = await safeRequest(() => getDashboardLayout(), null)
    const source = result?.data?.source || 'DEFAULT'
    dashboardWidgets.value = ['SAVED', 'DEFAULT_PRESET'].includes(source)
      ? sanitizeDashboardWidgets(result.data.widgets)
      : [...defaultDashboardWidgets]
    dashboardSections.value = sanitizeDashboardSections(result?.data?.sections)
    persistLocalDashboardWidgets()
    dashboardLayoutSync.source = source
    dashboardLayoutSync.updatedAt = result?.data?.updatedAt || ''
  } catch {
    dashboardLayoutSync.source = 'LOCAL'
  } finally {
    dashboardLayoutSync.pending = false
  }
}

async function handleApplyDashboardLayoutPreset() {
  if (!dashboardLayoutPresetToApply.value || dashboardLayoutSync.pending) return
  if (!isLoggedIn.value) {
    const preset = dashboardLayoutPresets.value.find((item) => item.id === dashboardLayoutPresetToApply.value)
    if (!preset) return
    dashboardWidgets.value = sanitizeDashboardWidgets(preset.widgets)
    dashboardSections.value = sanitizeDashboardSections(preset.sections)
    persistLocalDashboardWidgets()
    dashboardLayoutSync.source = 'LOCAL'
    dashboardLayoutSync.updatedAt = ''
    return
  }
  dashboardLayoutSync.pending = true
  const result = await safeRequest(() => applyDashboardLayoutPreset(dashboardLayoutPresetToApply.value), null)
  dashboardLayoutSync.pending = false
  if (!result?.data) return
  dashboardWidgets.value = sanitizeDashboardWidgets(result.data.widgets)
  dashboardSections.value = sanitizeDashboardSections(result.data.sections)
  dashboardLayoutSync.source = result.data.source || 'SAVED'
  dashboardLayoutSync.updatedAt = result.data.updatedAt || ''
  persistLocalDashboardWidgets()
  setStatusMessage(`Dashboard preset 적용 완료: ${dashboardLayoutPresetToApply.value}`)
}

async function handleCreateDashboardLayoutPreset() {
  if (!isAdmin.value) {
    setErrorMessage('Dashboard preset 생성 권한이 없습니다.')
    return
  }
  const name = dashboardLayoutPresetForm.name.trim()
  if (!name) {
    setErrorMessage('Dashboard preset 이름을 입력해야 합니다.')
    return
  }
  const result = await runAction(() => createDashboardLayoutPreset({
    schemaVersion: DASHBOARD_LAYOUT_SCHEMA_VERSION,
    name,
    description: dashboardLayoutPresetForm.description,
    widgets: dashboardWidgets.value,
    sections: dashboardSections.value,
  }))
  if (!result?.data) return
  dashboardLayoutPresets.value = [
    ...dashboardLayoutPresets.value.filter((preset) => preset.id !== result.data.id),
    result.data,
  ]
  dashboardLayoutPresetToApply.value = result.data.id
  dashboardLayoutPresetForm.name = ''
  dashboardLayoutPresetForm.description = ''
  setStatusMessage(`Dashboard preset 저장 완료: ${result.data.name}`)
}

async function handleUpdateDashboardLayoutPreset() {
  const preset = selectedDashboardLayoutPreset.value
  if (!preset?.custom) return
  const name = dashboardLayoutPresetForm.name.trim() || preset.name
  const result = await runAction(() => updateDashboardLayoutPreset(preset.id, {
    schemaVersion: DASHBOARD_LAYOUT_SCHEMA_VERSION,
    name,
    description: dashboardLayoutPresetForm.description || preset.description || '',
    widgets: dashboardWidgets.value,
    sections: dashboardSections.value,
  }))
  if (!result?.data) return
  dashboardLayoutPresets.value = dashboardLayoutPresets.value.map((item) => (
    item.id === result.data.id ? result.data : item
  ))
  dashboardLayoutPresetToApply.value = result.data.id
  dashboardLayoutPresetForm.name = ''
  dashboardLayoutPresetForm.description = ''
  setStatusMessage(`Dashboard preset 갱신 완료: ${result.data.name}`)
}

async function handleDeleteDashboardLayoutPreset() {
  const preset = selectedDashboardLayoutPreset.value
  if (!preset?.custom) return
  const result = await runAction(() => runCommand(() => deleteDashboardLayoutPreset(preset.id)))
  if (!result) return
  dashboardLayoutPresets.value = dashboardLayoutPresets.value.filter((item) => item.id !== preset.id)
  dashboardLayoutPresetToApply.value = dashboardLayoutPresets.value[0]?.id || ''
  setStatusMessage(`Dashboard preset 삭제 완료: ${preset.name}`)
}

async function handleExportDashboardLayoutPreset() {
  const preset = selectedDashboardLayoutPreset.value
  if (!preset) return
  const result = await runAction(() => exportDashboardLayoutPreset(preset.id))
  if (!result?.data) return
  const filename = `osmu-dashboard-preset-${preset.id}.json`
  downloadBlob(new Blob([JSON.stringify(result.data, null, 2)], { type: 'application/json;charset=utf-8' }), filename)
  setStatusMessage(`Dashboard preset 내보내기 완료: ${preset.name}`)
}

async function handleImportDashboardLayoutPreset(event) {
  const input = event?.target
  const file = input?.files?.[0]
  if (!file) return
  try {
    const payload = normalizeDashboardPresetImportPayload(JSON.parse(await file.text()))
    const result = await runAction(() => importDashboardLayoutPreset(payload))
    if (!result?.data) return
    dashboardLayoutPresets.value = [
      ...dashboardLayoutPresets.value.filter((preset) => preset.id !== result.data.id),
      result.data,
    ]
    dashboardLayoutPresetToApply.value = result.data.id
    setStatusMessage(`Dashboard preset 가져오기 완료: ${result.data.name}`)
  } catch (error) {
    setErrorMessage(error?.message || 'Dashboard preset JSON을 읽을 수 없습니다.')
  } finally {
    if (input) input.value = ''
  }
}

async function handleExportDashboardLayoutPresetBundle() {
  const result = await runAction(() => exportDashboardLayoutPresetBundle())
  if (!result?.data) return
  downloadBlob(
    new Blob([JSON.stringify(result.data, null, 2)], { type: 'application/json;charset=utf-8' }),
    'osmu-dashboard-preset-bundle.json',
  )
  const count = Array.isArray(result.data.presets) ? result.data.presets.length : 0
  setStatusMessage(`Dashboard preset bundle export complete: ${count} presets`)
}

async function handleImportDashboardLayoutPresetBundle(event) {
  const input = event?.target
  const file = input?.files?.[0]
  if (!file) return
  try {
    const payload = normalizeDashboardPresetBundleImportPayload(JSON.parse(await file.text()))
    const result = await runAction(() => importDashboardLayoutPresetBundle(payload))
    const importedPresets = Array.isArray(result?.data?.presets) ? result.data.presets : []
    if (importedPresets.length === 0) return
    const importedIds = new Set(importedPresets.map((preset) => preset.id))
    dashboardLayoutPresets.value = [
      ...dashboardLayoutPresets.value.filter((preset) => !importedIds.has(preset.id)),
      ...importedPresets,
    ]
    dashboardLayoutPresetToApply.value = importedPresets[0].id
    setStatusMessage(`Dashboard preset bundle import complete: ${result.data.importedCount ?? importedPresets.length} presets`)
  } catch (error) {
    setErrorMessage(error?.message || 'Dashboard preset bundle JSON import failed.')
  } finally {
    if (input) input.value = ''
  }
}

function updateDashboardLayoutDefaultTargetType(targetType) {
  dashboardLayoutDefaultForm.targetType = targetType
  const firstTarget = targetType === 'ORGANIZATION'
    ? organizations.value[0] && String(organizations.value[0].id)
    : dashboardLayoutDefaultRoleOptions[0].id
  dashboardLayoutDefaultForm.targetId = firstTarget || ''
}

async function handleSaveDashboardLayoutDefault() {
  if (!isAdmin.value) {
    setErrorMessage('Dashboard 기본 preset 설정 권한이 없습니다.')
    return
  }
  if (!dashboardLayoutDefaultForm.targetId || !dashboardLayoutDefaultForm.presetId) {
    setErrorMessage('기본 preset 대상과 preset을 선택해야 합니다.')
    return
  }
  const result = await runAction(() => saveDashboardLayoutDefault({
    targetType: dashboardLayoutDefaultForm.targetType,
    targetId: dashboardLayoutDefaultForm.targetId,
    presetId: dashboardLayoutDefaultForm.presetId,
  }))
  if (!result?.data) return
  dashboardLayoutDefaults.value = [
    ...dashboardLayoutDefaults.value.filter((item) => (
      item.targetType !== result.data.targetType || item.targetId !== result.data.targetId
    )),
    result.data,
  ].sort(compareDashboardLayoutDefaults)
  setStatusMessage(`Dashboard 기본 preset 저장 완료: ${result.data.targetType} ${result.data.targetId}`)
}

async function handleDeleteDashboardLayoutDefault(item) {
  const result = await runAction(() => runCommand(() => deleteDashboardLayoutDefault(item.targetType, item.targetId)))
  if (!result) return
  dashboardLayoutDefaults.value = dashboardLayoutDefaults.value.filter((entry) => (
    entry.targetType !== item.targetType || entry.targetId !== item.targetId
  ))
  setStatusMessage(`Dashboard 기본 preset 해제 완료: ${item.targetType} ${item.targetId}`)
}

async function openReadinessTarget(targetPage, targetPanel = '') {
  const target = navigationItems.find((item) => item.page === targetPage)
  if (target && canAccessNavigationItem(target)) {
    await router.push(target.to)
    await nextTick()
    focusPanel(targetPanel)
  }
}

function canAccessNavigationItem(item) {
  if (!item?.roles?.length) {
    return true
  }
  return item.roles.includes(session.user?.role)
}

function focusPanel(panelId) {
  if (!panelId || typeof document === 'undefined') return
  const element = document.getElementById(panelId)
  if (!element) return
  if (!element.hasAttribute('tabindex')) {
    element.setAttribute('tabindex', '-1')
  }
  element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  element.focus({ preventScroll: true })
}

let stopAuthSync = () => {}
let sessionRedirectPending = false
let dashboardAutoRefreshTimer = null
let dashboardAutoRefreshRunning = false

watch(dashboardAutoRefreshIntervalMs, (intervalMs) => {
  restartDashboardAutoRefresh(intervalMs)
}, { immediate: true })

onMounted(async () => {
  stopAuthSync = auth.startAuthSync(handleSessionExpired)
  refreshPendingMultipartUploads()
  if (isLoggedIn.value || await auth.restoreSession()) {
    await loadDashboard()
    return
  }
  await loadHealth()
})

onUnmounted(() => {
  uploadController.value?.abort()
  stopDashboardAutoRefresh()
  stopAuthSync()
})

async function refreshAll() {
  refreshPendingMultipartUploads()
  if (isLoggedIn.value) {
    await loadDashboard()
    return
  }
  await loadHealth()
}

function restartDashboardAutoRefresh(intervalMs = dashboardAutoRefreshIntervalMs.value) {
  stopDashboardAutoRefresh()
  if (!intervalMs || intervalMs <= 0 || typeof window === 'undefined') return
  dashboardAutoRefreshTimer = window.setInterval(() => {
    void refreshDashboardAutoData()
  }, intervalMs)
}

function stopDashboardAutoRefresh() {
  if (!dashboardAutoRefreshTimer || typeof window === 'undefined') return
  window.clearInterval(dashboardAutoRefreshTimer)
  dashboardAutoRefreshTimer = null
}

async function refreshDashboardAutoData() {
  if (dashboardAutoRefreshRunning || !isLoggedIn.value || activePage.value !== 'dashboard') return
  dashboardAutoRefreshRunning = true
  try {
    await loadDashboard({ background: true })
  } finally {
    dashboardAutoRefreshRunning = false
  }
}

async function loadHealth() {
  clearError()
  try {
    const [backend, storage, database] = await Promise.all([getHealth(), getStorageHealth(), getDatabaseHealth()])
    health.backend = backend.data.status
    health.storage = storage.data.status
    health.database = database.data.status
  } catch (error) {
    health.backend = 'DOWN'
    setError(error)
  }
}

async function loadDashboard(options = {}) {
  const background = options?.background === true
  if (!background) {
    clearError()
    dashboardLoadState.loading = true
    dashboardLoadState.error = ''
  }
  refreshPendingMultipartUploads()
  try {
    await loadDashboardWidgetCatalog()
    await Promise.all([loadDashboardLayout(), loadDashboardLayoutPresets(), loadDashboardLayoutDefaults()])
    const dashboardSummaryLoaded = canUseAuditTools.value ? await loadDashboardSummary() : false
    if (!dashboardSummaryLoaded) {
      await loadHealth()
    }
    await loadStorageBackendStatus()

    const [bucketResult, keyResult] = await Promise.all([
      safeRequest(() => getBuckets(), { items: [] }),
      safeRequest(() => getAccessKeys(), { items: [] }),
    ])

    buckets.value = bucketResult.items || []
    accessKeys.value = keyResult.items || []
    await Promise.all([loadStorageProfiles(), loadStorageProfileRequests()])
    await loadS3ClientConfig()
    syncAccessKeyBucketSelection()
    if (!dashboardSummaryLoaded) {
      Object.assign(usage, summarizeBuckets(buckets.value))
    }

    if (!selectedBucket.value && buckets.value.length > 0) {
      selectedBucket.value = buckets.value[0].name
    }

    if (canUseAdminTools.value) {
      const [userResult, organizationResult, organizationUsageResult, teamResult] = await Promise.all([
        safeRequest(() => getUsers(), { items: [] }),
        safeRequest(() => getOrganizations(), { items: [] }),
        safeRequest(() => getOrganizationUsage(), { items: [] }),
        safeRequest(() => getTeams(), { items: [] }),
      ])
      users.value = userResult.items || []
      organizations.value = organizationResult.items || []
      organizationUsages.value = organizationUsageResult.items || []
      teams.value = teamResult.items || []
      syncTeamFormDefaults()
      await loadBillingPricingPolicy()
      await loadChargebackPanel()
    } else {
      users.value = []
      organizations.value = []
      organizationUsages.value = []
      teams.value = []
      resetBillingPricingPolicy()
      resetChargebackPreview()
      resetChargebackAlerts()
      resetChargebackAlertNotificationPreview()
      resetChargebackAlertNotificationOutbox()
      resetChargebackInvoiceDrafts()
      resetChargebackFinalInvoices()
      resetChargebackPaymentProviderHandoffs()
      resetChargebackPaymentProviderAdapterReadiness()
      resetChargebackAdapterRetryWorker()
    }

    if (isAdmin.value) {
      await Promise.all([
        dashboardSummaryLoaded ? Promise.resolve() : loadAdminUsage(),
        dashboardSummaryLoaded ? Promise.resolve() : loadBackupStatus(),
        dashboardSummaryLoaded ? Promise.resolve() : loadRetentionStatus(),
        dashboardSummaryLoaded ? loadDataFlowDailyRollup() : loadDataFlowMonitoring(),
        loadDataFlowStorageStatus(),
        loadDataFlowRetention(),
        loadStorageExpansionExecutionLogRetentionStatus(),
        refreshLifecycleRules(),
        refreshLifecycleRuleConflicts(),
        loadQuotaPolicies(),
        loadStorageProfileRequests(),
        loadStorageExpansionRequests(),
        loadStorageExpansionSummary(),
        loadStorageExpansionRunnerPreflight(),
        loadObjectSharePolicy(),
        loadEnterpriseAuthPlan(),
        dashboardSummaryLoaded ? Promise.resolve() : refreshObjectShareAnalytics(),
        dashboardSummaryLoaded ? Promise.resolve() : handleLoadAuditLogs(),
      ])
    } else if (!isAuditor.value) {
      resetAdminOnlyState()
    }

    if (selectedBucket.value) {
      await loadSelectedBucketDetails()
    } else {
      objects.value = []
      objectPrefixes.value = []
    }

    if (!background) {
      dashboardLoadState.error = errorMessage.value || ''
    }
  } catch (error) {
    if (!background) {
      dashboardLoadState.error = error?.message || 'Dashboard 데이터를 불러오지 못했습니다.'
    }
    setError(error)
  } finally {
    if (!background) {
      dashboardLoadState.loading = false
    }
  }
}

async function safeRequest(action, fallback) {
  try {
    return await action()
  } catch {
    return fallback
  }
}

async function loadStorageProfiles() {
  const result = await safeRequest(() => getStorageProfiles(), { items: [] })
  storageProfiles.value = result.items || []
  if (!storageProfileForm.requestedProfile && storageProfiles.value.length > 0) {
    storageProfileForm.requestedProfile = storageProfiles.value[0].code
  }
}

async function loadStorageProfileRequests() {
  const loader = isAdmin.value ? getAdminStorageProfileRequests : getStorageProfileRequests
  const result = await safeRequest(() => loader(), { items: [] })
  storageProfileRequests.value = result.items || []
}

async function loadDashboardSummary() {
  const result = await safeRequest(() => getDashboardSummary(), null)
  if (!result?.data) {
    return false
  }
  if (result.data.usage) {
    Object.assign(usage, result.data.usage)
  }
  if (result.data.system) {
    applyHealthStatus(result.data.system)
  }
  if (result.data.backup) {
    applyBackupStatus(result.data.backup)
  }
  if (result.data.retention) {
    applyRetentionStatus(result.data.retention)
  }
  if (result.data.shareAnalytics) {
    applyObjectShareAnalytics(result.data.shareAnalytics)
  }
  if (result.data.quota) {
    applyDashboardQuotaSummary(result.data.quota)
  }
  if (result.data.readiness) {
    applyDashboardReadiness(result.data.readiness)
  }
  if (result.data.dataFlow) {
    applyDataFlowMonitoring(result.data.dataFlow)
  }
  if (Array.isArray(result.data.recentAuditLogs)) {
    auditLogs.value = result.data.recentAuditLogs
    auditNextCursor.value = ''
  } else if (Array.isArray(result.data.recentAuditLogs?.items)) {
    auditLogs.value = result.data.recentAuditLogs.items
    auditNextCursor.value = result.data.recentAuditLogs.nextCursor || ''
  }
  return true
}

async function loadDataFlowMonitoring() {
  const payload = dataFlowFilterPayload()
  const [snapshotResult, rollupResult, monthlyRollupResult] = await Promise.all([
    safeRequest(() => getDataFlowMonitoring(payload), null),
    safeRequest(() => getDataFlowDailyRollup(payload), null),
    safeRequest(() => getDataFlowMonthlyRollup(payload), null),
  ])
  if (snapshotResult?.data) {
    applyDataFlowMonitoring(snapshotResult.data)
  }
  if (rollupResult?.data) {
    applyDataFlowDailyRollup(rollupResult.data)
  }
  if (monthlyRollupResult?.data) {
    applyDataFlowMonthlyRollup(monthlyRollupResult.data)
  }
}

async function loadDataFlowDailyRollup() {
  const result = await safeRequest(() => getDataFlowDailyRollup(dataFlowFilterPayload()), null)
  if (result?.data) {
    applyDataFlowDailyRollup(result.data)
  }
}

async function loadDataFlowMonthlyRollup() {
  const result = await safeRequest(() => getDataFlowMonthlyRollup(dataFlowFilterPayload()), null)
  if (result?.data) {
    applyDataFlowMonthlyRollup(result.data)
  }
}

async function loadDataFlowRetention() {
  if (!isAdmin.value) {
    resetDataFlowRetention()
    return
  }
  const result = await safeRequest(() => getDataFlowRetentionStatus(), null)
  if (result?.data) {
    applyDataFlowRetention(result.data)
  }
}

async function loadDataFlowStorageStatus() {
  if (!isAdmin.value) {
    resetDataFlowStorageStatus()
    return
  }
  const result = await safeRequest(() => getDataFlowStorageStatus(), null)
  if (result?.data) {
    applyDataFlowStorageStatus(result.data)
  }
}

async function loadBillingPricingPolicy() {
  if (!canUseAdminTools.value) {
    resetBillingPricingPolicy()
    return
  }
  const result = await safeRequest(() => getBillingPricingPolicy(), null)
  if (result?.data) {
    applyBillingPricingPolicy(result.data)
  }
}

async function loadBillingPricingPolicyProposals() {
  if (!isAdmin.value) {
    resetBillingPricingPolicyProposals()
    return
  }
  const result = await safeRequest(() => getBillingPricingPolicyProposals({ limit: 25 }), null)
  if (result?.data) {
    applyBillingPricingPolicyProposals(result.data)
  }
}

async function loadChargebackPreview() {
  if (!canUseAdminTools.value) {
    resetChargebackPreview()
    return
  }
  const result = await safeRequest(() => getChargebackPreview(chargebackPreviewPayload()), null)
  if (result?.data) {
    applyChargebackPreview(result.data)
  }
}

async function loadChargebackDailyRollup() {
  if (!canUseAdminTools.value) {
    resetChargebackDailyRollup()
    return
  }
  const result = await safeRequest(() => getChargebackDailyRollup({
    ...chargebackPreviewPayload(),
    days: 30,
    limit: 200,
  }), null)
  if (result?.data) {
    applyChargebackDailyRollup(result.data)
  }
}

async function loadChargebackAlerts() {
  if (!canUseAdminTools.value) {
    resetChargebackAlerts()
    return
  }
  const result = await safeRequest(() => getChargebackAlerts(chargebackPreviewPayload()), null)
  if (result?.data) {
    applyChargebackAlerts(result.data)
  }
}

async function loadChargebackAlertNotificationPreview() {
  if (!canUseAdminTools.value) {
    resetChargebackAlertNotificationPreview()
    return
  }
  const result = await safeRequest(() => getChargebackAlertNotificationPreview(chargebackPreviewPayload()), null)
  if (result?.data) {
    applyChargebackAlertNotificationPreview(result.data)
  }
}

async function loadChargebackAlertNotificationOutbox() {
  if (!canUseAdminTools.value) {
    resetChargebackAlertNotificationOutbox()
    return
  }
  const result = await safeRequest(() => getChargebackAlertNotificationOutbox({ limit: 25 }), null)
  if (result?.data) {
    applyChargebackAlertNotificationOutbox(result.data)
  }
}

async function loadChargebackInvoiceDrafts() {
  if (!isAdmin.value) {
    resetChargebackInvoiceDrafts()
    return
  }
  const result = await safeRequest(() => getChargebackInvoiceDrafts({ limit: 25 }), null)
  if (result?.data) {
    applyChargebackInvoiceDrafts(result.data)
  }
}

async function loadChargebackFinalInvoices() {
  if (!isAdmin.value) {
    resetChargebackFinalInvoices()
    return
  }
  const result = await safeRequest(() => getChargebackFinalInvoices({ limit: 25 }), null)
  if (result?.data) {
    applyChargebackFinalInvoices(result.data)
  }
}

async function loadChargebackPaymentProviderHandoffs() {
  if (!isAdmin.value) {
    resetChargebackPaymentProviderHandoffs()
    return
  }
  const result = await safeRequest(() => getChargebackPaymentProviderHandoffs({ limit: 25 }), null)
  if (result?.data) {
    applyChargebackPaymentProviderHandoffs(result.data)
  }
}

async function loadChargebackPaymentProviderAdapterReadiness() {
  if (!isAdmin.value) {
    resetChargebackPaymentProviderAdapterReadiness()
    return
  }
  const result = await safeRequest(() => getChargebackPaymentProviderAdapterReadiness(), null)
  if (result?.data) {
    applyChargebackPaymentProviderAdapterReadiness(result.data)
  }
}

async function loadChargebackAdapterRetryWorker() {
  if (!isAdmin.value) {
    resetChargebackAdapterRetryWorker()
    return
  }
  const result = await safeRequest(() => getChargebackAdapterRetryWorkerStatus({ limit: 25 }), null)
  if (result?.data) {
    applyChargebackAdapterRetryWorker(result.data)
  }
}

async function loadChargebackPanel() {
  await Promise.all([
    loadChargebackPreview(),
    loadChargebackDailyRollup(),
    loadChargebackAlerts(),
    loadChargebackAlertNotificationPreview(),
    loadChargebackAlertNotificationOutbox(),
    loadChargebackInvoiceDrafts(),
    loadChargebackFinalInvoices(),
    loadChargebackPaymentProviderHandoffs(),
    loadChargebackPaymentProviderAdapterReadiness(),
    loadChargebackAdapterRetryWorker(),
    loadBillingPricingPolicyProposals(),
  ])
}

async function handleSaveBillingPricingPolicy() {
  if (!isAdmin.value) return
  const result = await runAction(() => saveBillingPricingPolicy(billingPricingPolicyPayload()))
  if (result?.data) {
    applyBillingPricingPolicy(result.data)
    await loadChargebackPanel()
    setStatusMessage('Billing pricing policy saved.')
  }
}

async function handleCreateBillingPricingPolicyProposal() {
  if (!isAdmin.value) return
  const result = await runAction(() => createBillingPricingPolicyProposal({
    ...billingPricingPolicyPayload(),
    reason: 'Admin billing panel pricing policy proposal',
  }))
  if (result?.data) {
    applyBillingPricingPolicyProposals({
      proposalCount: 1,
      proposals: result.data.proposal ? [result.data.proposal] : [],
      generatedAt: result.data.generatedAt,
    })
    await loadBillingPricingPolicyProposals()
    setStatusMessage('Billing pricing policy proposal created for internal approval.')
  }
}

async function handleApproveBillingPricingPolicyProposal(proposalId) {
  if (!isAdmin.value || !proposalId) return
  const result = await runAction(() => approveBillingPricingPolicyProposal(proposalId, {
    approvalNote: 'Approved from admin billing panel',
  }))
  if (result?.data) {
    if (result.data.appliedPolicy) {
      applyBillingPricingPolicy(result.data.appliedPolicy)
    }
    await loadBillingPricingPolicyProposals()
    await loadChargebackPanel()
    setStatusMessage('Billing pricing policy proposal approved and applied internally.')
  }
}

async function handleApproveBillingPricingPolicyProposalPriceList(proposalId) {
  if (!isAdmin.value || !proposalId) return
  const generatedAt = new Date()
  const result = await runAction(() => approveBillingPricingPolicyProposalPriceList(proposalId, {
    approvalReference: `PRICE-LIST-${generatedAt.toISOString().slice(0, 10)}`,
    approvalNote: 'Commercial price list approval recorded from admin billing panel',
    effectiveFrom: generatedAt.toISOString(),
  }))
  if (result?.data) {
    await loadBillingPricingPolicyProposals()
    setStatusMessage('Billing pricing policy proposal recorded as an approved price list.')
  }
}

async function handleQueueChargebackAlertNotifications() {
  const result = await runAction(() => queueChargebackAlertNotifications({
    ...chargebackPreviewPayload(),
    reason: 'Admin billing panel notification queue',
  }))
  if (result?.data) {
    applyChargebackAlertNotificationOutbox({
      deliveryCount: result.data.queuedCount,
      deliveries: result.data.deliveries || [],
      generatedAt: result.data.generatedAt,
    })
    await loadChargebackAlertNotificationOutbox()
    setStatusMessage('Chargeback notification outbox updated.')
  }
}

async function handleSendChargebackNotificationAdapter(payload = {}) {
  if (!isAdmin.value || !payload.deliveryId) return
  const result = await runAction(() => sendChargebackAlertNotificationAdapter(payload.deliveryId, {
    retryDelayMinutes: 60,
  }))
  if (result?.data) {
    await Promise.all([
      loadChargebackAlertNotificationOutbox(),
      loadChargebackAdapterRetryWorker(),
    ])
    setStatusMessage('Chargeback notification adapter send recorded.')
  }
}

async function handleRecordChargebackNotificationAdapterResult(payload = {}) {
  if (!isAdmin.value || !payload.deliveryId) return
  const retry = payload.result === 'RETRY'
  const result = await runAction(() => recordChargebackAlertNotificationAdapterResult(payload.deliveryId, {
    result: payload.result || 'BLOCKED_CREDENTIAL',
    retryDelayMinutes: retry ? 60 : undefined,
    lastError: retry
      ? 'Notification adapter retry scheduled from admin billing panel.'
      : 'Notification adapter credential/configuration reference missing.',
  }))
  if (result?.data) {
    await loadChargebackAlertNotificationOutbox()
    setStatusMessage('Chargeback notification adapter result recorded.')
  }
}

async function handleExportChargebackCsv() {
  const blob = await runAction(() => downloadChargebackPreviewCsv(chargebackPreviewPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-chargeback-preview-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Chargeback CSV export complete.')
  }
}

async function handleExportChargebackDailyRollupCsv() {
  const blob = await runAction(() => downloadChargebackDailyRollupCsv({
    ...chargebackPreviewPayload(),
    days: 30,
    limit: 200,
  }))
  if (blob) {
    downloadBlob(blob, `osmu-chargeback-daily-rollup-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Chargeback daily rollup CSV export complete.')
  }
}

async function handleExportChargebackInvoiceDraftCsv() {
  const blob = await runAction(() => downloadChargebackInvoiceDraftCsv(chargebackPreviewPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-chargeback-invoice-draft-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Chargeback invoice draft CSV export complete.')
  }
}

async function handleCreateChargebackInvoiceDrafts() {
  if (!isAdmin.value) return
  const result = await runAction(() => createChargebackInvoiceDrafts({
    ...chargebackPreviewPayload(),
    reason: 'Admin billing panel invoice draft persistence',
  }))
  if (result?.data) {
    applyChargebackInvoiceDrafts({
      invoiceCount: result.data.persistedCount,
      invoices: result.data.invoices || [],
      generatedAt: result.data.generatedAt,
    })
    await loadChargebackInvoiceDrafts()
    setStatusMessage('Chargeback invoice draft records saved.')
  }
}

async function handleApproveChargebackInvoiceDraft(invoiceId) {
  if (!isAdmin.value || !invoiceId) return
  const result = await runAction(() => approveChargebackInvoiceDraft(invoiceId, {
    approvalNote: 'Approved from admin billing panel',
  }))
  if (result?.data) {
    await loadChargebackInvoiceDrafts()
    setStatusMessage('Chargeback invoice draft approved internally.')
  }
}

async function handleFinalizeChargebackInvoiceDraft(invoiceId) {
  if (!isAdmin.value || !invoiceId) return
  const result = await runAction(() => finalizeChargebackInvoiceDraft(invoiceId, {
    finalizationNote: 'Finalized from admin billing panel',
  }))
  if (result?.data) {
    await loadChargebackFinalInvoices()
    setStatusMessage('Chargeback final invoice created.')
  }
}

async function handleRequestChargebackInvoicePayment(invoiceId) {
  if (!isAdmin.value || !invoiceId) return
  const result = await runAction(() => requestChargebackInvoicePayment(invoiceId, {
    paymentRequestNote: 'Payment requested from admin billing panel',
  }))
  if (result?.data) {
    await loadChargebackFinalInvoices()
    setStatusMessage('Chargeback payment request recorded.')
  }
}

async function handleQueueChargebackPaymentProviderHandoff(invoiceId) {
  if (!isAdmin.value || !invoiceId) return
  const result = await runAction(() => queueChargebackPaymentProviderHandoff(invoiceId, {
    paymentProvider: chargebackOptions.paymentProvider,
    paymentTargetAccount: chargebackOptions.paymentTargetAccount,
    reason: 'Admin billing panel payment provider handoff',
  }))
  if (result?.data) {
    applyChargebackPaymentProviderHandoffs({
      handoffCount: 1,
      handoffs: result.data.handoff ? [result.data.handoff] : [],
      generatedAt: result.data.generatedAt,
    })
    await loadChargebackPaymentProviderHandoffs()
    setStatusMessage('Chargeback payment provider handoff queued.')
  }
}

async function handleSendChargebackPaymentProviderAdapter(payload = {}) {
  if (!isAdmin.value || !payload.handoffId) return
  const result = await runAction(() => sendChargebackPaymentProviderHandoffAdapter(payload.handoffId, {
    retryDelayMinutes: 60,
  }))
  if (result?.data) {
    await Promise.all([
      loadChargebackPaymentProviderHandoffs(),
      loadChargebackAdapterRetryWorker(),
    ])
    setStatusMessage('Chargeback payment provider adapter send recorded.')
  }
}

async function handleRecordChargebackPaymentProviderAdapterResult(payload = {}) {
  if (!isAdmin.value || !payload.handoffId) return
  const retry = payload.result === 'RETRY'
  const result = await runAction(() => recordChargebackPaymentProviderHandoffAdapterResult(payload.handoffId, {
    result: payload.result || 'BLOCKED_CREDENTIAL',
    retryDelayMinutes: retry ? 60 : undefined,
    lastError: retry
      ? 'Payment provider adapter retry scheduled from admin billing panel.'
      : 'Payment provider adapter credential/configuration reference missing.',
  }))
  if (result?.data) {
    await loadChargebackPaymentProviderHandoffs()
    setStatusMessage('Chargeback payment provider adapter result recorded.')
  }
}

async function handleRunChargebackAdapterRetryWorker() {
  if (!isAdmin.value) return
  const result = await runAction(() => runChargebackAdapterRetryWorker({ dryRun: false, limit: 25 }))
  if (result?.data) {
    applyChargebackAdapterRetryWorker(result.data)
    await Promise.all([
      loadChargebackAlertNotificationOutbox(),
      loadChargebackPaymentProviderHandoffs(),
    ])
    setStatusMessage('Chargeback adapter retry worker completed.')
  }
}

async function handleRecordChargebackInvoicePayment(invoiceId) {
  if (!isAdmin.value || !invoiceId) return
  const result = await runAction(() => recordChargebackInvoicePayment(invoiceId, {
    paymentReference: `MANUAL-${new Date().toISOString().slice(0, 10)}`,
    paymentNote: 'Payment recorded from admin billing panel',
  }))
  if (result?.data) {
    await loadChargebackFinalInvoices()
    setStatusMessage('Chargeback payment record saved.')
  }
}

async function loadEnterpriseAuthPlan() {
  const result = await safeRequest(() => getEnterpriseAuthPlan(), null)
  enterpriseAuthPlan.value = result?.data || defaultEnterpriseAuthPlan()
}

function resetEnterpriseAuthPlan() {
  enterpriseAuthPlan.value = defaultEnterpriseAuthPlan()
}

function defaultEnterpriseAuthPlan() {
  return {
    status: 'LOCAL_ONLY',
    currentLoginMode: 'LOCAL_PASSWORD',
    activeLoginModes: ['LOCAL_PASSWORD'],
    plannedExternalModes: ['OIDC', 'LDAP'],
    externalProviderConfigured: false,
    oidc: { status: 'NOT_CONFIGURED', issuerUri: '', clientIdConfigured: false },
    ldap: { status: 'NOT_CONFIGURED', url: '', baseDn: '' },
    claimMapping: {
      subjectClaim: 'sub',
      emailClaim: 'email',
      nameClaim: 'name',
      roleClaim: 'osmu_roles',
      organizationClaim: 'osmu_org',
      teamClaim: 'osmu_teams',
      allowedDomains: [],
      jitProvisioningEnabled: false,
    },
    roleMappings: [],
    gates: [],
    nextImplementationSteps: [],
    generatedAt: '',
  }
}

async function handleExportDataFlowCsv() {
  const blob = await runAction(() => downloadDataFlowMonitoringCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Data flow CSV export complete.')
  }
}

async function handleExportDataFlowDailyRollupCsv() {
  const blob = await runAction(() => downloadDataFlowDailyRollupCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-daily-rollup-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Data flow daily rollup CSV export complete.')
  }
}

async function handleMaterializeDataFlowDailyRollup() {
  const result = await runAction(() => materializeDataFlowDailyRollup(dataFlowFilterPayload()))
  if (result?.data) {
    applyDataFlowDailyRollup(result.data)
    setStatusMessage(`Data flow daily rollup store refreshed: ${formatCount(result.data.storedPointCount || 0)} points.`)
  }
}

async function handleLoadMaterializedDataFlowDailyRollup() {
  const result = await runAction(() => getMaterializedDataFlowDailyRollup(dataFlowFilterPayload()))
  if (result?.data) {
    applyDataFlowDailyRollup(result.data)
    setStatusMessage(`Materialized data flow daily rollup loaded: ${formatCount(result.data.pointCount || 0)} points.`)
  }
}

async function handleExportMaterializedDataFlowDailyRollupCsv() {
  const blob = await runAction(() => downloadMaterializedDataFlowDailyRollupCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-daily-rollup-materialized-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Materialized data flow daily rollup CSV export complete.')
  }
}

async function handleLoadDataFlowMonthlyRollup() {
  const result = await runAction(() => getDataFlowMonthlyRollup(dataFlowFilterPayload()))
  if (result?.data) {
    applyDataFlowMonthlyRollup(result.data)
    setStatusMessage(`Data flow monthly rollup loaded: ${formatCount(result.data.pointCount || 0)} points.`)
  }
}

async function handleExportDataFlowMonthlyRollupCsv() {
  const blob = await runAction(() => downloadDataFlowMonthlyRollupCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-monthly-rollup-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Data flow monthly rollup CSV export complete.')
  }
}

async function handleMaterializeDataFlowMonthlyRollup() {
  const result = await runAction(() => materializeDataFlowMonthlyRollup(dataFlowFilterPayload()))
  if (result?.data) {
    applyDataFlowMonthlyRollup(result.data)
    setStatusMessage(`Data flow monthly rollup store refreshed: ${formatCount(result.data.storedPointCount || 0)} points.`)
  }
}

async function handleLoadMaterializedDataFlowMonthlyRollup() {
  const result = await runAction(() => getMaterializedDataFlowMonthlyRollup(dataFlowFilterPayload()))
  if (result?.data) {
    applyDataFlowMonthlyRollup(result.data)
    setStatusMessage(`Materialized data flow monthly rollup loaded: ${formatCount(result.data.pointCount || 0)} points.`)
  }
}

async function handleExportMaterializedDataFlowMonthlyRollupCsv() {
  const blob = await runAction(() => downloadMaterializedDataFlowMonthlyRollupCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-monthly-rollup-materialized-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Materialized data flow monthly rollup CSV export complete.')
  }
}

async function handleRunDataFlowRetention() {
  const result = await runAction(() => runDataFlowRetention({ includeEvents: true, includeDailyRollups: true, includeMonthlyRollups: true }))
  if (result?.data) {
    if (result.data.status) {
      applyDataFlowRetention(result.data.status)
    } else {
      await loadDataFlowRetention()
    }
    setStatusMessage(`Data flow retention completed: events ${formatCount(result.data.deletedEventCount || 0)}, daily rollups ${formatCount(result.data.deletedDailyRollupCount || 0)}, monthly rollups ${formatCount(result.data.deletedMonthlyRollupCount || 0)}.`)
  }
}

async function loadS3ClientConfig() {
  const result = await safeRequest(() => getS3ClientConfig(), null)
  if (result?.data) {
    applyS3ClientConfig(result.data)
  }
}

async function handleRefreshDashboardReadiness() {
  const result = await runAction(() => getDashboardReadiness())
  if (result?.data) {
    applyDashboardReadiness(result.data)
    setStatusMessage('Readiness 새로고침 완료')
  }
}

async function loadAdminUsage() {
  const result = await safeRequest(() => getUsage(), null)
  if (result?.data) {
    Object.assign(usage, result.data)
  }
}

async function loadBackupStatus() {
  const result = await safeRequest(() => getBackupStatus(), null)
  if (result?.data) {
    applyBackupStatus(result.data)
  }
}

async function loadRetentionStatus() {
  const result = await safeRequest(() => getObjectRetentionStatus(), null)
  if (result?.data) {
    applyRetentionStatus(result.data)
  }
}

async function loadStorageExpansionExecutionLogRetentionStatus() {
  const result = await safeRequest(() => getStorageExpansionExecutionLogRetentionStatus(), null)
  if (result?.data) {
    applyStorageExpansionExecutionLogRetentionStatus(result.data)
  }
}

async function handleLogout() {
  await runAction(() => logoutApi())
  resetSessionData()
  await router.push('/login')
}

function handleSessionExpired() {
  resetSessionData()
  const currentRoute = router.currentRoute.value
  if (sessionRedirectPending || !currentRoute?.meta?.requiresAuth) {
    return
  }

  sessionRedirectPending = true
  router.replace({
    name: 'login',
    query: {
      redirect: currentRoute.fullPath || '/dashboard',
      reason: 'session-expired',
    },
  }).finally(() => {
    sessionRedirectPending = false
  })
}

function resetSessionData() {
  buckets.value = []
  objects.value = []
  objectPrefixes.value = []
  accessKeys.value = []
  storageProfiles.value = []
  storageProfileRequests.value = []
  bucketStorageProfile.value = null
  storageProfileForm.requestedProfile = 'STANDARD'
  storageProfileForm.reason = ''
  storageProfileAdminNote.value = ''
  bucketPermissions.value = []
  users.value = []
  organizations.value = []
  organizationUsages.value = []
  selectedBucket.value = ''
  objectPrefix.value = ''
  objectSearch.value = ''
  objectTagFilter.value = ''
  objectViewMode.value = 'active'
  objectMetadata.value = null
  dashboardLayoutPresets.value = []
  dashboardLayoutPresetToApply.value = ''
  dashboardLayoutPresetForm.name = ''
  dashboardLayoutPresetForm.description = ''
  dashboardLayoutDefaults.value = []
  dashboardLayoutDefaultForm.targetType = 'ROLE'
  dashboardLayoutDefaultForm.targetId = 'USER'
  dashboardLayoutDefaultForm.presetId = ''
  dashboardLayoutSync.source = 'LOCAL'
  dashboardLayoutSync.updatedAt = ''
  dashboardLayoutSync.pending = false
  dashboardLoadState.loading = false
  dashboardLoadState.error = ''
  dashboardEditMode.value = false
  resetObjectVersions()
  resetObjectShareLinks()
  resetS3ClientConfig()
  resetAdminOnlyState()
  resetUploadRuntime()
}

function resetAdminOnlyState() {
  auditLogs.value = []
  auditNextCursor.value = ''
  quotaPolicies.value = []
  quotaPolicyHistory.value = []
  storageExpansionRequests.value = []
  storageExpansionManifest.value = null
  storageExpansionExecutionPlan.value = null
  storageExpansionGitOpsPlan.value = null
  storageExpansionExecutions.value = []
  storageExpansionApplyEvidence.value = ''
  resetStorageExpansionExecutionForm()
  lifecycleRules.value = []
  resetBackupStatus()
  resetRetentionPolicy()
  resetStorageExpansionExecutionLogRetention()
  resetStorageExpansionSummary()
  resetStorageExpansionRunnerPreflight()
  resetStorageBackendStatus()
  resetLifecycleRuleForm()
  resetLifecycleRuleConflicts()
  resetLifecycleXml()
  resetQuotaPolicyForm()
  resetStorageExpansionForm()
  resetObjectSharePolicy()
  resetObjectShareAnalytics()
  resetEnterpriseAuthPlan()
  resetDashboardQuotaSummary()
  resetDashboardReadiness()
  resetDataFlowMonitoring()
  resetBillingPricingPolicy()
  resetBillingPricingPolicyProposals()
  resetChargebackOptions()
  resetChargebackPreview()
  resetChargebackDailyRollup()
  resetChargebackAlerts()
  resetChargebackAlertNotificationPreview()
  resetChargebackAlertNotificationOutbox()
  resetChargebackInvoiceDrafts()
  resetChargebackFinalInvoices()
  resetChargebackPaymentProviderHandoffs()
  resetChargebackPaymentProviderAdapterReadiness()
  resetChargebackAdapterRetryWorker()
}

function resetUploadRuntime() {
  presignedUrl.value = ''
  shareLinkUrl.value = ''
  shareLinkPassword.value = ''
  shareLinkAllowedIpCidrs.value = ''
  pendingUploadId.value = ''
  pendingMultipartUploads.value = []
  uploadState.active = false
  uploadState.loadedBytes = 0
  uploadState.totalBytes = 0
  uploadState.percent = 0
  uploadState.message = ''
  uploadState.retryable = false
  lastUploadRequest.value = null
}

async function handleCreateBucket() {
  const quotaBytes = Number(bucketForm.quotaGb || 1) * BYTES_PER_GIB
  const payload = { name: bucketForm.name, quotaBytes }
  if (bucketForm.ownerType === 'ORG') {
    if (!canCreateOrgBucket.value) {
      setErrorMessage('조직 버킷 생성 권한이 없습니다.')
      return
    }
    if (isAdmin.value && !bucketForm.ownerId) {
      setErrorMessage('조직을 선택해야 합니다.')
      return
    }
    payload.ownerType = 'ORG'
    payload.ownerId = isAdmin.value ? Number(bucketForm.ownerId) : session.user?.organizationId
  }
  const result = await runAction(() => createBucket(payload))
  if (result) {
    bucketForm.name = ''
    bucketForm.ownerType = 'USER'
    bucketForm.ownerId = ''
    selectedBucket.value = result.data.name
    await loadDashboard()
    setStatusMessage(`${result.data?.name || payload.name} 버킷 생성 완료`)
  }
}

function handleDeleteBucket(bucketName) {
  openConfirmDialog({
    title: '버킷 삭제',
    message: `${bucketName} 버킷을 삭제합니다. 비어 있는 버킷만 삭제할 수 있습니다.`,
    confirmLabel: '삭제',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteBucket(bucketName)))
      if (!result) return false
      if (selectedBucket.value === bucketName) {
        selectedBucket.value = ''
        resetSelectedBucketState()
      }
      await loadDashboard()
      setStatusMessage(`${bucketName} 버킷 삭제 완료`)
      return true
    },
  })
}

async function handleSyncBucket(bucketName) {
  const result = await runAction(() => syncBucketUsage(bucketName))
  if (result) {
    await loadDashboard()
    const summary = result.data || {}
    setStatusMessage(`${bucketName} 버킷 사용량 동기화 완료 (added ${summary.metadataAddedCount || 0}, updated ${summary.metadataUpdatedCount || 0}, removed ${summary.metadataRemovedCount || 0})`)
  }
}

async function selectBucket(bucketName) {
  selectedBucket.value = bucketName
  resetSelectedBucketState()
  refreshPendingMultipartUploads()
  await loadSelectedBucketDetails()
}

function resetSelectedBucketState() {
  objectPrefix.value = ''
  objectSearch.value = ''
  objectTagFilter.value = ''
  objectViewMode.value = 'active'
  objectNextCursor.value = ''
  objectMetadata.value = null
  objectTagForm.key = ''
  objectTagForm.tags = ''
  resetObjectVersions()
  resetObjectShareLinks()
  resetBucketLifecycleXml()
  resetBucketTags()
  bucketStorageProfile.value = null
  presignedUrl.value = ''
  shareLinkUrl.value = ''
  shareLinkPassword.value = ''
  shareLinkAllowedIpCidrs.value = ''
}

async function loadSelectedBucketDetails() {
  await Promise.all([
    loadObjects(),
    loadBucketPermissions(),
    loadBucketLifecycleXml(),
    loadBucketTags(),
    loadBucketStorageProfile(),
  ])
}

async function loadBucketStorageProfile() {
  if (!selectedBucket.value) {
    bucketStorageProfile.value = null
    return
  }
  const result = await safeRequest(() => getBucketStorageProfile(selectedBucket.value), null)
  bucketStorageProfile.value = result?.data || null
}

async function handleCreateStorageProfileRequest() {
  if (!selectedBucket.value || !storageProfileForm.requestedProfile) return
  const result = await runAction(() => createStorageProfileRequest(selectedBucket.value, {
    requestedProfile: storageProfileForm.requestedProfile,
    reason: storageProfileForm.reason,
  }))
  if (!result?.data) return
  storageProfileForm.reason = ''
  await Promise.all([loadStorageProfileRequests(), loadBucketStorageProfile()])
  setStatusMessage(`Storage profile requested: ${result.data.requestedProfile?.name || result.data.requestedProfile?.code}`)
}

async function handleUpdateStorageProfileRequestStatus(payload) {
  if (!payload?.request?.id || !payload.status) return
  const result = await runAction(() => updateStorageProfileRequestStatus(
    payload.request.id,
    payload.status,
    storageProfileAdminNote.value,
  ))
  if (!result?.data) return
  storageProfileAdminNote.value = ''
  await Promise.all([loadStorageProfileRequests(), loadBucketStorageProfile()])
  setStatusMessage(`Storage profile request ${result.data.status}: ${result.data.bucketName}`)
}

async function handleApplyStorageProfileRequest(request) {
  if (!request?.id) return
  const result = await runAction(() => applyStorageProfileRequest(request.id))
  if (!result?.data) return
  await Promise.all([loadStorageProfileRequests(), loadBucketStorageProfile()])
  setStatusMessage(`Storage profile applied: ${result.data.bucketName} ${result.data.requestedProfile?.code}`)
}

async function loadObjects({ append = false } = {}) {
  if (!selectedBucket.value) {
    objects.value = []
    objectPrefixes.value = []
    objectNextCursor.value = ''
    return
  }
  const tagError = validateTagInput(objectTagFilter.value)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const result = await runAction(() => getObjects(selectedBucket.value, {
    prefix: objectPrefix.value,
    delimiter: objectViewMode.value === 'active' ? '/' : '',
    search: objectSearch.value,
    tag: objectTagFilter.value,
    cursor: append ? objectNextCursor.value : '',
    limit: objectListLimit.value,
    deleted: objectViewMode.value === 'trash',
  }))
  if (!result) return
  objects.value = append ? [...objects.value, ...result.items] : result.items
  objectPrefixes.value = objectViewMode.value === 'active'
    ? (append ? [...new Set([...objectPrefixes.value, ...(result.prefixes || [])])] : result.prefixes || [])
    : []
  objectNextCursor.value = result.nextCursor || ''
  if (!append) {
    objectMetadata.value = null
    resetObjectVersions()
    resetObjectShareLinks()
    shareLinkUrl.value = ''
  }
}

async function handleObjectViewModeChange(mode) {
  objectViewMode.value = mode
  objectNextCursor.value = ''
  await loadObjects()
}

async function handleOpenObjectPrefix(prefix) {
  objectPrefix.value = prefix
  await loadObjects()
}

async function handleSelectObjectPrefix(prefix) {
  objectPrefix.value = prefix
  await loadObjects()
}

async function handleObjectPrefixUp() {
  objectPrefix.value = parentObjectPrefix(objectPrefix.value)
  await loadObjects()
}

async function handleResetObjectFilter() {
  objectPrefix.value = ''
  objectSearch.value = ''
  objectTagFilter.value = ''
  await loadObjects()
}

function handleFileChange(event) {
  objectForm.file = event.target.files?.[0] ?? null
  lastUploadRequest.value = null
  uploadState.retryable = false
  uploadState.message = ''
  resetUploadErrorState()
  if (!objectForm.key && objectForm.file) {
    objectForm.key = objectForm.file.name
  }
  refreshPendingMultipartUploads()
  if (matchingMultipartResumeSession.value) {
    uploadState.message = 'Multipart resume ready'
  }
}

async function handleUploadObject() {
  if (!selectedBucket.value || !objectForm.file) {
    setErrorMessage('버킷과 파일을 선택해야 합니다.')
    return
  }
  const tagError = validateTagInput(objectForm.tags)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const request = {
    bucketName: selectedBucket.value,
    key: objectForm.key || objectForm.file.name,
    tags: objectForm.tags,
    file: objectForm.file,
  }
  lastUploadRequest.value = request
  await startObjectUpload(request)
}

async function startObjectUpload(request) {
  const controller = new AbortController()
  uploadController.value = controller
  uploadAbortMode.value = ''
  uploadState.active = true
  uploadState.loadedBytes = 0
  uploadState.totalBytes = request.file.size || 0
  uploadState.percent = 0
  uploadState.message = ''
  uploadState.retryable = false
  uploadState.multipart = false
  resetUploadErrorState()
  clearError()

  try {
    const uploadFn = request.file.size >= MULTIPART_UPLOAD_THRESHOLD_BYTES ? uploadObjectMultipart : uploadObject
    uploadState.multipart = uploadFn === uploadObjectMultipart
    uploadState.message = uploadFn === uploadObjectMultipart ? 'Multipart upload' : ''
    await uploadFn(request.bucketName, request.key, request.file, request.tags, updateUploadProgress, {
      signal: controller.signal,
      preserveSessionOnAbort: () => uploadAbortMode.value === 'pause',
      onResume: ({ completedBytes }) => {
        uploadState.message = completedBytes > 0 ? 'Multipart resume' : 'Multipart upload'
      },
    })
    uploadState.percent = 100
    uploadState.retryable = false
    uploadState.multipart = false
    resetUploadErrorState()
    lastUploadRequest.value = null
    objectForm.key = ''
    objectForm.tags = ''
    objectForm.file = null
    refreshPendingMultipartUploads()
    await loadDashboard()
    setStatusMessage(`${request.key} 업로드 완료`)
  } catch (error) {
    const aborted = controller.signal.aborted
    const paused = aborted && uploadAbortMode.value === 'pause'
    const message = aborted ? '업로드를 취소했습니다.' : error.message
    const resolvedMessage = paused ? 'Multipart upload paused. Resume from pending multipart.' : message
    paused ? setStatusMessage(resolvedMessage) : aborted ? setErrorMessage(resolvedMessage) : setError(error)
    uploadState.message = resolvedMessage
    uploadState.retryable = true
    uploadState.errorCode = aborted ? '' : error?.code || ''
    uploadState.errorStatus = aborted ? 0 : Number(error?.status || 0)
    uploadState.requestId = aborted ? '' : error?.requestId || ''
    refreshPendingMultipartUploads()
  } finally {
    uploadState.active = false
    uploadState.multipart = false
    uploadAbortMode.value = ''
    if (uploadController.value === controller) {
      uploadController.value = null
    }
  }
}

function resetUploadErrorState() {
  uploadState.errorCode = ''
  uploadState.errorStatus = 0
  uploadState.requestId = ''
}

function updateUploadProgress(progress) {
  uploadState.loadedBytes = progress.loaded
  uploadState.totalBytes = progress.total
  uploadState.percent = progress.percent
}

function handleCancelUpload() {
  uploadAbortMode.value = 'cancel'
  uploadController.value?.abort()
}

function handlePauseUpload() {
  uploadAbortMode.value = 'pause'
  uploadController.value?.abort()
}

async function handleRetryUpload() {
  if (lastUploadRequest.value) {
    await startObjectUpload(lastUploadRequest.value)
  }
}

async function handleResumeMatchingMultipartUpload(session) {
  if (isMatchingResumeSession(session)) {
    await handleUploadObject()
  }
}

function handleDiscardMultipartResume(storageKey) {
  openConfirmDialog({
    title: 'Multipart resume 삭제',
    message: '저장된 multipart 업로드 재개 정보를 삭제합니다. 진행 중이던 업로드는 처음부터 다시 시작해야 합니다.',
    confirmLabel: '삭제',
    action: async () => {
      deleteStoredMultipartUploadSession(storageKey)
      refreshPendingMultipartUploads()
      setStatusMessage('Multipart resume 삭제 완료')
      return true
    },
  })
}

function isMatchingResumeSession(session) {
  return Boolean(matchingMultipartResumeSession.value?.storageKey)
    && matchingMultipartResumeSession.value.storageKey === session.storageKey
}

function refreshPendingMultipartUploads() {
  pendingMultipartUploads.value = getStoredMultipartUploadSessions({ bucketName: selectedBucket.value || undefined })
}

async function handleCreatePresignedDownloadUrl(key) {
  const result = await runAction(() => createPresignedDownloadUrl(selectedBucket.value, key))
  if (result) {
    presignedUrl.value = result.data.url
    setStatusMessage(`${key} Presigned URL 생성 완료`)
  }
}

async function handleCreatePresignedUploadUrl() {
  if (!selectedBucket.value || !objectForm.key) {
    setErrorMessage('버킷과 key를 입력해야 합니다.')
    return
  }
  const result = await runAction(() => createPresignedUploadUrl(selectedBucket.value, {
    key: objectForm.key,
    tags: objectForm.tags,
    contentType: objectForm.file?.type || 'application/octet-stream',
    expiresInSeconds: 900,
  }))
  if (result) {
    presignedUrl.value = result.data.url
    pendingUploadId.value = result.data.uploadId
    setStatusMessage(`${objectForm.key} Presigned upload URL 생성 완료`)
  }
}

async function handleCompletePresignedUpload() {
  const result = await runAction(() => completePresignedUpload(selectedBucket.value, {
    uploadId: pendingUploadId.value,
    key: objectForm.key,
  }))
  if (result) {
    pendingUploadId.value = ''
    presignedUrl.value = ''
    await loadDashboard()
    setStatusMessage(`${objectForm.key} Presigned upload 완료`)
  }
}

function handleStartObjectTagEdit(object) {
  objectTagForm.key = object.key
  objectTagForm.tags = objectTagsToInput(object.tags)
}

async function handleUpdateObjectTags() {
  if (!selectedBucket.value || !objectTagForm.key) {
    setErrorMessage('버킷과 object key를 선택해야 합니다.')
    return
  }
  const tagError = validateTagInput(objectTagForm.tags)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const result = await runAction(() => updateObjectTags(selectedBucket.value, { key: objectTagForm.key, tags: objectTagForm.tags }))
  if (result) {
    objectTagForm.tags = objectTagsToInput(result.data.tags)
    await loadDashboard()
    setStatusMessage(`${objectTagForm.key} 태그 저장 완료`)
  }
}

function handleResetObjectTagForm() {
  objectTagForm.key = ''
  objectTagForm.tags = ''
}

async function handleLoadObjectMetadata(key) {
  const result = await runAction(() => getObjectMetadata(selectedBucket.value, key))
  if (result) {
    objectMetadata.value = result.data
  }
}

async function handleLoadObjectVersions(key) {
  objectVersions.key = key
  objectVersions.pending = true
  const result = await runAction(() => listObjectVersions(selectedBucket.value, key))
  objectVersions.pending = false
  if (result) {
    objectVersions.items = result.data || []
  }
}

function resetObjectVersions() {
  objectVersions.key = ''
  objectVersions.items = []
  objectVersions.pending = false
}

function resetObjectShareLinks() {
  objectShareLinks.key = ''
  objectShareLinks.items = []
  objectShareLinks.pending = false
}

async function handleCreateObjectShareLink(key) {
  const result = await runAction(() => createObjectShareLink(selectedBucket.value, key, {
    expiresInSeconds: 3600,
    note: 'Created from admin dashboard',
    maxDownloads: 100,
    password: shareLinkPassword.value,
    allowedIpCidrs: shareLinkAllowedIpCidrs.value,
  }))
  if (result) {
    shareLinkUrl.value = result.data.url
    await handleLoadObjectShareLinks(key)
    await refreshObjectShareAnalytics()
    setStatusMessage(`${key} 공유 링크 생성 완료`)
  }
}

async function handleLoadObjectShareLinks(key) {
  objectShareLinks.key = key
  objectShareLinks.pending = true
  const result = await runAction(() => getObjectShareLinks(selectedBucket.value, key, 20))
  objectShareLinks.pending = false
  if (result) {
    objectShareLinks.items = result.items || []
  }
}

function handleRevokeObjectShareLink(linkId) {
  if (!objectShareLinks.key) return
  const bucketName = selectedBucket.value
  const objectKey = objectShareLinks.key
  openConfirmDialog({
    title: '공유 링크 해제',
    message: `${objectKey} 공유 링크 #${linkId}를 해제합니다.`,
    confirmLabel: '해제',
    action: async () => {
      objectShareLinks.pending = true
      const result = await runAction(() => runCommand(() => deleteObjectShareLink(bucketName, linkId)))
      objectShareLinks.pending = false
      if (!result) return false
      await handleLoadObjectShareLinks(objectKey)
      await refreshObjectShareAnalytics()
      setStatusMessage(`${objectKey} 공유 링크 해제 완료`)
      return true
    },
  })
}

function handleCleanupObjectShareLinks() {
  if (!selectedBucket.value) return
  const bucketName = selectedBucket.value
  const objectKey = objectShareLinks.key
  openConfirmDialog({
    title: '만료 공유 링크 정리',
    message: `${bucketName} 버킷의 만료된 공유 링크를 EXPIRED 상태로 정리합니다.`,
    confirmLabel: '정리',
    action: async () => {
      objectShareLinks.pending = true
      const result = await runAction(() => cleanupObjectShareLinks(bucketName))
      objectShareLinks.pending = false
      if (!result) return false
      if (objectKey) {
        await handleLoadObjectShareLinks(objectKey)
      }
      await refreshObjectShareAnalytics()
      setStatusMessage(`${bucketName} 만료 공유 링크 정리 완료`)
      return true
    },
  })
}

async function handleDownloadObject(key) {
  const blob = await runAction(() => downloadObject(selectedBucket.value, key))
  if (blob) {
    downloadBlob(blob, key.split('/').pop() || 'download')
    setStatusMessage(`${key} 다운로드 시작`)
  }
}

function handleDeleteObject(key) {
  openConfirmDialog({
    title: '파일 삭제',
    message: `${selectedBucket.value}/${key} 파일을 휴지통으로 이동합니다.`,
    confirmLabel: '휴지통 이동',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteObject(selectedBucket.value, key)))
      if (!result) return false
      await loadDashboard()
      setStatusMessage(`${key} 휴지통 이동 완료`)
      return true
    },
  })
}

function handleRestoreObject(key) {
  openConfirmDialog({
    title: 'Object Restore',
    message: `${selectedBucket.value}/${key} 파일을 복구합니다.`,
    confirmLabel: 'Restore',
    action: async () => {
      const result = await runAction(() => restoreObject(selectedBucket.value, key))
      if (!result) return false
      await loadDashboard()
      setStatusMessage(`${key} 복구 완료`)
      return true
    },
  })
}

function handlePurgeObject(key) {
  openConfirmDialog({
    title: 'Object Purge',
    message: `${selectedBucket.value}/${key} 파일을 영구 삭제합니다. 되돌릴 수 없습니다.`,
    confirmLabel: 'Purge',
    action: async () => {
      const result = await runAction(() => runCommand(() => purgeObject(selectedBucket.value, key)))
      if (!result) return false
      await loadDashboard()
      setStatusMessage(`${key} 휴지통 이동 완료`)
      return true
    },
  })
}

async function handleRestoreObjectVersion(versionId) {
  if (!objectVersions.key) return
  objectVersions.pending = true
  const result = await runAction(() => restoreObjectVersion(selectedBucket.value, objectVersions.key, versionId))
  objectVersions.pending = false
  if (result) {
    await loadDashboard()
    await handleLoadObjectVersions(result.data.key)
    setStatusMessage(`${result.data.key} version 복구 완료`)
  }
}

async function handleDownloadObjectVersion(versionId) {
  if (!objectVersions.key) return
  const blob = await runAction(() => downloadObjectVersion(selectedBucket.value, objectVersions.key, versionId))
  if (blob) {
    downloadBlob(blob, `${objectVersions.key.split('/').pop() || 'download'}.version-${versionId}`)
    setStatusMessage(`${objectVersions.key} version 다운로드 시작`)
  }
}

function handleDeleteObjectVersion(versionId) {
  const key = objectVersions.key
  openConfirmDialog({
    title: 'Object Version Delete',
    message: `${selectedBucket.value}/${key} version ${versionId}를 영구 삭제합니다.`,
    confirmLabel: 'Delete',
    action: async () => {
      objectVersions.pending = true
      const result = await runAction(() => runCommand(() => deleteObjectVersion(selectedBucket.value, key, versionId)))
      objectVersions.pending = false
      if (!result) return false
      await loadDashboard()
      await handleLoadObjectVersions(key)
      setStatusMessage(`${key} version 삭제 완료`)
      return true
    },
  })
}

async function handleLoadNextObjects() {
  if (objectNextCursor.value) {
    await loadObjects({ append: true })
  }
}

async function loadBucketPermissions() {
  if (!selectedBucket.value) {
    bucketPermissions.value = []
    return
  }
  const result = await safeRequest(() => getBucketPermissions(selectedBucket.value), { items: [] })
  bucketPermissions.value = result.items || []
}

async function handleGrantBucketPermissions() {
  if (!selectedBucket.value || !bucketPermissionForm.subjectId || bucketPermissionForm.permissions.length === 0) {
    setErrorMessage('버킷, 대상, 권한을 선택해야 합니다.')
    return
  }
  const result = await runAction(() => grantBucketPermissions(selectedBucket.value, {
    subjectType: bucketPermissionForm.subjectType,
    subjectId: Number(bucketPermissionForm.subjectId),
    permissions: bucketPermissionForm.permissions,
  }))
  if (result) {
    bucketPermissions.value = result.items
    setStatusMessage(`${selectedBucket.value} 버킷 권한 부여 완료`)
  }
}

function handleRevokeBucketPermission(permissionId) {
  openConfirmDialog({
    title: '버킷 권한 회수',
    message: `${selectedBucket.value} 버킷 권한 #${permissionId}를 회수합니다.`,
    confirmLabel: '회수',
    action: async () => {
      const result = await runAction(() => runCommand(() => revokeBucketPermission(selectedBucket.value, permissionId)))
      if (!result) return false
      await loadBucketPermissions()
      setStatusMessage(`${selectedBucket.value} 버킷 권한 회수 완료`)
      return true
    },
  })
}

async function handleCreateAccessKey() {
  const result = await runAction(() => createAccessKey({
    name: accessKeyForm.name,
    bucketScopes: accessKeyForm.scopes.map((scope) => ({ bucketName: scope.bucketName, permissions: [...scope.permissions] })),
    expiresAt: localDateTimeToIso(accessKeyForm.expiresAt) || null,
  }))
  if (result) {
    newSecretKey.value = result.data.secretKey
    await loadDashboard()
    setStatusMessage(`${result.data?.name || accessKeyForm.name} Access Key 발급 완료`)
  }
}

function handleRotateAccessKey(keyId) {
  openConfirmDialog({
    title: 'Access Key Secret Rotate',
    message: `Access Key #${keyId} secret을 새로 발급합니다. 기존 Secret Key는 rotation grace period 동안만 허용됩니다.`,
    confirmLabel: 'Rotate',
    action: async () => {
      const result = await runAction(() => rotateAccessKey(keyId))
      if (!result) return false
      newSecretKey.value = result.data.secretKey
      await loadDashboard()
      setStatusMessage(`Access Key #${keyId} Secret Rotate 완료`)
      return true
    },
  })
}

function handleDeleteAccessKey(keyId) {
  openConfirmDialog({
    title: 'Access Key 비활성화',
    message: `Access Key #${keyId}를 비활성화합니다. 기존 S3 클라이언트 접근이 중단됩니다.`,
    confirmLabel: '비활성화',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteAccessKey(keyId)))
      if (!result) return false
      await loadDashboard()
      setStatusMessage(`Access Key #${keyId} 비활성화 완료`)
      return true
    },
  })
}

function handleBulkDisableAccessKeys(keyIds) {
  const ids = Array.isArray(keyIds) ? [...new Set(keyIds)].filter((keyId) => keyId !== undefined && keyId !== null) : []
  if (ids.length === 0) {
    setStatusMessage('비활성화할 Access Key 후보가 없습니다.')
    return
  }
  openConfirmDialog({
    title: 'Access Key Bulk Cleanup',
    message: `${ids.length}개의 만료/미사용 Access Key를 비활성화합니다. 기존 S3 클라이언트 접근이 중단됩니다.`,
    confirmLabel: 'Bulk disable',
    action: async () => {
      const result = await runAction(() => bulkDisableAccessKeys(ids))
      if (!result?.data) return false
      await loadDashboard()
      setStatusMessage(`${result.data.disabledCount}개 Access Key 비활성화 완료 / ${result.data.skippedCount}개 건너뜀`)
      return true
    },
  })
}

function handleAddAccessKeyScope() {
  if (!accessKeyForm.scopeBucket || accessKeyForm.scopePermissions.length === 0) {
    setErrorMessage('버킷과 권한을 선택해야 합니다.')
    return
  }
  const existing = accessKeyForm.scopes.find((scope) => scope.bucketName === accessKeyForm.scopeBucket)
  if (existing) {
    existing.permissions = mergePermissions(existing.permissions, accessKeyForm.scopePermissions)
    return
  }
  accessKeyForm.scopes.push({ bucketName: accessKeyForm.scopeBucket, permissions: [...accessKeyForm.scopePermissions] })
}

function handleRemoveAccessKeyScope(bucketName) {
  const index = accessKeyForm.scopes.findIndex((scope) => scope.bucketName === bucketName)
  if (index >= 0) {
    accessKeyForm.scopes.splice(index, 1)
  }
}

function syncAccessKeyBucketSelection() {
  const bucketNames = buckets.value.map((bucket) => bucket.name)
  accessKeyForm.scopes = accessKeyForm.scopes.filter((scope) => bucketNames.includes(scope.bucketName))
  if (!bucketNames.includes(accessKeyForm.scopeBucket)) {
    accessKeyForm.scopeBucket = bucketNames[0] ?? ''
  }
}

async function loadBucketLifecycleXml() {
  if (!selectedBucket.value || !canUseBucketLifecycle.value) {
    resetBucketLifecycleXml()
    return
  }
  bucketLifecycleXml.pending = true
  const result = await safeRequest(() => getBucketLifecycleS3Xml(selectedBucket.value), null)
  bucketLifecycleXml.pending = false
  if (result?.data) {
    bucketLifecycleXml.content = result.data.xml || ''
    bucketLifecycleXml.ruleCount = result.data.ruleCount ?? 0
    bucketLifecycleXml.savedCount = null
  }
}

async function handlePutBucketLifecycleXml() {
  if (!selectedBucket.value) return
  bucketLifecycleXml.pending = true
  const result = await runAction(() => putBucketLifecycleS3Xml(selectedBucket.value, bucketLifecycleXml.content))
  bucketLifecycleXml.pending = false
  if (result?.data) {
    const savedRuleCount = result.data.savedCount ?? result.data.ruleCount ?? result.data.importedCount ?? null
    bucketLifecycleXml.content = result.data.xml || bucketLifecycleXml.content
    bucketLifecycleXml.ruleCount = result.data.ruleCount ?? result.data.importedCount ?? bucketLifecycleXml.ruleCount
    bucketLifecycleXml.savedCount = savedRuleCount
    setStatusMessage(`${selectedBucket.value} bucket lifecycle 저장 완료`)
  }
}

function handleDeleteBucketLifecycleXml() {
  if (!selectedBucket.value) return
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: 'Bucket lifecycle 삭제',
    message: `${bucketName} 버킷의 S3 lifecycle XML 설정을 삭제합니다.`,
    confirmLabel: '삭제',
    action: async () => {
      bucketLifecycleXml.pending = true
      const result = await runAction(() => runCommand(() => deleteBucketLifecycleS3Xml(bucketName)))
      bucketLifecycleXml.pending = false
      if (!result) return false
      resetBucketLifecycleXml()
      setStatusMessage(`${bucketName} bucket lifecycle 삭제 완료`)
      return true
    },
  })
}

function resetBucketLifecycleXml() {
  bucketLifecycleXml.content = ''
  bucketLifecycleXml.ruleCount = 0
  bucketLifecycleXml.savedCount = null
  bucketLifecycleXml.pending = false
}

async function loadBucketTags() {
  if (!selectedBucket.value || !canUseBucketTags.value) {
    resetBucketTags()
    return
  }
  bucketTags.pending = true
  const result = await safeRequest(() => getBucketTags(selectedBucket.value), null)
  bucketTags.pending = false
  if (result?.data) {
    bucketTags.content = tagsToInput(result.data.tags)
    bucketTags.tagCount = result.data.tagCount ?? Object.keys(result.data.tags || {}).length
    bucketTags.savedCount = null
  }
}

async function handlePutBucketTags() {
  if (!selectedBucket.value) return
  const parsedTags = validateBucketTagInput(bucketTags.content)
  if (parsedTags.error) {
    setErrorMessage(parsedTags.error)
    return
  }
  bucketTags.pending = true
  const result = await runAction(() => putBucketTags(selectedBucket.value, tagPairsToMap(parsedTags.tags)))
  bucketTags.pending = false
  if (result?.data) {
    bucketTags.content = tagsToInput(result.data.tags)
    bucketTags.tagCount = result.data.tagCount ?? Object.keys(result.data.tags || {}).length
    bucketTags.savedCount = bucketTags.tagCount
    setStatusMessage(`${selectedBucket.value} bucket tags 저장 완료`)
  }
}

function handleDeleteBucketTags() {
  if (!selectedBucket.value) return
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: 'Bucket tags 삭제',
    message: `${bucketName} 버킷의 S3 tag 설정을 삭제합니다.`,
    confirmLabel: '삭제',
    action: async () => {
      bucketTags.pending = true
      const result = await runAction(() => runCommand(() => deleteBucketTags(bucketName)))
      bucketTags.pending = false
      if (!result) return false
      resetBucketTags()
      setStatusMessage(`${bucketName} bucket tags 삭제 완료`)
      return true
    },
  })
}

function resetBucketTags() {
  bucketTags.content = ''
  bucketTags.tagCount = 0
  bucketTags.savedCount = null
  bucketTags.pending = false
}

async function loadObjectSharePolicy() {
  const result = await safeRequest(() => getObjectSharePolicy(), null)
  if (result?.data) {
    Object.assign(objectSharePolicy, result.data)
    objectSharePolicyForm.requirePassword = Boolean(result.data.requirePassword)
    objectSharePolicyForm.requireIpAllowlist = Boolean(result.data.requireIpAllowlist)
    objectSharePolicyForm.maxExpiresSeconds = result.data.maxExpiresSeconds ?? 604800
    objectSharePolicyForm.maxDownloadsLimit = result.data.maxDownloadsLimit ?? ''
  }
}

async function handleSaveObjectSharePolicy() {
  objectSharePolicyForm.pending = true
  const result = await runAction(() => saveObjectSharePolicy({
    requirePassword: objectSharePolicyForm.requirePassword,
    requireIpAllowlist: objectSharePolicyForm.requireIpAllowlist,
    maxExpiresSeconds: Number(objectSharePolicyForm.maxExpiresSeconds || 604800),
    maxDownloadsLimit: objectSharePolicyForm.maxDownloadsLimit === '' ? null : Number(objectSharePolicyForm.maxDownloadsLimit),
  }))
  objectSharePolicyForm.pending = false
  if (result?.data) {
    Object.assign(objectSharePolicy, result.data)
    await refreshObjectShareAnalytics()
    setStatusMessage('공유 링크 정책 저장 완료')
  }
}

function resetObjectSharePolicy() {
  Object.assign(objectSharePolicy, {
    requirePassword: false,
    requireIpAllowlist: false,
    maxExpiresSeconds: 604800,
    maxDownloadsLimit: null,
    updatedAt: null,
  })
  objectSharePolicyForm.requirePassword = false
  objectSharePolicyForm.requireIpAllowlist = false
  objectSharePolicyForm.maxExpiresSeconds = 604800
  objectSharePolicyForm.maxDownloadsLimit = ''
  objectSharePolicyForm.pending = false
  resetObjectShareAnalytics()
}

async function refreshObjectShareAnalytics() {
  if (!isAdmin.value) return
  const result = await safeRequest(() => getObjectShareAnalytics(objectShareAnalyticsFilter.limit, {
    bucketName: objectShareAnalyticsFilter.bucketName,
    status: objectShareAnalyticsFilter.status,
  }), null)
  if (result?.data) {
    applyObjectShareAnalytics(result.data)
  }
}

function applyObjectShareAnalytics(data) {
  Object.assign(objectShareAnalytics, {
    totalLinks: data.totalLinks ?? 0,
    activeLinks: data.activeLinks ?? 0,
    expiredLinks: data.expiredLinks ?? 0,
    revokedLinks: data.revokedLinks ?? 0,
    limitReachedLinks: data.limitReachedLinks ?? 0,
    passwordProtectedLinks: data.passwordProtectedLinks ?? 0,
    ipRestrictedLinks: data.ipRestrictedLinks ?? 0,
    totalDownloads: data.totalDownloads ?? 0,
    lastAccessedAt: data.lastAccessedAt ?? null,
    recentLinks: data.recentLinks ?? [],
  })
}

function resetObjectShareAnalytics() {
  applyObjectShareAnalytics({})
}

function applyDashboardQuotaSummary(data) {
  Object.assign(dashboardQuota, {
    policyCount: data.policyCount ?? 0,
    warningPolicyCount: data.warningPolicyCount ?? 0,
    exhaustedPolicyCount: data.exhaustedPolicyCount ?? 0,
    totalQuotaBytes: data.totalQuotaBytes ?? 0,
    totalUsedBytes: data.totalUsedBytes ?? 0,
    totalRemainingBytes: data.totalRemainingBytes ?? 0,
    topPolicies: data.topPolicies ?? [],
  })
}

function resetDashboardQuotaSummary() {
  applyDashboardQuotaSummary({})
}

function applyDataFlowMonitoring(data = {}) {
  Object.assign(dataFlowMonitoring.traffic, {
    uploadedBytes: Number(data.traffic?.uploadedBytes || 0),
    downloadedBytes: Number(data.traffic?.downloadedBytes || 0),
    copiedBytes: Number(data.traffic?.copiedBytes || 0),
    totalBytes: Number(data.traffic?.totalBytes || 0),
    ingressBytes: Number(data.traffic?.ingressBytes || 0),
    egressBytes: Number(data.traffic?.egressBytes || 0),
    internalBytes: Number(data.traffic?.internalBytes || 0),
  })
  Object.assign(dataFlowMonitoring.operations, {
    uploadCount: Number(data.operations?.uploadCount || 0),
    downloadCount: Number(data.operations?.downloadCount || 0),
    copyCount: Number(data.operations?.copyCount || 0),
    listCount: Number(data.operations?.listCount || 0),
    deleteCount: Number(data.operations?.deleteCount || 0),
    cancelCount: Number(data.operations?.cancelCount || 0),
    failureCount: Number(data.operations?.failureCount || 0),
    totalCount: Number(data.operations?.totalCount || 0),
  })
  dataFlowMonitoring.topBuckets = Array.isArray(data.topBuckets) ? data.topBuckets : []
  dataFlowMonitoring.trendPoints = Array.isArray(data.trendPoints) ? data.trendPoints : []
  dataFlowMonitoring.recentEvents = Array.isArray(data.recentEvents) ? data.recentEvents : []
  dataFlowMonitoring.generatedAt = data.generatedAt || ''
}

function defaultDataFlowDailyRollup() {
  return {
    mode: 'DATA_FLOW_DAILY_ROLLUP',
    granularity: 'UTC_DAY',
    dayWindow: 30,
    pointLimit: 0,
    pointCount: 0,
    points: [],
    generatedAt: '',
    scopePolicy: '',
    storagePolicy: '',
    note: '',
  }
}

function defaultDataFlowMonthlyRollup() {
  return {
    mode: 'DATA_FLOW_MONTHLY_ROLLUP',
    rollupSource: 'DATA_FLOW_EVENTS',
    granularity: 'UTC_MONTH',
    monthWindow: 12,
    pointLimit: 0,
    pointCount: 0,
    points: [],
    generatedAt: '',
    scopePolicy: '',
    storagePolicy: '',
    note: '',
  }
}

function normalizeDataFlowDailyRollupPoint(point = {}) {
  return {
    day: point.day || '',
    bucketName: point.bucketName || '',
    source: point.source || '',
    operation: point.operation || '',
    successCount: Number(point.successCount || 0),
    failureCount: Number(point.failureCount || 0),
    cancelCount: Number(point.cancelCount || 0),
    totalCount: Number(point.totalCount || 0),
    uploadedBytes: Number(point.uploadedBytes || 0),
    downloadedBytes: Number(point.downloadedBytes || 0),
    copiedBytes: Number(point.copiedBytes || 0),
    totalBytes: Number(point.totalBytes || 0),
  }
}

function normalizeDataFlowMonthlyRollupPoint(point = {}) {
  return {
    month: point.month || '',
    bucketName: point.bucketName || '',
    source: point.source || '',
    operation: point.operation || '',
    successCount: Number(point.successCount || 0),
    failureCount: Number(point.failureCount || 0),
    cancelCount: Number(point.cancelCount || 0),
    totalCount: Number(point.totalCount || 0),
    uploadedBytes: Number(point.uploadedBytes || 0),
    downloadedBytes: Number(point.downloadedBytes || 0),
    copiedBytes: Number(point.copiedBytes || 0),
    totalBytes: Number(point.totalBytes || 0),
  }
}

function applyDataFlowDailyRollup(data = {}) {
  const points = Array.isArray(data.points)
    ? data.points.map((point) => normalizeDataFlowDailyRollupPoint(point))
    : []
  dataFlowMonitoring.dailyRollup = {
    ...defaultDataFlowDailyRollup(),
    ...data,
    dayWindow: Number(data.dayWindow || 30),
    pointLimit: Number(data.pointLimit || 0),
    pointCount: Number(data.pointCount ?? points.length),
    points,
    generatedAt: data.generatedAt || '',
    scopePolicy: data.scopePolicy || '',
    storagePolicy: data.storagePolicy || '',
    note: data.note || '',
  }
}

function applyDataFlowMonthlyRollup(data = {}) {
  const points = Array.isArray(data.points)
    ? data.points.map((point) => normalizeDataFlowMonthlyRollupPoint(point))
    : []
  dataFlowMonitoring.monthlyRollup = {
    ...defaultDataFlowMonthlyRollup(),
    ...data,
    monthWindow: Number(data.monthWindow || 12),
    pointLimit: Number(data.pointLimit || 0),
    pointCount: Number(data.pointCount ?? points.length),
    points,
    generatedAt: data.generatedAt || '',
    scopePolicy: data.scopePolicy || '',
    storagePolicy: data.storagePolicy || '',
    note: data.note || '',
  }
}

function defaultDataFlowRetentionPolicy() {
  return {
    enabled: false,
    jobAvailable: false,
    retentionDays: 0,
    batchSize: 0,
    deletedCount: 0,
    failedRunCount: 0,
  }
}

function defaultDataFlowRetention() {
  return {
    mode: 'DATA_FLOW_RETENTION',
    eventRetention: defaultDataFlowRetentionPolicy(),
    dailyRollupRetention: defaultDataFlowRetentionPolicy(),
    monthlyRollupRetention: defaultDataFlowRetentionPolicy(),
    generatedAt: '',
    note: '',
  }
}

function defaultDataFlowStorageStatus() {
  return {
    mode: 'DATA_FLOW_STORAGE_STATUS',
    metadataMode: '',
    repositoryHealthy: false,
    eventRowCount: 0,
    dailyRollupRowCount: 0,
    monthlyRollupRowCount: 0,
    summaryEventScanLimit: 0,
    dailyRollupWindowLimitDays: 0,
    monthlyRollupWindowLimitMonths: 0,
    aggregateStoreReady: false,
    partitionedOrTimeSeriesStoreEnabled: false,
    readiness: '',
    generatedAt: '',
    note: '',
  }
}

function defaultStorageBackendStatus() {
  return {
    mode: '',
    metadataMode: '',
    storageHealthy: false,
    accessKeyProvisionerHealthy: false,
    bucketCount: 0,
    objectCount: 0,
    usedBytes: 0,
    quotaBytes: 0,
    remainingBytes: 0,
    directMetricTotalBytes: 0,
    directMetricFreeBytes: 0,
    capacitySource: '',
    directStorageMetricsEnabled: false,
    minioAdminMetricsEnabled: false,
    directStorageMetricsStatus: '',
    directStorageMetricsSource: '',
    directStorageMetricsDetail: '',
    directStorageMetricNames: [],
    readiness: '',
    pendingGates: [],
    generatedAt: '',
    note: '',
  }
}

function normalizeDataFlowRetentionPolicy(policy = {}) {
  return {
    enabled: Boolean(policy.enabled),
    jobAvailable: Boolean(policy.jobAvailable),
    retentionDays: Number(policy.retentionDays || 0),
    batchSize: Number(policy.batchSize || 0),
    deletedCount: Number(policy.deletedCount || 0),
    failedRunCount: Number(policy.failedRunCount || 0),
  }
}

function applyDataFlowRetention(data = {}) {
  Object.assign(dataFlowRetention, {
    ...defaultDataFlowRetention(),
    mode: data.mode || 'DATA_FLOW_RETENTION',
    eventRetention: normalizeDataFlowRetentionPolicy(data.eventRetention),
    dailyRollupRetention: normalizeDataFlowRetentionPolicy(data.dailyRollupRetention),
    monthlyRollupRetention: normalizeDataFlowRetentionPolicy(data.monthlyRollupRetention),
    generatedAt: data.generatedAt || '',
    note: data.note || '',
  })
}

function applyDataFlowStorageStatus(data = {}) {
  Object.assign(dataFlowStorageStatus, {
    ...defaultDataFlowStorageStatus(),
    mode: data.mode || 'DATA_FLOW_STORAGE_STATUS',
    metadataMode: data.metadataMode || '',
    repositoryHealthy: Boolean(data.repositoryHealthy),
    eventRowCount: Number(data.eventRowCount || 0),
    dailyRollupRowCount: Number(data.dailyRollupRowCount || 0),
    monthlyRollupRowCount: Number(data.monthlyRollupRowCount || 0),
    summaryEventScanLimit: Number(data.summaryEventScanLimit || 0),
    dailyRollupWindowLimitDays: Number(data.dailyRollupWindowLimitDays || 0),
    monthlyRollupWindowLimitMonths: Number(data.monthlyRollupWindowLimitMonths || 0),
    aggregateStoreReady: Boolean(data.aggregateStoreReady),
    partitionedOrTimeSeriesStoreEnabled: Boolean(data.partitionedOrTimeSeriesStoreEnabled),
    readiness: data.readiness || '',
    generatedAt: data.generatedAt || '',
    note: data.note || '',
  })
}

function applyStorageBackendStatus(data = {}) {
  Object.assign(storageBackendStatus, {
    ...defaultStorageBackendStatus(),
    mode: data.mode || '',
    metadataMode: data.metadataMode || '',
    storageHealthy: Boolean(data.storageHealthy),
    accessKeyProvisionerHealthy: Boolean(data.accessKeyProvisionerHealthy),
    bucketCount: Number(data.bucketCount || 0),
    objectCount: Number(data.objectCount || 0),
    usedBytes: Number(data.usedBytes || 0),
    quotaBytes: Number(data.quotaBytes || 0),
    remainingBytes: Number(data.remainingBytes || 0),
    directMetricTotalBytes: Number(data.directMetricTotalBytes || 0),
    directMetricFreeBytes: Number(data.directMetricFreeBytes || 0),
    capacitySource: data.capacitySource || '',
    directStorageMetricsEnabled: Boolean(data.directStorageMetricsEnabled),
    minioAdminMetricsEnabled: Boolean(data.minioAdminMetricsEnabled),
    directStorageMetricsStatus: data.directStorageMetricsStatus || '',
    directStorageMetricsSource: data.directStorageMetricsSource || '',
    directStorageMetricsDetail: data.directStorageMetricsDetail || '',
    directStorageMetricNames: Array.isArray(data.directStorageMetricNames) ? data.directStorageMetricNames : [],
    readiness: data.readiness || '',
    pendingGates: Array.isArray(data.pendingGates) ? data.pendingGates : [],
    generatedAt: data.generatedAt || '',
    note: data.note || '',
  })
}

function resetDataFlowRetention() {
  applyDataFlowRetention({})
}

function resetDataFlowStorageStatus() {
  applyDataFlowStorageStatus({})
}

function resetStorageBackendStatus() {
  applyStorageBackendStatus({})
}

function resetDataFlowMonitoring() {
  applyDataFlowMonitoring({})
  applyDataFlowDailyRollup({})
  applyDataFlowMonthlyRollup({})
  resetDataFlowRetention()
  resetDataFlowStorageStatus()
}

function defaultBillingPricingPolicy() {
  return {
    currency: defaultChargebackOptions.currency,
    storageGbMonthRate: Number(defaultChargebackOptions.storageGbMonthRate),
    ingressGbRate: Number(defaultChargebackOptions.ingressGbRate),
    egressGbRate: Number(defaultChargebackOptions.egressGbRate),
    internalGbRate: Number(defaultChargebackOptions.internalGbRate),
    operationThousandRate: Number(defaultChargebackOptions.operationThousandRate),
    warningAmount: Number(defaultChargebackOptions.warningAmount),
    criticalAmount: Number(defaultChargebackOptions.criticalAmount),
    eventScanLimit: defaultChargebackOptions.eventScanLimit,
    updatedAt: '',
  }
}

function applyBillingPricingPolicy(data = {}, syncOptions = true) {
  const fallback = defaultBillingPricingPolicy()
  billingPricingPolicy.value = {
    ...fallback,
    ...data,
    storageGbMonthRate: Number(data.storageGbMonthRate ?? fallback.storageGbMonthRate),
    ingressGbRate: Number(data.ingressGbRate ?? fallback.ingressGbRate),
    egressGbRate: Number(data.egressGbRate ?? fallback.egressGbRate),
    internalGbRate: Number(data.internalGbRate ?? fallback.internalGbRate),
    operationThousandRate: Number(data.operationThousandRate ?? fallback.operationThousandRate),
    warningAmount: Number(data.warningAmount ?? fallback.warningAmount),
    criticalAmount: Number(data.criticalAmount ?? fallback.criticalAmount),
    eventScanLimit: Number(data.eventScanLimit || fallback.eventScanLimit),
  }
  if (syncOptions) {
    syncChargebackOptionsFromPolicy()
  }
}

function syncChargebackOptionsFromPolicy() {
  const policy = billingPricingPolicy.value || defaultBillingPricingPolicy()
  chargebackOptions.currency = policy.currency || defaultChargebackOptions.currency
  chargebackOptions.storageGbMonthRate = String(policy.storageGbMonthRate ?? defaultChargebackOptions.storageGbMonthRate)
  chargebackOptions.ingressGbRate = String(policy.ingressGbRate ?? defaultChargebackOptions.ingressGbRate)
  chargebackOptions.egressGbRate = String(policy.egressGbRate ?? defaultChargebackOptions.egressGbRate)
  chargebackOptions.internalGbRate = String(policy.internalGbRate ?? defaultChargebackOptions.internalGbRate)
  chargebackOptions.operationThousandRate = String(policy.operationThousandRate ?? defaultChargebackOptions.operationThousandRate)
  chargebackOptions.warningAmount = String(policy.warningAmount ?? defaultChargebackOptions.warningAmount)
  chargebackOptions.criticalAmount = String(policy.criticalAmount ?? defaultChargebackOptions.criticalAmount)
  chargebackOptions.notificationChannel = defaultChargebackOptions.notificationChannel
  chargebackOptions.notificationTarget = defaultChargebackOptions.notificationTarget
  chargebackOptions.paymentProvider = defaultChargebackOptions.paymentProvider
  chargebackOptions.paymentTargetAccount = defaultChargebackOptions.paymentTargetAccount
  chargebackOptions.eventScanLimit = Number(policy.eventScanLimit || defaultChargebackOptions.eventScanLimit)
}

function resetBillingPricingPolicy() {
  applyBillingPricingPolicy({})
}

function defaultBillingPricingPolicyProposals() {
  return {
    proposalCount: 0,
    proposals: [],
    generatedAt: '',
  }
}

function normalizeBillingPricingPolicyProposal(proposal = {}) {
  return {
    id: proposal.id,
    status: proposal.status || '',
    approvedPriceList: Boolean(proposal.approvedPriceList),
    currency: proposal.currency || defaultChargebackOptions.currency,
    storageGbMonthRate: Number(proposal.storageGbMonthRate || 0),
    ingressGbRate: Number(proposal.ingressGbRate || 0),
    egressGbRate: Number(proposal.egressGbRate || 0),
    internalGbRate: Number(proposal.internalGbRate || 0),
    operationThousandRate: Number(proposal.operationThousandRate || 0),
    warningAmount: Number(proposal.warningAmount || 0),
    criticalAmount: Number(proposal.criticalAmount || 0),
    eventScanLimit: Number(proposal.eventScanLimit || defaultChargebackOptions.eventScanLimit),
    requestedBy: proposal.requestedBy || '',
    approvedBy: proposal.approvedBy || '',
    reason: proposal.reason || '',
    approvalNote: proposal.approvalNote || '',
    commercialApprovedBy: proposal.commercialApprovedBy || '',
    commercialApprovalReference: proposal.commercialApprovalReference || '',
    commercialApprovalNote: proposal.commercialApprovalNote || '',
    createdAt: proposal.createdAt || '',
    updatedAt: proposal.updatedAt || '',
    approvedAt: proposal.approvedAt || '',
    appliedAt: proposal.appliedAt || '',
    commercialApprovedAt: proposal.commercialApprovedAt || '',
    commercialEffectiveFrom: proposal.commercialEffectiveFrom || '',
  }
}

function applyBillingPricingPolicyProposals(data = {}) {
  const proposals = Array.isArray(data.proposals)
    ? data.proposals.map((proposal) => normalizeBillingPricingPolicyProposal(proposal))
    : []
  billingPricingPolicyProposals.value = {
    proposalCount: Number(data.proposalCount ?? proposals.length),
    proposals,
    generatedAt: data.generatedAt || '',
  }
}

function resetBillingPricingPolicyProposals() {
  applyBillingPricingPolicyProposals({})
}

function defaultChargebackPreview() {
  return {
    currency: defaultChargebackOptions.currency,
    from: '',
    to: '',
    rates: {
      storageGbMonthRate: Number(defaultChargebackOptions.storageGbMonthRate),
      ingressGbRate: Number(defaultChargebackOptions.ingressGbRate),
      egressGbRate: Number(defaultChargebackOptions.egressGbRate),
      internalGbRate: Number(defaultChargebackOptions.internalGbRate),
      operationThousandRate: Number(defaultChargebackOptions.operationThousandRate),
    },
    eventScanLimit: defaultChargebackOptions.eventScanLimit,
    scannedEventCount: 0,
    organizationCount: 0,
    bucketCount: 0,
    usedBytes: 0,
    ingressBytes: 0,
    egressBytes: 0,
    internalBytes: 0,
    billableOperationCount: 0,
    failedOperationCount: 0,
    cancelledOperationCount: 0,
    estimatedTotalCost: 0,
    organizations: [],
    generatedAt: '',
  }
}

function applyChargebackPreview(data = {}) {
  const fallback = defaultChargebackPreview()
  chargebackPreview.value = {
    ...fallback,
    ...data,
    rates: {
      ...fallback.rates,
      ...(data.rates || {}),
    },
    organizations: Array.isArray(data.organizations) ? data.organizations : [],
  }
}

function resetChargebackPreview() {
  applyChargebackPreview({})
}

function defaultChargebackDailyRollup() {
  return {
    mode: 'CHARGEBACK_DAILY_ROLLUP',
    rollupSource: '',
    granularity: 'UTC_DAY',
    currency: defaultChargebackOptions.currency,
    days: 30,
    limit: 200,
    inputPointCount: 0,
    pointCount: 0,
    totalEstimatedCost: 0,
    points: [],
    generatedAt: '',
    note: '',
    storageCostPolicy: '',
  }
}

function normalizeChargebackDailyRollupPoint(point = {}) {
  return {
    day: point.day || '',
    organizationId: point.organizationId,
    organizationName: point.organizationName || '',
    bucketCount: Number(point.bucketCount || 0),
    objectCount: Number(point.objectCount || 0),
    usedBytes: Number(point.usedBytes || 0),
    ingressBytes: Number(point.ingressBytes || 0),
    egressBytes: Number(point.egressBytes || 0),
    internalBytes: Number(point.internalBytes || 0),
    billableOperationCount: Number(point.billableOperationCount || 0),
    failedOperationCount: Number(point.failedOperationCount || 0),
    cancelledOperationCount: Number(point.cancelledOperationCount || 0),
    projectedStorageCost: Number(point.projectedStorageCost || 0),
    ingressCost: Number(point.ingressCost || 0),
    egressCost: Number(point.egressCost || 0),
    internalCost: Number(point.internalCost || 0),
    operationCost: Number(point.operationCost || 0),
    estimatedTotalCost: Number(point.estimatedTotalCost || 0),
  }
}

function applyChargebackDailyRollup(data = {}) {
  const fallback = defaultChargebackDailyRollup()
  const points = Array.isArray(data.points)
    ? data.points.map((point) => normalizeChargebackDailyRollupPoint(point))
    : []
  chargebackDailyRollup.value = {
    ...fallback,
    ...data,
    days: Number(data.days || fallback.days),
    limit: Number(data.limit || fallback.limit),
    inputPointCount: Number(data.inputPointCount || 0),
    pointCount: Number(data.pointCount ?? points.length),
    totalEstimatedCost: Number(data.totalEstimatedCost || 0),
    points,
    generatedAt: data.generatedAt || '',
    note: data.note || '',
    storageCostPolicy: data.storageCostPolicy || '',
  }
}

function resetChargebackDailyRollup() {
  applyChargebackDailyRollup({})
}

function defaultChargebackAlerts() {
  return {
    currency: defaultChargebackOptions.currency,
    warningAmount: Number(defaultChargebackOptions.warningAmount),
    criticalAmount: Number(defaultChargebackOptions.criticalAmount),
    alertCount: 0,
    warningCount: 0,
    criticalCount: 0,
    organizations: [],
    generatedAt: '',
  }
}

function applyChargebackAlerts(data = {}) {
  const fallback = defaultChargebackAlerts()
  chargebackAlerts.value = {
    ...fallback,
    ...data,
    warningAmount: Number(data.warningAmount ?? fallback.warningAmount),
    criticalAmount: Number(data.criticalAmount ?? fallback.criticalAmount),
    alertCount: Number(data.alertCount || 0),
    warningCount: Number(data.warningCount || 0),
    criticalCount: Number(data.criticalCount || 0),
    organizations: Array.isArray(data.organizations) ? data.organizations : [],
  }
}

function resetChargebackAlerts() {
  applyChargebackAlerts({})
}

function defaultChargebackAlertNotificationPreview() {
  return {
    mode: 'PREVIEW',
    channel: defaultChargebackOptions.notificationChannel,
    target: 'UNCONFIGURED',
    externalDeliveryEnabled: false,
    currency: defaultChargebackOptions.currency,
    notificationCount: 0,
    notifications: [],
    generatedAt: '',
    note: '',
  }
}

function applyChargebackAlertNotificationPreview(data = {}) {
  const fallback = defaultChargebackAlertNotificationPreview()
  chargebackAlertNotificationPreview.value = {
    ...fallback,
    ...data,
    externalDeliveryEnabled: Boolean(data.externalDeliveryEnabled),
    notificationCount: Number(data.notificationCount || 0),
    notifications: Array.isArray(data.notifications) ? data.notifications : [],
  }
}

function resetChargebackAlertNotificationPreview() {
  applyChargebackAlertNotificationPreview({})
}

function defaultChargebackAlertNotificationOutbox() {
  return {
    deliveryCount: 0,
    deliveries: [],
    generatedAt: '',
  }
}

function normalizeChargebackAlertNotificationDelivery(delivery = {}) {
  return {
    id: delivery.id,
    organizationId: delivery.organizationId,
    organizationName: delivery.organizationName || '',
    severity: delivery.severity || '',
    estimatedTotalCost: Number(delivery.estimatedTotalCost || 0),
    warningAmount: Number(delivery.warningAmount || 0),
    criticalAmount: Number(delivery.criticalAmount || 0),
    channel: delivery.channel || '',
    target: delivery.target || '',
    status: delivery.status || '',
    attemptCount: Number(delivery.attemptCount || 0),
    nextAttemptAt: delivery.nextAttemptAt || '',
    subject: delivery.subject || '',
    message: delivery.message || '',
    payloadJson: delivery.payloadJson || '',
    requestedBy: delivery.requestedBy || '',
    reason: delivery.reason || '',
    createdAt: delivery.createdAt || '',
    updatedAt: delivery.updatedAt || '',
    lastError: delivery.lastError || '',
  }
}

function applyChargebackAlertNotificationOutbox(data = {}) {
  const deliveries = Array.isArray(data.deliveries)
    ? data.deliveries.map((delivery) => normalizeChargebackAlertNotificationDelivery(delivery))
    : []
  const fallback = defaultChargebackAlertNotificationOutbox()
  chargebackAlertNotificationOutbox.value = {
    ...fallback,
    ...data,
    deliveryCount: Number(data.deliveryCount ?? deliveries.length),
    deliveries,
  }
}

function resetChargebackAlertNotificationOutbox() {
  applyChargebackAlertNotificationOutbox({})
}

function defaultChargebackInvoiceDrafts() {
  return {
    invoiceCount: 0,
    invoices: [],
    generatedAt: '',
  }
}

function applyChargebackInvoiceDrafts(data = {}) {
  const fallback = defaultChargebackInvoiceDrafts()
  chargebackInvoiceDrafts.value = {
    ...fallback,
    ...data,
    invoiceCount: Number(data.invoiceCount || 0),
    invoices: Array.isArray(data.invoices) ? data.invoices : [],
  }
}

function resetChargebackInvoiceDrafts() {
  applyChargebackInvoiceDrafts({})
}

function defaultChargebackFinalInvoices() {
  return {
    invoiceCount: 0,
    invoices: [],
    generatedAt: '',
  }
}

function normalizeChargebackFinalInvoice(invoice = {}) {
  return {
    id: invoice.id,
    sourceDraftId: invoice.sourceDraftId,
    invoiceNumber: invoice.invoiceNumber || '',
    status: invoice.status || '',
    paymentStatus: invoice.paymentStatus || '',
    finalInvoice: Boolean(invoice.finalInvoice),
    paymentRequest: Boolean(invoice.paymentRequest),
    organizationId: invoice.organizationId,
    organizationName: invoice.organizationName || '',
    currency: invoice.currency || defaultChargebackOptions.currency,
    estimatedTotalCost: Number(invoice.estimatedTotalCost || 0),
    storageCost: Number(invoice.storageCost || 0),
    trafficCost: Number(invoice.trafficCost || 0),
    operationCost: Number(invoice.operationCost || 0),
    requestedBy: invoice.requestedBy || '',
    approvedBy: invoice.approvedBy || '',
    finalizedBy: invoice.finalizedBy || '',
    paymentRequestedBy: invoice.paymentRequestedBy || '',
    paymentRecordedBy: invoice.paymentRecordedBy || '',
    reason: invoice.reason || '',
    finalizationNote: invoice.finalizationNote || '',
    paymentRequestNote: invoice.paymentRequestNote || '',
    paymentReference: invoice.paymentReference || '',
    createdAt: invoice.createdAt || '',
    updatedAt: invoice.updatedAt || '',
    finalizedAt: invoice.finalizedAt || '',
    paymentRequestedAt: invoice.paymentRequestedAt || '',
    paidAt: invoice.paidAt || '',
    note: invoice.note || '',
  }
}

function applyChargebackFinalInvoices(data = {}) {
  const invoices = Array.isArray(data.invoices)
    ? data.invoices.map((invoice) => normalizeChargebackFinalInvoice(invoice))
    : []
  chargebackFinalInvoices.value = {
    invoiceCount: Number(data.invoiceCount ?? invoices.length),
    invoices,
    generatedAt: data.generatedAt || '',
  }
}

function resetChargebackFinalInvoices() {
  applyChargebackFinalInvoices({})
}

function defaultChargebackPaymentProviderHandoffs() {
  return {
    handoffCount: 0,
    handoffs: [],
    generatedAt: '',
  }
}

function normalizeChargebackPaymentProviderHandoff(handoff = {}) {
  return {
    id: handoff.id,
    finalInvoiceId: handoff.finalInvoiceId,
    invoiceNumber: handoff.invoiceNumber || '',
    organizationId: handoff.organizationId,
    organizationName: handoff.organizationName || '',
    currency: handoff.currency || defaultChargebackOptions.currency,
    amount: Number(handoff.amount || 0),
    provider: handoff.provider || '',
    targetAccount: handoff.targetAccount || '',
    status: handoff.status || '',
    attemptCount: Number(handoff.attemptCount || 0),
    nextAttemptAt: handoff.nextAttemptAt || '',
    payloadJson: handoff.payloadJson || '',
    requestedBy: handoff.requestedBy || '',
    reason: handoff.reason || '',
    createdAt: handoff.createdAt || '',
    updatedAt: handoff.updatedAt || '',
    lastError: handoff.lastError || '',
  }
}

function applyChargebackPaymentProviderHandoffs(data = {}) {
  const handoffs = Array.isArray(data.handoffs)
    ? data.handoffs.map((handoff) => normalizeChargebackPaymentProviderHandoff(handoff))
    : []
  chargebackPaymentProviderHandoffs.value = {
    handoffCount: Number(data.handoffCount ?? handoffs.length),
    handoffs,
    generatedAt: data.generatedAt || '',
  }
}

function resetChargebackPaymentProviderHandoffs() {
  applyChargebackPaymentProviderHandoffs({})
}

function defaultChargebackPaymentProviderAdapterReadiness() {
  return {
    mode: 'PAYMENT_PROVIDER_ADAPTER_READINESS',
    status: '',
    nativeApiSupported: false,
    nativeApiReady: false,
    profileCount: 0,
    webhookReadyProfileCount: 0,
    nativeApiReadyProfileCount: 0,
    profiles: [],
    generatedAt: '',
    scopePolicy: '',
    secretPolicy: '',
    note: '',
  }
}

function normalizeChargebackPaymentProviderAdapterProfile(profile = {}) {
  return {
    providerProfile: profile.providerProfile || '',
    sampleProvider: profile.sampleProvider || '',
    adapterMode: profile.adapterMode || '',
    status: profile.status || '',
    webhookProfileConfigured: Boolean(profile.webhookProfileConfigured),
    nativeApiSupported: Boolean(profile.nativeApiSupported),
    nativeApiReady: Boolean(profile.nativeApiReady),
    requiredConfiguration: profile.requiredConfiguration || '',
    note: profile.note || '',
  }
}

function applyChargebackPaymentProviderAdapterReadiness(data = {}) {
  const profiles = Array.isArray(data.profiles)
    ? data.profiles.map((profile) => normalizeChargebackPaymentProviderAdapterProfile(profile))
    : []
  const fallback = defaultChargebackPaymentProviderAdapterReadiness()
  chargebackPaymentProviderAdapterReadiness.value = {
    ...fallback,
    ...data,
    nativeApiSupported: Boolean(data.nativeApiSupported),
    nativeApiReady: Boolean(data.nativeApiReady),
    profileCount: Number(data.profileCount ?? profiles.length),
    webhookReadyProfileCount: Number(data.webhookReadyProfileCount || 0),
    nativeApiReadyProfileCount: Number(data.nativeApiReadyProfileCount || 0),
    profiles,
    generatedAt: data.generatedAt || '',
    scopePolicy: data.scopePolicy || '',
    secretPolicy: data.secretPolicy || '',
    note: data.note || '',
  }
}

function resetChargebackPaymentProviderAdapterReadiness() {
  applyChargebackPaymentProviderAdapterReadiness({})
}

function defaultChargebackAdapterRetryWorker() {
  return {
    mode: 'ADAPTER_RETRY_WORKER',
    enabled: false,
    dryRun: true,
    externalAdaptersEnabled: false,
    scanLimit: 50,
    notificationCandidateCount: 0,
    paymentCandidateCount: 0,
    updatedCount: 0,
    items: [],
    generatedAt: '',
    note: '',
  }
}

function normalizeChargebackAdapterRetryWorkerItem(item = {}) {
  return {
    itemType: item.itemType || '',
    id: item.id,
    fromStatus: item.fromStatus || '',
    toStatus: item.toStatus || '',
    attemptCount: Number(item.attemptCount || 0),
    nextAttemptAt: item.nextAttemptAt || '',
    note: item.note || '',
  }
}

function applyChargebackAdapterRetryWorker(data = {}) {
  const items = Array.isArray(data.items)
    ? data.items.map((item) => normalizeChargebackAdapterRetryWorkerItem(item))
    : []
  const fallback = defaultChargebackAdapterRetryWorker()
  chargebackAdapterRetryWorker.value = {
    ...fallback,
    ...data,
    enabled: Boolean(data.enabled),
    dryRun: data.dryRun !== false,
    externalAdaptersEnabled: Boolean(data.externalAdaptersEnabled),
    scanLimit: Number(data.scanLimit || fallback.scanLimit),
    notificationCandidateCount: Number(data.notificationCandidateCount || 0),
    paymentCandidateCount: Number(data.paymentCandidateCount || 0),
    updatedCount: Number(data.updatedCount || 0),
    items,
    generatedAt: data.generatedAt || '',
    note: data.note || '',
  }
}

function resetChargebackAdapterRetryWorker() {
  applyChargebackAdapterRetryWorker({})
}

function applyDashboardReadiness(data) {
  Object.assign(dashboardReadiness, {
    status: data.status || 'UNKNOWN',
    runtimeProfile: data.runtimeProfile || '-',
    blockerCount: Number(data.blockerCount || 0),
    warningCount: Number(data.warningCount || 0),
    blockers: Array.isArray(data.blockers) ? data.blockers : [],
    warnings: Array.isArray(data.warnings) ? data.warnings : [],
    severitySummaries: Array.isArray(data.severitySummaries) ? data.severitySummaries : [],
    categorySummaries: Array.isArray(data.categorySummaries) ? data.categorySummaries : [],
    items: Array.isArray(data.items) ? data.items : [],
    operationsReadinessSummary: normalizeOperationsReadinessSummary(data.operationsReadinessSummary),
    operationsEvidencePlan: normalizeOperationsEvidencePlan(data.operationsEvidencePlan),
    operationsEvidenceInvocation: normalizeOperationsEvidenceInvocation(data.operationsEvidenceInvocation),
    operationsInvocationUnblockPlan: normalizeOperationsInvocationUnblockPlan(data.operationsInvocationUnblockPlan),
    operationsDispatchPreflight: normalizeOperationsDispatchPreflight(data.operationsDispatchPreflight),
    operationsWorkflowRunIdPlan: normalizeOperationsWorkflowRunIdPlan(data.operationsWorkflowRunIdPlan),
    operationsArtifactCollectionPlan: normalizeOperationsArtifactCollectionPlan(data.operationsArtifactCollectionPlan),
    operationsReadinessArtifactImport: normalizeOperationsReadinessArtifactImport(data.operationsReadinessArtifactImport),
    operationsReadinessFinalize: normalizeOperationsReadinessFinalize(data.operationsReadinessFinalize),
    operationsHandoffPackage: normalizeOperationsHandoffPackage(data.operationsHandoffPackage),
    storageExpansionFinalize: normalizeStorageExpansionFinalize(data.storageExpansionFinalize),
    kubernetesHaDrReadiness: normalizeKubernetesHaDrReadiness(data.kubernetesHaDrReadiness),
    kubernetesDrFinalize: normalizeKubernetesDrFinalize(data.kubernetesDrFinalize),
    iamRbacEvidence: normalizeIamRbacEvidence(data.iamRbacEvidence),
    securityEvidence: normalizeSecurityEvidence(data.securityEvidence),
    secretRotationEvidence: normalizeSecretRotationEvidence(data.secretRotationEvidence),
    commercialIntegrationEvidence: normalizeCommercialIntegrationEvidence(data.commercialIntegrationEvidence),
    commercialApprovalEvidence: normalizeCommercialApprovalEvidence(data.commercialApprovalEvidence),
    enterpriseAuthSmokeEvidence: normalizeEnterpriseAuthSmokeEvidence(data.enterpriseAuthSmokeEvidence),
    enterpriseAuthJitRollbackEvidence: normalizeEnterpriseAuthJitRollbackEvidence(data.enterpriseAuthJitRollbackEvidence),
    dataFlowStoragePlan: normalizeDataFlowStoragePlan(data.dataFlowStoragePlan),
    dataFlowQueryRetentionBudget: normalizeDataFlowQueryRetentionBudget(data.dataFlowQueryRetentionBudget),
    dataFlowStorageTransitionRunbook: normalizeDataFlowStorageTransitionRunbook(data.dataFlowStorageTransitionRunbook),
    storageBackendTelemetryEvidence: normalizeStorageBackendTelemetryEvidence(data.storageBackendTelemetryEvidence),
    monitoringThresholdEvidence: normalizeMonitoringThresholdEvidence(data.monitoringThresholdEvidence),
    clusterNetworkAccessReviewEvidence: normalizeHardeningEvidence(data.clusterNetworkAccessReviewEvidence),
    helmValuesHardeningEvidence: normalizeHardeningEvidence(data.helmValuesHardeningEvidence),
    supportEscalationHandoffEvidence: normalizeSupportEscalationHandoffEvidence(data.supportEscalationHandoffEvidence),
    minioBucketCorsVerification: normalizeMinioBucketCorsVerification(data.minioBucketCorsVerification),
    operationsEvidenceHandoff: normalizeOperationsEvidenceHandoff(data.operationsEvidenceHandoff),
    operationsReadinessConvergence: normalizeOperationsReadinessConvergence(data.operationsReadinessConvergence),
    kubernetesOperationsReportSync: normalizeKubernetesOperationsReportSync(data.kubernetesOperationsReportSync),
    generatedAt: data.generatedAt || '',
  })
  if (readinessCategoryFilter.value !== 'ALL' && !dashboardReadiness.categorySummaries.some((summary) => summary.category === readinessCategoryFilter.value)) {
    readinessCategoryFilter.value = 'ALL'
  }
  if (readinessSeverityFilter.value !== 'ALL' && !dashboardReadiness.severitySummaries.some((summary) => summary.severity === readinessSeverityFilter.value)) {
    readinessSeverityFilter.value = 'ALL'
  }
}

function resetDashboardReadiness() {
  applyDashboardReadiness({})
}

function normalizeOperationsEvidencePlanSummary(summary = {}) {
  return {
    totalActions: Number(summary?.totalActions || 0),
    kubernetesLiveActions: Number(summary?.kubernetesLiveActions || 0),
    securityCiActions: Number(summary?.securityCiActions || 0),
    operatorRemediationActions: Number(summary?.operatorRemediationActions || 0),
    requiresOperatorApprovalCount: Number(summary?.requiresOperatorApprovalCount || 0),
    requiresKubeconfigSecretCount: Number(summary?.requiresKubeconfigSecretCount || 0),
    actionsWithPlaceholdersCount: Number(summary?.actionsWithPlaceholdersCount || 0),
    unplannedCheckCount: Number(summary?.unplannedCheckCount || 0),
  }
}

function normalizeOperationsEvidencePlanCategoryCounts(counts = []) {
  if (!Array.isArray(counts)) {
    return []
  }
  return counts
    .map((item) => ({
      category: item?.category || '',
      count: Number(item?.count || 0),
    }))
    .filter((item) => item.category)
}

function normalizeOperationsReadinessRemediations(remediations = []) {
  if (!Array.isArray(remediations)) return []
  return remediations.map((item) => ({
    name: item?.name || '',
    category: item?.category || '',
    evidencePath: item?.evidencePath || '',
    requiredEvidence: item?.requiredEvidence || '',
    detail: item?.detail || '',
    command: item?.command || '',
    workflow: item?.workflow || '',
    workflowCommand: item?.workflowCommand || '',
    note: item?.note || '',
  }))
}

function normalizeOperationsReadinessSummary(summary = {}) {
  return {
    result: summary?.result || '',
    summary: summary?.summary || '',
    reportPath: summary?.reportPath || '',
    generatedAt: summary?.generatedAt || '',
    passedCount: Number(summary?.passedCount || 0),
    pendingCount: Number(summary?.pendingCount || 0),
    totalCount: Number(summary?.totalCount || 0),
    checkCount: Number(summary?.checkCount || 0),
    pendingCategorySummary: summary?.pendingCategorySummary || '',
    pendingCategoryCounts: normalizeOperationsEvidencePlanCategoryCounts(summary?.pendingCategoryCounts),
    pendingRemediationCount: Number(summary?.pendingRemediationCount || 0),
    pendingRemediations: normalizeOperationsReadinessRemediations(summary?.pendingRemediations),
    decisionRule: summary?.decisionRule || '',
  }
}

function normalizeOperationsEvidencePlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceSummary: plan?.sourceSummary || '',
    sourceReport: plan?.sourceReport || '',
    sourcePassedCount: Number(plan?.sourcePassedCount || 0),
    sourcePendingCount: Number(plan?.sourcePendingCount || 0),
    sourceTotalCount: Number(plan?.sourceTotalCount || 0),
    sourceCheckCount: Number(plan?.sourceCheckCount || 0),
    sourcePendingRemediationCount: Number(plan?.sourcePendingRemediationCount || 0),
    sourcePendingRemediationEntryCount: Number(plan?.sourcePendingRemediationEntryCount || 0),
    sourcePendingRemediationActionCount: Number(plan?.sourcePendingRemediationActionCount || 0),
    sourcePendingRemediationMissingActionCount: Number(plan?.sourcePendingRemediationMissingActionCount || 0),
    sourcePendingRemediationCoverageReady: Boolean(plan?.sourcePendingRemediationCoverageReady),
    pendingCount: Number(plan?.pendingCount || 0),
    actionCount: Number(plan?.actionCount || 0),
    unplannedCount: Number(plan?.unplannedCount || 0),
    pendingCategorySummary: plan?.pendingCategorySummary || '',
    pendingCategoryCounts: normalizeOperationsEvidencePlanCategoryCounts(plan?.pendingCategoryCounts),
    actionSummary: normalizeOperationsEvidencePlanSummary(plan?.actionSummary),
    actions: Array.isArray(plan?.actions) ? plan.actions : [],
  }
}

function normalizeOperationsEvidenceInvocation(invocation = {}) {
  return {
    result: invocation?.result || '',
    sourceSummary: invocation?.sourceSummary || '',
    sourcePlan: invocation?.sourcePlan || '',
    sourcePassedCount: Number(invocation?.sourcePassedCount || 0),
    sourcePendingCount: Number(invocation?.sourcePendingCount || 0),
    sourceTotalCount: Number(invocation?.sourceTotalCount || 0),
    sourceCheckCount: Number(invocation?.sourceCheckCount || 0),
    commandMode: invocation?.commandMode || '',
    executionMode: invocation?.executionMode || '',
    selectedActionCount: Number(invocation?.selectedActionCount || 0),
    selectedActionOrders: Array.isArray(invocation?.selectedActionOrders)
      ? invocation.selectedActionOrders
      : [],
    plannedCount: Number(invocation?.plannedCount || 0),
    blockedCount: Number(invocation?.blockedCount || 0),
    executedCount: Number(invocation?.executedCount || 0),
    failedCount: Number(invocation?.failedCount || 0),
    actions: Array.isArray(invocation?.actions) ? invocation.actions : [],
  }
}

function normalizeOperationsInvocationUnblockPlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceInvocationReport: plan?.sourceInvocationReport || '',
    sourceResult: plan?.sourceResult || '',
    sourceSummary: plan?.sourceSummary || '',
    sourcePassedCount: Number(plan?.sourcePassedCount || 0),
    sourcePendingCount: Number(plan?.sourcePendingCount || 0),
    sourceTotalCount: Number(plan?.sourceTotalCount || 0),
    sourceCheckCount: Number(plan?.sourceCheckCount || 0),
    selectedActionCount: Number(plan?.selectedActionCount || 0),
    plannedCount: Number(plan?.plannedCount || 0),
    blockedCount: Number(plan?.blockedCount || 0),
    failedCount: Number(plan?.failedCount || 0),
    needsKubeconfigSecretConfirmation: Boolean(plan?.needsKubeconfigSecretConfirmation),
    needsOperatorApprovalConfirmation: Boolean(plan?.needsOperatorApprovalConfirmation),
    requiredPlaceholderCount: Number(plan?.requiredPlaceholderCount || 0),
    ambiguousRepeatedPlaceholderCount: Number(plan?.ambiguousRepeatedPlaceholderCount || 0),
    confirmationGroupCount: Number(plan?.confirmationGroupCount || 0),
    requiredInputGroupCount: Number(plan?.requiredInputGroupCount || 0),
    blockedActionOrders: Array.isArray(plan?.blockedActionOrders) ? plan.blockedActionOrders : [],
    plannedActionOrders: Array.isArray(plan?.plannedActionOrders) ? plan.plannedActionOrders : [],
    confirmedPlanCommand: plan?.confirmedPlanCommand || '',
    blockedOnlyPlanCommand: plan?.blockedOnlyPlanCommand || '',
    plannedOnlyCommand: plan?.plannedOnlyCommand || '',
    decisionRule: plan?.decisionRule || '',
    confirmationGroups: Array.isArray(plan?.confirmationGroups) ? plan.confirmationGroups : [],
    requiredInputGroups: Array.isArray(plan?.requiredInputGroups) ? plan.requiredInputGroups : [],
    actions: Array.isArray(plan?.actions) ? plan.actions : [],
  }
}

function normalizeDispatchPreflightGitRefSafety(gitRefSafety = {}) {
  return {
    checked: Boolean(gitRefSafety?.checked),
    status: gitRefSafety?.status || '',
    githubRef: gitRefSafety?.githubRef || '',
    currentBranch: gitRefSafety?.currentBranch || '',
    commitSha: gitRefSafety?.commitSha || '',
    shortCommitSha: gitRefSafety?.shortCommitSha || '',
    upstreamRef: gitRefSafety?.upstreamRef || '',
    upstreamCommitSha: gitRefSafety?.upstreamCommitSha || '',
    aheadCount: Number(gitRefSafety?.aheadCount || 0),
    behindCount: Number(gitRefSafety?.behindCount || 0),
    workingTreeDirty: Boolean(gitRefSafety?.workingTreeDirty),
    githubRefMatchesCurrentBranch: Boolean(gitRefSafety?.githubRefMatchesCurrentBranch),
    githubRefLikelyContainsCommit: Boolean(gitRefSafety?.githubRefLikelyContainsCommit),
    suggestedGitHubRef: gitRefSafety?.suggestedGitHubRef || '',
    suggestedPushCommand: gitRefSafety?.suggestedPushCommand || '',
    note: gitRefSafety?.note || '',
  }
}
function normalizeOperationsDispatchPreflight(preflight = {}) {
  return {
    result: preflight?.result || '',
    sourceUnblockPlan: preflight?.sourceUnblockPlan || '',
    sourceResult: preflight?.sourceResult || '',
    sourcePassedCount: Number(preflight?.sourcePassedCount || 0),
    sourcePendingCount: Number(preflight?.sourcePendingCount || 0),
    sourceTotalCount: Number(preflight?.sourceTotalCount || 0),
    sourceCheckCount: Number(preflight?.sourceCheckCount || 0),
    selectedActionCount: Number(preflight?.selectedActionCount || 0),
    selectedActionOrders: Array.isArray(preflight?.selectedActionOrders) ? preflight.selectedActionOrders : [],
    readyActionCount: Number(preflight?.readyActionCount || 0),
    readyActionOrders: Array.isArray(preflight?.readyActionOrders) ? preflight.readyActionOrders : [],
    blockedActionCount: Number(preflight?.blockedActionCount || 0),
    blockedActionOrders: Array.isArray(preflight?.blockedActionOrders) ? preflight.blockedActionOrders : [],
    needsKubeconfigSecretConfirmation: Boolean(preflight?.needsKubeconfigSecretConfirmation),
    needsOperatorApprovalConfirmation: Boolean(preflight?.needsOperatorApprovalConfirmation),
    requiredInputCount: Number(preflight?.requiredInputCount || 0),
    missingInputCount: Number(preflight?.missingInputCount || 0),
    ambiguousInputCount: Number(preflight?.ambiguousInputCount || 0),
    unsafeInputCount: Number(preflight?.unsafeInputCount || 0),
    invalidInputCount: Number(preflight?.invalidInputCount || 0),
    failedCheckCount: Number(preflight?.failedCheckCount || 0),
    warningCheckCount: Number(preflight?.warningCheckCount || 0),
    requiredGitHubSecrets: Array.isArray(preflight?.requiredGitHubSecrets) ? preflight.requiredGitHubSecrets : [],
    githubCliPath: preflight?.githubCliPath || '',
    githubRepository: preflight?.githubRepository || '',
    githubRef: preflight?.githubRef || '',
    gitRefSafety: normalizeDispatchPreflightGitRefSafety(preflight?.gitRefSafety),
    workflowFiles: Array.isArray(preflight?.workflowFiles) ? preflight.workflowFiles : [],
    checks: Array.isArray(preflight?.checks) ? preflight.checks : [],
    readyPlanCommand: preflight?.readyPlanCommand || '',
    executeCommand: preflight?.executeCommand || '',
    apiExecuteCommand: preflight?.apiExecuteCommand || '',
    readySubsetPlanCommand: preflight?.readySubsetPlanCommand || '',
    readySubsetExecuteCommand: preflight?.readySubsetExecuteCommand || '',
    readySubsetApiExecuteCommand: preflight?.readySubsetApiExecuteCommand || '',
    requiredInputs: Array.isArray(preflight?.requiredInputs) ? preflight.requiredInputs : [],
    inputTemplates: Array.isArray(preflight?.inputTemplates) ? preflight.inputTemplates : [],
    decisionRule: preflight?.decisionRule || '',
  }
}

function normalizeOperationsWorkflowRunIdInputs(inputs = []) {
  return Array.isArray(inputs)
    ? inputs.map((input) => ({
      workflow: input?.workflow || '',
      group: input?.group || '',
      actionOrders: Array.isArray(input?.actionOrders) ? input.actionOrders : [],
      runIdParameter: input?.runIdParameter || '',
      recommendedRunId: input?.recommendedRunId || '',
      artifactName: input?.artifactName || '',
      requiredForReadiness: Boolean(input?.requiredForReadiness),
      readyForArtifactDownload: Boolean(input?.readyForArtifactDownload),
      runsUrl: input?.runsUrl || '',
      runListJsonPath: input?.runListJsonPath || '',
      queryCommand: input?.queryCommand || '',
      gitHubApiQueryUrl: input?.gitHubApiQueryUrl || '',
      sourceSelected: Boolean(input?.sourceSelected),
      supplementalForSecurityFinalizer: Boolean(input?.supplementalForSecurityFinalizer),
    }))
    : []
}

function normalizeOperationsInputValueActionSummaries(actions = []) {
  return Array.isArray(actions)
    ? actions.map((action) => ({
      actionOrder: Number(action?.actionOrder || 0),
      actionName: action?.actionName || '',
      category: action?.category || '',
      workflow: action?.workflow || '',
      inputFree: Boolean(action?.inputFree),
      status: action?.status || '',
      valueCount: Number(action?.valueCount || 0),
      readyValueCount: Number(action?.readyValueCount || 0),
      missingValueCount: Number(action?.missingValueCount || 0),
      unsafeValueCount: Number(action?.unsafeValueCount || 0),
      invalidValueCount: Number(action?.invalidValueCount || 0),
      nonReadyValueKeys: Array.isArray(action?.nonReadyValueKeys) ? action.nonReadyValueKeys : [],
    }))
    : []
}
function normalizeOperationsWorkflowRunIdPlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceInvocationReport: plan?.sourceInvocationReport || '',
    invocationResult: plan?.invocationResult || '',
    sourceSummary: plan?.sourceSummary || '',
    sourcePassedCount: Number(plan?.sourcePassedCount || 0),
    sourcePendingCount: Number(plan?.sourcePendingCount || 0),
    sourceTotalCount: Number(plan?.sourceTotalCount || 0),
    sourceCheckCount: Number(plan?.sourceCheckCount || 0),
    selectedActionOrders: Array.isArray(plan?.selectedActionOrders)
      ? plan.selectedActionOrders
      : (Array.isArray(plan?.sourceActionOrders) ? plan.sourceActionOrders : []),
    branch: plan?.branch || '',
    githubRepository: plan?.githubRepository || '',
    queryMode: plan?.queryMode || '',
    runListJsonDirectory: plan?.runListJsonDirectory || '',
    runListJsonDirectoryCommand: plan?.runListJsonDirectoryCommand || '',
    githubApiRunListCommand: plan?.githubApiRunListCommand || '',
    githubApiBaseUrl: plan?.githubApiBaseUrl || '',
    runListJsonFilePattern: plan?.runListJsonFilePattern || '',
    runListJsonHandoffNote: plan?.runListJsonHandoffNote || '',
    browserWorkflowRunsUrls: Array.isArray(plan?.browserWorkflowRunsUrls) ? plan.browserWorkflowRunsUrls : [],
    workflowRunIdInputs: normalizeOperationsWorkflowRunIdInputs(plan?.workflowRunIdInputs),
    recommendedCommands: Array.isArray(plan?.recommendedCommands) ? plan.recommendedCommands : [],
    limit: Number(plan?.limit || 0),
    workflowCount: Number(plan?.workflowCount || 0),
    readyWorkflowCount: Number(plan?.readyWorkflowCount || 0),
    missingWorkflowCount: Number(plan?.missingWorkflowCount || 0),
    staleWorkflowCount: Number(plan?.staleWorkflowCount || 0),
    imageSigningVersion: plan?.imageSigningVersion || '',
    commitSha: plan?.commitSha || '',
    artifactCollectionPlanCommand: plan?.artifactCollectionPlanCommand || '',
    securityEvidenceFinalizerReady: Boolean(plan?.securityEvidenceFinalizerReady),
    securityEvidenceFinalizerRunIdInputs: Array.isArray(plan?.securityEvidenceFinalizerRunIdInputs)
      ? plan.securityEvidenceFinalizerRunIdInputs
      : [],
    securityEvidenceFinalizerRunIdInputHints: normalizeOperationsWorkflowRunIdInputs(plan?.securityEvidenceFinalizerRunIdInputHints),
    securityEvidenceFinalizerMissingRunIdInputs: Array.isArray(plan?.securityEvidenceFinalizerMissingRunIdInputs)
      ? plan.securityEvidenceFinalizerMissingRunIdInputs
      : [],
    securityEvidenceFinalizerDependencyNote: plan?.securityEvidenceFinalizerDependencyNote || '',
    securityEvidenceFinalizerCommand: plan?.securityEvidenceFinalizerCommand || '',
    decisionRule: plan?.decisionRule || '',
    workflows: Array.isArray(plan?.workflows) ? plan.workflows : [],
  }
}

function normalizeOperationsArtifactCollectionPlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceInvocationReport: plan?.sourceInvocationReport || '',
    invocationResult: plan?.invocationResult || '',
    sourceSummary: plan?.sourceSummary || '',
    sourcePassedCount: Number(plan?.sourcePassedCount || 0),
    sourcePendingCount: Number(plan?.sourcePendingCount || 0),
    sourceTotalCount: Number(plan?.sourceTotalCount || 0),
    sourceCheckCount: Number(plan?.sourceCheckCount || 0),
    selectedActionOrders: Array.isArray(plan?.selectedActionOrders)
      ? plan.selectedActionOrders
      : (Array.isArray(plan?.sourceActionOrders) ? plan.sourceActionOrders : []),
    invocationSummary: plan?.invocationSummary || '',
    artifactCount: Number(plan?.artifactCount || 0),
    requiredArtifactCount: Number(plan?.requiredArtifactCount || 0),
    readyArtifactCount: Number(plan?.readyArtifactCount || 0),
    missingRequiredArtifactCount: Number(plan?.missingRequiredArtifactCount || 0),
    securitySourceArtifactCount: Number(plan?.securitySourceArtifactCount || 0),
    readySecuritySourceArtifactCount: Number(plan?.readySecuritySourceArtifactCount || 0),
    missingSecuritySourceArtifactCount: Number(plan?.missingSecuritySourceArtifactCount || 0),
    securityEvidenceFinalizerReady: Boolean(plan?.securityEvidenceFinalizerReady),
    securityEvidenceFinalizerInputs: Array.isArray(plan?.securityEvidenceFinalizerInputs)
      ? plan.securityEvidenceFinalizerInputs.map((input) => ({
        name: input?.name || '',
        runIdParameter: input?.runIdParameter || '',
        workflow: input?.workflow || '',
        artifactName: input?.artifactName || '',
        artifactNameParameter: input?.artifactNameParameter || '',
        runId: input?.runId || '',
        ready: Boolean(input?.ready),
        sourceArtifactSelected: Boolean(input?.sourceArtifactSelected),
        sourceArtifactReady: Boolean(input?.sourceArtifactReady),
        requiredForSecurityFinalizer: Boolean(input?.requiredForSecurityFinalizer),
        note: input?.note || '',
      }))
      : [],
    securityEvidenceFinalizerMissingRunIdInputs: Array.isArray(plan?.securityEvidenceFinalizerMissingRunIdInputs)
      ? plan.securityEvidenceFinalizerMissingRunIdInputs
      : [],
    securityEvidenceFinalizerCommand: plan?.securityEvidenceFinalizerCommand || '',
    operationsArtifactFinalizerCommand: plan?.operationsArtifactFinalizerCommand || '',
    dataFlowStoragePlanInputNote: plan?.dataFlowStoragePlanInputNote || '',
    dataFlowQueryRetentionBudgetInputNote: plan?.dataFlowQueryRetentionBudgetInputNote || '',
    dataFlowStorageTransitionRunbookInputNote: plan?.dataFlowStorageTransitionRunbookInputNote || '',
    minioBucketCorsInputNote: plan?.minioBucketCorsInputNote || '',
    localImportCommand: plan?.localImportCommand || '',
    decisionRule: plan?.decisionRule || '',
    artifacts: Array.isArray(plan?.artifacts) ? plan.artifacts : [],
  }
}

function normalizeOperationsReadinessArtifactImport(report = {}) {
  return {
    result: report?.result || '',
    status: report?.status || '',
    selectedGroupCount: Number(report?.selectedGroupCount || 0),
    importedCount: Number(report?.importedCount || 0),
    failedCount: Number(report?.failedCount || 0),
    outputDirectory: report?.outputDirectory || '',
    secretPolicy: report?.secretPolicy || '',
    entries: Array.isArray(report?.entries) ? report.entries : [],
  }
}

function normalizeOperationsReadinessFinalize(report = {}) {
  return {
    result: report?.result || '',
    status: report?.status || '',
    readinessResult: report?.readinessResult || '',
    readinessSummary: report?.readinessSummary || '',
    namespace: report?.namespace || '',
    sourceNamespace: report?.sourceNamespace || '',
    restoreNamespace: report?.restoreNamespace || '',
    backupTimestamp: report?.backupTimestamp || '',
    powerShellCommand: report?.powerShellCommand || '',
    failedCount: Number(report?.failedCount || 0),
    selectedSteps: report?.selectedSteps && typeof report.selectedSteps === 'object' ? report.selectedSteps : {},
    paths: report?.paths && typeof report.paths === 'object' ? report.paths : {},
    commands: Array.isArray(report?.commands) ? report.commands : [],
    steps: Array.isArray(report?.steps) ? report.steps : [],
    gaps: Array.isArray(report?.gaps) ? report.gaps : [],
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeOperationsHandoffPackage(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    passedCount: Number(report?.passedCount || 0),
    failureCount: Number(report?.failureCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    checkCount: Number(report?.checkCount || 0),
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    evidenceRefs: report?.evidenceRefs && typeof report.evidenceRefs === 'object' ? report.evidenceRefs : {},
    operationsReadinessSnapshot: report?.operationsReadinessSnapshot && typeof report.operationsReadinessSnapshot === 'object' ? report.operationsReadinessSnapshot : {},
    operationsConvergenceSnapshot: report?.operationsConvergenceSnapshot && typeof report.operationsConvergenceSnapshot === 'object' ? report.operationsConvergenceSnapshot : {},
    dataFlowStoragePlanSnapshot: normalizeDataFlowStoragePlan(report?.dataFlowStoragePlanSnapshot),
    dataFlowQueryRetentionBudgetSnapshot: normalizeDataFlowQueryRetentionBudget(report?.dataFlowQueryRetentionBudgetSnapshot),
    dataFlowStorageTransitionRunbookSnapshot: normalizeDataFlowStorageTransitionRunbook(report?.dataFlowStorageTransitionRunbookSnapshot),
    secretRotationSnapshot: normalizeSecretRotationEvidence(report?.secretRotationSnapshot),
    commercialIntegrationSnapshot: normalizeCommercialIntegrationEvidence(report?.commercialIntegrationSnapshot),
    commercialApprovalSnapshot: normalizeCommercialApprovalEvidence(report?.commercialApprovalSnapshot),
    chargebackCloseoutSnapshot: report?.chargebackCloseoutSnapshot && typeof report.chargebackCloseoutSnapshot === 'object' ? report.chargebackCloseoutSnapshot : {},
    enterpriseAuthSmokeSnapshot: normalizeEnterpriseAuthSmokeEvidence(report?.enterpriseAuthSmokeSnapshot),
    enterpriseAuthJitRollbackSnapshot: normalizeEnterpriseAuthJitRollbackEvidence(report?.enterpriseAuthJitRollbackSnapshot),
    monitoringThresholdSnapshot: normalizeMonitoringThresholdEvidence(report?.monitoringThresholdSnapshot),
    clusterNetworkAccessReviewSnapshot: normalizeHardeningEvidence(report?.clusterNetworkAccessReviewSnapshot),
    helmValuesHardeningSnapshot: normalizeHardeningEvidence(report?.helmValuesHardeningSnapshot),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeCommercialIntegrationEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    integrationCount: Number(report?.integrationCount || 0),
    verifiedCount: Number(report?.verifiedCount || 0),
    requiredCount: Number(report?.requiredCount || 0),
    requiredVerifiedCount: Number(report?.requiredVerifiedCount || 0),
    paymentProviderAdapterReadinessReviewed: Boolean(report?.paymentProviderAdapterReadinessReviewed),
    paymentProviderAdapterReadinessStatus: report?.paymentProviderAdapterReadinessStatus || '',
    paymentProviderAdapterWebhookReadyProfileCount: Number(report?.paymentProviderAdapterWebhookReadyProfileCount || 0),
    paymentProviderAdapterNativeReadyProfileCount: Number(report?.paymentProviderAdapterNativeReadyProfileCount || 0),
    failureCount: Number(report?.failureCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeStorageExpansionFinalize(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    startedAt: report?.startedAt || '',
    completedAt: report?.completedAt || '',
    namespace: report?.namespace || '',
    tenantName: report?.tenantName || '',
    serviceAccount: report?.serviceAccount || '',
    impersonateRunner: Boolean(report?.impersonateRunner),
    runBackendDryRunRunner: Boolean(report?.runBackendDryRunRunner),
    runBackendApply: Boolean(report?.runBackendApply),
    confirmApply: Boolean(report?.confirmApply),
    runStorageBackendTelemetry: Boolean(report?.runStorageBackendTelemetry),
    failedCount: Number(report?.failedCount || 0),
    evidence: report?.evidence && typeof report.evidence === 'object' ? report.evidence : {},
    gaps: Array.isArray(report?.gaps) ? report.gaps : [],
    steps: Array.isArray(report?.steps) ? report.steps : [],
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeKubernetesHaDrReadiness(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    namespace: report?.namespace || '',
    kubectlPath: report?.kubectlPath || '',
    restoreManifestPath: report?.restoreManifestPath || '',
    failureCount: Number(report?.failureCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
  }
}

function normalizeKubernetesDrFinalize(report = {}) {
  return {
    result: report?.result || '',
    status: report?.status || '',
    generatedAt: report?.generatedAt || '',
    startedAt: report?.startedAt || '',
    completedAt: report?.completedAt || '',
    sourceNamespace: report?.sourceNamespace || '',
    restoreNamespace: report?.restoreNamespace || '',
    backupTimestamp: report?.backupTimestamp || '',
    serverDryRunOnly: Boolean(report?.serverDryRunOnly),
    confirmRestore: Boolean(report?.confirmRestore),
    runBackupDrill: Boolean(report?.runBackupDrill),
    runRestoreSmoke: Boolean(report?.runRestoreSmoke),
    writeEvidenceRequest: Boolean(report?.writeEvidenceRequest),
    submitEvidence: Boolean(report?.submitEvidence),
    runS3ClientSmoke: Boolean(report?.runS3ClientSmoke),
    failedStepCount: Number(report?.failedStepCount || 0),
    gaps: Array.isArray(report?.gaps) ? report.gaps : [],
    commands: Array.isArray(report?.commands) ? report.commands : [],
    steps: Array.isArray(report?.steps) ? report.steps : [],
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeIamRbacEvidence(report = {}) {
  return {
    result: report?.result || '',
    status: report?.status || '',
    generatedAt: report?.generatedAt || '',
    startedAt: report?.startedAt || '',
    completedAt: report?.completedAt || '',
    namespace: report?.namespace || '',
    serviceAccount: report?.serviceAccount || '',
    powerShellCommand: report?.powerShellCommand || '',
    gradleCommand: report?.gradleCommand || '',
    runBackendPolicyTests: Boolean(report?.runBackendPolicyTests),
    runKubernetesLiveAuth: Boolean(report?.runKubernetesLiveAuth),
    failedCount: Number(report?.failedCount || 0),
    gaps: Array.isArray(report?.gaps) ? report.gaps : [],
    commands: Array.isArray(report?.commands) ? report.commands : [],
    steps: Array.isArray(report?.steps) ? report.steps : [],
    decisionRule: report?.decisionRule || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeSecurityEvidence(report = {}) {
  const imageSigning = report?.imageSigning || {}
  const containerSecurity = report?.containerSecurity || {}
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    failureCount: Number(report?.failureCount || 0),
    allowSyntheticEvidence: Boolean(report?.allowSyntheticEvidence),
    inputs: report?.inputs && typeof report.inputs === 'object' ? report.inputs : {},
    promoted: report?.promoted && typeof report.promoted === 'object' ? report.promoted : {},
    source: report?.source && typeof report.source === 'object' ? report.source : {},
    images: report?.images && typeof report.images === 'object' ? report.images : {},
    checks: Array.isArray(report?.checks) ? report.checks : [],
    imageSigning: {
      ...imageSigning,
      failureCount: Number(imageSigning?.failureCount || 0),
    },
    containerSecurity: {
      ...containerSecurity,
      failureCount: Number(containerSecurity?.failureCount || 0),
      backendSbomPackageCount: Number(containerSecurity?.backendSbomPackageCount || 0),
      backendSbomByteSize: Number(containerSecurity?.backendSbomByteSize || 0),
      frontendSbomPackageCount: Number(containerSecurity?.frontendSbomPackageCount || 0),
      frontendSbomByteSize: Number(containerSecurity?.frontendSbomByteSize || 0),
    },
    decisionRule: report?.decisionRule || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeSecretRotationEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    rotationWindow: report?.rotationWindow && typeof report.rotationWindow === 'object' ? report.rotationWindow : {},
    evidenceRefs: report?.evidenceRefs && typeof report.evidenceRefs === 'object' ? report.evidenceRefs : {},
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    rotatedCount: Number(report?.rotatedCount || 0),
    coreRotatedCount: Number(report?.coreRotatedCount || 0),
    coreRequiredCount: Number(report?.coreRequiredCount || 0),
    failureCount: Number(report?.failureCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    rotations: Array.isArray(report?.rotations) ? report.rotations : [],
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeCommercialApprovalEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    productVersion: report?.productVersion || '',
    approvedBy: report?.approvedBy || '',
    approvedAt: report?.approvedAt || '',
    passedCount: Number(report?.passedCount || 0),
    failureCount: Number(report?.failureCount || 0),
    checkCount: Number(report?.checkCount || 0),
    pricingPolicyProposalCommercialApproved: Boolean(report?.pricingPolicyProposalCommercialApproved),
    pricingPolicyProposalCommercialApprovedCount: Number(report?.pricingPolicyProposalCommercialApprovedCount || 0),
    pricingPolicyProposalApprovedPriceListCount: Number(report?.pricingPolicyProposalApprovedPriceListCount || 0),
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    evidenceRefs: report?.evidenceRefs && typeof report.evidenceRefs === 'object' ? report.evidenceRefs : {},
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeEnterpriseAuthSmokeEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    executionMode: report?.executionMode || '',
    apiBase: report?.apiBase || '',
    requireOidc: Boolean(report?.requireOidc),
    requireLdap: Boolean(report?.requireLdap),
    requireAuditEvents: Boolean(report?.requireAuditEvents),
    inputs: report?.inputs && typeof report.inputs === 'object' ? report.inputs : {},
    scopeOut: report?.scopeOut && typeof report.scopeOut === 'object' ? report.scopeOut : {},
    passCount: Number(report?.passCount || 0),
    failCount: Number(report?.failCount || 0),
    blockedCount: Number(report?.blockedCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    skippedCount: Number(report?.skippedCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeEnterpriseAuthJitRollbackEvidence(report = {}) {
  const smokeSnapshot = report?.enterpriseAuthSmokeSnapshot || {}
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    evidenceRef: report?.evidenceRef || '',
    reviewWindow: report?.reviewWindow && typeof report.reviewWindow === 'object' ? report.reviewWindow : {},
    enterpriseAuthSmokeSnapshot: {
      provided: Boolean(smokeSnapshot?.provided),
      parsed: Boolean(smokeSnapshot?.parsed),
      formatVersion: smokeSnapshot?.formatVersion || '',
      result: smokeSnapshot?.result || '',
      executionMode: smokeSnapshot?.executionMode || '',
      passCount: Number(smokeSnapshot?.passCount || 0),
      failCount: Number(smokeSnapshot?.failCount || 0),
      blockedCount: Number(smokeSnapshot?.blockedCount || 0),
      plannedCount: Number(smokeSnapshot?.plannedCount || 0),
      scopeOutAccepted: Boolean(smokeSnapshot?.scopeOutAccepted),
      detail: smokeSnapshot?.detail || '',
    },
    evidenceRefs: report?.evidenceRefs && typeof report.evidenceRefs === 'object' ? report.evidenceRefs : {},
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    failureCount: Number(report?.failureCount || 0),
    checkCount: Number(report?.checkCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeDataFlowStoragePlanCandidateDecision(candidateDecision = {}) {
  return {
    decision: candidateDecision?.decision || '',
    evidenceModel: candidateDecision?.evidenceModel || '',
    requiresMariaDbQueryEvidence: Boolean(candidateDecision.requiresMariaDbQueryEvidence),
    requiresTargetStoreEvidence: Boolean(candidateDecision.requiresTargetStoreEvidence),
    queryPlanEvidencePassed: Boolean(candidateDecision.queryPlanEvidencePassed),
    targetStoreEvidenceConfirmed: Boolean(candidateDecision.targetStoreEvidenceConfirmed),
    nextAction: candidateDecision?.nextAction || '',
    safeDataPolicy: candidateDecision?.safeDataPolicy || '',
  }
}

function normalizeDataFlowStoragePlan(report = {}) {
  const queryPlanEvidence = report?.queryPlanEvidence || {}
  return {
    result: report?.result || '',
    recordedAt: report?.recordedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    evidenceRef: report?.evidenceRef || '',
    candidateStore: report?.candidateStore || '',
    candidateDecision: normalizeDataFlowStoragePlanCandidateDecision(report?.candidateDecision),
    expectedPeakEventsPerDay: Number(report?.expectedPeakEventsPerDay || 0),
    expectedQueryWindowDays: Number(report?.expectedQueryWindowDays || 0),
    targetP95QueryLatencyMs: Number(report?.targetP95QueryLatencyMs || 0),
    eventRetentionDays: Number(report?.eventRetentionDays || 0),
    dailyRollupRetentionDays: Number(report?.dailyRollupRetentionDays || 0),
    monthlyRollupRetentionMonths: Number(report?.monthlyRollupRetentionMonths || 0),
    checkCount: Number(report?.checkCount || 0),
    passedCount: Number(report?.passedCount || 0),
    pendingCount: Number(report?.pendingCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    queryPlanEvidence: {
      provided: Boolean(queryPlanEvidence.provided),
      path: queryPlanEvidence.path || '',
      parsed: Boolean(queryPlanEvidence.parsed),
      formatVersion: queryPlanEvidence.formatVersion || '',
      expectedFormatVersion: queryPlanEvidence.expectedFormatVersion || '',
      validFormatVersion: Boolean(queryPlanEvidence.validFormatVersion),
      result: queryPlanEvidence.result || '',
      mode: queryPlanEvidence.mode || '',
      checkCount: Number(queryPlanEvidence.checkCount || 0),
      passedCount: Number(queryPlanEvidence.passedCount || 0),
      failedCount: Number(queryPlanEvidence.failedCount || 0),
      failedChecks: Array.isArray(queryPlanEvidence.failedChecks) ? queryPlanEvidence.failedChecks : [],
      detail: queryPlanEvidence.detail || '',
    },
    scopePolicy: report?.scopePolicy || '',
  }
}

function normalizeDataFlowQueryRetentionBudget(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    evidenceRef: report?.evidenceRef || '',
    storagePlanResult: report?.storagePlanResult || '',
    candidateStore: report?.candidateStore || '',
    targetP95QueryLatencyMs: Number(report?.targetP95QueryLatencyMs || 0),
    observedP95QueryLatencyMs: Number(report?.observedP95QueryLatencyMs || 0),
    observedP99QueryLatencyMs: Number(report?.observedP99QueryLatencyMs || 0),
    querySampleCount: Number(report?.querySampleCount || 0),
    observedQueryWindowDays: Number(report?.observedQueryWindowDays || 0),
    retentionBudgetSeconds: Number(report?.retentionBudgetSeconds || 0),
    detailedRetentionObservedSeconds: Number(report?.detailedRetentionObservedSeconds || 0),
    dailyRollupRetentionObservedSeconds: Number(report?.dailyRollupRetentionObservedSeconds || 0),
    monthlyRollupRetentionObservedSeconds: Number(report?.monthlyRollupRetentionObservedSeconds || 0),
    detailedRetentionDeletedRows: Number(report?.detailedRetentionDeletedRows || 0),
    dailyRollupRetentionDeletedRows: Number(report?.dailyRollupRetentionDeletedRows || 0),
    monthlyRollupRetentionDeletedRows: Number(report?.monthlyRollupRetentionDeletedRows || 0),
    queryLatencyWithinBudget: Boolean(report?.queryLatencyWithinBudget),
    retentionJobsWithinBudget: Boolean(report?.retentionJobsWithinBudget),
    failureCount: Number(report?.failureCount || 0),
    checkCount: Number(report?.checkCount || 0),
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    topFailedChecks: Array.isArray(report?.topFailedChecks) ? report.topFailedChecks : [],
    scopePolicy: report?.scopePolicy || '',
  }
}

function normalizeDataFlowStorageTransitionRunbook(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    evidenceRef: report?.evidenceRef || '',
    storagePlanResult: report?.storagePlanResult || '',
    candidateStore: report?.candidateStore || '',
    targetP95QueryLatencyMs: Number(report?.targetP95QueryLatencyMs || 0),
    failureCount: Number(report?.failureCount || 0),
    checkCount: Number(report?.checkCount || 0),
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    topFailedChecks: Array.isArray(report?.topFailedChecks) ? report.topFailedChecks : [],
    scopePolicy: report?.scopePolicy || '',
  }
}

function normalizeStorageBackendTelemetryEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    sourceMode: report?.sourceMode || '',
    minioAlias: report?.minioAlias || '',
    evidenceRef: report?.evidenceRef || '',
    adminInfoJsonSha256: report?.adminInfoJsonSha256 || '',
    rawAdminInfoStored: Boolean(report?.rawAdminInfoStored),
    poolCount: Number(report?.poolCount || 0),
    serverCount: Number(report?.serverCount || 0),
    onlineServerCount: Number(report?.onlineServerCount || 0),
    offlineServerCount: Number(report?.offlineServerCount || 0),
    driveCount: Number(report?.driveCount || 0),
    totalBytes: Number(report?.totalBytes || 0),
    usedBytes: Number(report?.usedBytes || 0),
    freeBytes: Number(report?.freeBytes || 0),
    capacityKnown: Boolean(report?.capacityKnown),
    failureCount: Number(report?.failureCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
  }
}

function normalizeMonitoringThresholdEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    evidenceRef: report?.evidenceRef || '',
    reviewWindow: report?.reviewWindow && typeof report.reviewWindow === 'object' ? report.reviewWindow : {},
    thresholdTargetsPath: report?.thresholdTargetsPath || '',
    requiredAlertCount: Number(report?.requiredAlertCount || 0),
    mappedAlertCount: Number(report?.mappedAlertCount || 0),
    missingAlerts: Array.isArray(report?.missingAlerts) ? report.missingAlerts : [],
    routeCount: Number(report?.routeCount || 0),
    routes: Array.isArray(report?.routes) ? report.routes : [],
    grafanaPanelCount: Number(report?.grafanaPanelCount || 0),
    tuningEvidenceCount: Number(report?.tuningEvidenceCount || 0),
    alertTargetCoverageComplete: Boolean(report?.alertTargetCoverageComplete),
    routeCoverageComplete: Boolean(report?.routeCoverageComplete),
    grafanaPanelCoverageComplete: Boolean(report?.grafanaPanelCoverageComplete),
    tuningEvidenceCoverageComplete: Boolean(report?.tuningEvidenceCoverageComplete),
    thresholdMappingComplete: Boolean(report?.thresholdMappingComplete),
    evidenceRefs: report?.evidenceRefs && typeof report.evidenceRefs === 'object' ? report.evidenceRefs : {},
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    failureCount: Number(report?.failureCount || 0),
    checkCount: Number(report?.checkCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeHardeningEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    reviewWindow: report?.reviewWindow && typeof report.reviewWindow === 'object' ? report.reviewWindow : {},
    evidence: report?.evidence && typeof report.evidence === 'object' ? report.evidence : {},
    staticSnapshot: report?.staticSnapshot && typeof report.staticSnapshot === 'object' ? report.staticSnapshot : {},
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    passCount: Number(report?.passCount || 0),
    failureCount: Number(report?.failureCount || 0),
    totalCount: Number(report?.totalCount || report?.checkCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeSupportEscalationHandoffEvidence(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    environmentName: report?.environmentName || '',
    targetCluster: report?.targetCluster || '',
    operatorName: report?.operatorName || '',
    reviewWindow: report?.reviewWindow && typeof report.reviewWindow === 'object' ? report.reviewWindow : {},
    evidence: report?.evidence && typeof report.evidence === 'object' ? report.evidence : {},
    documentSnapshot: report?.documentSnapshot && typeof report.documentSnapshot === 'object' ? report.documentSnapshot : {},
    confirmations: report?.confirmations && typeof report.confirmations === 'object' ? report.confirmations : {},
    passCount: Number(report?.passCount || 0),
    failureCount: Number(report?.failureCount || 0),
    totalCount: Number(report?.totalCount || report?.checkCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    secretPolicy: report?.secretPolicy || '',
  }
}

function normalizeMinioBucketCorsVerification(report = {}) {
  const commands = report?.operatorCommands || {}
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    sourceMode: report?.sourceMode || '',
    bucketName: report?.bucketName || '',
    minioAlias: report?.minioAlias || '',
    sourceRef: report?.sourceRef || '',
    executeRequested: Boolean(report?.executeRequested),
    rawCorsXmlStored: Boolean(report?.rawCorsXmlStored),
    ruleCount: Number(report?.ruleCount || 0),
    exposedHeaderCount: Number(report?.exposedHeaderCount || 0),
    failureCount: Number(report?.failureCount || 0),
    plannedCount: Number(report?.plannedCount || 0),
    allowedOrigins: Array.isArray(report?.allowedOrigins) ? report.allowedOrigins : [],
    allowedMethods: Array.isArray(report?.allowedMethods) ? report.allowedMethods : [],
    allowedHeaders: Array.isArray(report?.allowedHeaders) ? report.allowedHeaders : [],
    exposeHeaders: Array.isArray(report?.exposeHeaders) ? report.exposeHeaders : [],
    maxAgeSeconds: Array.isArray(report?.maxAgeSeconds) ? report.maxAgeSeconds : [],
    checks: Array.isArray(report?.checks) ? report.checks : [],
    decisionRule: report?.decisionRule || '',
    scopePolicy: report?.scopePolicy || '',
    operatorCommands: {
      collectWithMc: commands.collectWithMc || '',
      verifyFromFile: commands.verifyFromFile || '',
      collectAndVerify: commands.collectAndVerify || '',
    },
  }
}

function normalizeOperationsEvidenceHandoff(handoff = {}) {
  const nextStep = handoff?.nextStep || {}
  const currentBottleneck = handoff?.currentBottleneck || nextStep
  return {
    result: handoff?.result || '',
    generatedAt: handoff?.generatedAt || '',
    nextStep: {
      code: nextStep.code || '',
      title: nextStep.title || '',
      command: nextStep.command || '',
      reason: nextStep.reason || '',
      note: nextStep.note || '',
      dispatchUrls: Array.isArray(nextStep.dispatchUrls) ? nextStep.dispatchUrls : [],
    },
    currentBottleneck: {
      code: currentBottleneck.code || '',
      title: currentBottleneck.title || '',
      command: currentBottleneck.command || '',
      reason: currentBottleneck.reason || '',
      note: currentBottleneck.note || '',
      dispatchUrls: Array.isArray(currentBottleneck.dispatchUrls) ? currentBottleneck.dispatchUrls : [],
    },
    stageCount: Number(handoff?.stageCount || 0),
    readyStageCount: Number(handoff?.readyStageCount || 0),
    readinessSummary: handoff?.readinessSummary || '',
    readinessPassedCount: Number(handoff?.readinessPassedCount || 0),
    readinessPendingCount: Number(handoff?.readinessPendingCount || 0),
    readinessTotalCount: Number(handoff?.readinessTotalCount || 0),
    readinessCheckCount: Number(handoff?.readinessCheckCount || 0),
    dispatchPreflightResult: handoff?.dispatchPreflightResult || '',
    dispatchGithubRepository: handoff?.dispatchGithubRepository || '',
    requiredGitHubSecretCount: Number(handoff?.requiredGitHubSecretCount || 0),
    requiredGitHubSecrets: Array.isArray(handoff?.requiredGitHubSecrets) ? handoff.requiredGitHubSecrets : [],
    requiredGitHubSecretSummaries: Array.isArray(handoff?.requiredGitHubSecretSummaries) ? handoff.requiredGitHubSecretSummaries : [],
    readyDispatchTemplateCount: Number(handoff?.readyDispatchTemplateCount || 0),
    blockedDispatchTemplateCount: Number(handoff?.blockedDispatchTemplateCount || 0),
    readyDispatchActionOrders: Array.isArray(handoff?.readyDispatchActionOrders) ? handoff.readyDispatchActionOrders : [],
    blockedDispatchActionOrders: Array.isArray(handoff?.blockedDispatchActionOrders) ? handoff.blockedDispatchActionOrders : [],
    invocationSelectedActionOrders: Array.isArray(handoff?.invocationSelectedActionOrders) ? handoff.invocationSelectedActionOrders : [],
    dispatchPreflightSelectedActionOrders: Array.isArray(handoff?.dispatchPreflightSelectedActionOrders) ? handoff.dispatchPreflightSelectedActionOrders : [],
    workflowRunIdPlanActionOrders: Array.isArray(handoff?.workflowRunIdPlanActionOrders) ? handoff.workflowRunIdPlanActionOrders : [],
    workflowRunIdPlanQueryMode: handoff?.workflowRunIdPlanQueryMode || '',
    workflowRunIdPlanGithubApiTokenPresent: Boolean(handoff?.workflowRunIdPlanGithubApiTokenPresent),
    workflowRunIdPlanGithubApiUnauthenticated: Boolean(handoff?.workflowRunIdPlanGithubApiUnauthenticated),
    workflowRunIdPlanQueryExecuted: Boolean(handoff?.workflowRunIdPlanQueryExecuted),
    workflowRunIdPlanQueryExecutedCount: Number(handoff?.workflowRunIdPlanQueryExecutedCount || 0),
    workflowRunIdPlanQueryWorkflowCount: Number(handoff?.workflowRunIdPlanQueryWorkflowCount || 0),
    workflowRunIdPlanQuerySucceededCount: Number(handoff?.workflowRunIdPlanQuerySucceededCount || 0),
    workflowRunIdPlanQueryErrorCount: Number(handoff?.workflowRunIdPlanQueryErrorCount || 0),
    workflowRunIdPlanCandidateCount: Number(handoff?.workflowRunIdPlanCandidateCount || 0),
    inputFreeBlockedReviewReportExists: Boolean(handoff?.inputFreeBlockedReviewReportExists),
    inputFreeBlockedReviewReportResult: handoff?.inputFreeBlockedReviewReportResult || '',
    inputFreeBlockedReviewReportGeneratedAt: handoff?.inputFreeBlockedReviewReportGeneratedAt || '',
    inputFreeBlockedReviewReportSelectedActionCount: Number(handoff?.inputFreeBlockedReviewReportSelectedActionCount || 0),
    inputFreeBlockedReviewReportPlannedCount: Number(handoff?.inputFreeBlockedReviewReportPlannedCount || 0),
    inputFreeBlockedReviewReportBlockedCount: Number(handoff?.inputFreeBlockedReviewReportBlockedCount || 0),
    inputFreeBlockedReviewReportFailedCount: Number(handoff?.inputFreeBlockedReviewReportFailedCount || 0),
    inputFreeBlockedReviewReportExecutedCount: Number(handoff?.inputFreeBlockedReviewReportExecutedCount || 0),
    inputFreeBlockedReviewReportActionOrders: Array.isArray(handoff?.inputFreeBlockedReviewReportActionOrders) ? handoff.inputFreeBlockedReviewReportActionOrders : [],
    inputFreeBlockedReviewReportStale: Boolean(handoff?.inputFreeBlockedReviewReportStale),
    inputFreeBlockedReviewReportScopeMismatch: Boolean(handoff?.inputFreeBlockedReviewReportScopeMismatch),
    inputFreeBlockedActions: Array.isArray(handoff?.inputFreeBlockedActions) ? handoff.inputFreeBlockedActions : [],
    operatorInputValuesProfileReportPath: handoff?.operatorInputValuesProfileReportPath || '',
    operatorInputValuesProfileExists: Boolean(handoff?.operatorInputValuesProfileExists),
    operatorInputValuesProfileResult: handoff?.operatorInputValuesProfileResult || '',
    operatorInputValuesProfileGeneratedAt: handoff?.operatorInputValuesProfileGeneratedAt || '',
    operatorInputValuesProfileDefaultsUsed: Boolean(handoff?.operatorInputValuesProfileDefaultsUsed),
    operatorInputValuesProfileDefaultsSkipped: Boolean(handoff?.operatorInputValuesProfileDefaultsSkipped),
    operatorInputValuesProfileDefaultsSkipReason: handoff?.operatorInputValuesProfileDefaultsSkipReason || '',
    operatorInputValuesProfileDefaultValueCount: Number(handoff?.operatorInputValuesProfileDefaultValueCount || 0),
    operatorInputValuesProfileFilledValueCount: Number(handoff?.operatorInputValuesProfileFilledValueCount || 0),
    operatorInputValuesProfileBlankValueCount: Number(handoff?.operatorInputValuesProfileBlankValueCount || 0),
    operatorInputValuesProfileCommand: handoff?.operatorInputValuesProfileCommand || '',
    operatorInputValuesCheckCommand: handoff?.operatorInputValuesCheckCommand || '',
    operatorInputValuesCheckResult: handoff?.operatorInputValuesCheckResult || '',
    operatorInputValuesCheckValueCount: Number(handoff?.operatorInputValuesCheckValueCount || 0),
    operatorInputValuesCheckReadyValueCount: Number(handoff?.operatorInputValuesCheckReadyValueCount || 0),
    operatorInputValuesCheckMissingValueCount: Number(handoff?.operatorInputValuesCheckMissingValueCount || 0),
    operatorInputValuesCheckUnsafeValueCount: Number(handoff?.operatorInputValuesCheckUnsafeValueCount || 0),
    operatorInputValuesCheckInvalidValueCount: Number(handoff?.operatorInputValuesCheckInvalidValueCount || 0),
    operatorInputValuesCheckValueReadyActionCount: Number(handoff?.operatorInputValuesCheckValueReadyActionCount || 0),
    operatorInputValuesCheckNonReadyActionCount: Number(handoff?.operatorInputValuesCheckNonReadyActionCount || 0),
    operatorInputValuesCheckActionSummaryCount: Number(handoff?.operatorInputValuesCheckActionSummaryCount || 0),
    operatorInputValuesCheckNonReadyActionOrders: Array.isArray(handoff?.operatorInputValuesCheckNonReadyActionOrders) ? handoff.operatorInputValuesCheckNonReadyActionOrders : [],
    operatorInputValuesCheckNonReadyActionSummaries: normalizeOperationsInputValueActionSummaries(handoff?.operatorInputValuesCheckNonReadyActionSummaries),
    artifactCollectionActionOrders: Array.isArray(handoff?.artifactCollectionActionOrders) ? handoff.artifactCollectionActionOrders : [],
    dispatchPreflightScopeMismatch: Boolean(handoff?.dispatchPreflightScopeMismatch),
    workflowRunIdPlanStale: Boolean(handoff?.workflowRunIdPlanStale),
    workflowRunIdPlanScopeMismatch: Boolean(handoff?.workflowRunIdPlanScopeMismatch),
    artifactCollectionStale: Boolean(handoff?.artifactCollectionStale),
    artifactCollectionScopeMismatch: Boolean(handoff?.artifactCollectionScopeMismatch),
    staleReportCount: Number(handoff?.staleReportCount || 0),
    readyDispatchWorkflows: Array.isArray(handoff?.readyDispatchWorkflows) ? handoff.readyDispatchWorkflows : [],
    blockedDispatchWorkflows: Array.isArray(handoff?.blockedDispatchWorkflows) ? handoff.blockedDispatchWorkflows : [],
    browserDispatchChecklistCount: Number(handoff?.browserDispatchChecklistCount || 0),
    browserDispatchChecklist: Array.isArray(handoff?.browserDispatchChecklist) ? handoff.browserDispatchChecklist : [],
    securityEvidenceFinalizerRunIdInputHintCount: Number(handoff?.securityEvidenceFinalizerRunIdInputHintCount || 0),
    securityEvidenceFinalizerRunIdInputHints: normalizeOperationsWorkflowRunIdInputs(handoff?.securityEvidenceFinalizerRunIdInputHints),
    dispatchWorkflows: Array.isArray(handoff?.dispatchWorkflows) ? handoff.dispatchWorkflows : [],
    blockedActionCount: Number(handoff?.blockedActionCount || 0),
    missingWorkflowRunCount: Number(handoff?.missingWorkflowRunCount || 0),
    missingRequiredArtifactCount: Number(handoff?.missingRequiredArtifactCount || 0),
    failedImportCount: Number(handoff?.failedImportCount || 0),
    finalizerFailedCount: Number(handoff?.finalizerFailedCount || 0),
    finalizerGapCount: Number(handoff?.finalizerGapCount || 0),
    postDispatchCommands: Array.isArray(handoff?.postDispatchCommands) ? handoff.postDispatchCommands : [],
    stages: Array.isArray(handoff?.stages) ? handoff.stages : [],
  }
}

function normalizeOperationsReadinessConvergence(report = {}) {
  const bottleneck = report?.currentBottleneck || {}
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    handoffReportPath: report?.handoffReportPath || '',
    readinessReportPath: report?.readinessReportPath || '',
    operationsReadinessFinalizeReportPath: report?.operationsReadinessFinalizeReportPath || '',
    handoffExists: Boolean(report?.handoffExists),
    handoffResult: report?.handoffResult || '',
    readinessExists: Boolean(report?.readinessExists),
    readinessResult: report?.readinessResult || '',
    readinessSummary: report?.readinessSummary || '',
    readinessPassedCount: Number(report?.readinessPassedCount || 0),
    readinessPendingCount: Number(report?.readinessPendingCount || 0),
    readinessTotalCount: Number(report?.readinessTotalCount || 0),
    readinessCheckCount: Number(report?.readinessCheckCount || 0),
    finalizerExists: Boolean(report?.finalizerExists),
    finalizerResult: report?.finalizerResult || '',
    finalizerReadinessResult: report?.finalizerReadinessResult || '',
    finalizerFailedCount: Number(report?.finalizerFailedCount || 0),
    finalizerFailedCountValid: typeof report?.finalizerFailedCountValid === 'boolean'
      ? report.finalizerFailedCountValid
      : null,
    finalizerFailedCountRaw: report?.finalizerFailedCountRaw || '',
    kubernetesOperationsReportSyncReportPath: report?.kubernetesOperationsReportSyncReportPath || '',
    kubernetesReportSyncExists: Boolean(report?.kubernetesReportSyncExists),
    kubernetesReportSyncResult: report?.kubernetesReportSyncResult || '',
    kubernetesReportSyncStale: Boolean(report?.kubernetesReportSyncStale),
    kubernetesReportSyncTimestamp: report?.kubernetesReportSyncTimestamp || '',
    kubernetesReportSyncTimestampSource: report?.kubernetesReportSyncTimestampSource || '',
    kubernetesReportSyncFreshnessReason: report?.kubernetesReportSyncFreshnessReason || '',
    kubernetesReportSyncFailedCount: Number(report?.kubernetesReportSyncFailedCount || 0),
    kubernetesReportSyncFailedCountValid: typeof report?.kubernetesReportSyncFailedCountValid === 'boolean'
      ? report.kubernetesReportSyncFailedCountValid
      : null,
    kubernetesReportSyncFailedCountRaw: report?.kubernetesReportSyncFailedCountRaw || '',
    kubernetesReportSyncConfigMapName: report?.kubernetesReportSyncConfigMapName || '',
    kubernetesReportSyncConfigMapKey: report?.kubernetesReportSyncConfigMapKey || '',
    kubernetesReportSyncSourceReportResult: report?.kubernetesReportSyncSourceReportResult || '',
    kubernetesReportSyncWorkflowCommand: report?.kubernetesReportSyncWorkflowCommand || '',
    kubernetesReportSyncWorkflowNote: report?.kubernetesReportSyncWorkflowNote || '',
    kubernetesReportSyncReady: Boolean(report?.kubernetesReportSyncReady),
    finalizerGapCount: Number(report?.finalizerGapCount || 0),
    stageCount: Number(report?.stageCount || 0),
    readyStageCount: Number(report?.readyStageCount || 0),
    blockedActionCount: Number(report?.blockedActionCount || 0),
    handoffRequiredGitHubSecretCount: Number(report?.handoffRequiredGitHubSecretCount || 0),
    handoffRequiredGitHubSecrets: Array.isArray(report?.handoffRequiredGitHubSecrets) ? report.handoffRequiredGitHubSecrets : [],
    handoffRequiredGitHubSecretSummaries: Array.isArray(report?.handoffRequiredGitHubSecretSummaries) ? report.handoffRequiredGitHubSecretSummaries : [],
    handoffWorkflowRunIdPlanQueryMode: report?.handoffWorkflowRunIdPlanQueryMode || '',
    handoffWorkflowRunIdPlanGithubApiTokenPresent: Boolean(report?.handoffWorkflowRunIdPlanGithubApiTokenPresent),
    handoffWorkflowRunIdPlanGithubApiUnauthenticated: Boolean(report?.handoffWorkflowRunIdPlanGithubApiUnauthenticated),
    handoffWorkflowRunIdPlanQueryExecuted: Boolean(report?.handoffWorkflowRunIdPlanQueryExecuted),
    handoffWorkflowRunIdPlanQueryExecutedCount: Number(report?.handoffWorkflowRunIdPlanQueryExecutedCount || 0),
    handoffWorkflowRunIdPlanQueryWorkflowCount: Number(report?.handoffWorkflowRunIdPlanQueryWorkflowCount || 0),
    handoffWorkflowRunIdPlanQuerySucceededCount: Number(report?.handoffWorkflowRunIdPlanQuerySucceededCount || 0),
    handoffWorkflowRunIdPlanQueryErrorCount: Number(report?.handoffWorkflowRunIdPlanQueryErrorCount || 0),
    handoffWorkflowRunIdPlanCandidateCount: Number(report?.handoffWorkflowRunIdPlanCandidateCount || 0),
    handoffInputFreeBlockedReviewReportExists: Boolean(report?.handoffInputFreeBlockedReviewReportExists),
    handoffInputFreeBlockedReviewReportResult: report?.handoffInputFreeBlockedReviewReportResult || '',
    handoffInputFreeBlockedReviewReportGeneratedAt: report?.handoffInputFreeBlockedReviewReportGeneratedAt || '',
    handoffInputFreeBlockedReviewReportSelectedActionCount: Number(report?.handoffInputFreeBlockedReviewReportSelectedActionCount || 0),
    handoffInputFreeBlockedReviewReportPlannedCount: Number(report?.handoffInputFreeBlockedReviewReportPlannedCount || 0),
    handoffInputFreeBlockedReviewReportBlockedCount: Number(report?.handoffInputFreeBlockedReviewReportBlockedCount || 0),
    handoffInputFreeBlockedReviewReportFailedCount: Number(report?.handoffInputFreeBlockedReviewReportFailedCount || 0),
    handoffInputFreeBlockedReviewReportExecutedCount: Number(report?.handoffInputFreeBlockedReviewReportExecutedCount || 0),
    handoffInputFreeBlockedReviewReportActionOrders: Array.isArray(report?.handoffInputFreeBlockedReviewReportActionOrders) ? report.handoffInputFreeBlockedReviewReportActionOrders : [],
    handoffInputFreeBlockedReviewReportStale: Boolean(report?.handoffInputFreeBlockedReviewReportStale),
    handoffInputFreeBlockedReviewReportScopeMismatch: Boolean(report?.handoffInputFreeBlockedReviewReportScopeMismatch),
    handoffOperatorInputValuesProfileReportPath: report?.handoffOperatorInputValuesProfileReportPath || '',
    handoffOperatorInputValuesProfileExists: Boolean(report?.handoffOperatorInputValuesProfileExists),
    handoffOperatorInputValuesProfileResult: report?.handoffOperatorInputValuesProfileResult || '',
    handoffOperatorInputValuesProfileGeneratedAt: report?.handoffOperatorInputValuesProfileGeneratedAt || '',
    handoffOperatorInputValuesProfileDefaultsUsed: Boolean(report?.handoffOperatorInputValuesProfileDefaultsUsed),
    handoffOperatorInputValuesProfileDefaultsSkipped: Boolean(report?.handoffOperatorInputValuesProfileDefaultsSkipped),
    handoffOperatorInputValuesProfileDefaultsSkipReason: report?.handoffOperatorInputValuesProfileDefaultsSkipReason || '',
    handoffOperatorInputValuesProfileDefaultValueCount: Number(report?.handoffOperatorInputValuesProfileDefaultValueCount || 0),
    handoffOperatorInputValuesProfileFilledValueCount: Number(report?.handoffOperatorInputValuesProfileFilledValueCount || 0),
    handoffOperatorInputValuesProfileBlankValueCount: Number(report?.handoffOperatorInputValuesProfileBlankValueCount || 0),
    handoffOperatorInputValuesCheckResult: report?.handoffOperatorInputValuesCheckResult || '',
    handoffOperatorInputValuesCheckValueCount: Number(report?.handoffOperatorInputValuesCheckValueCount || 0),
    handoffOperatorInputValuesCheckReadyValueCount: Number(report?.handoffOperatorInputValuesCheckReadyValueCount || 0),
    handoffOperatorInputValuesCheckMissingValueCount: Number(report?.handoffOperatorInputValuesCheckMissingValueCount || 0),
    handoffOperatorInputValuesCheckUnsafeValueCount: Number(report?.handoffOperatorInputValuesCheckUnsafeValueCount || 0),
    handoffOperatorInputValuesCheckInvalidValueCount: Number(report?.handoffOperatorInputValuesCheckInvalidValueCount || 0),
    handoffOperatorInputValuesCheckValueReadyActionCount: Number(report?.handoffOperatorInputValuesCheckValueReadyActionCount || 0),
    handoffOperatorInputValuesCheckNonReadyActionCount: Number(report?.handoffOperatorInputValuesCheckNonReadyActionCount || 0),
    handoffOperatorInputValuesCheckActionSummaryCount: Number(report?.handoffOperatorInputValuesCheckActionSummaryCount || 0),
    handoffOperatorInputValuesCheckNonReadyActionOrders: Array.isArray(report?.handoffOperatorInputValuesCheckNonReadyActionOrders) ? report.handoffOperatorInputValuesCheckNonReadyActionOrders : [],
    handoffOperatorInputValuesCheckNonReadyActionSummaries: normalizeOperationsInputValueActionSummaries(report?.handoffOperatorInputValuesCheckNonReadyActionSummaries),
    missingWorkflowRunCount: Number(report?.missingWorkflowRunCount || 0),
    missingRequiredArtifactCount: Number(report?.missingRequiredArtifactCount || 0),
    failedImportCount: Number(report?.failedImportCount || 0),
    currentBottleneck: {
      code: bottleneck.code || '',
      title: bottleneck.title || '',
      reason: bottleneck.reason || '',
      command: bottleneck.command || '',
      note: bottleneck.note || '',
      dispatchUrls: Array.isArray(bottleneck.dispatchUrls) ? bottleneck.dispatchUrls : [],
    },
    handoffStale: Boolean(report?.handoffStale),
    handoffTimestamp: report?.handoffTimestamp || '',
    handoffTimestampSource: report?.handoffTimestampSource || '',
    readinessTimestamp: report?.readinessTimestamp || '',
    readinessTimestampSource: report?.readinessTimestampSource || '',
    handoffPostDispatchCommands: Array.isArray(report?.handoffPostDispatchCommands) ? report.handoffPostDispatchCommands : [],
    handoffBrowserDispatchDependencyNotes: Array.isArray(report?.handoffBrowserDispatchDependencyNotes) ? report.handoffBrowserDispatchDependencyNotes : [],
    handoffSecurityEvidenceFinalizerRunIdInputHintCount: Number(report?.handoffSecurityEvidenceFinalizerRunIdInputHintCount || 0),
    handoffSecurityEvidenceFinalizerRunIdInputHints: normalizeOperationsWorkflowRunIdInputs(report?.handoffSecurityEvidenceFinalizerRunIdInputHints),
    recommendedCommands: Array.isArray(report?.recommendedCommands) ? report.recommendedCommands : [],
    decisionRule: report?.decisionRule || '',
    safetyPolicy: report?.safetyPolicy || '',
  }
}

function normalizeKubernetesOperationsReportSync(report = {}) {
  return {
    result: report?.result || '',
    generatedAt: report?.generatedAt || '',
    namespace: report?.namespace || '',
    configMapName: report?.configMapName || '',
    configMapKey: report?.configMapKey || '',
    evidenceConfigMapKey: report?.evidenceConfigMapKey || '',
    dataFlowStoragePlanConfigMapKey: report?.dataFlowStoragePlanConfigMapKey || '',
    dataFlowStorageTransitionRunbookConfigMapKey: report?.dataFlowStorageTransitionRunbookConfigMapKey || '',
    dataFlowQueryRetentionBudgetConfigMapKey: report?.dataFlowQueryRetentionBudgetConfigMapKey || '',
    publishDataFlowStoragePlanToConfigMap: Boolean(report?.publishDataFlowStoragePlanToConfigMap),
    publishDataFlowQueryRetentionBudgetToConfigMap: Boolean(report?.publishDataFlowQueryRetentionBudgetToConfigMap),
    publishDataFlowStorageTransitionRunbookToConfigMap: Boolean(report?.publishDataFlowStorageTransitionRunbookToConfigMap),
    sourceReportPath: report?.sourceReportPath || '',
    sourceReportFormatVersion: report?.sourceReportFormatVersion || '',
    sourceReportResult: report?.sourceReportResult || '',
    sourceReportBytes: Number(report?.sourceReportBytes || 0),
    sourceReportSha256: report?.sourceReportSha256 || '',
    dataFlowStorageTransitionRunbookResult: report?.dataFlowStorageTransitionRunbookResult || '',
    dataFlowStorageTransitionRunbookStoragePlanResult: report?.dataFlowStorageTransitionRunbookStoragePlanResult || '',
    dataFlowStorageTransitionRunbookCandidateStore: report?.dataFlowStorageTransitionRunbookCandidateStore || '',
    dataFlowQueryRetentionBudgetResult: report?.dataFlowQueryRetentionBudgetResult || '',
    dataFlowQueryRetentionBudgetStoragePlanResult: report?.dataFlowQueryRetentionBudgetStoragePlanResult || '',
    dataFlowQueryRetentionBudgetCandidateStore: report?.dataFlowQueryRetentionBudgetCandidateStore || '',
    dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs: Number(report?.dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs || 0),
    dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs: Number(report?.dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs || 0),
    dataFlowQueryRetentionBudgetRetentionBudgetSeconds: Number(report?.dataFlowQueryRetentionBudgetRetentionBudgetSeconds || 0),
    dataFlowQueryRetentionBudgetFailureCount: Number(report?.dataFlowQueryRetentionBudgetFailureCount || 0),
    dataFlowQueryRetentionBudgetCheckCount: Number(report?.dataFlowQueryRetentionBudgetCheckCount || 0),
    dataFlowStorageTransitionRunbookFailureCount: Number(report?.dataFlowStorageTransitionRunbookFailureCount || 0),
    dataFlowStorageTransitionRunbookCheckCount: Number(report?.dataFlowStorageTransitionRunbookCheckCount || 0),
    dataFlowStorageTransitionRunbookBytes: Number(report?.dataFlowStorageTransitionRunbookBytes || 0),
    dataFlowStorageTransitionRunbookSha256: report?.dataFlowStorageTransitionRunbookSha256 || '',
    clientDryRunCommand: report?.clientDryRunCommand || '',
    serverDryRunCommand: report?.serverDryRunCommand || '',
    applyCommand: report?.applyCommand || '',
    checkCount: Number(report?.checkCount || 0),
    failedCount: Number(report?.failedCount || 0),
    checks: Array.isArray(report?.checks) ? report.checks : [],
    safetyPolicy: report?.safetyPolicy || '',
  }
}

async function loadQuotaPolicies() {
  const [policyResult, historyResult] = await Promise.all([
    safeRequest(() => getQuotaPolicies(), { items: [] }),
    safeRequest(() => getQuotaPolicyHistory(50), { items: [] }),
  ])
  quotaPolicies.value = policyResult.items || []
  quotaPolicyHistory.value = historyResult.items || []
}

async function loadStorageExpansionRequests() {
  const result = await safeRequest(() => getStorageExpansionRequests(), { items: [] })
  storageExpansionRequests.value = result.items || []
}

async function loadStorageExpansionSummary() {
  const result = await safeRequest(() => getStorageExpansionSummary(), { data: null })
  if (result?.data) {
    applyStorageExpansionSummary(result.data)
  }
}

async function loadStorageExpansionRunnerPreflight() {
  const result = await safeRequest(() => getStorageExpansionRunnerPreflight(), { data: null })
  if (result?.data) {
    applyStorageExpansionRunnerPreflight(result.data)
  }
}

async function handleSaveQuotaPolicy() {
  if (!quotaPolicyForm.targetId) {
    setErrorMessage('쿼터 대상이 필요합니다.')
    return
  }
  const quotaBytes = Number(quotaPolicyForm.quotaGb || 1) * BYTES_PER_GIB
  const result = await runAction(() => saveQuotaPolicy(quotaPolicyForm.targetType, quotaPolicyForm.targetId, quotaBytes, quotaPolicyForm.reason))
  if (result) {
    resetQuotaPolicyForm()
    await loadQuotaPolicies()
    await loadDashboard()
    setStatusMessage('쿼터 정책 저장 완료')
  }
}

function editQuotaPolicy(policy) {
  quotaPolicyForm.targetType = policy.targetType
  quotaPolicyForm.targetId = String(policy.targetId)
  quotaPolicyForm.quotaGb = Math.max(1, Math.round(Number(policy.quotaBytes || 0) / BYTES_PER_GIB))
  quotaPolicyForm.reason = 'quota update'
  quotaPolicyForm.editingKey = `${policy.targetType}-${policy.targetId}`
}

function handleDeleteQuotaPolicy(policy) {
  openConfirmDialog({
    title: '쿼터 정책 삭제',
    message: `${policy.targetType} #${policy.targetId} 쿼터 정책을 삭제합니다.`,
    confirmLabel: '삭제',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteQuotaPolicy(policy.targetType, policy.targetId, quotaPolicyForm.reason || 'policy cleanup')))
      if (!result) return false
      await loadQuotaPolicies()
      setStatusMessage(`${policy.targetType} #${policy.targetId} 쿼터 정책 삭제 완료`)
      return true
    },
  })
}

function resetQuotaPolicyTarget() {
  quotaPolicyForm.targetId = ''
  quotaPolicyForm.targetSearch = ''
}

function resetQuotaPolicyForm() {
  quotaPolicyForm.targetType = 'USER'
  quotaPolicyForm.targetId = ''
  quotaPolicyForm.targetSearch = ''
  quotaPolicyForm.quotaGb = 100
  quotaPolicyForm.reason = ''
  quotaPolicyForm.editingKey = ''
}

async function handleCreateStorageExpansionRequest() {
  const requestedCapacityBytes = Number(storageExpansionForm.capacityGb || 1) * BYTES_PER_GIB
  const result = await runAction(() => createStorageExpansionRequest({
    requestedCapacityBytes,
    serverCount: Number(storageExpansionForm.serverCount || 4),
    volumesPerServer: Number(storageExpansionForm.volumesPerServer || 1),
    reason: storageExpansionForm.reason,
  }))
  if (!result?.data) return
  storageExpansionRequests.value = [
    result.data,
    ...storageExpansionRequests.value.filter((request) => request.id !== result.data.id),
  ]
  storageExpansionManifest.value = null
  storageExpansionExecutionPlan.value = null
  storageExpansionGitOpsPlan.value = null
  storageExpansionExecutions.value = []
  resetStorageExpansionExecutionForm()
  resetStorageExpansionForm()
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion request created: ${result.data.poolName}`)
}

async function handlePreviewStorageExpansionManifest(request) {
  if (!request?.id) return
  const result = await runAction(() => getStorageExpansionRequestManifest(request.id))
  if (!result?.data) return
  storageExpansionManifest.value = result.data
  setStatusMessage(`Storage expansion manifest preview: ${result.data.poolName}`)
}

async function handleDownloadStorageExpansionManifest(artifact) {
  if (!storageExpansionManifest.value?.requestId) return
  const value = ['tenant', 'helm', 'bundle'].includes(artifact) ? artifact : 'bundle'
  const content = await runAction(() => downloadStorageExpansionManifestArtifact(
    storageExpansionManifest.value.requestId,
    value,
  ))
  if (content === null || content === undefined) return
  const suffix = value === 'tenant' ? 'tenant' : value === 'helm' ? 'helm-values' : 'bundle'
  const filename = `osmu-storage-expansion-${storageExpansionManifest.value.poolName}-${suffix}.yaml`
  downloadBlob(new Blob([content], { type: 'application/x-yaml;charset=utf-8' }), filename)
  setStatusMessage(`Storage expansion manifest downloaded: ${filename}`)
}

async function handleCreateStorageExpansionExecutionPlan(request) {
  if (!request?.id) return
  const result = await runAction(() => createStorageExpansionExecutionPlan(request.id))
  if (!result?.data) return
  storageExpansionExecutionPlan.value = result.data
  storageExpansionApplyEvidence.value = result.data.evidenceTemplate || ''
  setStatusMessage(`Storage expansion dry-run ready: ${result.data.poolName}`)
}

async function handleCreateStorageExpansionGitOpsPlan(request) {
  if (!request?.id) return
  const result = await runAction(() => createStorageExpansionGitOpsPlan(request.id))
  if (!result?.data) return
  storageExpansionGitOpsPlan.value = result.data
  setStatusMessage(`Storage expansion GitOps draft ready: ${result.data.branchName}`)
}

async function handleRecordStorageExpansionDryRunExecution() {
  if (!storageExpansionExecutionPlan.value?.requestId) return
  const result = await runAction(() => recordStorageExpansionDryRunExecution(
    storageExpansionExecutionPlan.value.requestId,
    {
      executionType: storageExpansionExecutionForm.dryRunType,
      result: storageExpansionExecutionForm.dryRunResult,
      output: storageExpansionExecutionForm.dryRunOutput,
      externalUrl: storageExpansionExecutionForm.dryRunExternalUrl,
      notes: storageExpansionExecutionForm.dryRunNotes,
    },
  ))
  if (!result?.data) return
  storageExpansionExecutions.value = [
    result.data,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.id),
  ]
  storageExpansionExecutionForm.requestId = result.data.requestId
  storageExpansionExecutionForm.dryRunOutput = ''
  storageExpansionExecutionForm.dryRunExternalUrl = ''
  storageExpansionExecutionForm.dryRunNotes = ''
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion dry-run recorded: ${result.data.executionType} ${result.data.result}`)
}

async function handleRunStorageExpansionDryRunExecution() {
  if (!storageExpansionExecutionPlan.value?.requestId) return
  const result = await runAction(() => runStorageExpansionDryRunExecution(
    storageExpansionExecutionPlan.value.requestId,
    {
      executionType: storageExpansionExecutionForm.dryRunType,
    },
  ))
  if (!result?.data) return
  storageExpansionExecutions.value = [
    result.data,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.id),
  ]
  storageExpansionExecutionForm.requestId = result.data.requestId
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion dry-run runner: ${result.data.executionType} ${result.data.result}`)
}

async function handleRunStorageExpansionApplyExecution() {
  if (!storageExpansionExecutionPlan.value?.requestId) return
  const result = await runAction(() => runStorageExpansionApplyExecution(
    storageExpansionExecutionPlan.value.requestId,
    {
      applyType: storageExpansionExecutionForm.applyRunType,
    },
  ))
  if (!result?.data?.execution) return
  storageExpansionExecutions.value = [
    result.data.execution,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.execution.id),
  ]
  if (result.data.request) {
    storageExpansionRequests.value = storageExpansionRequests.value.map((request) => (
      request.id === result.data.request.id ? result.data.request : request
    ))
    if (result.data.request.status === 'APPLIED') {
      if (storageExpansionManifest.value?.requestId === result.data.request.id) {
        storageExpansionManifest.value = null
      }
      if (storageExpansionExecutionPlan.value?.requestId === result.data.request.id) {
        storageExpansionExecutionPlan.value = null
      }
      if (storageExpansionGitOpsPlan.value?.requestId === result.data.request.id) {
        storageExpansionGitOpsPlan.value = null
      }
      storageExpansionApplyEvidence.value = ''
    }
  }
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion apply runner: ${result.data.execution.result}`)
}

async function handleRunStorageExpansionRollbackExecution() {
  const requestId = Number(storageExpansionExecutionForm.requestId || 0)
  if (!requestId) return
  const payload = {
    rollbackType: storageExpansionExecutionForm.rollbackType,
    kubectlTarget: storageExpansionExecutionForm.rollbackKubectlTarget,
  }
  const revision = Number(storageExpansionExecutionForm.rollbackHelmRevision || 0)
  if (revision > 0) {
    payload.helmRevision = revision
  }
  const result = await runAction(() => runStorageExpansionRollbackExecution(requestId, payload))
  if (!result?.data?.execution) return
  storageExpansionExecutions.value = [
    result.data.execution,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.execution.id),
  ]
  if (result.data.request) {
    storageExpansionRequests.value = storageExpansionRequests.value.map((request) => (
      request.id === result.data.request.id ? result.data.request : request
    ))
  }
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion rollback runner: ${result.data.execution.result}`)
}

async function handleRunStorageExpansionGitOpsPrExecution() {
  if (!storageExpansionGitOpsPlan.value?.requestId) return
  const result = await runAction(() => runStorageExpansionGitOpsPrExecution(storageExpansionGitOpsPlan.value.requestId))
  if (!result?.data) return
  storageExpansionExecutions.value = [
    result.data,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.id),
  ]
  storageExpansionExecutionForm.requestId = result.data.requestId
  if (result.data.externalUrl) {
    storageExpansionExecutionForm.gitOpsPrUrl = result.data.externalUrl
  }
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion GitOps PR runner: ${result.data.result}`)
}

async function handleRecordStorageExpansionGitOpsPrExecution() {
  if (!storageExpansionGitOpsPlan.value?.requestId) return
  const result = await runAction(() => recordStorageExpansionGitOpsPrExecution(
    storageExpansionGitOpsPlan.value.requestId,
    {
      externalUrl: storageExpansionExecutionForm.gitOpsPrUrl,
      mergeSha: storageExpansionExecutionForm.gitOpsMergeSha,
      pipelineUrl: storageExpansionExecutionForm.gitOpsPipelineUrl,
      notes: storageExpansionExecutionForm.gitOpsNotes,
    },
  ))
  if (!result?.data) return
  storageExpansionExecutions.value = [
    result.data,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.id),
  ]
  storageExpansionExecutionForm.requestId = result.data.requestId
  storageExpansionExecutionForm.gitOpsPrUrl = ''
  storageExpansionExecutionForm.gitOpsMergeSha = ''
  storageExpansionExecutionForm.gitOpsPipelineUrl = ''
  storageExpansionExecutionForm.gitOpsNotes = ''
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion GitOps PR recorded: ${result.data.externalUrl}`)
}

async function handleDownloadStorageExpansionGitOpsBundle() {
  if (!storageExpansionGitOpsPlan.value?.requestId) return
  const blob = await runAction(() => downloadStorageExpansionGitOpsArtifactBundle(storageExpansionGitOpsPlan.value.requestId))
  if (!blob) return
  const filename = `osmu-storage-expansion-${storageExpansionGitOpsPlan.value.poolName}-gitops.zip`
  downloadBlob(blob, filename)
  setStatusMessage(`Storage expansion GitOps bundle downloaded: ${filename}`)
}

async function handleLoadStorageExpansionExecutions(request) {
  if (!request?.id) return
  storageExpansionExecutionForm.requestId = request.id
  const result = await runAction(() => getStorageExpansionExecutions(request.id))
  if (!result) return
  storageExpansionExecutions.value = result.items || []
  setStatusMessage(`Storage expansion execution history loaded: ${request.poolName}`)
}

async function handleCreateStorageExpansionExecutionRecord() {
  const requestId = Number(storageExpansionExecutionForm.requestId || 0)
  if (!requestId) return
  const result = await runAction(() => createStorageExpansionExecutionRecord(requestId, {
    executionType: storageExpansionExecutionForm.executionType,
    result: storageExpansionExecutionForm.result,
    command: storageExpansionExecutionForm.command,
    output: storageExpansionExecutionForm.output,
    externalUrl: storageExpansionExecutionForm.externalUrl,
    artifactSha256: storageExpansionExecutionForm.artifactSha256,
    notes: storageExpansionExecutionForm.notes,
  }))
  if (!result?.data) return
  storageExpansionExecutions.value = [
    result.data,
    ...storageExpansionExecutions.value.filter((execution) => execution.id !== result.data.id),
  ]
  const previousRequestId = storageExpansionExecutionForm.requestId
  resetStorageExpansionExecutionForm()
  storageExpansionExecutionForm.requestId = previousRequestId
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion execution recorded: ${result.data.executionType} ${result.data.result}`)
}

async function handleApplyStorageExpansionFromExecution(execution) {
  if (!execution?.requestId || !execution.id) return
  const result = await runAction(() => applyStorageExpansionExecutionRecord(execution.requestId, execution.id))
  if (!result?.data) return
  storageExpansionRequests.value = storageExpansionRequests.value.map((request) => (
    request.id === result.data.id ? result.data : request
  ))
  if (storageExpansionManifest.value?.requestId === result.data.id) {
    storageExpansionManifest.value = null
  }
  if (storageExpansionExecutionPlan.value?.requestId === result.data.id) {
    storageExpansionExecutionPlan.value = null
  }
  if (storageExpansionGitOpsPlan.value?.requestId === result.data.id) {
    storageExpansionGitOpsPlan.value = null
  }
  storageExpansionApplyEvidence.value = ''
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion applied from execution: ${result.data.poolName}`)
}

async function handleUpdateStorageExpansionStatus(payload) {
  if (!payload?.request?.id || !payload.status) return
  const result = await runAction(() => updateStorageExpansionRequestStatus(
    payload.request.id,
    payload.status,
    payload.appliedEvidence || '',
  ))
  if (!result?.data) return
  storageExpansionRequests.value = storageExpansionRequests.value.map((request) => (
    request.id === result.data.id ? result.data : request
  ))
  if (storageExpansionManifest.value?.requestId === result.data.id) {
    storageExpansionManifest.value = null
  }
  if (storageExpansionExecutionPlan.value?.requestId === result.data.id) {
    storageExpansionExecutionPlan.value = null
  }
  if (storageExpansionGitOpsPlan.value?.requestId === result.data.id) {
    storageExpansionGitOpsPlan.value = null
  }
  if (result.data.status === 'APPLIED') {
    storageExpansionApplyEvidence.value = ''
  }
  await loadStorageExpansionSummary()
  setStatusMessage(`Storage expansion status updated: ${result.data.poolName} ${result.data.status}`)
}

function resetStorageExpansionForm() {
  storageExpansionForm.capacityGb = 1024
  storageExpansionForm.serverCount = 4
  storageExpansionForm.volumesPerServer = 1
  storageExpansionForm.reason = ''
}

function resetStorageExpansionExecutionForm() {
  storageExpansionExecutionForm.requestId = ''
  storageExpansionExecutionForm.executionType = 'HELM_DIFF'
  storageExpansionExecutionForm.result = 'SUCCESS'
  storageExpansionExecutionForm.command = ''
  storageExpansionExecutionForm.output = ''
  storageExpansionExecutionForm.externalUrl = ''
  storageExpansionExecutionForm.artifactSha256 = ''
  storageExpansionExecutionForm.notes = ''
  storageExpansionExecutionForm.dryRunType = 'KUBECTL_DIFF'
  storageExpansionExecutionForm.dryRunResult = 'SUCCESS'
  storageExpansionExecutionForm.dryRunOutput = ''
  storageExpansionExecutionForm.dryRunExternalUrl = ''
  storageExpansionExecutionForm.dryRunNotes = ''
  storageExpansionExecutionForm.applyRunType = 'KUBECTL_APPLY'
  storageExpansionExecutionForm.gitOpsPrUrl = ''
  storageExpansionExecutionForm.gitOpsMergeSha = ''
  storageExpansionExecutionForm.gitOpsPipelineUrl = ''
  storageExpansionExecutionForm.gitOpsNotes = ''
  storageExpansionExecutionForm.rollbackType = 'HELM_ROLLBACK'
  storageExpansionExecutionForm.rollbackHelmRevision = ''
  storageExpansionExecutionForm.rollbackKubectlTarget = 'statefulset/osmu-minio'
}

async function refreshLifecycleRules() {
  const result = await safeRequest(() => getObjectLifecycleRules(), { data: [] })
  lifecycleRules.value = result.data || []
}

function resetLifecycleRuleForm() {
  lifecycleRuleForm.ruleId = ''
  lifecycleRuleForm.name = ''
  lifecycleRuleForm.enabled = true
  lifecycleRuleForm.priority = 100
  lifecycleRuleForm.bucketName = ''
  lifecycleRuleForm.targetType = 'OBJECT_VERSION'
  lifecycleRuleForm.prefix = ''
  lifecycleRuleForm.tags = ''
  lifecycleRuleForm.retentionDays = 30
  lifecycleRuleForm.batchSize = 100
  lifecycleRuleForm.pending = false
}

async function handleSaveObjectLifecycleRule() {
  lifecycleRuleForm.pending = true
  const payload = {
    ruleId: lifecycleRuleForm.ruleId || null,
    name: lifecycleRuleForm.name,
    enabled: lifecycleRuleForm.enabled,
    priority: Number(lifecycleRuleForm.priority || 100),
    bucketName: lifecycleRuleForm.bucketName,
    targetType: lifecycleRuleForm.targetType,
    prefix: lifecycleRuleForm.prefix,
    tags: lifecycleRuleForm.tags,
    retentionDays: Number(lifecycleRuleForm.retentionDays || 30),
    batchSize: Number(lifecycleRuleForm.batchSize || 100),
  }
  const result = await runAction(() => saveObjectLifecycleRule(payload))
  lifecycleRuleForm.pending = false
  if (result) {
    resetLifecycleRuleForm()
    await refreshLifecycleRules()
    await refreshLifecycleRuleConflicts()
    setStatusMessage(`${payload.name} lifecycle rule 저장 완료`)
  }
}

function editLifecycleRule(rule) {
  lifecycleRuleForm.ruleId = rule.ruleId
  lifecycleRuleForm.name = rule.name
  lifecycleRuleForm.enabled = Boolean(rule.enabled)
  lifecycleRuleForm.priority = rule.priority || 100
  lifecycleRuleForm.bucketName = rule.bucketName || ''
  lifecycleRuleForm.targetType = rule.targetType || 'OBJECT_VERSION'
  lifecycleRuleForm.prefix = rule.prefix || ''
  lifecycleRuleForm.tags = objectTagsToInput(rule.tags)
  lifecycleRuleForm.retentionDays = rule.retentionDays || 30
  lifecycleRuleForm.batchSize = rule.batchSize || 100
}

function handleDeleteObjectLifecycleRule(rule) {
  openConfirmDialog({
    title: 'Lifecycle rule 삭제',
    message: `${rule.name} rule을 삭제합니다.`,
    confirmLabel: 'Delete',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteObjectLifecycleRule(rule.ruleId)))
      if (!result) return false
      await refreshLifecycleRules()
      await refreshLifecycleRuleConflicts()
      setStatusMessage(`${rule.name} lifecycle rule 삭제 완료`)
      return true
    },
  })
}

async function handleDryRunObjectLifecycleRule(rule) {
  lifecycleRulePreview.pendingRuleId = rule.ruleId
  const result = await runAction(() => dryRunObjectLifecycleRule(rule.ruleId, 25))
  lifecycleRulePreview.pendingRuleId = ''
  if (result?.data) {
    Object.assign(lifecycleRulePreview, {
      ruleId: rule.ruleId,
      ruleName: rule.name,
      targetType: result.data.targetType || rule.targetType,
      candidateCount: result.data.candidateCount || 0,
      candidateBytes: result.data.candidateBytes || 0,
      cutoff: result.data.cutoff || '',
      truncated: Boolean(result.data.truncated),
      candidates: result.data.candidates || [],
      pendingRuleId: '',
    })
  }
}

async function refreshLifecycleRuleConflicts() {
  if (!isAdmin.value) return
  lifecycleRuleConflicts.pending = true
  const result = await safeRequest(() => getObjectLifecycleConflicts(), null)
  lifecycleRuleConflicts.pending = false
  if (result?.data) {
    applyLifecycleRuleConflicts(result.data)
  }
}

function applyLifecycleRuleConflicts(data) {
  lifecycleRuleConflicts.ruleCount = data.ruleCount || 0
  lifecycleRuleConflicts.conflictCount = data.conflictCount || 0
  lifecycleRuleConflicts.conflicts = data.conflicts || []
}

function resetLifecycleRuleConflicts() {
  lifecycleRuleConflicts.ruleCount = 0
  lifecycleRuleConflicts.conflictCount = 0
  lifecycleRuleConflicts.conflicts = []
  lifecycleRuleConflicts.pending = false
  lifecycleRulePreview.ruleId = ''
  lifecycleRulePreview.ruleName = ''
  lifecycleRulePreview.candidates = []
}

function normalizeDashboardPresetImportPayload(payload) {
  if (payload?.data?.preset) {
    return payload.data
  }
  return payload
}

function normalizeDashboardPresetBundleImportPayload(payload) {
  if (payload?.data?.presets) {
    return payload.data
  }
  return payload
}

function compareDashboardLayoutDefaults(left, right) {
  return `${left.targetType}:${left.targetId}`.localeCompare(`${right.targetType}:${right.targetId}`)
}

async function handleExportLifecycleXml() {
  lifecycleXml.pending = true
  const result = await runAction(() => getObjectLifecycleS3Xml())
  lifecycleXml.pending = false
  if (result?.data) {
    lifecycleXml.content = result.data.xml || ''
    setStatusMessage('Lifecycle XML export 완료')
  }
}

async function handleImportLifecycleXml() {
  lifecycleXml.pending = true
  const result = await runAction(() => importObjectLifecycleS3Xml(lifecycleXml.content))
  lifecycleXml.pending = false
  if (result?.data) {
    lifecycleXml.importedCount = result.data.importedCount ?? result.data.ruleCount ?? null
    await refreshLifecycleRules()
    await refreshLifecycleRuleConflicts()
    setStatusMessage(`Lifecycle XML import 완료: ${lifecycleXml.importedCount ?? 0} rules`)
  }
}

function resetLifecycleXml() {
  lifecycleXml.content = ''
  lifecycleXml.importedCount = null
  lifecycleXml.pending = false
}

async function handleRunObjectRetentionPurge() {
  retentionPolicy.pending = true
  const result = await runAction(() => runObjectRetentionPurge())
  retentionPolicy.pending = false
  if (result?.data) {
    retentionPolicy.lastPurgedCount = result.data.purgedCount ?? result.data.deletedCount ?? 0
    await loadRetentionStatus()
    await loadDashboard()
    setStatusMessage(`Retention purge 완료: ${retentionPolicy.lastPurgedCount} objects`)
  }
}

async function handleRunStorageExpansionExecutionLogRetention() {
  executionLogRetention.pending = true
  const result = await runAction(() => runStorageExpansionExecutionLogRetention())
  executionLogRetention.pending = false
  if (result?.data) {
    executionLogRetention.lastRedactedOutputCount = result.data.redactedOutputCount ?? 0
    if (result.data.status) {
      applyStorageExpansionExecutionLogRetentionStatus(result.data.status)
    } else {
      await loadStorageExpansionExecutionLogRetentionStatus()
    }
    setStatusMessage(`Execution log retention complete: ${executionLogRetention.lastRedactedOutputCount} outputs`)
  }
}

async function handleCreateOrganization() {
  const defaultQuotaBytes = Number(organizationForm.defaultQuotaTb || 1) * 1024 * BYTES_PER_GIB
  const result = await runAction(() => createOrganization({
    name: organizationForm.name,
    description: organizationForm.description,
    defaultQuotaBytes,
  }))
  if (result) {
    organizationForm.name = ''
    organizationForm.description = ''
    await loadDashboard()
    setStatusMessage(`${result.data?.name || organizationForm.name || '조직'} 생성 완료`)
  }
}

async function loadTeams() {
  if (!canUseAdminTools.value) {
    teams.value = []
    return
  }
  const result = await safeRequest(() => getTeams(), { items: [] })
  teams.value = result.items || []
  syncTeamFormDefaults()
}

async function handleCreateTeam() {
  if (!teamForm.organizationId || !teamForm.name) {
    setErrorMessage('조직과 팀 이름을 입력해야 합니다.')
    return
  }
  const memberIds = teamForm.memberIds
    .map((memberId) => Number(memberId))
    .filter((memberId) => Number.isFinite(memberId) && memberId > 0)
  const result = await runAction(() => createTeam({
    organizationId: Number(teamForm.organizationId),
    name: teamForm.name,
    description: teamForm.description,
    memberIds,
  }))
  if (result) {
    const createdName = result.data?.name || teamForm.name
    resetTeamForm()
    await loadTeams()
    setStatusMessage(`${createdName} 팀 생성 완료`)
  }
}

function handleDeleteTeam(team) {
  openConfirmDialog({
    title: '팀 삭제',
    message: `${team.name} 팀을 삭제하고 연결된 TEAM 버킷 권한을 정리합니다.`,
    confirmLabel: '삭제',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteTeam(team.id)))
      if (!result) return false
      await loadTeams()
      await loadBucketPermissions()
      setStatusMessage(`${team.name} 팀 삭제 완료`)
      return true
    },
  })
}

function resetTeamForm() {
  teamForm.name = ''
  teamForm.description = ''
  teamForm.memberIds = []
  syncTeamFormDefaults()
}

function syncTeamFormDefaults() {
  if (!teamForm.organizationId && organizations.value.length > 0) {
    teamForm.organizationId = String(organizations.value[0].id)
  }
}

async function handleCreateUser() {
  const result = await runAction(() => createUser({
    loginId: userForm.loginId,
    email: userForm.email,
    name: userForm.name,
    password: userForm.password,
    role: userForm.role,
    organizationId: userForm.organizationId ? Number(userForm.organizationId) : null,
  }))
  if (result) {
    userForm.loginId = ''
    userForm.email = ''
    userForm.name = ''
    userForm.password = ''
    userForm.organizationId = ''
    await loadDashboard()
    setStatusMessage(`${result.data?.loginId || userForm.loginId || '사용자'} 생성 완료`)
  }
}

async function handleToggleUserStatus(user) {
  const nextStatus = user.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
  if (nextStatus === 'INACTIVE') {
    openConfirmDialog({
      title: '사용자 비활성화',
      message: `${user.loginId} 사용자를 비활성화합니다. 연결된 Access Key도 사용할 수 없습니다.`,
      confirmLabel: '비활성화',
      action: () => applyUserStatus(user.id, nextStatus),
    })
    return
  }
  await applyUserStatus(user.id, nextStatus)
}

async function applyUserStatus(userId, nextStatus) {
  const result = await runAction(() => updateUserStatus(userId, nextStatus))
  if (!result) return false
  await loadDashboard()
  setStatusMessage(`사용자 상태 ${nextStatus} 변경 완료`)
  return true
}

async function handleLoadAuditLogs() {
  if (!canUseAuditTools.value) return
  const result = await safeRequest(() => getAuditLogs(auditFilterPayload()), { items: [], nextCursor: '' })
  auditLogs.value = result.items || []
  auditNextCursor.value = result.nextCursor || ''
}

async function handleLoadNextAuditLogs() {
  if (!auditNextCursor.value) return
  const result = await runAction(() => getAuditLogs(auditFilterPayload(auditNextCursor.value)))
  if (result) {
    auditLogs.value = [...auditLogs.value, ...result.items]
    auditNextCursor.value = result.nextCursor || ''
  }
}

async function handleResetAuditFilter() {
  auditFilter.eventType = ''
  auditFilter.actorId = ''
  auditFilter.requestId = ''
  auditFilter.targetType = ''
  auditFilter.targetId = ''
  auditFilter.result = ''
  auditFilter.from = ''
  auditFilter.to = ''
  auditFilter.limit = 50
  await handleLoadAuditLogs()
}

function handleExportAuditCsv() {
  const rows = [
    ['id', 'eventType', 'actorId', 'targetType', 'targetId', 'result', 'requestId'],
    ...auditLogs.value.map((entry) => [
      entry.id,
      entry.eventType,
      entry.actorId,
      entry.targetType,
      entry.targetId,
      entry.result,
      entry.requestId,
    ]),
  ]
  const csv = rows.map((row) => row.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')
  downloadBlob(new Blob([csv], { type: 'text/csv;charset=utf-8' }), 'osmu-audit.csv')
}

function openConfirmDialog({ title, message, confirmLabel, action }) {
  Object.assign(confirmDialog, { open: true, title, message, confirmLabel: confirmLabel || '확인', pending: false, action })
}

function closeConfirmDialog() {
  if (confirmDialog.pending) return
  Object.assign(confirmDialog, { open: false, title: '', message: '', confirmLabel: '확인', pending: false, action: null })
}

async function handleConfirmDialogAction() {
  if (!confirmDialog.action) {
    closeConfirmDialog()
    return
  }
  confirmDialog.pending = true
  const shouldClose = await confirmDialog.action()
  confirmDialog.pending = false
  if (shouldClose !== false) {
    closeConfirmDialog()
  }
}

async function runAction(action) {
  clearError()
  clearStatusMessage()
  actionPendingCount.value += 1
  try {
    return await action()
  } catch (error) {
    setError(error)
    return null
  } finally {
    actionPendingCount.value = Math.max(0, actionPendingCount.value - 1)
  }
}

async function runCommand(command) {
  await command()
  return true
}

function setError(error) {
  errorMessage.value = error?.message || '요청 처리 중 오류가 발생했습니다.'
  errorRequestId.value = error?.requestId || ''
  errorCode.value = error?.code || ''
  errorStatus.value = Number(error?.status || 0)
  clearStatusMessage()
}

function setErrorMessage(message) {
  errorMessage.value = message
  errorRequestId.value = ''
  errorCode.value = ''
  errorStatus.value = 0
  clearStatusMessage()
}

function clearError() {
  errorMessage.value = ''
  errorRequestId.value = ''
  errorCode.value = ''
  errorStatus.value = 0
}

async function handleAdminRemediationPrimary() {
  const action = adminActionRemediation.value?.action
  if (action === 'login') {
    handleSessionExpired()
    return
  }
  if (action === 'refresh') {
    await refreshAll()
  }
}

function setStatusMessage(message) {
  clearError()
  statusMessage.value = message
}

function clearStatusMessage() {
  statusMessage.value = ''
}

function applyHealthStatus(data) {
  health.backend = data.backend || data.status || 'DOWN'
  health.storage = data.storage || 'DOWN'
  health.database = data.database || 'DOWN'
  health.accessKeyProvisioner = data.accessKeyProvisioner || 'UNKNOWN'
  health.metadataEngine = data.metadataEngine || '-'
  health.storageEngine = data.storageEngine || '-'
}

function applyBackupStatus(data) {
  backupStatus.status = data.status || 'UNKNOWN'
  backupStatus.metadataStore = data.metadataStore || '-'
  backupStatus.objectStore = data.objectStore || '-'
  backupStatus.databaseHealthy = Boolean(data.databaseHealthy)
  backupStatus.storageHealthy = Boolean(data.storageHealthy)
  backupStatus.rpoTarget = data.rpoTarget || '-'
  backupStatus.rtoTarget = data.rtoTarget || '-'
  backupStatus.runbookAvailable = Boolean(data.runbookAvailable)
  backupStatus.restoreDrillExecuted = Boolean(data.restoreDrillExecuted)
  backupStatus.lastBackupAt = data.lastBackupAt || ''
  backupStatus.lastRestoreDrillAt = data.lastRestoreDrillAt || ''
  backupStatus.latestRestoreDrillEvidence = data.latestRestoreDrillEvidence || null
  backupStatus.pendingGates = data.pendingGates || []
}

function resetBackupStatus() {
  applyBackupStatus({ status: 'UNKNOWN', pendingGates: [] })
}

function applyRetentionStatus(data) {
  retentionPolicy.enabled = Boolean(data.enabled)
  retentionPolicy.retentionDays = data.retentionDays || 0
  retentionPolicy.batchSize = data.batchSize || 0
  retentionPolicy.purgedObjectCount = data.purgedObjectCount || 0
  retentionPolicy.failedObjectCount = data.failedObjectCount || 0
  retentionPolicy.failedRunCount = data.failedRunCount || 0
  retentionPolicy.lastPurgedCount = data.lastPurgedCount ?? retentionPolicy.lastPurgedCount
}

function applyStorageExpansionExecutionLogRetentionStatus(data) {
  executionLogRetention.enabled = Boolean(data.enabled)
  executionLogRetention.retentionDays = data.retentionDays || 0
  executionLogRetention.batchSize = data.batchSize || 0
  executionLogRetention.pendingOutputCount = data.pendingOutputCount || 0
  executionLogRetention.redactedOutputCount = data.redactedOutputCount || 0
  executionLogRetention.failedRunCount = data.failedRunCount || 0
}

function applyStorageExpansionSummary(data) {
  Object.assign(storageExpansionSummary, {
    requestCount: data.requestCount || 0,
    openRequestCount: data.openRequestCount || 0,
    plannedRequestCount: data.plannedRequestCount || 0,
    approvedRequestCount: data.approvedRequestCount || 0,
    appliedRequestCount: data.appliedRequestCount || 0,
    rejectedRequestCount: data.rejectedRequestCount || 0,
    totalRequestedCapacityBytes: data.totalRequestedCapacityBytes || 0,
    openRequestedCapacityBytes: data.openRequestedCapacityBytes || 0,
    totalEstimatedUsableCapacityBytes: data.totalEstimatedUsableCapacityBytes || 0,
    openEstimatedUsableCapacityBytes: data.openEstimatedUsableCapacityBytes || 0,
    executionCount: data.executionCount || 0,
    successExecutionCount: data.successExecutionCount || 0,
    failedExecutionCount: data.failedExecutionCount || 0,
    skippedExecutionCount: data.skippedExecutionCount || 0,
    timedOutExecutionCount: data.timedOutExecutionCount || 0,
    latestRequest: data.latestRequest || null,
    latestExecution: data.latestExecution || null,
    recentExecutions: Array.isArray(data.recentExecutions) ? data.recentExecutions : [],
  })
}

function applyStorageExpansionRunnerPreflight(data) {
  Object.assign(storageExpansionRunnerPreflight, {
    status: data.status || 'DISABLED',
    ready: Boolean(data.ready),
    enabledRunnerCount: data.enabledRunnerCount || 0,
    failedCheckCount: data.failedCheckCount || 0,
    checks: Array.isArray(data.checks) ? data.checks : [],
  })
}

function resetRetentionPolicy() {
  Object.assign(retentionPolicy, {
    enabled: false,
    retentionDays: 0,
    batchSize: 0,
    purgedObjectCount: 0,
    failedObjectCount: 0,
    failedRunCount: 0,
    lastPurgedCount: null,
    pending: false,
  })
}

function resetStorageExpansionExecutionLogRetention() {
  Object.assign(executionLogRetention, {
    enabled: false,
    retentionDays: 0,
    batchSize: 0,
    pendingOutputCount: 0,
    redactedOutputCount: 0,
    failedRunCount: 0,
    lastRedactedOutputCount: null,
    pending: false,
  })
}

function resetStorageExpansionSummary() {
  applyStorageExpansionSummary({})
}

function resetStorageExpansionRunnerPreflight() {
  applyStorageExpansionRunnerPreflight({})
}

function applyS3ClientConfig(data) {
  Object.assign(s3ClientConfig, {
    endpoint: data.endpoint || '',
    region: data.region || '',
    signatureVersion: data.signatureVersion || '',
    service: data.service || '',
    pathStyleSupported: data.pathStyleSupported !== false,
    virtualHostedStyleEnabled: Boolean(data.virtualHostedStyleEnabled),
    virtualHostedStyleDomainSuffixes: Array.isArray(data.virtualHostedStyleDomainSuffixes)
      ? data.virtualHostedStyleDomainSuffixes
      : [],
  })
}

function resetS3ClientConfig() {
  applyS3ClientConfig({})
}

function formatBytes(value) {
  const bytes = Number(value || 0)
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB', 'TB', 'PB']
  let size = bytes / 1024
  let unitIndex = 0
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024
    unitIndex += 1
  }
  return `${size.toFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}`
}

function formatOptionalBytes(value) {
  if (value === null || value === undefined) return '-'
  return formatBytes(value)
}

function formatCount(value) {
  const count = Number(value || 0)
  return Number.isInteger(count) ? String(count) : count.toFixed(1)
}

function quotaPolicyPercent(policy) {
  const quotaBytes = Number(policy?.quotaBytes || 0)
  if (quotaBytes <= 0) return 0
  return Math.min(100, Math.round((Number(policy?.usedBytes || 0) / quotaBytes) * 100))
}

function formatKeyScope(key) {
  if (key.bucketScopes?.length) {
    return key.bucketScopes.map((scope) => `${scope.bucketName}: ${scope.permissions?.join('+')}`).join(', ')
  }
  return `${key.allowedBuckets?.join(', ') || '-'} / ${key.permissions?.join(', ') || '-'}`
}

function formatObjectTags(tags) {
  if (!tags || Object.keys(tags).length === 0) return '-'
  return objectTagsToInput(tags)
}

function formatChecksumMap(checksums) {
  if (!checksums || Object.keys(checksums).length === 0) return '-'
  return Object.entries(checksums).map(([name, value]) => `${name}: ${value}`).join(', ')
}

function formatDateTime(value) {
  if (!value) return '-'
  return new Date(value).toLocaleString()
}

function formatMultipartResumeStatus(session) {
  const updatedAt = formatDateTime(session.updatedAt)
  if (session.expired) return `Expired / ${updatedAt}`
  if (session.expiresAt) return `Expires ${formatDateTime(session.expiresAt)} / ${updatedAt}`
  return updatedAt
}

function metadataStatusLabel(status) {
  if (status === 'SYNCED') return '동기화됨'
  if (status === 'STALE') return '불일치'
  if (status === 'MISSING_IN_STORAGE') return '스토리지 없음'
  return status || '-'
}

function metadataStatusClass(status) {
  if (status === 'SYNCED') return 'up'
  if (status === 'STALE') return 'mock'
  return 'down'
}

function statusClass(status) {
  const value = String(status || '').toUpperCase()
  if (['UP', 'READY', 'HEALTHY', 'OK', 'ON', 'ACTIVE', 'COMPLETED', 'SUCCESS', 'RECORDED'].includes(value)) return 'up'
  if (['MOCK', 'UNKNOWN', 'DEGRADED', 'PENDING', 'DRILL_PENDING', 'REVIEW', 'PARTIAL', 'MISSING'].includes(value)) return 'mock'
  return 'down'
}

function validateTagInput(tags) {
  return validateObjectTagInput(tags)
}

function objectTagsToInput(tags) {
  return tagsToInput(tags)
}

function objectKeyParts(key) {
  return splitObjectKeyBySearch(key, objectSearch.value)
}

function mergePermissions(current, next) {
  const values = new Set([...(current ?? []), ...(next ?? [])])
  return ['READ', 'WRITE', 'DELETE', 'ADMIN'].filter((permission) => values.has(permission))
}

function auditFilterPayload(cursor = '') {
  return {
    eventType: auditFilter.eventType.trim(),
    actorId: auditFilter.actorId.trim(),
    requestId: auditFilter.requestId.trim(),
    targetType: auditFilter.targetType.trim(),
    targetId: auditFilter.targetId.trim(),
    result: auditFilter.result,
    cursor,
    from: localDateTimeToIso(auditFilter.from),
    to: localDateTimeToIso(auditFilter.to),
    limit: auditFilter.limit || 50,
  }
}

function updateDataFlowFilter(field, value) {
  if (Object.prototype.hasOwnProperty.call(dataFlowFilter, field)) {
    dataFlowFilter[field] = value
  }
}

function handleResetDataFlowFilter() {
  dataFlowFilter.from = ''
  dataFlowFilter.to = ''
  dataFlowFilter.bucketName = ''
  dataFlowFilter.actorId = ''
  dataFlowFilter.source = ''
  dataFlowFilter.operation = ''
  dataFlowFilter.status = ''
  dataFlowFilter.limit = 50
  dataFlowFilter.months = 12
  dataFlowFilter.monthlyMaterialized = false
  loadDataFlowMonitoring()
}

function updateChargebackOption(event) {
  const field = event?.field
  if (!Object.prototype.hasOwnProperty.call(chargebackOptions, field)) return
  chargebackOptions[field] = field === 'eventScanLimit'
    ? normalizedChargebackNumber(event.value, defaultChargebackOptions.eventScanLimit)
    : event.value
}

function resetChargebackOptions() {
  syncChargebackOptionsFromPolicy()
}

async function handleResetChargebackOptions() {
  resetChargebackOptions()
  await loadChargebackPanel()
}

function dataFlowFilterPayload() {
  return {
    bucketName: dataFlowFilter.bucketName.trim(),
    actorId: dataFlowFilter.actorId.trim(),
    source: dataFlowFilter.source,
    operation: dataFlowFilter.operation,
    status: dataFlowFilter.status,
    from: localDateTimeToIso(dataFlowFilter.from),
    to: localDateTimeToIso(dataFlowFilter.to),
    limit: dataFlowFilter.limit || 50,
    months: dataFlowFilter.months || 12,
    materialized: dataFlowFilter.monthlyMaterialized,
  }
}

function chargebackPreviewPayload() {
  const payload = {
    from: localDateTimeToIso(chargebackOptions.from),
    to: localDateTimeToIso(chargebackOptions.to),
    currency: String(chargebackOptions.currency || '').trim(),
    eventScanLimit: normalizedChargebackNumber(chargebackOptions.eventScanLimit, defaultChargebackOptions.eventScanLimit),
    notificationChannel: String(chargebackOptions.notificationChannel || '').trim(),
    notificationTarget: String(chargebackOptions.notificationTarget || '').trim(),
  }
  for (const field of chargebackRateFields) {
    payload[field] = normalizedChargebackNumber(chargebackOptions[field], '')
  }
  return payload
}

function billingPricingPolicyPayload() {
  return {
    currency: String(chargebackOptions.currency || '').trim(),
    storageGbMonthRate: normalizedChargebackNumber(chargebackOptions.storageGbMonthRate, 0),
    ingressGbRate: normalizedChargebackNumber(chargebackOptions.ingressGbRate, 0),
    egressGbRate: normalizedChargebackNumber(chargebackOptions.egressGbRate, 0),
    internalGbRate: normalizedChargebackNumber(chargebackOptions.internalGbRate, 0),
    operationThousandRate: normalizedChargebackNumber(chargebackOptions.operationThousandRate, 0),
    warningAmount: normalizedChargebackNumber(chargebackOptions.warningAmount, 0),
    criticalAmount: normalizedChargebackNumber(chargebackOptions.criticalAmount, 0),
    eventScanLimit: normalizedChargebackNumber(chargebackOptions.eventScanLimit, defaultChargebackOptions.eventScanLimit),
    reason: 'Admin billing panel policy update',
  }
}

function normalizedChargebackNumber(value, fallback) {
  if (value === '' || value === null || value === undefined) return fallback
  const number = Number(value)
  return Number.isFinite(number) ? number : fallback
}

function localDateTimeToIso(value) {
  return value ? new Date(value).toISOString() : ''
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
</script>
