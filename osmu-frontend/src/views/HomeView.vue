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
        :backup-status="backupStatus"
        :upload-state="uploadState"
        :data-flow-monitoring="dataFlowMonitoring"
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
        @retry-upload="handleRetryUpload"
        @resume-matching-multipart-upload="handleResumeMatchingMultipartUpload"
        @discard-multipart-resume="handleDiscardMultipartResume"
        @update-object-tags="handleUpdateObjectTags"
        @reset-object-tag-form="handleResetObjectTagForm"
        @open-object-prefix="handleOpenObjectPrefix"
        @download-object="handleDownloadObject"
        @create-presigned-download-url="handleCreatePresignedDownloadUrl"
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
        :selected-bucket="selectedBucket"
        :can-show-bucket-permissions="canShowBucketPermissions"
        :bucket-permission-form="bucketPermissionForm"
        :users="users"
        :organizations="organizations"
        :bucket-permissions="bucketPermissions"
        :can-use-bucket-lifecycle="canUseBucketLifecycle"
        :bucket-lifecycle-xml="bucketLifecycleXml"
        :can-use-bucket-tags="canUseBucketTags"
        :bucket-tags="bucketTags"
        :is-admin="isAdmin"
        :object-share-policy-form="objectSharePolicyForm"
        :object-share-analytics="objectShareAnalytics"
        :object-share-analytics-filter="objectShareAnalyticsFilter"
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
  applyStorageExpansionExecutionRecord,
  applyStorageProfileRequest,
  applyDashboardLayoutPreset,
  bulkDisableAccessKeys,
  cleanupObjectShareLinks,
  completePresignedUpload,
  createAccessKey,
  createBucket,
  createDashboardLayoutPreset,
  createObjectShareLink,
  createOrganization,
  createPresignedDownloadUrl,
  createPresignedUploadUrl,
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
  deleteQuotaPolicy,
  deleteStoredMultipartUploadSession,
  downloadStorageExpansionGitOpsArtifactBundle,
  downloadStorageExpansionManifestArtifact,
  downloadObject,
  downloadObjectVersion,
  downloadDataFlowMonitoringCsv,
  dryRunObjectLifecycleRule,
  exportDashboardLayoutPreset,
  exportDashboardLayoutPresetBundle,
  getAccessKeys,
  getAuditLogs,
  getBackupStatus,
  getBucketLifecycleS3Xml,
  getBucketPermissions,
  getBucketStorageProfile,
  getBucketTags,
  getBuckets,
  getDatabaseHealth,
  getDashboardLayout,
  getDashboardLayoutDefaults,
  getDashboardLayoutPresets,
  getDashboardReadiness,
  getDashboardSummary,
  getDashboardWidgetCatalog,
  getDataFlowMonitoring,
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
  getStorageHealth,
  getStorageExpansionExecutionLogRetentionStatus,
  getStorageExpansionRequestManifest,
  getStorageExpansionExecutions,
  getStorageExpansionRequests,
  getStorageExpansionRunnerPreflight,
  getStorageExpansionSummary,
  getStorageProfiles,
  getStorageProfileRequests,
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
  purgeObject,
  putBucketLifecycleS3Xml,
  putBucketTags,
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
  runStorageExpansionGitOpsPrExecution,
  runObjectRetentionPurge,
  saveDashboardLayoutDefault,
  saveObjectLifecycleRule,
  saveObjectSharePolicy,
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
  { page: 'dashboard', to: '/dashboard', label: 'Dashboard', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'storage', to: '/storage', label: 'Storage', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'objects', to: '/objects', label: 'Objects', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'developer', to: '/developer', label: 'Developer', roles: ['ADMIN', 'ORG_ADMIN', 'USER'] },
  { page: 'admin', to: '/admin', label: 'Admin', roles: ['ADMIN', 'ORG_ADMIN'] },
  { page: 'audit', to: '/audit', label: 'Audit', roles: ['ADMIN'] },
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
  { id: 'requests', title: '요청/감사 현황', description: '최근 감사 이벤트', category: 'AUDIT', adminOnly: true },
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

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const session = auth.state
const isLoggedIn = auth.isLoggedIn
const isAdmin = auth.isAdmin
const isOrgAdmin = auth.isOrgAdmin
const canUseAdminTools = auth.canUseAdminTools

const health = reactive({
  backend: 'DOWN',
  storage: 'DOWN',
  database: 'DOWN',
  accessKeyProvisioner: 'UNKNOWN',
  metadataEngine: '-',
  storageEngine: '-',
})
const usage = reactive({ totalQuotaBytes: 0, usedBytes: 0, remainingBytes: 0, bucketCount: 0, objectCount: 0 })
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
  operationsEvidencePlan: {
    result: '',
    sourceSummary: '',
    sourceReport: '',
    pendingCount: 0,
    actionCount: 0,
    unplannedCount: 0,
    actions: [],
  },
  operationsEvidenceInvocation: {
    result: '',
    sourceSummary: '',
    sourcePlan: '',
    commandMode: '',
    executionMode: '',
    selectedActionCount: 0,
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
    selectedActionCount: 0,
    plannedCount: 0,
    blockedCount: 0,
    failedCount: 0,
    needsKubeconfigSecretConfirmation: false,
    needsOperatorApprovalConfirmation: false,
    requiredPlaceholderCount: 0,
    ambiguousRepeatedPlaceholderCount: 0,
    blockedActionOrders: [],
    plannedActionOrders: [],
    confirmedPlanCommand: '',
    blockedOnlyPlanCommand: '',
    plannedOnlyCommand: '',
    decisionRule: '',
    actions: [],
  },
  operationsDispatchPreflight: {
    result: '',
    sourceUnblockPlan: '',
    sourceResult: '',
    selectedActionCount: 0,
    selectedActionOrders: [],
    needsKubeconfigSecretConfirmation: false,
    needsOperatorApprovalConfirmation: false,
    requiredInputCount: 0,
    missingInputCount: 0,
    ambiguousInputCount: 0,
    failedCheckCount: 0,
    warningCheckCount: 0,
    requiredGitHubSecrets: [],
    workflowFiles: [],
    checks: [],
    readyPlanCommand: '',
    executeCommand: '',
    requiredInputs: [],
    decisionRule: '',
  },
  operationsWorkflowRunIdPlan: {
    result: '',
    sourceInvocationReport: '',
    invocationResult: '',
    branch: '',
    queryMode: '',
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
    invocationSummary: '',
    artifactCount: 0,
    requiredArtifactCount: 0,
    readyArtifactCount: 0,
    missingRequiredArtifactCount: 0,
    securityEvidenceFinalizerCommand: '',
    operationsArtifactFinalizerCommand: '',
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
  operationsEvidenceHandoff: {
    result: '',
    generatedAt: '',
    nextStep: {
      code: '',
      title: '',
      command: '',
      reason: '',
      note: '',
    },
    stageCount: 0,
    readyStageCount: 0,
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
    finalizerExists: false,
    finalizerResult: '',
    finalizerReadinessResult: '',
    finalizerFailedCount: 0,
    kubernetesOperationsReportSyncReportPath: '',
    kubernetesReportSyncExists: false,
    kubernetesReportSyncResult: '',
    kubernetesReportSyncFailedCount: 0,
    kubernetesReportSyncConfigMapName: '',
    kubernetesReportSyncConfigMapKey: '',
    kubernetesReportSyncSourceReportResult: '',
    kubernetesReportSyncReady: false,
    finalizerGapCount: 0,
    stageCount: 0,
    readyStageCount: 0,
    blockedActionCount: 0,
    missingWorkflowRunCount: 0,
    missingRequiredArtifactCount: 0,
    failedImportCount: 0,
    currentBottleneck: {
      code: '',
      title: '',
      reason: '',
      command: '',
    },
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
    sourceReportPath: '',
    sourceReportFormatVersion: '',
    sourceReportResult: '',
    sourceReportBytes: 0,
    sourceReportSha256: '',
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
const accessKeyForm = reactive({ name: 'local-dev-key', expiresAt: '', scopeBucket: '', scopePermissions: ['READ', 'WRITE', 'DELETE'], scopes: [] })
const bucketPermissionForm = reactive({ subjectType: 'USER', subjectId: '', permissions: ['READ'] })
const userForm = reactive({ loginId: '', email: '', name: '', password: '', role: 'USER', organizationId: '' })
const organizationForm = reactive({ name: '', description: '', defaultQuotaTb: 10 })
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
const dataFlowFilter = reactive({ from: '', to: '', bucketName: '', actorId: '', source: '', operation: '', status: '', limit: 50 })
const uploadState = reactive({ active: false, loadedBytes: 0, totalBytes: 0, percent: 0, message: '', retryable: false })
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
  generatedAt: '',
})
const confirmDialog = reactive({ open: false, title: '', message: '', confirmLabel: '확인', pending: false, action: null })
const dashboardLayoutSync = reactive({ source: 'LOCAL', updatedAt: '', pending: false })
const dashboardLoadState = reactive({ loading: false, error: '' })

const buckets = ref([])
const objects = ref([])
const accessKeys = ref([])
const bucketPermissions = ref([])
const users = ref([])
const organizations = ref([])
const organizationUsages = ref([])
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
const statusMessage = ref('')
const actionPendingCount = ref(0)
const newSecretKey = ref('')
const presignedUrl = ref('')
const shareLinkUrl = ref('')
const shareLinkPassword = ref('')
const shareLinkAllowedIpCidrs = ref('')
const pendingUploadId = ref('')
const uploadController = ref(null)
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
  return getStoredMultipartUploadSessionForFile(selectedBucket.value, objectForm.key, objectForm.file, objectForm.tags)
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
  return dashboardWidgetCatalog.value.filter((widget) => !widget.adminOnly || isAdmin.value)
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
  return item?.adminOnly ? ['ADMIN'] : ['ADMIN', 'ORG_ADMIN', 'USER']
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
    const dashboardSummaryLoaded = isAdmin.value ? await loadDashboardSummary() : false
    if (!dashboardSummaryLoaded) {
      await loadHealth()
    }

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
      const [userResult, organizationResult, organizationUsageResult] = await Promise.all([
        safeRequest(() => getUsers(), { items: [] }),
        safeRequest(() => getOrganizations(), { items: [] }),
        safeRequest(() => getOrganizationUsage(), { items: [] }),
      ])
      users.value = userResult.items || []
      organizations.value = organizationResult.items || []
      organizationUsages.value = organizationUsageResult.items || []
    } else {
      users.value = []
      organizations.value = []
      organizationUsages.value = []
    }

    if (isAdmin.value) {
      await Promise.all([
        dashboardSummaryLoaded ? Promise.resolve() : loadAdminUsage(),
        dashboardSummaryLoaded ? Promise.resolve() : loadBackupStatus(),
        dashboardSummaryLoaded ? Promise.resolve() : loadRetentionStatus(),
        dashboardSummaryLoaded ? Promise.resolve() : loadDataFlowMonitoring(),
        loadStorageExpansionExecutionLogRetentionStatus(),
        refreshLifecycleRules(),
        refreshLifecycleRuleConflicts(),
        loadQuotaPolicies(),
        loadStorageProfileRequests(),
        loadStorageExpansionRequests(),
        loadStorageExpansionSummary(),
        loadStorageExpansionRunnerPreflight(),
        loadObjectSharePolicy(),
        dashboardSummaryLoaded ? Promise.resolve() : refreshObjectShareAnalytics(),
        dashboardSummaryLoaded ? Promise.resolve() : handleLoadAuditLogs(),
      ])
    } else {
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
  const result = await safeRequest(() => getDataFlowMonitoring(dataFlowFilterPayload()), null)
  if (result?.data) {
    applyDataFlowMonitoring(result.data)
  }
}

async function handleExportDataFlowCsv() {
  const blob = await runAction(() => downloadDataFlowMonitoringCsv(dataFlowFilterPayload()))
  if (blob) {
    downloadBlob(blob, `osmu-data-flow-${new Date().toISOString().slice(0, 10)}.csv`)
    setStatusMessage('Data flow CSV export complete.')
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
  resetLifecycleRuleForm()
  resetLifecycleRuleConflicts()
  resetLifecycleXml()
  resetQuotaPolicyForm()
  resetStorageExpansionForm()
  resetObjectSharePolicy()
  resetObjectShareAnalytics()
  resetDashboardQuotaSummary()
  resetDashboardReadiness()
  resetDataFlowMonitoring()
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
    setStatusMessage(`${bucketName} 버킷 사용량 동기화 완료`)
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
  uploadState.active = true
  uploadState.loadedBytes = 0
  uploadState.totalBytes = request.file.size || 0
  uploadState.percent = 0
  uploadState.message = ''
  uploadState.retryable = false
  clearError()

  try {
    const uploadFn = request.file.size >= MULTIPART_UPLOAD_THRESHOLD_BYTES ? uploadObjectMultipart : uploadObject
    uploadState.message = uploadFn === uploadObjectMultipart ? 'Multipart upload' : ''
    await uploadFn(request.bucketName, request.key, request.file, request.tags, updateUploadProgress, {
      signal: controller.signal,
      onResume: ({ completedBytes }) => {
        uploadState.message = completedBytes > 0 ? 'Multipart resume' : 'Multipart upload'
      },
    })
    uploadState.percent = 100
    uploadState.retryable = false
    lastUploadRequest.value = null
    objectForm.key = ''
    objectForm.tags = ''
    objectForm.file = null
    refreshPendingMultipartUploads()
    await loadDashboard()
    setStatusMessage(`${request.key} 업로드 완료`)
  } catch (error) {
    const aborted = controller.signal.aborted
    const message = aborted ? '업로드를 취소했습니다.' : error.message
    aborted ? setErrorMessage(message) : setError(error)
    uploadState.message = message
    uploadState.retryable = true
    refreshPendingMultipartUploads()
  } finally {
    uploadState.active = false
    if (uploadController.value === controller) {
      uploadController.value = null
    }
  }
}

function updateUploadProgress(progress) {
  uploadState.loadedBytes = progress.loaded
  uploadState.totalBytes = progress.total
  uploadState.percent = progress.percent
}

function handleCancelUpload() {
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
      setStatusMessage(`${key} 영구 삭제 완료`)
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
    bucketLifecycleXml.content = result.data.xml || bucketLifecycleXml.content
    bucketLifecycleXml.ruleCount = result.data.ruleCount ?? bucketLifecycleXml.ruleCount
    bucketLifecycleXml.savedCount = result.data.savedCount ?? result.data.ruleCount ?? null
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
  const tagError = validateBucketTagInput(bucketTags.content)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  bucketTags.pending = true
  const result = await runAction(() => putBucketTags(selectedBucket.value, tagPairsToMap(bucketTags.content)))
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

function resetDataFlowMonitoring() {
  applyDataFlowMonitoring({})
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
    operationsEvidencePlan: normalizeOperationsEvidencePlan(data.operationsEvidencePlan),
    operationsEvidenceInvocation: normalizeOperationsEvidenceInvocation(data.operationsEvidenceInvocation),
    operationsInvocationUnblockPlan: normalizeOperationsInvocationUnblockPlan(data.operationsInvocationUnblockPlan),
    operationsDispatchPreflight: normalizeOperationsDispatchPreflight(data.operationsDispatchPreflight),
    operationsWorkflowRunIdPlan: normalizeOperationsWorkflowRunIdPlan(data.operationsWorkflowRunIdPlan),
    operationsArtifactCollectionPlan: normalizeOperationsArtifactCollectionPlan(data.operationsArtifactCollectionPlan),
    operationsReadinessArtifactImport: normalizeOperationsReadinessArtifactImport(data.operationsReadinessArtifactImport),
    operationsReadinessFinalize: normalizeOperationsReadinessFinalize(data.operationsReadinessFinalize),
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

function normalizeOperationsEvidencePlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceSummary: plan?.sourceSummary || '',
    sourceReport: plan?.sourceReport || '',
    pendingCount: Number(plan?.pendingCount || 0),
    actionCount: Number(plan?.actionCount || 0),
    unplannedCount: Number(plan?.unplannedCount || 0),
    actions: Array.isArray(plan?.actions) ? plan.actions : [],
  }
}

function normalizeOperationsEvidenceInvocation(invocation = {}) {
  return {
    result: invocation?.result || '',
    sourceSummary: invocation?.sourceSummary || '',
    sourcePlan: invocation?.sourcePlan || '',
    commandMode: invocation?.commandMode || '',
    executionMode: invocation?.executionMode || '',
    selectedActionCount: Number(invocation?.selectedActionCount || 0),
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
    selectedActionCount: Number(plan?.selectedActionCount || 0),
    plannedCount: Number(plan?.plannedCount || 0),
    blockedCount: Number(plan?.blockedCount || 0),
    failedCount: Number(plan?.failedCount || 0),
    needsKubeconfigSecretConfirmation: Boolean(plan?.needsKubeconfigSecretConfirmation),
    needsOperatorApprovalConfirmation: Boolean(plan?.needsOperatorApprovalConfirmation),
    requiredPlaceholderCount: Number(plan?.requiredPlaceholderCount || 0),
    ambiguousRepeatedPlaceholderCount: Number(plan?.ambiguousRepeatedPlaceholderCount || 0),
    blockedActionOrders: Array.isArray(plan?.blockedActionOrders) ? plan.blockedActionOrders : [],
    plannedActionOrders: Array.isArray(plan?.plannedActionOrders) ? plan.plannedActionOrders : [],
    confirmedPlanCommand: plan?.confirmedPlanCommand || '',
    blockedOnlyPlanCommand: plan?.blockedOnlyPlanCommand || '',
    plannedOnlyCommand: plan?.plannedOnlyCommand || '',
    decisionRule: plan?.decisionRule || '',
    actions: Array.isArray(plan?.actions) ? plan.actions : [],
  }
}

function normalizeOperationsDispatchPreflight(preflight = {}) {
  return {
    result: preflight?.result || '',
    sourceUnblockPlan: preflight?.sourceUnblockPlan || '',
    sourceResult: preflight?.sourceResult || '',
    selectedActionCount: Number(preflight?.selectedActionCount || 0),
    selectedActionOrders: Array.isArray(preflight?.selectedActionOrders) ? preflight.selectedActionOrders : [],
    needsKubeconfigSecretConfirmation: Boolean(preflight?.needsKubeconfigSecretConfirmation),
    needsOperatorApprovalConfirmation: Boolean(preflight?.needsOperatorApprovalConfirmation),
    requiredInputCount: Number(preflight?.requiredInputCount || 0),
    missingInputCount: Number(preflight?.missingInputCount || 0),
    ambiguousInputCount: Number(preflight?.ambiguousInputCount || 0),
    failedCheckCount: Number(preflight?.failedCheckCount || 0),
    warningCheckCount: Number(preflight?.warningCheckCount || 0),
    requiredGitHubSecrets: Array.isArray(preflight?.requiredGitHubSecrets) ? preflight.requiredGitHubSecrets : [],
    workflowFiles: Array.isArray(preflight?.workflowFiles) ? preflight.workflowFiles : [],
    checks: Array.isArray(preflight?.checks) ? preflight.checks : [],
    readyPlanCommand: preflight?.readyPlanCommand || '',
    executeCommand: preflight?.executeCommand || '',
    requiredInputs: Array.isArray(preflight?.requiredInputs) ? preflight.requiredInputs : [],
    decisionRule: preflight?.decisionRule || '',
  }
}

function normalizeOperationsWorkflowRunIdPlan(plan = {}) {
  return {
    result: plan?.result || '',
    sourceInvocationReport: plan?.sourceInvocationReport || '',
    invocationResult: plan?.invocationResult || '',
    branch: plan?.branch || '',
    queryMode: plan?.queryMode || '',
    limit: Number(plan?.limit || 0),
    workflowCount: Number(plan?.workflowCount || 0),
    readyWorkflowCount: Number(plan?.readyWorkflowCount || 0),
    missingWorkflowCount: Number(plan?.missingWorkflowCount || 0),
    staleWorkflowCount: Number(plan?.staleWorkflowCount || 0),
    imageSigningVersion: plan?.imageSigningVersion || '',
    commitSha: plan?.commitSha || '',
    artifactCollectionPlanCommand: plan?.artifactCollectionPlanCommand || '',
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
    invocationSummary: plan?.invocationSummary || '',
    artifactCount: Number(plan?.artifactCount || 0),
    requiredArtifactCount: Number(plan?.requiredArtifactCount || 0),
    readyArtifactCount: Number(plan?.readyArtifactCount || 0),
    missingRequiredArtifactCount: Number(plan?.missingRequiredArtifactCount || 0),
    securityEvidenceFinalizerCommand: plan?.securityEvidenceFinalizerCommand || '',
    operationsArtifactFinalizerCommand: plan?.operationsArtifactFinalizerCommand || '',
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

function normalizeOperationsEvidenceHandoff(handoff = {}) {
  const nextStep = handoff?.nextStep || {}
  return {
    result: handoff?.result || '',
    generatedAt: handoff?.generatedAt || '',
    nextStep: {
      code: nextStep.code || '',
      title: nextStep.title || '',
      command: nextStep.command || '',
      reason: nextStep.reason || '',
      note: nextStep.note || '',
    },
    stageCount: Number(handoff?.stageCount || 0),
    readyStageCount: Number(handoff?.readyStageCount || 0),
    blockedActionCount: Number(handoff?.blockedActionCount || 0),
    missingWorkflowRunCount: Number(handoff?.missingWorkflowRunCount || 0),
    missingRequiredArtifactCount: Number(handoff?.missingRequiredArtifactCount || 0),
    failedImportCount: Number(handoff?.failedImportCount || 0),
    finalizerFailedCount: Number(handoff?.finalizerFailedCount || 0),
    finalizerGapCount: Number(handoff?.finalizerGapCount || 0),
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
    finalizerExists: Boolean(report?.finalizerExists),
    finalizerResult: report?.finalizerResult || '',
    finalizerReadinessResult: report?.finalizerReadinessResult || '',
    finalizerFailedCount: Number(report?.finalizerFailedCount || 0),
    kubernetesOperationsReportSyncReportPath: report?.kubernetesOperationsReportSyncReportPath || '',
    kubernetesReportSyncExists: Boolean(report?.kubernetesReportSyncExists),
    kubernetesReportSyncResult: report?.kubernetesReportSyncResult || '',
    kubernetesReportSyncFailedCount: Number(report?.kubernetesReportSyncFailedCount || 0),
    kubernetesReportSyncConfigMapName: report?.kubernetesReportSyncConfigMapName || '',
    kubernetesReportSyncConfigMapKey: report?.kubernetesReportSyncConfigMapKey || '',
    kubernetesReportSyncSourceReportResult: report?.kubernetesReportSyncSourceReportResult || '',
    kubernetesReportSyncReady: Boolean(report?.kubernetesReportSyncReady),
    finalizerGapCount: Number(report?.finalizerGapCount || 0),
    stageCount: Number(report?.stageCount || 0),
    readyStageCount: Number(report?.readyStageCount || 0),
    blockedActionCount: Number(report?.blockedActionCount || 0),
    missingWorkflowRunCount: Number(report?.missingWorkflowRunCount || 0),
    missingRequiredArtifactCount: Number(report?.missingRequiredArtifactCount || 0),
    failedImportCount: Number(report?.failedImportCount || 0),
    currentBottleneck: {
      code: bottleneck.code || '',
      title: bottleneck.title || '',
      reason: bottleneck.reason || '',
      command: bottleneck.command || '',
    },
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
    sourceReportPath: report?.sourceReportPath || '',
    sourceReportFormatVersion: report?.sourceReportFormatVersion || '',
    sourceReportResult: report?.sourceReportResult || '',
    sourceReportBytes: Number(report?.sourceReportBytes || 0),
    sourceReportSha256: report?.sourceReportSha256 || '',
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
  if (!isAdmin.value) return
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
  clearStatusMessage()
}

function setErrorMessage(message) {
  errorMessage.value = message
  errorRequestId.value = ''
  clearStatusMessage()
}

function clearError() {
  errorMessage.value = ''
  errorRequestId.value = ''
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
  loadDataFlowMonitoring()
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
  }
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
