<template>
  <section class="dashboard-config-panel panel" data-testid="dashboard-config-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Dashboard Palettes</p>
        <h3>대시보드 패널 구성</h3>
        <small data-testid="dashboard-layout-sync">{{ dashboardLayoutSyncLabel }}</small>
      </div>
      <span class="panel-head-actions">
        <button data-testid="dashboard-edit-mode-toggle" type="button" class="ghost" :disabled="dashboardLayoutPending" @click="$emit('toggle-dashboard-edit-mode')">
          {{ dashboardEditMode ? '조회 mode' : '편집 mode' }}
        </button>
        <button v-if="dashboardEditMode" data-testid="dashboard-widget-reset-button" type="button" class="ghost" :disabled="dashboardLayoutPending" @click="$emit('reset-dashboard-widgets')">초기화</button>
      </span>
    </div>
    <p v-if="!dashboardEditMode" class="dashboard-view-mode-summary" data-testid="dashboard-view-mode-summary">
      조회 mode / {{ visibleDashboardWidgets.length }} visible panels / {{ dashboardLayoutSyncLabel }}
    </p>
    <div v-if="dashboardLoading" class="dashboard-state-panel dashboard-loading-state" data-testid="dashboard-loading-state" role="status" aria-live="polite">
      <strong>Dashboard loading</strong>
      <small>최신 layout, bucket, access key, readiness 상태를 불러오는 중입니다.</small>
    </div>
    <div v-if="dashboardLoadError" class="dashboard-state-panel dashboard-error-state" data-testid="dashboard-error-state" role="alert">
      <span>
        <strong>Dashboard load failed</strong>
        <small>{{ dashboardLoadError }}</small>
      </span>
      <button data-testid="dashboard-retry-button" type="button" class="ghost" @click="$emit('retry-dashboard-load')">Retry</button>
    </div>
    <template v-if="dashboardEditMode">
    <div class="inline-form dashboard-add-form">
      <select data-testid="dashboard-widget-select" :value="dashboardWidgetToAdd" @change="$emit('update-widget-to-add', $event.target.value)">
        <option value="">추가할 패널 선택</option>
        <optgroup v-for="group in availableDashboardWidgetGroups" :key="group.category" :label="dashboardWidgetCategoryLabel(group.category)">
          <option v-for="widget in group.widgets" :key="widget.id" :value="widget.id">
            {{ widget.title }}
          </option>
        </optgroup>
      </select>
      <button data-testid="dashboard-widget-add-button" type="button" :disabled="dashboardLayoutPending || !dashboardWidgetToAdd" @click="$emit('add-dashboard-widget')">패널 추가</button>
    </div>
    <div class="dashboard-widget-catalog" data-testid="dashboard-widget-catalog">
      <section
        v-for="group in availableDashboardWidgetGroups"
        :key="group.category"
        class="widget-category"
        :data-testid="`dashboard-widget-category-${categoryTestId(group.category)}`"
      >
        <h4>{{ dashboardWidgetCategoryLabel(group.category) }}</h4>
        <div class="widget-chip-list">
          <button
            v-for="widget in group.widgets"
            :key="widget.id"
            data-testid="dashboard-widget-catalog-button"
            type="button"
            class="widget-chip"
            :title="widget.description"
            :disabled="dashboardLayoutPending"
            @click="$emit('add-dashboard-widget-by-id', widget.id)"
          >
            {{ widget.title }}
          </button>
        </div>
      </section>
      <p v-if="availableDashboardWidgetGroups.length === 0" class="empty">추가 가능한 패널 없음</p>
    </div>
    <div class="inline-form dashboard-preset-form">
      <select data-testid="dashboard-layout-preset-select" :value="dashboardLayoutPresetToApply" @change="$emit('update-dashboard-layout-preset', $event.target.value)">
        <option value="">Layout preset</option>
        <option v-for="preset in dashboardLayoutPresets" :key="preset.id" :value="preset.id">
          {{ preset.name }}
        </option>
      </select>
      <button
        data-testid="dashboard-layout-preset-apply-button"
        type="button"
        class="ghost"
        :disabled="dashboardLayoutPending || !dashboardLayoutPresetToApply"
        @click="$emit('apply-dashboard-layout-preset')"
      >
        Preset 적용
      </button>
      <button
        v-if="canDeleteDashboardLayoutPreset"
        data-testid="dashboard-layout-preset-delete-button"
        type="button"
        class="danger"
        :disabled="dashboardLayoutPending"
        @click="$emit('delete-dashboard-layout-preset')"
      >
        Preset 삭제
      </button>
      <button
        v-if="canExportDashboardLayoutPreset"
        data-testid="dashboard-layout-preset-export-button"
        type="button"
        class="ghost"
        :disabled="dashboardLayoutPending"
        @click="$emit('export-dashboard-layout-preset')"
      >
        Preset 내보내기
      </button>
      <button
        v-if="canExportDashboardLayoutPresetBundle"
        data-testid="dashboard-layout-preset-bundle-export-button"
        type="button"
        class="ghost"
        :disabled="dashboardLayoutPending"
        @click="$emit('export-dashboard-layout-preset-bundle')"
      >
        Bundle Export
      </button>
    </div>
    <div v-if="canCreateDashboardLayoutPreset" class="inline-form dashboard-preset-save-form">
      <input
        data-testid="dashboard-layout-preset-name-input"
        :value="dashboardLayoutPresetForm.name"
        placeholder="Preset name"
        @input="$emit('update-dashboard-layout-preset-name', $event.target.value)"
      />
      <input
        data-testid="dashboard-layout-preset-description-input"
        :value="dashboardLayoutPresetForm.description"
        placeholder="Description"
        @input="$emit('update-dashboard-layout-preset-description', $event.target.value)"
      />
      <button
        data-testid="dashboard-layout-preset-save-button"
        type="button"
        :disabled="dashboardLayoutPending || !dashboardLayoutPresetForm.name.trim()"
        @click="$emit('create-dashboard-layout-preset')"
      >
        현재 구성 저장
      </button>
      <button
        v-if="canUpdateDashboardLayoutPreset"
        data-testid="dashboard-layout-preset-update-button"
        type="button"
        class="ghost"
        :disabled="dashboardLayoutPending"
        @click="$emit('update-custom-dashboard-layout-preset')"
      >
        선택 preset 갱신
      </button>
      <label
        v-if="canImportDashboardLayoutPreset"
        class="file-control ghost"
        data-testid="dashboard-layout-preset-import-label"
      >
        Preset 가져오기
        <input
          data-testid="dashboard-layout-preset-import-input"
          type="file"
          accept="application/json,.json"
          :disabled="dashboardLayoutPending"
          @change="$emit('import-dashboard-layout-preset', $event)"
        />
      </label>
      <label
        v-if="canImportDashboardLayoutPresetBundle"
        class="file-control ghost"
        data-testid="dashboard-layout-preset-bundle-import-label"
      >
        Bundle Import
        <input
          data-testid="dashboard-layout-preset-bundle-import-input"
          type="file"
          accept="application/json,.json"
          :disabled="dashboardLayoutPending"
          @change="$emit('import-dashboard-layout-preset-bundle', $event)"
        />
      </label>
    </div>
    <section v-if="canManageDashboardLayoutDefaults" class="dashboard-default-panel" data-testid="dashboard-layout-default-panel">
      <div class="inline-form dashboard-default-form" data-testid="dashboard-layout-default-form">
        <select
          data-testid="dashboard-layout-default-target-type"
          :value="dashboardLayoutDefaultForm.targetType"
          @change="$emit('update-dashboard-layout-default-target-type', $event.target.value)"
        >
          <option value="ROLE">Role</option>
          <option value="ORGANIZATION">Organization</option>
        </select>
        <select
          data-testid="dashboard-layout-default-target-id"
          :value="dashboardLayoutDefaultForm.targetId"
          @change="$emit('update-dashboard-layout-default-target-id', $event.target.value)"
        >
          <option value="">Target</option>
          <option v-for="target in dashboardLayoutDefaultTargetOptions" :key="target.id" :value="target.id">
            {{ target.label }}
          </option>
        </select>
        <select
          data-testid="dashboard-layout-default-preset-id"
          :value="dashboardLayoutDefaultForm.presetId"
          @change="$emit('update-dashboard-layout-default-preset-id', $event.target.value)"
        >
          <option value="">Default preset</option>
          <option v-for="preset in dashboardLayoutPresets" :key="preset.id" :value="preset.id">
            {{ preset.name }}
          </option>
        </select>
        <button
          data-testid="dashboard-layout-default-save-button"
          type="button"
          :disabled="dashboardLayoutPending || !dashboardLayoutDefaultForm.targetId || !dashboardLayoutDefaultForm.presetId"
          @click="$emit('save-dashboard-layout-default')"
        >
          기본 preset 저장
        </button>
      </div>
      <ul class="compact-list dashboard-default-list" data-testid="dashboard-layout-default-list">
        <li v-for="item in dashboardLayoutDefaults" :key="`${item.targetType}-${item.targetId}`">
          <span class="list-main">
            <b>{{ item.targetType }} {{ item.targetId }}</b>
            <small>{{ item.presetName || item.presetId }} / {{ item.presetCustom ? 'custom' : 'built-in' }}</small>
          </span>
          <button
            data-testid="dashboard-layout-default-delete-button"
            type="button"
            class="danger"
            :disabled="dashboardLayoutPending"
            @click="$emit('delete-dashboard-layout-default', item)"
          >
            해제
          </button>
        </li>
        <li v-if="dashboardLayoutDefaults.length === 0" class="empty">기본 preset 없음</li>
      </ul>
    </section>
    <ul class="widget-config-list" data-testid="dashboard-widget-list">
      <li
        v-for="(widget, index) in dashboardWidgets"
        :key="widget.id"
        :data-testid="`dashboard-widget-config-${widget.id}`"
        :class="{
          'is-dragging': dashboardWidgetDragIndex === index,
          'is-drop-target': dashboardWidgetDropIndex === index && dashboardWidgetDragIndex !== index,
        }"
        :draggable="!dashboardLayoutPending"
        :aria-grabbed="dashboardWidgetDragIndex === index ? 'true' : 'false'"
        @dragstart="$emit('start-dashboard-widget-drag', index, $event)"
        @dragenter.prevent="$emit('hover-dashboard-widget-drag', index)"
        @dragover.prevent
        @drop.prevent="$emit('drop-dashboard-widget', index, $event)"
        @dragend="$emit('end-dashboard-widget-drag')"
      >
        <span>
          <span class="drag-grip" data-testid="dashboard-widget-drag-handle" aria-hidden="true">::</span>
          <strong>{{ dashboardWidgetTitle(widget.id) }}</strong>
          <small>{{ widget.enabled ? '표시 중' : '숨김' }} · {{ dashboardWidgetSizeLabel(widget.size) }} · {{ dashboardWidgetToneLabel(widget) }} · {{ dashboardWidgetRefreshIntervalLabel(widget) }}</small>
          <small data-testid="dashboard-widget-access-mode">{{ dashboardWidgetAccessLabel(widget.id) }}</small>
        </span>
        <span class="widget-actions">
          <button data-testid="dashboard-widget-move-up-button" type="button" class="ghost" :disabled="dashboardLayoutPending || index === 0" @click="$emit('move-dashboard-widget', index, -1)">위</button>
          <button data-testid="dashboard-widget-move-down-button" type="button" class="ghost" :disabled="dashboardLayoutPending || index === dashboardWidgets.length - 1" @click="$emit('move-dashboard-widget', index, 1)">아래</button>
          <button data-testid="dashboard-widget-size-button" type="button" class="ghost" :disabled="dashboardLayoutPending" @click="$emit('toggle-dashboard-widget-size', widget.id)">
            크기
          </button>
          <label class="widget-option-control" data-testid="dashboard-widget-section-control">
            <span>Section</span>
            <select
              data-testid="dashboard-widget-section-select"
              :value="dashboardWidgetSection(widget)"
              :disabled="dashboardLayoutPending"
              @change="$emit('update-dashboard-widget-section', widget.id, $event.target.value)"
            >
              <option v-for="section in dashboardWidgetSections" :key="section.id" :value="section.id">
                {{ section.label }}
              </option>
            </select>
          </label>
          <label
            v-for="option in dashboardWidgetConfigOptions(widget.id)"
            :key="`${widget.id}-${option.key}`"
            class="widget-option-control"
            data-testid="dashboard-widget-option-control"
          >
            <span>{{ option.label }}</span>
            <select
              data-testid="dashboard-widget-option-select"
              :value="dashboardWidgetOptionValue(widget, option.key)"
              :disabled="dashboardLayoutPending"
              @change="$emit('update-dashboard-widget-option', widget.id, option.key, $event.target.value)"
            >
              <option v-for="value in option.values" :key="value" :value="value">
                {{ value }}
              </option>
            </select>
          </label>
          <button data-testid="dashboard-widget-toggle-button" type="button" class="ghost" :disabled="dashboardLayoutPending" @click="$emit('toggle-dashboard-widget', widget.id)">
            {{ widget.enabled ? '숨김' : '표시' }}
          </button>
          <button data-testid="dashboard-widget-remove-button" type="button" class="danger" :disabled="dashboardLayoutPending" @click="$emit('remove-dashboard-widget', widget.id)">제거</button>
        </span>
      </li>
    </ul>
    </template>
  </section>

  <section
    v-if="!dashboardLoading && visibleDashboardWidgetSections.length === 0"
    class="empty-state-panel dashboard-empty-state"
    data-testid="dashboard-empty-state"
  >
    <div class="empty-state-body">
      <strong>표시할 dashboard panel이 없습니다</strong>
      <small>편집 mode에서 panel을 다시 표시하거나 preset을 적용하세요.</small>
    </div>
  </section>

  <section v-else class="dashboard-widget-sections" data-testid="dashboard-widget-sections">
    <section
      v-for="section in visibleDashboardWidgetSections"
      :key="section.id"
      class="dashboard-widget-section"
      :data-testid="`dashboard-widget-section-${section.id}`"
    >
      <div class="dashboard-widget-section-head">
        <h3>{{ dashboardWidgetSectionLabel(section.id) }}</h3>
        <span v-if="dashboardEditMode" class="section-actions">
          <button
            data-testid="dashboard-widget-section-toggle-button"
            type="button"
            class="ghost"
            :disabled="dashboardLayoutPending"
            @click="$emit('toggle-dashboard-section', section.id)"
          >
            {{ section.collapsed ? 'Show' : 'Hide' }}
          </button>
          <button
            data-testid="dashboard-widget-section-move-up-button"
            type="button"
            class="ghost"
            :disabled="dashboardLayoutPending || section.index === 0"
            @click="$emit('move-dashboard-widget-section', section.id, -1)"
          >
            위
          </button>
          <button
            data-testid="dashboard-widget-section-move-down-button"
            type="button"
            class="ghost"
            :disabled="dashboardLayoutPending || section.index === visibleDashboardWidgetSections.length - 1"
            @click="$emit('move-dashboard-widget-section', section.id, 1)"
          >
            아래
          </button>
        </span>
      </div>
      <p
        v-if="section.collapsed"
        class="dashboard-widget-section-collapsed"
        :data-testid="`dashboard-widget-section-collapsed-${section.id}`"
      >
        Section hidden
      </p>
      <div v-else class="metrics-grid dashboard-widget-grid" data-testid="metrics-grid">
        <article
          v-for="widget in section.widgets"
          :key="widget.id"
          :id="`dashboard-widget-${widget.id}`"
          :class="['metric', 'dashboard-widget', `widget-${widget.id}`, `dashboard-widget-${widget.size || 'normal'}`, `dashboard-widget-tone-${dashboardWidgetTone(widget)}`]"
          :data-testid="`dashboard-widget-${widget.id}`"
        >
      <span>{{ dashboardWidgetTitle(widget.id) }}</span>
      <template v-if="widget.id === 'capacity'">
        <strong>{{ usagePercent }}%</strong>
        <small>{{ formatBytes(usage.usedBytes) }} / {{ formatBytes(usage.totalQuotaBytes) }}</small>
      </template>
      <template v-else-if="widget.id === 'remaining'">
        <strong>{{ formatBytes(usage.remainingBytes) }}</strong>
        <small>할당 쿼터 기준</small>
      </template>
      <template v-else-if="widget.id === 'buckets'">
        <strong>{{ usage.bucketCount }}</strong>
        <small>{{ selectedBucket || '선택된 버킷 없음' }}</small>
      </template>
      <template v-else-if="widget.id === 'objects'">
        <strong>{{ usage.objectCount }}</strong>
        <small>{{ objectViewMode === 'trash' ? '휴지통 보기' : '활성 파일 보기' }}</small>
      </template>
      <template v-else-if="widget.id === 'health'">
        <strong>{{ health.backend }}</strong>
        <small>Storage {{ health.storage }} / DB {{ health.database }}</small>
        <small v-if="storageBackendStatus.mode" data-testid="dashboard-storage-backend-status">{{ storageBackendStatusLabel }}</small>
      </template>
      <template v-else-if="widget.id === 'runtime'">
        <strong>{{ runtimeReadinessLabel }}</strong>
        <small>{{ health.metadataEngine }} metadata / {{ health.storageEngine }} object / {{ health.accessKeyProvisioner }} keys</small>
      </template>
      <template v-else-if="widget.id === 'readiness'">
        <strong>{{ dashboardReadiness.status }}</strong>
        <small>{{ dashboardReadiness.blockerCount }} blockers / {{ dashboardReadiness.warningCount }} warnings</small>
      </template>
      <template v-else-if="widget.id === 'backup'">
        <strong>{{ backupStatus.status }}</strong>
        <small>{{ backupStatus.metadataStore }} / {{ backupStatus.objectStore }}</small>
      </template>
      <template v-else-if="widget.id === 'io'">
        <strong>{{ uploadState.active ? `${uploadState.percent}%` : formatBytes(dataFlowTraffic.totalBytes || uploadState.loadedBytes) }}</strong>
        <small>{{ uploadState.message || dataFlowTrafficLabel }}</small>
        <small data-testid="dashboard-data-flow-ops">{{ dataFlowOperationLabel }}</small>
      </template>
      <template v-else-if="widget.id === 'requests'">
        <strong>{{ auditLogs.length }}</strong>
        <small>{{ auditNextCursor ? '추가 로그 있음' : '최근 감사 로그' }}</small>
      </template>
      <template v-else-if="widget.id === 'sharing'">
        <strong>{{ objectShareAnalytics.activeLinks }}</strong>
        <small>{{ objectShareAnalytics.totalLinks }} total / {{ objectShareAnalytics.totalDownloads }} downloads</small>
      </template>
      <template v-else-if="widget.id === 'quota'">
        <strong>{{ dashboardQuota.warningPolicyCount + dashboardQuota.exhaustedPolicyCount }}</strong>
        <small>{{ dashboardQuota.policyCount }} policies / {{ dashboardQuota.exhaustedPolicyCount }} exhausted</small>
      </template>
      <template v-else-if="widget.id === 'access-keys'">
        <strong>{{ accessKeySummary.activeCount }}</strong>
        <small data-testid="dashboard-access-key-total">{{ accessKeySummary.totalCount }} total / {{ health.accessKeyProvisioner }} provisioner</small>
        <small data-testid="dashboard-access-key-risk">{{ accessKeySummary.expiredCount }} expired / {{ accessKeySummary.expiringSoonCount }} expiring / {{ accessKeySummary.unusedCount }} unused</small>
      </template>
      <template v-else-if="widget.id === 'identity'">
        <strong>{{ users.length }} / {{ organizations.length }}</strong>
        <small>users / organizations</small>
      </template>
      <template v-else-if="widget.id === 'lifecycle'">
        <strong>{{ lifecycleRuleConflicts.conflictCount || 0 }}</strong>
        <small>{{ lifecycleRules.length }} rules / {{ lifecycleRuleConflicts.ruleCount || 0 }} checked</small>
      </template>
      <template v-else-if="widget.id === 'selected'">
        <strong>{{ selectedBucket || '-' }}</strong>
        <small>{{ nextActionLabel }}</small>
      </template>
      <template v-else-if="widget.id === 'retention'">
        <strong>{{ retentionPolicy.enabled ? 'ON' : 'OFF' }}</strong>
        <small>{{ retentionPolicy.retentionDays || '-' }}일 보존</small>
      </template>
      <template v-else-if="widget.id === 'execution-retention'">
        <strong>{{ formatCount(executionLogRetention.pendingOutputCount) }}</strong>
        <small>{{ executionLogRetention.enabled ? `${executionLogRetention.retentionDays || '-'}d retention` : 'disabled' }}</small>
      </template>
      <template v-else-if="widget.id === 'storage-expansion'">
        <strong>{{ formatCount(storageExpansionOpenRequestCount) }}</strong>
        <small>{{ formatCount(storageExpansionRequestCount) }} requests / {{ formatCount(storageExpansionExecutionCount) }} executions</small>
      </template>
        </article>
      </div>
    </section>
  </section>

  <section class="ops-grid">
    <article class="panel readiness-panel" data-testid="dashboard-readiness-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Demo Readiness</p>
          <h3>데모/배포 준비도</h3>
        </div>
        <div class="panel-head-actions">
          <button
            v-if="isAdmin"
            data-testid="dashboard-readiness-refresh-button"
            type="button"
            class="ghost"
            @click="$emit('refresh-dashboard-readiness')"
          >
            재점검
          </button>
          <span :class="['status-pill', statusClass(dashboardReadiness.status)]">{{ dashboardReadiness.status }}</span>
        </div>
      </div>
      <dl class="status-dl">
        <div>
          <dt>Runtime</dt>
          <dd>{{ dashboardReadiness.runtimeProfile }}</dd>
        </div>
        <div>
          <dt>Issues</dt>
          <dd>{{ dashboardReadiness.blockerCount }} blockers / {{ dashboardReadiness.warningCount }} warnings</dd>
        </div>
        <div>
          <dt>Last Check</dt>
          <dd>{{ formatDateTime(dashboardReadiness.generatedAt) || '-' }}</dd>
        </div>
      </dl>
      <div v-if="operationsReadinessItems.length > 0" class="readiness-operations-summary" data-testid="readiness-operations-summary">
        <div>
          <strong>{{ operationsReadinessItems.length }} operations evidence gaps</strong>
          <small>{{ operationsReadinessPrimaryMessage }}</small>
          <small
            v-if="operationsEvidencePlanItem"
            data-testid="readiness-evidence-plan-summary"
          >
            Plan: {{ operationsEvidencePlanItem.message }}
          </small>
          <small
            v-if="operationsEvidenceInvocationItem"
            data-testid="readiness-evidence-invocation-item-summary"
          >
            Invocation: {{ operationsEvidenceInvocationItem.message }}
          </small>
          <small
            v-if="operationsInvocationUnblockPlanItem"
            data-testid="readiness-invocation-unblock-item-summary"
          >
            Unblock: {{ operationsInvocationUnblockPlanItem.message }}
          </small>
          <small
            v-if="operationsDispatchPreflightItem"
            data-testid="readiness-dispatch-preflight-item-summary"
          >
            Preflight: {{ operationsDispatchPreflightItem.message }}
          </small>
          <small
            v-if="operationsWorkflowRunIdPlanItem"
            data-testid="readiness-workflow-run-id-item-summary"
          >
            Run IDs: {{ operationsWorkflowRunIdPlanItem.message }}
          </small>
          <small
            v-if="operationsArtifactCollectionPlanItem"
            data-testid="readiness-artifact-collection-item-summary"
          >
            Artifacts: {{ operationsArtifactCollectionPlanItem.message }}
          </small>
          <small
            v-if="operationsReadinessArtifactImportItem"
            data-testid="readiness-artifact-import-item-summary"
          >
            Import: {{ operationsReadinessArtifactImportItem.message }}
          </small>
          <small
            v-if="operationsReadinessFinalizeItem"
            data-testid="readiness-finalizer-item-summary"
          >
            Finalizer: {{ operationsReadinessFinalizeItem.message }}
          </small>
          <small
            v-if="operationsEvidenceHandoffItem"
            data-testid="readiness-evidence-handoff-item-summary"
          >
            Handoff: {{ operationsEvidenceHandoffItem.message }}
          </small>
          <small
            v-if="operationsHandoffPackageItem"
            data-testid="readiness-handoff-package-item-summary"
          >
            Package: {{ operationsHandoffPackageItem.message }}
          </small>
          <small
            v-if="dataFlowStoragePlanItem"
            data-testid="readiness-data-flow-storage-plan-item-summary"
          >
            Data-flow plan: {{ dataFlowStoragePlanItem.message }}
          </small>
          <small
            v-if="dataFlowStorageTransitionRunbook.result"
            data-testid="readiness-data-flow-storage-transition-runbook-item-summary"
          >
            Data-flow runbook: {{ dataFlowStorageTransitionRunbook.result }} /
            store {{ dataFlowStorageTransitionRunbook.candidateStore || 'unknown' }} /
            failures {{ dataFlowStorageTransitionRunbook.failureCount || 0 }}
          </small>
          <small
            v-if="storageBackendTelemetryEvidence.result"
            data-testid="readiness-storage-telemetry-item-summary"
          >
            Storage telemetry: {{ storageBackendTelemetryEvidence.result }} /
            pools {{ storageBackendTelemetryEvidence.poolCount || 0 }} /
            offline {{ storageBackendTelemetryEvidence.offlineServerCount || 0 }}
          </small>
          <small
            v-if="monitoringThresholdEvidence.result"
            data-testid="readiness-monitoring-threshold-evidence-item-summary"
          >
            Monitoring thresholds: {{ monitoringThresholdEvidence.result }} /
            alerts {{ monitoringThresholdEvidence.mappedAlertCount || 0 }}/{{ monitoringThresholdEvidence.requiredAlertCount || 0 }} /
            failures {{ monitoringThresholdEvidence.failureCount || 0 }}
          </small>
          <small
            v-if="minioBucketCorsVerification.result"
            data-testid="readiness-minio-bucket-cors-item-summary"
          >
            Bucket CORS: {{ minioBucketCorsVerification.result }} /
            exposed {{ minioBucketCorsVerification.exposedHeaderCount || 0 }} /
            failures {{ minioBucketCorsVerification.failureCount || 0 }}
          </small>
          <small
            v-if="storageExpansionFinalize.result"
            data-testid="readiness-storage-expansion-finalize-item-summary"
          >
            Storage expansion: {{ storageExpansionFinalize.result }} /
            failures {{ storageExpansionFinalize.failedCount || 0 }}
          </small>
          <small
            v-if="kubernetesHaDrReadiness.result"
            data-testid="readiness-kubernetes-ha-dr-item-summary"
          >
            HA/DR: {{ kubernetesHaDrReadiness.result }} /
            failures {{ kubernetesHaDrReadiness.failureCount || 0 }}
          </small>
          <small
            v-if="kubernetesDrFinalize.result"
            data-testid="readiness-kubernetes-dr-finalize-item-summary"
          >
            Kubernetes DR: {{ kubernetesDrFinalize.result }} /
            gaps {{ kubernetesDrFinalize.gaps?.length || 0 }}
          </small>
          <small
            v-if="iamRbacEvidence.result"
            data-testid="readiness-iam-rbac-evidence-item-summary"
          >
            IAM/RBAC: {{ iamRbacEvidence.result }} /
            status {{ iamRbacEvidence.status || 'unknown' }} /
            failures {{ iamRbacEvidence.failedCount || 0 }}
          </small>
          <small
            v-if="securityEvidence.result || securityEvidence.imageSigning?.result || securityEvidence.containerSecurity?.result"
            data-testid="readiness-security-evidence-item-summary"
          >
            Security evidence: {{ securityEvidence.result || 'pending finalizer' }} /
            image {{ securityEvidence.imageSigning?.result || 'missing' }} /
            container {{ securityEvidence.containerSecurity?.result || 'missing' }}
          </small>
          <small
            v-if="secretRotationEvidence.result"
            data-testid="readiness-secret-rotation-evidence-item-summary"
          >
            Secret rotation: {{ secretRotationEvidence.result }} /
            core {{ secretRotationEvidence.coreRotatedCount || 0 }}/{{ secretRotationEvidence.coreRequiredCount || 0 }} /
            failures {{ secretRotationEvidence.failureCount || 0 }}
          </small>
          <small
            v-if="operationsReadinessConvergenceItem"
            data-testid="readiness-convergence-item-summary"
          >
            Convergence: {{ operationsReadinessConvergenceItem.message }}
          </small>
          <small
            v-if="kubernetesOperationsReportSyncItem"
            data-testid="readiness-kubernetes-report-sync-item-summary"
          >
            K8s sync: {{ kubernetesOperationsReportSyncItem.message }}
          </small>
        </div>
        <button
          data-testid="readiness-operations-filter-button"
          type="button"
          class="ghost"
          @click="$emit('update-readiness-category-filter', 'OPERATIONS')"
        >
          Operations
        </button>
      </div>
      <div
        v-if="storageBackendTelemetryEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-storage-telemetry-summary"
      >
        <strong>Storage telemetry: {{ storageBackendTelemetryEvidence.result }}</strong>
        <small>
          {{ storageBackendTelemetryEvidence.environmentName || 'unknown env' }} /
          {{ storageBackendTelemetryEvidence.targetCluster || 'unknown cluster' }} /
          operator {{ storageBackendTelemetryEvidence.operatorName || 'unknown' }} /
          source {{ storageBackendTelemetryEvidence.sourceMode || 'unknown' }} /
          alias {{ storageBackendTelemetryEvidence.minioAlias || 'unknown' }} /
          pools {{ storageBackendTelemetryEvidence.poolCount || 0 }} /
          servers {{ storageBackendTelemetryEvidence.serverCount || 0 }} /
          online {{ storageBackendTelemetryEvidence.onlineServerCount || 0 }} /
          offline {{ storageBackendTelemetryEvidence.offlineServerCount || 0 }} /
          drives {{ storageBackendTelemetryEvidence.driveCount || 0 }} /
          used {{ formatBytes(storageBackendTelemetryEvidence.usedBytes || 0) }} /
          free {{ formatBytes(storageBackendTelemetryEvidence.freeBytes || 0) }} /
          total {{ formatBytes(storageBackendTelemetryEvidence.totalBytes || 0) }} /
          capacity {{ storageBackendTelemetryEvidence.capacityKnown ? 'known' : 'unknown' }}
        </small>
        <small v-if="storageBackendTelemetryEvidence.evidenceRef">
          evidence {{ storageBackendTelemetryEvidence.evidenceRef }}
        </small>
        <small v-if="storageBackendTelemetryEvidence.adminInfoJsonSha256">
          admin info sha256 {{ storageBackendTelemetryEvidence.adminInfoJsonSha256 }}
        </small>
        <small v-if="storageBackendTelemetryEvidence.scopePolicy">
          {{ storageBackendTelemetryEvidence.scopePolicy }}
        </small>
      </div>
      <div
        v-if="monitoringThresholdEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-monitoring-threshold-evidence-summary"
      >
        <strong>Monitoring thresholds: {{ monitoringThresholdEvidence.result }}</strong>
        <small>
          {{ monitoringThresholdEvidence.environmentName || 'unknown env' }} /
          {{ monitoringThresholdEvidence.targetCluster || 'unknown cluster' }} /
          {{ monitoringThresholdEvidence.operatorName || 'unknown operator' }} /
          alerts {{ monitoringThresholdEvidence.mappedAlertCount || 0 }} of {{ monitoringThresholdEvidence.requiredAlertCount || 0 }} /
          routes {{ monitoringThresholdEvidence.routeCount || 0 }} /
          panels {{ monitoringThresholdEvidence.grafanaPanelCount || 0 }} /
          tuning refs {{ monitoringThresholdEvidence.tuningEvidenceCount || 0 }} /
          failures {{ monitoringThresholdEvidence.failureCount || 0 }} of {{ monitoringThresholdEvidence.checkCount || 0 }}
        </small>
        <small
          v-if="monitoringThresholdReviewWindowSummary"
          data-testid="readiness-monitoring-threshold-review-window"
        >
          Review window: {{ monitoringThresholdReviewWindowSummary }}
        </small>
        <small
          v-if="monitoringThresholdEvidence.thresholdTargetsPath"
          data-testid="readiness-monitoring-threshold-targets-path"
        >
          Targets: {{ monitoringThresholdEvidence.thresholdTargetsPath }}
        </small>
        <small
          v-if="monitoringThresholdRouteSummary"
          data-testid="readiness-monitoring-threshold-routes"
        >
          Routes: {{ monitoringThresholdRouteSummary }}
        </small>
        <small
          v-if="monitoringThresholdMissingAlertSummary"
          data-testid="readiness-monitoring-threshold-missing-alerts"
        >
          Missing alerts: {{ monitoringThresholdMissingAlertSummary }}
        </small>
        <small
          v-if="monitoringThresholdEvidenceRefSummary"
          data-testid="readiness-monitoring-threshold-evidence-refs"
        >
          Evidence refs: {{ monitoringThresholdEvidenceRefSummary }}
        </small>
        <small
          v-if="monitoringThresholdConfirmationSummary"
          data-testid="readiness-monitoring-threshold-confirmations"
        >
          Confirmations: {{ monitoringThresholdConfirmationSummary }}
        </small>
        <small v-if="monitoringThresholdEvidence.secretPolicy">
          {{ monitoringThresholdEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="monitoringThresholdEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-monitoring-threshold-evidence-checks"
        data-testid="readiness-monitoring-threshold-evidence-checks"
      >
        <li
          v-for="check in monitoringThresholdEvidenceChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="minioBucketCorsVerification.result"
        class="readiness-invocation-summary"
        data-testid="readiness-minio-bucket-cors-summary"
      >
        <strong>MinIO bucket CORS: {{ minioBucketCorsVerification.result }}</strong>
        <small>
          bucket {{ minioBucketCorsVerification.bucketName || 'unknown' }} /
          alias {{ minioBucketCorsVerification.minioAlias || 'unknown' }} /
          mode {{ minioBucketCorsVerification.sourceMode || 'unknown' }} /
          rules {{ minioBucketCorsVerification.ruleCount || 0 }} /
          exposed headers {{ minioBucketCorsVerification.exposedHeaderCount || 0 }} /
          failures {{ minioBucketCorsVerification.failureCount || 0 }} /
          raw XML stored {{ minioBucketCorsVerification.rawCorsXmlStored ? 'yes' : 'no' }}
        </small>
        <small
          v-if="minioBucketCorsExposeSummary"
          data-testid="readiness-minio-bucket-cors-expose-headers"
        >
          Expose headers: {{ minioBucketCorsExposeSummary }}
        </small>
        <small
          v-if="minioBucketCorsAllowedHeadersSummary"
          data-testid="readiness-minio-bucket-cors-allowed-headers"
        >
          Allowed headers: {{ minioBucketCorsAllowedHeadersSummary }}
        </small>
        <small
          v-if="minioBucketCorsMaxAgeSummary"
          data-testid="readiness-minio-bucket-cors-max-age"
        >
          Max age seconds: {{ minioBucketCorsMaxAgeSummary }}
        </small>
        <small v-if="minioBucketCorsVerification.scopePolicy">
          {{ minioBucketCorsVerification.scopePolicy }}
        </small>
        <div
          v-if="minioBucketCorsOperatorCommands.length > 0"
          class="readiness-artifact-command-row"
          data-testid="readiness-minio-bucket-cors-operator-commands"
        >
          <button
            v-for="command in minioBucketCorsOperatorCommands"
            :key="command.name"
            type="button"
            class="ghost"
            :title="`Copy ${command.label}`"
            @click="copyReadinessRemediationCommand(command.command)"
          >
            {{ command.label }}
          </button>
        </div>
      </div>
      <ol
        v-if="minioBucketCorsChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-minio-bucket-cors-checks"
        data-testid="readiness-minio-bucket-cors-checks"
      >
        <li
          v-for="check in minioBucketCorsChecks.slice(0, 4)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.passed ? 'PASS' : 'FAIL' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="storageExpansionFinalize.result"
        class="readiness-invocation-summary"
        data-testid="readiness-storage-expansion-finalize-summary"
      >
        <strong>Storage expansion finalizer: {{ storageExpansionFinalize.result }}</strong>
        <small>
          {{ storageExpansionFinalize.namespace || 'unknown namespace' }} /
          tenant {{ storageExpansionFinalize.tenantName || 'unknown tenant' }} /
          service account {{ storageExpansionFinalize.serviceAccount || 'unknown service account' }} /
          failures {{ storageExpansionFinalize.failedCount || 0 }} /
          backend dry-run {{ storageExpansionFinalize.runBackendDryRunRunner ? 'selected' : 'missing' }} /
          apply {{ storageExpansionFinalize.runBackendApply ? 'selected' : 'missing' }} /
          confirm apply {{ storageExpansionFinalize.confirmApply ? 'yes' : 'no' }} /
          telemetry {{ storageExpansionFinalize.runStorageBackendTelemetry ? 'selected' : 'missing' }} /
          impersonate {{ storageExpansionFinalize.impersonateRunner ? 'yes' : 'no' }}
        </small>
        <small
          v-if="storageExpansionFinalizeWindowSummary"
          data-testid="readiness-storage-expansion-finalize-window"
        >
          Window: {{ storageExpansionFinalizeWindowSummary }}
        </small>
        <small v-if="storageExpansionFinalizeEvidenceSummary" data-testid="readiness-storage-expansion-finalize-evidence">
          Evidence: {{ storageExpansionFinalizeEvidenceSummary }}
        </small>
        <small v-if="storageExpansionFinalize.secretPolicy">
          {{ storageExpansionFinalize.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="storageExpansionFinalizeSteps.length > 0"
        class="readiness-evidence-plan-actions readiness-storage-expansion-finalize-steps"
        data-testid="readiness-storage-expansion-finalize-steps"
      >
        <li
          v-for="step in storageExpansionFinalizeSteps.slice(0, 4)"
          :key="step.name"
        >
          <span>
            <strong>{{ step.result || 'unknown' }} / {{ step.name }}</strong>
            <small>{{ step.notes || 'exit code ' + (step.exitCode || 0) }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="storageExpansionFinalizeGaps.length > 0"
        class="readiness-evidence-plan-actions readiness-storage-expansion-finalize-gaps"
        data-testid="readiness-storage-expansion-finalize-gaps"
      >
        <li
          v-for="gap in storageExpansionFinalizeGaps.slice(0, 3)"
          :key="gap"
        >
          <span>
            <strong>Gap</strong>
            <small>{{ gap }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="kubernetesHaDrReadiness.result"
        class="readiness-invocation-summary"
        data-testid="readiness-kubernetes-ha-dr-summary"
      >
        <strong>Kubernetes HA/DR readiness: {{ kubernetesHaDrReadiness.result }}</strong>
        <small>
          {{ kubernetesHaDrReadiness.namespace || 'unknown namespace' }} /
          failures {{ kubernetesHaDrReadiness.failureCount || 0 }} /
          checks {{ kubernetesHaDrChecks.length }}
        </small>
        <small
          v-if="kubernetesHaDrInputSummary"
          data-testid="readiness-kubernetes-ha-dr-inputs"
        >
          Inputs: {{ kubernetesHaDrInputSummary }}
        </small>
      </div>
      <ol
        v-if="kubernetesHaDrChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-kubernetes-ha-dr-checks"
        data-testid="readiness-kubernetes-ha-dr-checks"
      >
        <li
          v-for="check in kubernetesHaDrChecks.slice(0, 5)"
          :key="check.name"
        >
          <span>
            <strong>{{ check.passed ? 'PASS' : 'FAIL' }} / {{ check.name }}</strong>
            <small>{{ check.summary || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="kubernetesDrFinalize.result"
        class="readiness-invocation-summary"
        data-testid="readiness-kubernetes-dr-finalize-summary"
      >
        <strong>Kubernetes DR finalizer: {{ kubernetesDrFinalize.result }}</strong>
        <small>
          {{ kubernetesDrFinalize.sourceNamespace || 'unknown source' }} ->
          {{ kubernetesDrFinalize.restoreNamespace || 'unknown restore' }} /
          status {{ kubernetesDrFinalize.status || 'unknown' }} /
          backup {{ kubernetesDrFinalize.backupTimestamp || 'unset' }} /
          confirmed {{ kubernetesDrFinalize.confirmRestore ? 'yes' : 'no' }} /
          failed steps {{ kubernetesDrFinalize.failedStepCount || 0 }}
        </small>
        <small
          v-if="kubernetesDrFinalizeWindowSummary"
          data-testid="readiness-kubernetes-dr-finalize-window"
        >
          Window: {{ kubernetesDrFinalizeWindowSummary }}
        </small>
        <small
          data-testid="readiness-kubernetes-dr-finalize-options"
        >
          Options: {{ kubernetesDrFinalizeOptionSummary }}
        </small>
        <small
          v-if="kubernetesDrFinalizeCommandSummary"
          data-testid="readiness-kubernetes-dr-finalize-commands"
        >
          Commands: {{ kubernetesDrFinalizeCommandSummary }}
        </small>
        <small v-if="kubernetesDrFinalize.secretPolicy">
          {{ kubernetesDrFinalize.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="kubernetesDrFinalizeSteps.length > 0"
        class="readiness-evidence-plan-actions readiness-kubernetes-dr-finalize-steps"
        data-testid="readiness-kubernetes-dr-finalize-steps"
      >
        <li
          v-for="step in kubernetesDrFinalizeSteps.slice(0, 4)"
          :key="step.name"
        >
          <span>
            <strong>{{ step.result || 'unknown' }} / {{ step.name }}</strong>
            <small>{{ step.notes || 'exit code ' + (step.exitCode || 0) }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="kubernetesDrFinalizeGaps.length > 0"
        class="readiness-evidence-plan-actions readiness-kubernetes-dr-finalize-gaps"
        data-testid="readiness-kubernetes-dr-finalize-gaps"
      >
        <li
          v-for="gap in kubernetesDrFinalizeGaps.slice(0, 3)"
          :key="gap"
        >
          <span>
            <strong>Gap</strong>
            <small>{{ gap }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="iamRbacEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-iam-rbac-evidence-summary"
      >
        <strong>IAM/RBAC evidence: {{ iamRbacEvidence.result }}</strong>
        <small>
          {{ iamRbacEvidence.namespace || 'unknown namespace' }} /
          {{ iamRbacEvidence.serviceAccount || 'unknown service account' }} /
          status {{ iamRbacEvidence.status || 'unknown' }} /
          failures {{ iamRbacEvidence.failedCount || 0 }} /
          backend tests {{ iamRbacEvidence.runBackendPolicyTests ? 'selected' : 'not selected' }} /
          live auth {{ iamRbacEvidence.runKubernetesLiveAuth ? 'selected' : 'not selected' }}
        </small>
        <small
          v-if="iamRbacEvidenceWindowSummary"
          data-testid="readiness-iam-rbac-evidence-window"
        >
          Window: {{ iamRbacEvidenceWindowSummary }}
        </small>
        <small
          v-if="iamRbacEvidenceRunCommandSummary"
          data-testid="readiness-iam-rbac-evidence-run-commands"
        >
          Run commands: {{ iamRbacEvidenceRunCommandSummary }}
        </small>
        <small v-if="iamRbacEvidenceCommandSummary" data-testid="readiness-iam-rbac-evidence-commands">
          Commands: {{ iamRbacEvidenceCommandSummary }}
        </small>
        <small v-if="iamRbacEvidence.secretPolicy">
          {{ iamRbacEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="iamRbacEvidenceSteps.length > 0"
        class="readiness-evidence-plan-actions readiness-iam-rbac-evidence-steps"
        data-testid="readiness-iam-rbac-evidence-steps"
      >
        <li
          v-for="step in iamRbacEvidenceSteps.slice(0, 4)"
          :key="step.name"
        >
          <span>
            <strong>{{ step.result || 'unknown' }} / {{ step.name }}</strong>
            <small>{{ step.notes || 'exit code ' + (step.exitCode || 0) }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="iamRbacEvidenceGaps.length > 0"
        class="readiness-evidence-plan-actions readiness-iam-rbac-evidence-gaps"
        data-testid="readiness-iam-rbac-evidence-gaps"
      >
        <li
          v-for="gap in iamRbacEvidenceGaps.slice(0, 3)"
          :key="gap"
        >
          <span>
            <strong>Gap</strong>
            <small>{{ gap }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="securityEvidence.result || securityEvidence.imageSigning?.result || securityEvidence.containerSecurity?.result"
        class="readiness-invocation-summary"
        data-testid="readiness-security-evidence-summary"
      >
        <strong>Security evidence: {{ securityEvidence.result || 'pending finalizer' }}</strong>
        <small>
          failures {{ securityEvidence.failureCount || 0 }} /
          image {{ securityEvidence.imageSigning?.result || 'missing' }} /
          container {{ securityEvidence.containerSecurity?.result || 'missing' }} /
          image failures {{ securityEvidence.imageSigning?.failureCount || 0 }} /
          container failures {{ securityEvidence.containerSecurity?.failureCount || 0 }}
        </small>
        <small data-testid="readiness-security-evidence-mode">
          Mode: synthetic {{ securityEvidence.allowSyntheticEvidence ? 'allowed' : 'blocked' }}
        </small>
        <small v-if="securityEvidenceImageSummary" data-testid="readiness-security-evidence-images">
          Images: {{ securityEvidenceImageSummary }}
        </small>
        <small v-if="securityEvidenceSignatureSummary" data-testid="readiness-security-evidence-signatures">
          Signatures: {{ securityEvidenceSignatureSummary }}
        </small>
        <small v-if="securityEvidenceContainerSummary" data-testid="readiness-security-evidence-container">
          Container/SBOM: {{ securityEvidenceContainerSummary }}
        </small>
        <small v-if="securityEvidenceSourceSummary" data-testid="readiness-security-evidence-source">
          Source: {{ securityEvidenceSourceSummary }}
        </small>
        <small v-if="securityEvidencePromotedSummary" data-testid="readiness-security-evidence-promoted">
          Promoted: {{ securityEvidencePromotedSummary }}
        </small>
        <small v-if="securityEvidence.secretPolicy">
          {{ securityEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="securityEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-security-evidence-checks"
        data-testid="readiness-security-evidence-checks"
      >
        <li
          v-for="check in securityEvidenceChecks.slice(0, 4)"
          :key="check.name"
        >
          <span>
            <strong>{{ check.passed ? 'PASS' : 'FAIL' }} / {{ check.name }}</strong>
            <small>{{ check.detail || check.evidencePath || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="secretRotationEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-secret-rotation-evidence-summary"
      >
        <strong>Secret rotation evidence: {{ secretRotationEvidence.result }}</strong>
        <small>
          {{ secretRotationEvidence.environmentName || 'unknown env' }} /
          {{ secretRotationEvidence.targetCluster || 'unknown cluster' }} /
          {{ secretRotationEvidence.operatorName || 'unknown operator' }} /
          core {{ secretRotationEvidence.coreRotatedCount || 0 }} of {{ secretRotationEvidence.coreRequiredCount || 0 }} /
          rotated {{ secretRotationEvidence.rotatedCount || 0 }} /
          failures {{ secretRotationEvidence.failureCount || 0 }} /
          planned {{ secretRotationEvidence.plannedCount || 0 }}
        </small>
        <small
          v-if="secretRotationWindowSummary"
          data-testid="readiness-secret-rotation-window"
        >
          Rotation window: {{ secretRotationWindowSummary }}
        </small>
        <small
          v-if="secretRotationEvidenceRefSummary"
          data-testid="readiness-secret-rotation-evidence-refs"
        >
          Evidence refs: {{ secretRotationEvidenceRefSummary }}
        </small>
        <small
          v-if="secretRotationConfirmationSummary"
          data-testid="readiness-secret-rotation-confirmations"
        >
          Confirmations: {{ secretRotationConfirmationSummary }}
        </small>
        <small v-if="secretRotationEvidence.secretPolicy">
          {{ secretRotationEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="secretRotationEvidenceRotations.length > 0"
        class="readiness-evidence-plan-actions readiness-secret-rotation-evidence-rotations"
        data-testid="readiness-secret-rotation-evidence-rotations"
      >
        <li
          v-for="rotation in secretRotationEvidenceRotations.slice(0, 4)"
          :key="rotation.id || rotation.name"
        >
          <span>
            <strong>{{ rotation.rotated ? 'ROTATED' : 'PENDING' }} / {{ rotation.core ? 'core' : 'optional' }} / {{ rotation.name || rotation.id }}</strong>
            <small>{{ rotation.note || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="secretRotationEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-secret-rotation-evidence-checks"
        data-testid="readiness-secret-rotation-evidence-checks"
      >
        <li
          v-for="check in secretRotationEvidenceChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="commercialIntegrationEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-commercial-integration-evidence-summary"
      >
        <strong>Commercial integration evidence: {{ commercialIntegrationEvidence.result }}</strong>
        <small>
          {{ commercialIntegrationEvidence.environmentName || 'unknown env' }} /
          {{ commercialIntegrationEvidence.targetCluster || 'unknown cluster' }} /
          {{ commercialIntegrationEvidence.operatorName || 'unknown operator' }} /
          verified {{ commercialIntegrationEvidence.verifiedCount || 0 }} of {{ commercialIntegrationEvidence.integrationCount || 0 }} /
          required {{ commercialIntegrationEvidence.requiredVerifiedCount || 0 }} of {{ commercialIntegrationEvidence.requiredCount || 0 }} /
          payment adapters {{ commercialIntegrationEvidence.paymentProviderAdapterReadinessStatus || 'unknown' }} /
          failures {{ commercialIntegrationEvidence.failureCount || 0 }} /
          planned {{ commercialIntegrationEvidence.plannedCount || 0 }}
        </small>
        <small
          v-if="commercialIntegrationAdapterSummary"
          data-testid="readiness-commercial-integration-adapters"
        >
          Adapter readiness: {{ commercialIntegrationAdapterSummary }}
        </small>
        <small v-if="commercialIntegrationEvidence.scopePolicy">
          {{ commercialIntegrationEvidence.scopePolicy }}
        </small>
        <small v-if="commercialIntegrationEvidence.secretPolicy">
          {{ commercialIntegrationEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="commercialIntegrationEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-commercial-integration-evidence-checks"
        data-testid="readiness-commercial-integration-evidence-checks"
      >
        <li
          v-for="check in commercialIntegrationEvidenceChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || check.evidenceRef || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="commercialApprovalEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-commercial-approval-evidence-summary"
      >
        <strong>Commercial approval evidence: {{ commercialApprovalEvidence.result }}</strong>
        <small>
          {{ commercialApprovalEvidence.productVersion || 'unknown version' }} /
          approved by {{ commercialApprovalEvidence.approvedBy || 'unknown' }} /
          approved at {{ commercialApprovalEvidence.approvedAt || 'unknown time' }} /
          passed {{ commercialApprovalEvidence.passedCount || 0 }} /
          failures {{ commercialApprovalEvidence.failureCount || 0 }} /
          checks {{ commercialApprovalEvidence.checkCount || 0 }} /
          commercial proposal approvals {{ commercialApprovalEvidence.pricingPolicyProposalCommercialApprovedCount || 0 }} /
          price-list approvals {{ commercialApprovalEvidence.pricingPolicyProposalApprovedPriceListCount || 0 }}
        </small>
        <small
          v-if="commercialApprovalEvidenceRefSummary"
          data-testid="readiness-commercial-approval-evidence-refs"
        >
          Evidence refs: {{ commercialApprovalEvidenceRefSummary }}
        </small>
        <small
          v-if="commercialApprovalConfirmationSummary"
          data-testid="readiness-commercial-approval-confirmations"
        >
          Confirmations: {{ commercialApprovalConfirmationSummary }}
        </small>
        <small v-if="commercialApprovalEvidence.scopePolicy">
          {{ commercialApprovalEvidence.scopePolicy }}
        </small>
        <small v-if="commercialApprovalEvidence.secretPolicy">
          {{ commercialApprovalEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="commercialApprovalEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-commercial-approval-evidence-checks"
        data-testid="readiness-commercial-approval-evidence-checks"
      >
        <li
          v-for="check in commercialApprovalEvidenceChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || check.evidenceRef || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="enterpriseAuthSmokeEvidence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-enterprise-auth-smoke-evidence-summary"
      >
        <strong>Enterprise auth smoke: {{ enterpriseAuthSmokeEvidence.result }}</strong>
        <small>
          mode {{ enterpriseAuthSmokeEvidence.executionMode || 'unknown' }} /
          OIDC {{ enterpriseAuthSmokeEvidence.requireOidc ? 'required' : 'optional' }} /
          LDAP {{ enterpriseAuthSmokeEvidence.requireLdap ? 'required' : 'optional' }} /
          audit {{ enterpriseAuthSmokeEvidence.requireAuditEvents ? 'required' : 'optional' }} /
          pass {{ enterpriseAuthSmokeEvidence.passCount || 0 }} /
          fail {{ enterpriseAuthSmokeEvidence.failCount || 0 }} /
          blocked {{ enterpriseAuthSmokeEvidence.blockedCount || 0 }} /
          planned {{ enterpriseAuthSmokeEvidence.plannedCount || 0 }} /
          skipped {{ enterpriseAuthSmokeEvidence.skippedCount || 0 }}
        </small>
        <small
          v-if="enterpriseAuthSmokeEvidence.apiBase"
          data-testid="readiness-enterprise-auth-smoke-api-base"
        >
          API base: {{ enterpriseAuthSmokeEvidence.apiBase }}
        </small>
        <small
          v-if="enterpriseAuthSmokeInputSummary"
          data-testid="readiness-enterprise-auth-smoke-inputs"
        >
          Inputs: {{ enterpriseAuthSmokeInputSummary }}
        </small>
        <small
          v-if="enterpriseAuthSmokeScopeOutSummary"
          data-testid="readiness-enterprise-auth-smoke-scope-out"
        >
          Scope-out: {{ enterpriseAuthSmokeScopeOutSummary }}
        </small>
        <small v-if="enterpriseAuthSmokeEvidence.secretPolicy">
          {{ enterpriseAuthSmokeEvidence.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="enterpriseAuthSmokeEvidenceChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-enterprise-auth-smoke-evidence-checks"
        data-testid="readiness-enterprise-auth-smoke-evidence-checks"
      >
        <li
          v-for="check in enterpriseAuthSmokeEvidenceChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.category || '-' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || check.endpoint || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="dataFlowStoragePlan.result"
        class="readiness-invocation-summary"
        data-testid="readiness-data-flow-storage-plan-summary"
      >
        <strong>Data-flow storage plan: {{ dataFlowStoragePlan.result }}</strong>
        <small>
          {{ dataFlowStoragePlan.environmentName || 'unknown env' }} /
          {{ dataFlowStoragePlan.targetCluster || 'unknown cluster' }} /
          store {{ dataFlowStoragePlan.candidateStore || 'unknown' }} /
          peak {{ formatCount(dataFlowStoragePlan.expectedPeakEventsPerDay || 0) }}/day /
          query {{ dataFlowStoragePlan.expectedQueryWindowDays || 0 }}d /
          p95 <= {{ dataFlowStoragePlan.targetP95QueryLatencyMs || 0 }}ms /
          passed {{ dataFlowStoragePlan.passedCount || 0 }} of {{ dataFlowStoragePlan.checkCount || 0 }}
        </small>
        <small
          v-if="dataFlowQueryPlanEvidence.provided || dataFlowQueryPlanEvidence.expectedFormatVersion"
          data-testid="readiness-data-flow-query-plan-evidence-summary"
        >
          Query plan evidence:
          {{ dataFlowQueryPlanEvidence.result || 'missing' }} /
          passed {{ dataFlowQueryPlanEvidence.passedCount || 0 }} of {{ dataFlowQueryPlanEvidence.checkCount || 0 }} /
          failed {{ dataFlowQueryPlanEvidence.failedCount || 0 }}
        </small>
        <small v-if="dataFlowStoragePlan.scopePolicy">
          {{ dataFlowStoragePlan.scopePolicy }}
        </small>
      </div>
      <ol
        v-if="dataFlowStoragePlanChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-data-flow-storage-plan-checks"
        data-testid="readiness-data-flow-storage-plan-checks"
      >
        <li
          v-for="check in dataFlowStoragePlanChecks.slice(0, 3)"
          :key="check.id || check.title"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.title || check.id }}</strong>
            <small>{{ check.detail || check.nextAction || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="dataFlowStorageTransitionRunbook.result"
        class="readiness-invocation-summary"
        data-testid="readiness-data-flow-storage-transition-runbook-summary"
      >
        <strong>Data-flow transition runbook: {{ dataFlowStorageTransitionRunbook.result }}</strong>
        <small>
          {{ dataFlowStorageTransitionRunbook.environmentName || 'unknown env' }} /
          {{ dataFlowStorageTransitionRunbook.targetCluster || 'unknown cluster' }} /
          {{ dataFlowStorageTransitionRunbook.operatorName || 'unknown operator' }} /
          plan {{ dataFlowStorageTransitionRunbook.storagePlanResult || '-' }} /
          store {{ dataFlowStorageTransitionRunbook.candidateStore || '-' }} /
          p95 <= {{ dataFlowStorageTransitionRunbook.targetP95QueryLatencyMs || 0 }}ms /
          failures {{ dataFlowStorageTransitionRunbook.failureCount || 0 }} of {{ dataFlowStorageTransitionRunbook.checkCount || 0 }}
        </small>
        <small
          v-if="dataFlowStorageTransitionRunbookConfirmationSummary"
          data-testid="readiness-data-flow-storage-transition-runbook-confirmations"
        >
          Confirmations: {{ dataFlowStorageTransitionRunbookConfirmationSummary }}
        </small>
        <small v-if="dataFlowStorageTransitionRunbook.evidenceRef">
          evidence {{ dataFlowStorageTransitionRunbook.evidenceRef }}
        </small>
        <small v-if="dataFlowStorageTransitionRunbook.scopePolicy">
          {{ dataFlowStorageTransitionRunbook.scopePolicy }}
        </small>
      </div>
      <ol
        v-if="dataFlowStorageTransitionRunbookChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-data-flow-storage-transition-runbook-checks"
        data-testid="readiness-data-flow-storage-transition-runbook-checks"
      >
        <li
          v-for="check in dataFlowStorageTransitionRunbookChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="operationsHandoffPackage.result"
        class="readiness-invocation-summary"
        data-testid="readiness-handoff-package-summary"
      >
        <strong>Handoff package: {{ operationsHandoffPackage.result }}</strong>
        <small>
          {{ operationsHandoffPackage.environmentName || 'unknown env' }} /
          {{ operationsHandoffPackage.targetCluster || 'unknown cluster' }} /
          failures {{ operationsHandoffPackage.failureCount || 0 }} /
          planned {{ operationsHandoffPackage.plannedCount || 0 }} /
          checks {{ operationsHandoffPackage.checkCount || 0 }}
        </small>
        <small v-if="operationsHandoffPackage.secretPolicy">
          {{ operationsHandoffPackage.secretPolicy }}
        </small>
        <small
          v-if="operationsHandoffPackageEvidenceRefSummary"
          data-testid="readiness-handoff-package-evidence-refs"
        >
          Evidence refs: {{ operationsHandoffPackageEvidenceRefSummary }}
        </small>
        <small
          v-if="operationsHandoffPackageReadinessSnapshot.result"
          data-testid="readiness-handoff-package-readiness-snapshot-summary"
        >
          Readiness snapshot:
          {{ operationsHandoffPackageReadinessSnapshot.result }} /
          passed {{ operationsHandoffPackageReadinessSnapshot.passedCount || 0 }} /
          pending {{ operationsHandoffPackageReadinessSnapshot.pendingCount || 0 }} /
          checks {{ operationsHandoffPackageReadinessSnapshot.checkCount || 0 }}
        </small>
        <small
          v-if="operationsHandoffPackageConvergenceSnapshot.result"
          data-testid="readiness-handoff-package-convergence-snapshot-summary"
        >
          Convergence snapshot:
          {{ operationsHandoffPackageConvergenceSnapshot.result }} /
          readiness {{ operationsHandoffPackageConvergenceSnapshot.readinessResult || '-' }} /
          sync {{ operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncReady ? 'ready' : 'not-ready' }} /
          source {{ operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncSourceReportResult || 'unknown' }} /
          finalizer failed {{ operationsHandoffPackageConvergenceSnapshot.finalizerFailedCount || 0 }} /
          finalizer gaps {{ operationsHandoffPackageConvergenceSnapshot.finalizerGapCount || 0 }}
          <template v-if="operationsHandoffPackageConvergenceSnapshot.finalizerFailedCountValid === false">
            / finalizer count invalid {{ operationsHandoffPackageConvergenceSnapshot.finalizerFailedCountRaw || 'missing' }}
          </template>
          <template v-if="operationsHandoffPackageConvergenceSnapshot.finalizerGapCountValid === false">
            / finalizer gap invalid {{ operationsHandoffPackageConvergenceSnapshot.finalizerGapCountRaw || 'missing' }}
          </template>
          <template v-if="operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncReadyValid === false">
            / sync ready invalid {{ operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncReadyRaw || 'missing' }}
          </template>
          <template v-if="operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncFailedCountValid === false">
            / sync count invalid {{ operationsHandoffPackageConvergenceSnapshot.kubernetesReportSyncFailedCountRaw || 'missing' }}
          </template>
        </small>
        <small
          v-if="operationsHandoffPackageDataFlowStoragePlanSnapshot.result"
          data-testid="readiness-handoff-package-data-flow-snapshot-summary"
        >
          Data-flow snapshot:
          {{ operationsHandoffPackageDataFlowStoragePlanSnapshot.result }} /
          store {{ operationsHandoffPackageDataFlowStoragePlanSnapshot.candidateStore || '-' }} /
          passed {{ operationsHandoffPackageDataFlowStoragePlanSnapshot.passedCount || 0 }} /
          pending {{ operationsHandoffPackageDataFlowStoragePlanSnapshot.pendingCount || 0 }} /
          query-plan {{ operationsHandoffPackageDataFlowQueryPlanSnapshot.result || '-' }}
        </small>
        <small
          v-if="operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot.result"
          data-testid="readiness-handoff-package-data-flow-transition-runbook-snapshot-summary"
        >
          Data-flow runbook snapshot:
          {{ operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot.result }} /
          plan {{ operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot.storagePlanResult || '-' }} /
          store {{ operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot.candidateStore || '-' }} /
          failures {{ operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot.failureCount || 0 }}
        </small>
        <small
          v-if="operationsHandoffPackageSecretRotationSnapshot.result"
          data-testid="readiness-handoff-package-secret-rotation-snapshot-summary"
        >
          Secret rotation snapshot:
          {{ operationsHandoffPackageSecretRotationSnapshot.result }} /
          core {{ operationsHandoffPackageSecretRotationSnapshot.coreRotatedCount || 0 }} of {{ operationsHandoffPackageSecretRotationSnapshot.coreRequiredCount || 0 }} /
          failures {{ operationsHandoffPackageSecretRotationSnapshot.failureCount || 0 }}
        </small>
        <small
          v-if="operationsHandoffPackageCommercialIntegrationSnapshot.result"
          data-testid="readiness-handoff-package-commercial-integration-snapshot-summary"
        >
          Commercial integration snapshot:
          {{ operationsHandoffPackageCommercialIntegrationSnapshot.result }} /
          required {{ operationsHandoffPackageCommercialIntegrationSnapshot.requiredVerifiedCount || 0 }} of {{ operationsHandoffPackageCommercialIntegrationSnapshot.requiredCount || 0 }} /
          adapters {{ operationsHandoffPackageCommercialIntegrationSnapshot.paymentProviderAdapterReadinessStatus || '-' }} /
          failures {{ operationsHandoffPackageCommercialIntegrationSnapshot.failureCount || 0 }}
        </small>
        <small
          v-if="operationsHandoffPackageCommercialApprovalSnapshot.result"
          data-testid="readiness-handoff-package-commercial-approval-snapshot-summary"
        >
          Commercial approval snapshot:
          {{ operationsHandoffPackageCommercialApprovalSnapshot.result }} /
          {{ operationsHandoffPackageCommercialApprovalSnapshot.productVersion || 'unknown version' }} /
          price-list {{ operationsHandoffPackageCommercialApprovalSnapshot.pricingPolicyProposalApprovedPriceListCount || 0 }} /
          failures {{ operationsHandoffPackageCommercialApprovalSnapshot.failureCount || 0 }}
        </small>
        <small
          v-if="operationsHandoffPackageEnterpriseAuthSmokeSnapshot.result"
          data-testid="readiness-handoff-package-enterprise-auth-snapshot-summary"
        >
          Enterprise auth snapshot:
          {{ operationsHandoffPackageEnterpriseAuthSmokeSnapshot.result }} /
          mode {{ operationsHandoffPackageEnterpriseAuthSmokeSnapshot.executionMode || '-' }} /
          pass {{ operationsHandoffPackageEnterpriseAuthSmokeSnapshot.passCount || 0 }} /
          fail {{ operationsHandoffPackageEnterpriseAuthSmokeSnapshot.failCount || 0 }} /
          blocked {{ operationsHandoffPackageEnterpriseAuthSmokeSnapshot.blockedCount || 0 }} /
          scope-out {{ operationsHandoffPackageEnterpriseAuthSmokeScopeOutSummary || '-' }}
        </small>
        <small
          v-if="operationsHandoffPackageMonitoringThresholdSnapshot.result"
          data-testid="readiness-handoff-package-monitoring-threshold-snapshot-summary"
        >
          Monitoring threshold snapshot:
          {{ operationsHandoffPackageMonitoringThresholdSnapshot.result }} /
          alerts {{ operationsHandoffPackageMonitoringThresholdSnapshot.mappedAlertCount || 0 }} of {{ operationsHandoffPackageMonitoringThresholdSnapshot.requiredAlertCount || 0 }} /
          routes {{ operationsHandoffPackageMonitoringThresholdSnapshot.routeCount || 0 }} /
          failures {{ operationsHandoffPackageMonitoringThresholdSnapshot.failureCount || 0 }}
        </small>
      </div>
      <ol
        v-if="operationsHandoffPackageChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-handoff-package-checks"
        data-testid="readiness-handoff-package-checks"
      >
        <li
          v-for="check in operationsHandoffPackageChecks.slice(0, 3)"
          :key="check.id || check.name"
        >
          <span>
            <strong>{{ check.status || 'UNKNOWN' }} / {{ check.name || check.id }}</strong>
            <small>{{ check.detail || check.evidenceRef || 'detail unavailable' }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="operationsEvidenceHandoff.result"
        class="readiness-invocation-summary"
        data-testid="readiness-evidence-handoff-summary"
      >
        <strong>Handoff: {{ operationsEvidenceHandoff.result }}</strong>
        <small>
          Next {{ operationsEvidenceHandoffNextStep.code || 'none' }} /
          {{ operationsEvidenceHandoff.readyStageCount }} of {{ operationsEvidenceHandoff.stageCount }} stages ready /
          {{ operationsEvidenceHandoff.blockedActionCount }} blocked /
          {{ operationsEvidenceHandoff.missingWorkflowRunCount }} missing runs /
          {{ operationsEvidenceHandoff.missingRequiredArtifactCount }} missing artifacts /
          finalizer gaps {{ operationsEvidenceHandoff.finalizerGapCount || 0 }}
        </small>
        <small v-if="operationsEvidenceHandoffNextStep.reason">
          {{ operationsEvidenceHandoffNextStep.reason }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsEvidenceHandoffNextStep.command"
            data-testid="readiness-evidence-handoff-command-copy-button"
            type="button"
            class="ghost"
            title="Copy operations handoff next command"
            @click="copyReadinessRemediationCommand(operationsEvidenceHandoffNextStep.command)"
          >
            Next Command
          </button>
        </div>
      </div>
      <ol
        v-if="operationsEvidenceHandoffStages.length > 0"
        class="readiness-evidence-plan-actions readiness-evidence-handoff-stages"
        data-testid="readiness-evidence-handoff-stages"
      >
        <li
          v-for="stage in operationsEvidenceHandoffStages.slice(0, 3)"
          :key="stage.name"
        >
          <span>
            <strong>{{ stage.name }} 쨌 {{ formatEvidenceHandoffStageState(stage) }}</strong>
            <small>{{ formatEvidenceHandoffStageMeta(stage) }}</small>
            <code v-if="stage.command">{{ stage.command }}</code>
          </span>
          <button
            v-if="stage.command"
            data-testid="readiness-evidence-handoff-stage-command-copy-button"
            type="button"
            class="ghost"
            title="Copy handoff stage command"
            @click="copyReadinessRemediationCommand(stage.command)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsReadinessConvergence.result"
        class="readiness-invocation-summary"
        data-testid="readiness-convergence-summary"
      >
        <strong>Convergence: {{ operationsReadinessConvergence.result }}</strong>
        <small>
          bottleneck {{ operationsReadinessConvergenceBottleneck.code || 'none' }} /
          readiness {{ operationsReadinessConvergence.readinessResult || 'unknown' }} /
          finalizer {{ operationsReadinessConvergence.finalizerResult || 'unknown' }} /
          k8s sync {{ operationsReadinessConvergence.kubernetesReportSyncResult || 'unknown' }} /
          finalizer failed {{ operationsReadinessConvergence.finalizerFailedCount || 0 }} /
          finalizer gaps {{ operationsReadinessConvergence.finalizerGapCount || 0 }} /
          {{ operationsReadinessConvergence.readyStageCount }} of {{ operationsReadinessConvergence.stageCount }} stages ready
          <template v-if="operationsReadinessConvergence.finalizerFailedCountValid === false">
            / finalizer count invalid {{ operationsReadinessConvergence.finalizerFailedCountRaw || 'missing' }}
          </template>
        </small>
        <small v-if="operationsReadinessConvergence.kubernetesReportSyncConfigMapName">
          report sync {{ operationsReadinessConvergence.kubernetesReportSyncConfigMapName }} /
          {{ operationsReadinessConvergence.kubernetesReportSyncReady ? 'sync ready' : 'sync not-ready' }} /
          source {{ operationsReadinessConvergence.kubernetesReportSyncSourceReportResult || 'unknown' }}
          <template v-if="operationsReadinessConvergence.kubernetesReportSyncFailedCountValid === false">
            / sync count invalid {{ operationsReadinessConvergence.kubernetesReportSyncFailedCountRaw || 'missing' }}
          </template>
        </small>
        <small v-if="operationsReadinessConvergenceBottleneck.reason">
          {{ operationsReadinessConvergenceBottleneck.reason }}
        </small>
        <small v-if="operationsReadinessConvergence.kubernetesReportSyncWorkflowNote">
          {{ operationsReadinessConvergence.kubernetesReportSyncWorkflowNote }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsReadinessConvergenceBottleneck.command"
            data-testid="readiness-convergence-command-copy-button"
            type="button"
            class="ghost"
            title="Copy convergence bottleneck command"
            @click="copyReadinessRemediationCommand(operationsReadinessConvergenceBottleneck.command)"
          >
            Bottleneck Command
          </button>
          <button
            v-if="operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand"
            data-testid="readiness-convergence-workflow-command-copy-button"
            type="button"
            class="ghost"
            title="Copy convergence workflow command"
            @click="copyReadinessRemediationCommand(operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand)"
          >
            Workflow Command
          </button>
        </div>
      </div>
      <ol
        v-if="operationsReadinessConvergenceCommands.length > 0"
        class="readiness-evidence-plan-actions readiness-convergence-commands"
        data-testid="readiness-convergence-commands"
      >
        <li
          v-for="command in operationsReadinessConvergenceCommands.slice(0, 3)"
          :key="`${command.order}-${command.name}`"
        >
          <span>
            <strong>{{ command.order }}. {{ command.name || 'Convergence command' }}</strong>
            <small>{{ command.reason || 'reason unavailable' }}</small>
            <code v-if="command.command">{{ command.command }}</code>
          </span>
          <button
            v-if="command.command"
            data-testid="readiness-convergence-command-list-copy-button"
            type="button"
            class="ghost"
            title="Copy convergence recommended command"
            @click="copyReadinessRemediationCommand(command.command)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="kubernetesOperationsReportSync.result"
        class="readiness-invocation-summary"
        data-testid="readiness-kubernetes-report-sync-summary"
      >
        <strong>K8s report sync: {{ kubernetesOperationsReportSync.result }}</strong>
        <small>
          namespace {{ kubernetesOperationsReportSync.namespace || 'unknown' }} /
          configmap {{ kubernetesOperationsReportSync.configMapName || 'unknown' }} /
          key {{ kubernetesOperationsReportSync.configMapKey || 'unknown' }} /
          source {{ kubernetesOperationsReportSync.sourceReportResult || 'unknown' }} /
          plan {{ kubernetesOperationsReportSync.publishDataFlowStoragePlanToConfigMap ? 'mounted' : 'optional' }} /
          runbook {{ kubernetesOperationsReportSync.publishDataFlowStorageTransitionRunbookToConfigMap ? (kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookResult || 'mounted') : 'optional' }} /
          checks {{ kubernetesOperationsReportSync.checkCount || 0 }} /
          failed {{ kubernetesOperationsReportSync.failedCount || 0 }}
        </small>
        <small
          v-if="kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookConfigMapKey"
          data-testid="readiness-kubernetes-report-sync-runbook-summary"
        >
          runbook key {{ kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookConfigMapKey }} /
          store {{ kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCandidateStore || 'unknown' }} /
          plan {{ kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookStoragePlanResult || 'unknown' }} /
          failures {{ kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookFailureCount || 0 }}/{{ kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCheckCount || 0 }}
        </small>
        <small v-if="kubernetesOperationsReportSync.sourceReportSha256">
          sha256 {{ kubernetesOperationsReportSync.sourceReportSha256 }}
        </small>
        <small v-if="kubernetesOperationsReportSync.safetyPolicy">
          {{ kubernetesOperationsReportSync.safetyPolicy }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="kubernetesOperationsReportSync.serverDryRunCommand"
            data-testid="readiness-kubernetes-report-sync-server-dry-run-copy-button"
            type="button"
            class="ghost"
            title="Copy Kubernetes report sync server dry-run command"
            @click="copyReadinessRemediationCommand(kubernetesOperationsReportSync.serverDryRunCommand)"
          >
            Server Dry-run
          </button>
          <button
            v-if="kubernetesOperationsReportSync.applyCommand"
            data-testid="readiness-kubernetes-report-sync-apply-copy-button"
            type="button"
            class="ghost"
            title="Copy Kubernetes report sync apply command"
            @click="copyReadinessRemediationCommand(kubernetesOperationsReportSync.applyCommand)"
          >
            Apply
          </button>
        </div>
      </div>
      <ol
        v-if="kubernetesOperationsReportSyncChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-kubernetes-report-sync-checks"
        data-testid="readiness-kubernetes-report-sync-checks"
      >
        <li
          v-for="check in kubernetesOperationsReportSyncChecks.slice(0, 3)"
          :key="check.name"
        >
          <span>
            <strong>{{ check.name || 'sync check' }} - {{ check.passed ? 'passed' : 'failed' }}</strong>
            <small>{{ formatKubernetesReportSyncCheckMeta(check) }}</small>
            <code v-if="check.command">{{ check.command }}</code>
          </span>
          <button
            v-if="check.command"
            data-testid="readiness-kubernetes-report-sync-check-command-copy-button"
            type="button"
            class="ghost"
            title="Copy Kubernetes report sync check command"
            @click="copyReadinessRemediationCommand(check.command)"
          >
            Copy
          </button>
        </li>
      </ol>
      <ol
        v-if="operationsEvidencePlanActions.length > 0"
        class="readiness-evidence-plan-actions"
        data-testid="readiness-evidence-plan-actions"
      >
        <li
          v-for="action in operationsEvidencePlanActions.slice(0, 3)"
          :key="`${action.order}-${action.name}`"
        >
          <span>
            <strong>{{ action.order }}. {{ action.name }}</strong>
            <small>{{ formatEvidencePlanActionMeta(action) }}</small>
            <code v-if="evidencePlanActionCommand(action)">{{ evidencePlanActionCommand(action) }}</code>
          </span>
          <button
            v-if="evidencePlanActionCommand(action)"
            data-testid="readiness-evidence-plan-command-copy-button"
            type="button"
            class="ghost"
            title="Copy evidence plan command"
            @click="copyReadinessRemediationCommand(evidencePlanActionCommand(action))"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsEvidenceInvocation.result"
        class="readiness-invocation-summary"
        data-testid="readiness-evidence-invocation-summary"
      >
        <strong>Invocation: {{ operationsEvidenceInvocation.result }}</strong>
        <small>
          {{ operationsEvidenceInvocation.selectedActionCount }} selected /
          {{ operationsEvidenceInvocation.plannedCount }} planned /
          {{ operationsEvidenceInvocation.blockedCount }} blocked /
          {{ operationsEvidenceInvocation.failedCount }} failed
        </small>
      </div>
      <ol
        v-if="operationsEvidenceInvocationActions.length > 0"
        class="readiness-evidence-plan-actions readiness-evidence-invocation-actions"
        data-testid="readiness-evidence-invocation-actions"
      >
        <li
          v-for="action in operationsEvidenceInvocationActions.slice(0, 3)"
          :key="`${action.order}-${action.status}-${action.name}`"
        >
          <span>
            <strong>{{ action.order }}. {{ action.name }} · {{ action.status || 'planned' }}</strong>
            <small>{{ formatEvidenceInvocationActionMeta(action) }}</small>
            <small v-if="formatInvocationBlockReasons(action)">{{ formatInvocationBlockReasons(action) }}</small>
            <code v-if="action.command">{{ action.command }}</code>
          </span>
          <button
            v-if="action.command"
            data-testid="readiness-evidence-invocation-command-copy-button"
            type="button"
            class="ghost"
            title="Copy evidence invocation command"
            @click="copyReadinessRemediationCommand(action.command)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsInvocationUnblockPlan.result"
        class="readiness-invocation-summary"
        data-testid="readiness-invocation-unblock-summary"
      >
        <strong>Unblock plan: {{ operationsInvocationUnblockPlan.result }}</strong>
        <small>
          {{ operationsInvocationUnblockPlan.blockedCount }} blocked /
          {{ operationsInvocationUnblockPlan.requiredPlaceholderCount }} placeholders /
          {{ operationsInvocationUnblockPlan.ambiguousRepeatedPlaceholderCount }} ambiguous
        </small>
        <small v-if="formatInvocationUnblockConfirmationMeta()">
          {{ formatInvocationUnblockConfirmationMeta() }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsInvocationUnblockPlan.confirmedPlanCommand"
            data-testid="readiness-invocation-unblock-confirmed-command-copy-button"
            type="button"
            class="ghost"
            title="Copy confirmed invocation plan command"
            @click="copyReadinessRemediationCommand(operationsInvocationUnblockPlan.confirmedPlanCommand)"
          >
            Confirmed Plan
          </button>
          <button
            v-if="operationsInvocationUnblockPlan.blockedOnlyPlanCommand"
            data-testid="readiness-invocation-unblock-blocked-command-copy-button"
            type="button"
            class="ghost"
            title="Copy blocked-only invocation plan command"
            @click="copyReadinessRemediationCommand(operationsInvocationUnblockPlan.blockedOnlyPlanCommand)"
          >
            Blocked Only
          </button>
        </div>
      </div>
      <ol
        v-if="operationsInvocationUnblockActions.length > 0"
        class="readiness-evidence-plan-actions readiness-invocation-unblock-actions"
        data-testid="readiness-invocation-unblock-actions"
      >
        <li
          v-for="action in operationsInvocationUnblockActions.slice(0, 3)"
          :key="`${action.order}-${action.status}-${action.name}`"
        >
          <span>
            <strong>{{ action.order }}. {{ action.name }} 쨌 {{ action.status || 'action required' }}</strong>
            <small>{{ formatInvocationUnblockActionMeta(action) }}</small>
            <small v-if="formatInvocationUnblockInputs(action)">{{ formatInvocationUnblockInputs(action) }}</small>
            <code v-if="action.planCommand">{{ action.planCommand }}</code>
          </span>
          <button
            v-if="action.planCommand"
            data-testid="readiness-invocation-unblock-action-command-copy-button"
            type="button"
            class="ghost"
            title="Copy unblock action plan command"
            @click="copyReadinessRemediationCommand(action.planCommand)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsDispatchPreflight.result"
        class="readiness-invocation-summary"
        data-testid="readiness-dispatch-preflight-summary"
      >
        <strong>Dispatch preflight: {{ operationsDispatchPreflight.result }}</strong>
        <small>
          {{ operationsDispatchPreflight.selectedActionCount }} selected /
          {{ operationsDispatchPreflight.failedCheckCount }} failed /
          {{ operationsDispatchPreflight.missingInputCount }} missing inputs /
          {{ operationsDispatchPreflight.unsafeInputCount || 0 }} unsafe /
          {{ operationsDispatchPreflight.invalidInputCount || 0 }} invalid /
          {{ operationsDispatchPreflight.ambiguousInputCount || 0 }} ambiguous /
          {{ operationsDispatchPreflight.warningCheckCount }} warnings
        </small>
        <small
          v-if="operationsDispatchPreflightSourceSummary"
          data-testid="readiness-dispatch-preflight-source"
        >
          Source: {{ operationsDispatchPreflightSourceSummary }}
        </small>
        <small data-testid="readiness-dispatch-preflight-confirmations">
          Confirmations: kubeconfig {{ operationsDispatchPreflight.needsKubeconfigSecretConfirmation ? 'required' : 'not required' }} /
          operator approval {{ operationsDispatchPreflight.needsOperatorApprovalConfirmation ? 'required' : 'not required' }}
        </small>
        <small
          v-if="operationsDispatchPreflightSelectedOrderSummary"
          data-testid="readiness-dispatch-preflight-selected-orders"
        >
          Selected actions: {{ operationsDispatchPreflightSelectedOrderSummary }}
        </small>
        <small v-if="formatDispatchPreflightSecrets()">
          {{ formatDispatchPreflightSecrets() }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsDispatchPreflight.readyPlanCommand"
            data-testid="readiness-dispatch-preflight-plan-command-copy-button"
            type="button"
            class="ghost"
            title="Copy dispatch preflight plan command"
            @click="copyReadinessRemediationCommand(operationsDispatchPreflight.readyPlanCommand)"
          >
            Ready Plan
          </button>
          <button
            v-if="operationsDispatchPreflight.executeCommand"
            data-testid="readiness-dispatch-preflight-execute-command-copy-button"
            type="button"
            class="ghost"
            title="Copy dispatch preflight execute command"
            @click="copyReadinessRemediationCommand(operationsDispatchPreflight.executeCommand)"
          >
            Execute
          </button>
        </div>
      </div>
      <ol
        v-if="operationsDispatchPreflightChecks.length > 0"
        class="readiness-evidence-plan-actions readiness-dispatch-preflight-checks"
        data-testid="readiness-dispatch-preflight-checks"
      >
        <li
          v-for="check in operationsDispatchPreflightChecks.slice(0, 4)"
          :key="check.code"
        >
          <span>
            <strong>{{ check.code }} 夷?{{ check.status || 'unknown' }}</strong>
            <small>{{ check.message || 'No detail' }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="operationsDispatchPreflightInputs.length > 0"
        class="readiness-evidence-plan-actions readiness-dispatch-preflight-inputs"
        data-testid="readiness-dispatch-preflight-inputs"
      >
        <li
          v-for="input in operationsDispatchPreflightInputs.slice(0, 4)"
          :key="`${input.actionOrder}-${input.parameter}-${input.placeholder}`"
        >
          <span>
            <strong>{{ input.parameter || input.placeholder }} 夷?{{ input.supplied ? 'supplied' : 'missing' }}</strong>
            <small>{{ formatDispatchPreflightInputMeta(input) }}</small>
          </span>
        </li>
      </ol>
      <ol
        v-if="operationsDispatchPreflightWorkflowFiles.length > 0"
        class="readiness-evidence-plan-actions readiness-dispatch-preflight-workflows"
        data-testid="readiness-dispatch-preflight-workflows"
      >
        <li
          v-for="workflow in operationsDispatchPreflightWorkflowFiles.slice(0, 3)"
          :key="`${workflow.actionOrder}-${workflow.workflow}`"
        >
          <span>
            <strong>{{ workflow.workflow }} 夷?{{ workflow.exists ? 'present' : 'missing' }}</strong>
            <small>{{ formatDispatchPreflightWorkflowMeta(workflow) }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="operationsWorkflowRunIdPlan.result"
        class="readiness-invocation-summary"
        data-testid="readiness-workflow-run-id-summary"
      >
        <strong>Workflow run ids: {{ operationsWorkflowRunIdPlan.result }}</strong>
        <small>
          {{ operationsWorkflowRunIdPlan.readyWorkflowCount }} ready /
          {{ operationsWorkflowRunIdPlan.workflowCount }} workflows /
          {{ operationsWorkflowRunIdPlan.missingWorkflowCount }} missing /
          {{ operationsWorkflowRunIdPlan.staleWorkflowCount || 0 }} stale
        </small>
        <small
          v-if="operationsWorkflowRunIdPlanSourceSummary"
          data-testid="readiness-workflow-run-id-source"
        >
          Source: {{ operationsWorkflowRunIdPlanSourceSummary }}
        </small>
        <small
          v-if="operationsWorkflowRunIdPlanTargetSummary"
          data-testid="readiness-workflow-run-id-target"
        >
          Target: {{ operationsWorkflowRunIdPlanTargetSummary }}
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsWorkflowRunIdPlan.artifactCollectionPlanCommand"
            data-testid="readiness-workflow-run-id-artifact-plan-command-copy-button"
            type="button"
            class="ghost"
            title="Copy artifact collection plan command"
            @click="copyReadinessRemediationCommand(operationsWorkflowRunIdPlan.artifactCollectionPlanCommand)"
          >
            Artifact Plan
          </button>
          <button
            v-if="operationsWorkflowRunIdPlan.securityEvidenceFinalizerCommand"
            data-testid="readiness-workflow-run-id-security-command-copy-button"
            type="button"
            class="ghost"
            title="Copy security evidence finalizer command"
            @click="copyReadinessRemediationCommand(operationsWorkflowRunIdPlan.securityEvidenceFinalizerCommand)"
          >
            Security
          </button>
        </div>
      </div>
      <ol
        v-if="operationsWorkflowRunIdPlanWorkflows.length > 0"
        class="readiness-evidence-plan-actions readiness-workflow-run-id-actions"
        data-testid="readiness-workflow-run-id-actions"
      >
        <li
          v-for="workflow in operationsWorkflowRunIdPlanWorkflows.slice(0, 3)"
          :key="workflow.workflow"
        >
          <span>
            <strong>{{ workflow.workflow }} 쨌 {{ workflow.readyForArtifactDownload ? 'ready' : 'query required' }}</strong>
            <small>{{ formatWorkflowRunIdMeta(workflow) }}</small>
            <code v-if="workflow.queryCommand">{{ workflow.queryCommand }}</code>
          </span>
          <button
            v-if="workflow.queryCommand"
            data-testid="readiness-workflow-run-id-query-copy-button"
            type="button"
            class="ghost"
            title="Copy workflow run query command"
            @click="copyReadinessRemediationCommand(workflow.queryCommand)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsArtifactCollectionPlan.result"
        class="readiness-invocation-summary"
        data-testid="readiness-artifact-collection-summary"
      >
        <strong>Artifact collection: {{ operationsArtifactCollectionPlan.result }}</strong>
        <small>
          {{ operationsArtifactCollectionPlan.readyArtifactCount }} ready /
          {{ operationsArtifactCollectionPlan.artifactCount }} artifacts /
          {{ operationsArtifactCollectionPlan.requiredArtifactCount || 0 }} required /
          {{ operationsArtifactCollectionPlan.missingRequiredArtifactCount }} missing required
        </small>
        <small
          v-if="operationsArtifactCollectionPlanSourceSummary"
          data-testid="readiness-artifact-collection-source"
        >
          Source: {{ operationsArtifactCollectionPlanSourceSummary }}
        </small>
        <small
          v-if="operationsArtifactCollectionPlan.securityEvidenceFinalizerCommand"
          data-testid="readiness-artifact-collection-security-command"
        >
          Security finalizer ready
        </small>
        <div class="readiness-artifact-command-row">
          <button
            v-if="operationsArtifactCollectionPlan.securityEvidenceFinalizerCommand"
            data-testid="readiness-artifact-security-finalizer-command-copy-button"
            type="button"
            class="ghost"
            title="Copy security evidence finalizer command"
            @click="copyReadinessRemediationCommand(operationsArtifactCollectionPlan.securityEvidenceFinalizerCommand)"
          >
            Security
          </button>
          <button
            v-if="operationsArtifactCollectionPlan.operationsArtifactFinalizerCommand"
            data-testid="readiness-artifact-finalizer-command-copy-button"
            type="button"
            class="ghost"
            title="Copy operations artifact finalizer command"
            @click="copyReadinessRemediationCommand(operationsArtifactCollectionPlan.operationsArtifactFinalizerCommand)"
          >
            Finalizer
          </button>
          <button
            v-if="operationsArtifactCollectionPlan.localImportCommand"
            data-testid="readiness-artifact-local-import-command-copy-button"
            type="button"
            class="ghost"
            title="Copy local artifact import command"
            @click="copyReadinessRemediationCommand(operationsArtifactCollectionPlan.localImportCommand)"
          >
            Import
          </button>
        </div>
        <small
          v-if="operationsArtifactCollectionPlan.dataFlowStoragePlanInputNote"
          data-testid="readiness-artifact-data-flow-note"
        >
          {{ operationsArtifactCollectionPlan.dataFlowStoragePlanInputNote }}
        </small>
        <button
          v-if="operationsArtifactCollectionPlan.dataFlowStoragePlanInputNote"
          data-testid="readiness-artifact-data-flow-note-copy-button"
          type="button"
          class="ghost"
          title="Copy direct data-flow storage plan input note"
          @click="copyReadinessRemediationCommand(operationsArtifactCollectionPlan.dataFlowStoragePlanInputNote)"
        >
          Copy data-flow note
        </button>
        <small
          v-if="operationsArtifactCollectionPlan.dataFlowStorageTransitionRunbookInputNote"
          data-testid="readiness-artifact-data-flow-runbook-note"
        >
          {{ operationsArtifactCollectionPlan.dataFlowStorageTransitionRunbookInputNote }}
        </small>
        <button
          v-if="operationsArtifactCollectionPlan.dataFlowStorageTransitionRunbookInputNote"
          data-testid="readiness-artifact-data-flow-runbook-note-copy-button"
          type="button"
          class="ghost"
          title="Copy direct data-flow transition runbook input note"
          @click="copyReadinessRemediationCommand(operationsArtifactCollectionPlan.dataFlowStorageTransitionRunbookInputNote)"
        >
          Copy runbook note
        </button>
      </div>
      <ol
        v-if="operationsArtifactCollectionArtifacts.length > 0"
        class="readiness-evidence-plan-actions readiness-artifact-collection-actions"
        data-testid="readiness-artifact-collection-actions"
      >
        <li
          v-for="artifact in operationsArtifactCollectionArtifacts.slice(0, 3)"
          :key="`${artifact.group}-${artifact.workflow}`"
        >
          <span>
            <strong>{{ artifact.group }} 쨌 {{ artifact.ready ? 'ready' : 'needs run id' }}</strong>
            <small>{{ formatArtifactCollectionMeta(artifact) }}</small>
            <code v-if="artifact.downloadCommand">{{ artifact.downloadCommand }}</code>
          </span>
          <button
            v-if="artifact.downloadCommand"
            data-testid="readiness-artifact-download-command-copy-button"
            type="button"
            class="ghost"
            title="Copy artifact download command"
            @click="copyReadinessRemediationCommand(artifact.downloadCommand)"
          >
            Copy
          </button>
        </li>
      </ol>
      <div
        v-if="operationsReadinessArtifactImport.result"
        class="readiness-invocation-summary"
        data-testid="readiness-artifact-import-summary"
      >
        <strong>Artifact import: {{ operationsReadinessArtifactImport.result }}</strong>
        <small>
          status {{ operationsReadinessArtifactImport.status || 'unknown' }} /
          {{ operationsReadinessArtifactImport.importedCount }} imported /
          {{ operationsReadinessArtifactImport.failedCount }} failed /
          {{ operationsReadinessArtifactImport.selectedGroupCount }} groups
        </small>
        <small
          v-if="operationsReadinessArtifactImport.outputDirectory"
          data-testid="readiness-artifact-import-output"
        >
          Output: {{ operationsReadinessArtifactImport.outputDirectory }}
        </small>
        <small v-if="operationsReadinessArtifactImport.secretPolicy">
          {{ operationsReadinessArtifactImport.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="operationsReadinessArtifactImportEntries.length > 0"
        class="readiness-evidence-plan-actions readiness-artifact-import-entries"
        data-testid="readiness-artifact-import-entries"
      >
        <li
          v-for="entry in operationsReadinessArtifactImportEntries.slice(0, 4)"
          :key="`${entry.group}-${entry.fileName}`"
        >
          <span>
            <strong>{{ entry.group }} 夷?{{ entry.status || 'unknown' }}</strong>
            <small>{{ formatArtifactImportEntryMeta(entry) }}</small>
          </span>
        </li>
      </ol>
      <div
        v-if="operationsReadinessFinalize.result"
        class="readiness-invocation-summary"
        data-testid="readiness-finalizer-summary"
      >
        <strong>Operations finalizer: {{ operationsReadinessFinalize.result }}</strong>
        <small>
          status {{ operationsReadinessFinalize.status || 'unknown' }} /
          readiness {{ operationsReadinessFinalize.readinessResult || 'unknown' }} /
          failed {{ operationsReadinessFinalize.failedCount }} /
          gaps {{ operationsReadinessFinalizeGaps.length }}
        </small>
        <small
          v-if="operationsReadinessFinalizeContextSummary"
          data-testid="readiness-finalizer-context"
        >
          Context: {{ operationsReadinessFinalizeContextSummary }}
        </small>
        <small
          v-if="operationsReadinessFinalizeSelectedStepSummary"
          data-testid="readiness-finalizer-selected-steps"
        >
          Selected: {{ operationsReadinessFinalizeSelectedStepSummary }}
        </small>
        <small
          v-if="operationsReadinessFinalizePathSummary"
          data-testid="readiness-finalizer-paths"
        >
          Paths: {{ operationsReadinessFinalizePathSummary }}
        </small>
        <small v-if="operationsReadinessFinalize.secretPolicy">
          {{ operationsReadinessFinalize.secretPolicy }}
        </small>
      </div>
      <ol
        v-if="operationsReadinessFinalizeCommands.length > 0"
        class="readiness-evidence-plan-actions readiness-finalizer-commands"
        data-testid="readiness-finalizer-commands"
      >
        <li
          v-for="command in operationsReadinessFinalizeCommands.slice(0, 3)"
          :key="`${command.name}-${command.script}`"
        >
          <span>
            <strong>{{ command.name || command.script }}</strong>
            <small>{{ formatReadinessFinalizeCommandMeta(command) }}</small>
            <code v-if="command.command">{{ command.command }}</code>
          </span>
          <button
            v-if="command.command"
            data-testid="readiness-finalizer-command-copy-button"
            type="button"
            class="ghost"
            title="Copy operations finalizer command"
            @click="copyReadinessRemediationCommand(command.command)"
          >
            Copy
          </button>
        </li>
      </ol>
      <ol
        v-if="operationsReadinessFinalizeSteps.length > 0"
        class="readiness-evidence-plan-actions readiness-finalizer-steps"
        data-testid="readiness-finalizer-steps"
      >
        <li
          v-for="step in operationsReadinessFinalizeSteps.slice(0, 3)"
          :key="`${step.name}-${step.result}`"
        >
          <span>
            <strong>{{ step.name || step.script }} 夷?{{ step.result || 'unknown' }}</strong>
            <small>{{ formatReadinessFinalizeStepMeta(step) }}</small>
          </span>
        </li>
      </ol>
      <div class="readiness-filter-row">
        <label>
          Category
          <select
            data-testid="readiness-category-filter"
            :value="readinessCategoryFilter"
            @change="$emit('update-readiness-category-filter', $event.target.value)"
          >
            <option
              v-for="option in readinessCategoryOptions"
              :key="option.category"
              :value="option.category"
            >
              {{ option.category }} ({{ option.totalCount }})
            </option>
          </select>
        </label>
        <label>
          Severity
          <select
            data-testid="readiness-severity-filter"
            :value="readinessSeverityFilter"
            @change="$emit('update-readiness-severity-filter', $event.target.value)"
          >
            <option
              v-for="option in readinessSeverityOptions"
              :key="option.severity"
              :value="option.severity"
            >
              {{ option.severity }} ({{ option.totalCount }})
            </option>
          </select>
        </label>
      </div>
      <ul class="task-list readiness-task-list">
        <li v-if="visibleReadinessItems.length === 0">필수 점검 통과</li>
        <li
          v-for="item in visibleReadinessItems.slice(0, 6)"
          :key="`${item.severity}-${item.code}-${item.message}`"
          :data-testid="`readiness-item-${item.code}`"
        >
          <span>
            <strong>
              <em class="readiness-category">{{ item.category || 'GENERAL' }}</em>
              {{ item.code }}
            </strong>
            <small>{{ item.message }}</small>
            <span
              v-if="hasReadinessRemediation(item)"
              class="readiness-remediation"
              data-testid="readiness-remediation"
            >
              <span v-if="item.remediationCommand" class="readiness-remediation-command">
                <code>{{ item.remediationCommand }}</code>
                <button
                  data-testid="readiness-remediation-copy-button"
                  type="button"
                  class="ghost"
                  title="Copy remediation command"
                  @click="copyReadinessRemediationCommand(item.remediationCommand)"
                >
                  Copy
                </button>
              </span>
              <small v-if="item.remediationWorkflow">Workflow: {{ item.remediationWorkflow }}</small>
              <span v-if="item.remediationWorkflowCommand" class="readiness-remediation-command">
                <code>{{ item.remediationWorkflowCommand }}</code>
                <button
                  data-testid="readiness-remediation-workflow-copy-button"
                  type="button"
                  class="ghost"
                  title="Copy workflow command"
                  @click="copyReadinessRemediationCommand(item.remediationWorkflowCommand)"
                >
                  Copy
                </button>
              </span>
              <small v-if="item.evidencePath">Evidence: {{ item.evidencePath }}</small>
              <small v-if="item.remediationNote">{{ item.remediationNote }}</small>
            </span>
          </span>
          <button type="button" class="ghost" @click="$emit('open-readiness-target', item.targetPage, item.targetPanel)">
            {{ item.actionLabel || '보기' }}
          </button>
        </li>
      </ul>
    </article>

    <article id="backup-status-panel" class="panel backup-panel" data-testid="backup-status-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Backup Readiness</p>
          <h3>백업/복구 준비도</h3>
        </div>
        <span :class="['status-pill', statusClass(backupStatus.status)]">{{ backupStatus.status }}</span>
      </div>
      <dl class="status-dl">
        <div>
          <dt>Metadata</dt>
          <dd>{{ backupStatus.metadataStore }}</dd>
        </div>
        <div>
          <dt>Object Store</dt>
          <dd>{{ backupStatus.objectStore }}</dd>
        </div>
        <div>
          <dt>RPO / RTO</dt>
          <dd>{{ backupStatus.rpoTarget }} / {{ backupStatus.rtoTarget }}</dd>
        </div>
      </dl>
      <div class="backup-evidence" data-testid="backup-restore-evidence">
        <span>Latest restore drill</span>
        <strong :class="['status-pill', statusClass(backupStatus.latestRestoreDrillEvidence?.result || (backupStatus.restoreDrillExecuted ? 'RECORDED' : 'MISSING'))]">
          {{ backupStatus.latestRestoreDrillEvidence?.result || (backupStatus.restoreDrillExecuted ? 'RECORDED' : 'NOT RECORDED') }}
        </strong>
        <small v-if="backupStatus.latestRestoreDrillEvidence">
          {{ backupStatus.latestRestoreDrillEvidence.environment || '-' }} /
          {{ formatDateTime(backupStatus.latestRestoreDrillEvidence.recordedAt) || '-' }}
        </small>
        <small v-else>No restore drill evidence recorded.</small>
      </div>
      <ul class="task-list">
        <li v-if="backupStatus.pendingGates.length === 0">필수 게이트 통과</li>
        <li v-for="gate in backupStatus.pendingGates" :key="gate">{{ gate }}</li>
      </ul>
    </article>

    <article v-if="isAdmin" id="data-flow-monitoring-panel" class="panel data-flow-panel" data-testid="data-flow-monitoring-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Data Flow Monitoring</p>
          <h3>데이터 흐름 감시</h3>
        </div>
        <span :class="['status-pill', dataFlowStatusClass]">{{ dataFlowStatusLabel }}</span>
      </div>
      <form class="data-flow-filter-form" data-testid="data-flow-filter-form" @submit.prevent="$emit('refresh-data-flow-monitoring')">
        <label>
          <span>From</span>
          <input
            data-testid="data-flow-filter-from"
            type="datetime-local"
            :value="dataFlowFilter.from"
            @input="$emit('update-data-flow-filter', 'from', $event.target.value)"
          />
        </label>
        <label>
          <span>To</span>
          <input
            data-testid="data-flow-filter-to"
            type="datetime-local"
            :value="dataFlowFilter.to"
            @input="$emit('update-data-flow-filter', 'to', $event.target.value)"
          />
        </label>
        <label>
          <span>Bucket</span>
          <input
            data-testid="data-flow-filter-bucket"
            type="text"
            :value="dataFlowFilter.bucketName"
            placeholder="bucket"
            @input="$emit('update-data-flow-filter', 'bucketName', $event.target.value)"
          />
        </label>
        <label>
          <span>Actor</span>
          <input
            data-testid="data-flow-filter-actor"
            type="text"
            :value="dataFlowFilter.actorId"
            placeholder="loginId"
            @input="$emit('update-data-flow-filter', 'actorId', $event.target.value)"
          />
        </label>
        <label>
          <span>Source</span>
          <select
            data-testid="data-flow-filter-source"
            :value="dataFlowFilter.source"
            @change="$emit('update-data-flow-filter', 'source', $event.target.value)"
          >
            <option value="">All</option>
            <option value="rest">REST</option>
            <option value="s3">S3</option>
            <option value="s3-copy">S3 Copy</option>
          </select>
        </label>
        <label>
          <span>Operation</span>
          <select
            data-testid="data-flow-filter-operation"
            :value="dataFlowFilter.operation"
            @change="$emit('update-data-flow-filter', 'operation', $event.target.value)"
          >
            <option value="">All</option>
            <option value="upload">Upload</option>
            <option value="download">Download</option>
            <option value="copy">Copy</option>
            <option value="list">List</option>
            <option value="delete">Delete</option>
          </select>
        </label>
        <label>
          <span>Status</span>
          <select
            data-testid="data-flow-filter-status"
            :value="dataFlowFilter.status"
            @change="$emit('update-data-flow-filter', 'status', $event.target.value)"
          >
            <option value="">All</option>
            <option value="SUCCESS">Success</option>
            <option value="FAILED">Failed</option>
            <option value="CANCELLED">Cancelled</option>
          </select>
        </label>
        <label>
          <span>Limit</span>
          <input
            data-testid="data-flow-filter-limit"
            type="number"
            min="1"
            max="500"
            :value="dataFlowFilter.limit"
            @input="$emit('update-data-flow-filter', 'limit', Number($event.target.value || 50))"
          />
        </label>
        <label>
          <span>Months</span>
          <input
            data-testid="data-flow-filter-months"
            type="number"
            min="1"
            max="60"
            :value="dataFlowFilter.months"
            @input="$emit('update-data-flow-filter', 'months', Number($event.target.value || 12))"
          />
        </label>
        <label>
          <span>Monthly Source</span>
          <select
            data-testid="data-flow-filter-monthly-materialized"
            :value="dataFlowFilter.monthlyMaterialized ? 'true' : 'false'"
            @change="$emit('update-data-flow-filter', 'monthlyMaterialized', $event.target.value === 'true')"
          >
            <option value="false">Live</option>
            <option value="true">Store</option>
          </select>
        </label>
        <div class="data-flow-filter-actions">
          <button data-testid="data-flow-refresh-button" type="submit" class="ghost">Refresh</button>
          <button data-testid="data-flow-export-button" type="button" class="ghost" @click="$emit('export-data-flow-csv')">CSV</button>
          <button data-testid="data-flow-daily-rollup-export-button" type="button" class="ghost" @click="$emit('export-data-flow-daily-rollup-csv')">Rollup CSV</button>
          <button data-testid="data-flow-daily-rollup-materialize-button" type="button" class="ghost" @click="$emit('materialize-data-flow-daily-rollup')">Refresh Store</button>
          <button data-testid="data-flow-daily-rollup-materialized-load-button" type="button" class="ghost" @click="$emit('load-materialized-data-flow-daily-rollup')">Load Store</button>
          <button data-testid="data-flow-daily-rollup-materialized-export-button" type="button" class="ghost" @click="$emit('export-materialized-data-flow-daily-rollup-csv')">Store CSV</button>
          <button data-testid="data-flow-monthly-rollup-load-button" type="button" class="ghost" @click="$emit('load-data-flow-monthly-rollup')">Monthly</button>
          <button data-testid="data-flow-monthly-rollup-export-button" type="button" class="ghost" @click="$emit('export-data-flow-monthly-rollup-csv')">Monthly CSV</button>
          <button data-testid="data-flow-monthly-rollup-materialize-button" type="button" class="ghost" @click="$emit('materialize-data-flow-monthly-rollup')">Monthly Store</button>
          <button data-testid="data-flow-monthly-rollup-materialized-load-button" type="button" class="ghost" @click="$emit('load-materialized-data-flow-monthly-rollup')">Load Monthly Store</button>
          <button data-testid="data-flow-monthly-rollup-materialized-export-button" type="button" class="ghost" @click="$emit('export-materialized-data-flow-monthly-rollup-csv')">Monthly Store CSV</button>
          <button data-testid="data-flow-reset-button" type="button" class="ghost" @click="$emit('reset-data-flow-filter')">Reset</button>
        </div>
      </form>
      <dl class="status-dl compact data-flow-retention-strip" data-testid="data-flow-retention-panel">
        <div>
          <dt>Event Retention</dt>
          <dd data-testid="data-flow-retention-event-days">{{ dataFlowRetentionEventLabel }}</dd>
        </div>
        <div>
          <dt>Daily Rollup</dt>
          <dd data-testid="data-flow-retention-rollup-days">{{ dataFlowRetentionRollupLabel }}</dd>
        </div>
        <div>
          <dt>Monthly Rollup</dt>
          <dd data-testid="data-flow-retention-monthly-rollup-days">{{ dataFlowRetentionMonthlyRollupLabel }}</dd>
        </div>
        <div>
          <dt>Deleted</dt>
          <dd data-testid="data-flow-retention-deleted">{{ dataFlowRetentionDeletedLabel }}</dd>
        </div>
        <div>
          <dt>Failed Runs</dt>
          <dd data-testid="data-flow-retention-failed">{{ dataFlowRetentionFailureLabel }}</dd>
        </div>
        <div class="data-flow-retention-actions">
          <dt>Retention</dt>
          <dd>
            <button data-testid="data-flow-retention-refresh-button" type="button" class="ghost" @click="$emit('refresh-data-flow-retention')">Refresh</button>
            <button data-testid="data-flow-retention-run-button" type="button" class="ghost" @click="$emit('run-data-flow-retention')">Run</button>
          </dd>
        </div>
      </dl>
      <dl class="status-dl compact data-flow-storage-strip" data-testid="data-flow-storage-panel">
        <div>
          <dt>Storage</dt>
          <dd data-testid="data-flow-storage-status">{{ dataFlowStorageStatusLabel }}</dd>
        </div>
        <div>
          <dt>Rows</dt>
          <dd data-testid="data-flow-storage-rows">{{ dataFlowStorageRowsLabel }}</dd>
        </div>
        <div>
          <dt>Window</dt>
          <dd data-testid="data-flow-storage-window">{{ dataFlowStorageWindowLabel }}</dd>
        </div>
      </dl>
      <dl class="status-dl compact">
        <div>
          <dt>Total Traffic</dt>
          <dd data-testid="data-flow-total-bytes">{{ formatBytes(dataFlowTraffic.totalBytes || 0) }}</dd>
        </div>
        <div>
          <dt>Upload / Download / Copy</dt>
          <dd>{{ formatBytes(dataFlowTraffic.uploadedBytes || 0) }} / {{ formatBytes(dataFlowTraffic.downloadedBytes || 0) }} / {{ formatBytes(dataFlowTraffic.copiedBytes || 0) }}</dd>
        </div>
        <div>
          <dt>Operations</dt>
          <dd>{{ formatCount(dataFlowOperations.totalCount || 0) }}</dd>
        </div>
        <div>
          <dt>Failed / Cancelled</dt>
          <dd data-testid="data-flow-failed-cancelled">{{ formatCount(dataFlowOperations.failureCount || 0) }} / {{ formatCount(dataFlowOperations.cancelCount || 0) }}</dd>
        </div>
      </dl>
      <div class="data-flow-trend" data-testid="data-flow-trend-chart">
        <div v-if="dataFlowTrendPoints.length === 0" class="data-flow-trend-empty">
          <strong>No trend data yet</strong>
          <small>source and operation buckets will appear here</small>
        </div>
        <div
          v-for="point in dataFlowTrendPoints"
          :key="`${point.bucketStartAt}-${point.source}-${point.operation}`"
          class="data-flow-trend-row"
        >
          <span class="data-flow-trend-label">
            <strong>{{ point.operation || 'unknown' }}</strong>
            <small>{{ point.source || 'unknown' }} / {{ formatDateTime(point.bucketStartAt) || '-' }}</small>
          </span>
          <span class="data-flow-trend-meter" aria-hidden="true">
            <span :style="{ width: dataFlowTrendWidth(point) }"></span>
          </span>
          <b>{{ formatCount(point.totalCount || 0) }}</b>
          <small>{{ formatCount(point.failureCount || 0) }} fail / {{ formatCount(point.cancelCount || 0) }} cancel / {{ formatBytes(point.bytes || 0) }}</small>
        </div>
      </div>
      <ul class="compact-list" data-testid="data-flow-daily-rollup">
        <li v-if="dataFlowDailyRollupPoints.length === 0">
          <span>
            <strong>No daily rollup yet</strong>
            <small>daily bucket/source/operation aggregates will appear here</small>
          </span>
        </li>
        <li v-for="point in dataFlowDailyRollupPoints" :key="`${point.day}-${point.bucketName}-${point.source}-${point.operation}`" data-testid="data-flow-daily-rollup-row">
          <span>
            <strong>{{ point.day || '-' }} / {{ point.bucketName || 'unknown' }}</strong>
            <small>{{ point.source || 'unknown' }} / {{ point.operation || 'unknown' }} / {{ formatCount(point.successCount || 0) }} ok / {{ formatCount(point.failureCount || 0) }} fail / {{ formatCount(point.cancelCount || 0) }} cancel</small>
          </span>
          <b data-testid="data-flow-daily-rollup-bytes">{{ formatBytes(point.totalBytes || 0) }}</b>
        </li>
      </ul>
      <ul class="compact-list" data-testid="data-flow-monthly-rollup">
        <li v-if="dataFlowMonthlyRollupPoints.length === 0">
          <span>
            <strong>No monthly rollup yet</strong>
            <small>monthly bucket/source/operation aggregates will appear here</small>
          </span>
        </li>
        <li v-for="point in dataFlowMonthlyRollupPoints" :key="`${point.month}-${point.bucketName}-${point.source}-${point.operation}`" data-testid="data-flow-monthly-rollup-row">
          <span>
            <strong>{{ point.month || '-' }} / {{ point.bucketName || 'unknown' }}</strong>
            <small>{{ point.source || 'unknown' }} / {{ point.operation || 'unknown' }} / {{ formatCount(point.successCount || 0) }} ok / {{ formatCount(point.failureCount || 0) }} fail / {{ formatCount(point.cancelCount || 0) }} cancel</small>
          </span>
          <b data-testid="data-flow-monthly-rollup-bytes">{{ formatBytes(point.totalBytes || 0) }}</b>
        </li>
      </ul>
      <ul class="compact-list" data-testid="data-flow-top-buckets">
        <li v-if="dataFlowTopBuckets.length === 0">
          <span>
            <strong>No bucket traffic yet</strong>
            <small>uploads, downloads, and copies will appear here</small>
          </span>
        </li>
        <li v-for="bucket in dataFlowTopBuckets" :key="bucket.bucketName">
          <span>
            <strong>{{ bucket.bucketName }}</strong>
            <small>{{ formatBytes(bucket.totalBytes || 0) }} / {{ formatCount(bucket.uploadCount || 0) }} uploads / {{ formatCount(bucket.downloadCount || 0) }} downloads / {{ formatCount(bucket.copyCount || 0) }} copies / {{ formatCount(bucket.listCount || 0) }} lists</small>
          </span>
          <b>{{ formatDateTime(bucket.lastEventAt) || '-' }}</b>
        </li>
      </ul>
      <ul class="compact-list" data-testid="data-flow-recent-events">
        <li v-if="dataFlowRecentEvents.length === 0">
          <span>
            <strong>No recent data flow events</strong>
            <small>object upload, download, cancel, and failure events are monitored</small>
          </span>
        </li>
        <li v-for="event in dataFlowRecentEvents" :key="`${event.createdAt}-${event.eventType}-${event.bucketName}-${event.objectKey}`">
          <span>
            <strong>{{ event.eventType }} / {{ event.status }}</strong>
            <small>{{ event.bucketName }}{{ event.objectKey ? `/${event.objectKey}` : '' }} / {{ formatBytes(event.sizeBytes || 0) }} / {{ event.source || '-' }}</small>
          </span>
          <b>{{ formatDateTime(event.createdAt) || '-' }}</b>
        </li>
      </ul>
    </article>

    <article class="panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Selected Workspace</p>
          <h3>{{ selectedBucket || '버킷을 선택하세요' }}</h3>
        </div>
        <span class="bucket-label">{{ bucketObjectsLabel }}</span>
      </div>
      <div class="focus-summary">
        <div>
          <span>권장 다음 작업</span>
          <strong>{{ nextActionLabel }}</strong>
        </div>
        <button type="button" class="ghost" :disabled="!selectedBucket" @click="$emit('load-selected-bucket-details')">
          선택 버킷 다시 읽기
        </button>
      </div>
    </article>

    <article v-if="isAdmin" class="panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Retention</p>
          <h3>휴지통 보존 정책</h3>
        </div>
        <span :class="['status-pill', retentionPolicy.enabled ? 'up' : 'mock']">
          {{ retentionPolicy.enabled ? 'ON' : 'OFF' }}
        </span>
      </div>
      <dl class="status-dl compact">
        <div>
          <dt>보존 기간</dt>
          <dd>{{ retentionPolicy.retentionDays || '-' }}일</dd>
        </div>
        <div>
          <dt>삭제/실패</dt>
          <dd>{{ formatCount(retentionPolicy.purgedObjectCount) }} / {{ formatCount(retentionPolicy.failedObjectCount) }}</dd>
        </div>
      </dl>
      <button
        type="button"
        class="ghost"
        :disabled="!retentionPolicy.enabled || retentionPolicy.pending"
        @click="$emit('run-object-retention-purge')"
      >
        {{ retentionPolicy.pending ? '실행 중' : 'Purge 실행' }}
      </button>
    </article>

    <article v-if="isAdmin" class="panel" data-testid="execution-log-retention-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Execution Log Retention</p>
          <h3>Storage Expansion Logs</h3>
        </div>
        <span :class="['status-pill', executionLogRetention.enabled ? 'up' : 'mock']">
          {{ executionLogRetention.enabled ? 'ON' : 'OFF' }}
        </span>
      </div>
      <dl class="status-dl compact">
        <div>
          <dt>Pending</dt>
          <dd data-testid="execution-log-retention-pending">{{ formatCount(executionLogRetention.pendingOutputCount) }}</dd>
        </div>
        <div>
          <dt>Redacted/Failed</dt>
          <dd>{{ formatCount(executionLogRetention.redactedOutputCount) }} / {{ formatCount(executionLogRetention.failedRunCount) }}</dd>
        </div>
      </dl>
      <button
        data-testid="execution-log-retention-run-button"
        type="button"
        class="ghost"
        :disabled="!executionLogRetention.enabled || executionLogRetention.pending"
        @click="$emit('run-storage-expansion-execution-log-retention')"
      >
        {{ executionLogRetention.pending ? 'Running' : 'Run retention' }}
      </button>
    </article>

    <article v-if="isAdmin" class="panel" data-testid="storage-expansion-dashboard-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Storage Expansion</p>
          <h3>Pool Expansion Status</h3>
        </div>
        <span :class="['status-pill', storageExpansionIssueExecutionCount > 0 ? 'down' : storageExpansionOpenRequestCount > 0 ? 'mock' : 'up']">
          {{ storageExpansionIssueExecutionCount > 0 ? 'CHECK' : storageExpansionOpenRequestCount > 0 ? 'OPEN' : 'CLEAR' }}
        </span>
      </div>
      <dl class="status-dl compact">
        <div>
          <dt>Open</dt>
          <dd data-testid="storage-expansion-dashboard-open">{{ formatCount(storageExpansionOpenRequestCount) }}</dd>
        </div>
        <div>
          <dt>Applied/Rejected</dt>
          <dd>{{ formatCount(storageExpansionStatusCount('APPLIED')) }} / {{ formatCount(storageExpansionStatusCount('REJECTED')) }}</dd>
        </div>
        <div>
          <dt>Executions</dt>
          <dd>{{ formatCount(storageExpansionExecutionCount) }}</dd>
        </div>
        <div>
          <dt>Failed/Timed out</dt>
          <dd data-testid="storage-expansion-dashboard-issues">{{ formatCount(storageExpansionIssueExecutionCount) }}</dd>
        </div>
        <div>
          <dt>Open Capacity</dt>
          <dd>{{ formatBytes(storageExpansionOpenCapacityBytes) }}</dd>
        </div>
      </dl>
      <ul class="compact-list" data-testid="storage-expansion-dashboard-list">
        <li v-if="latestStorageExpansionRequests.length === 0">
          <span>
            <strong>No expansion requests</strong>
            <small>ready for new capacity request</small>
          </span>
        </li>
        <li v-for="request in latestStorageExpansionRequests" :key="request.id">
          <span>
            <strong>{{ request.poolName || `request-${request.id}` }}</strong>
            <small>{{ formatBytes(Number(request.requestedCapacityBytes) || 0) }} / {{ request.serverCount || 0 }} servers</small>
          </span>
          <b>{{ request.status }}</b>
        </li>
      </ul>
      <ul class="compact-list" data-testid="storage-expansion-dashboard-executions">
        <li v-if="recentStorageExpansionExecutions.length === 0">
          <span>
            <strong>No execution history</strong>
            <small>dry-run/apply evidence not recorded yet</small>
          </span>
        </li>
        <li v-for="execution in recentStorageExpansionExecutions" :key="execution.id">
          <span>
            <strong>{{ execution.executionType }}</strong>
            <small>request #{{ execution.requestId }} / {{ formatDateTime(execution.createdAt) || '-' }}</small>
          </span>
          <b>{{ execution.result }}</b>
        </li>
      </ul>
    </article>

    <DashboardSharePanel
      v-if="isAdmin"
      :analytics="objectShareAnalytics"
      :format-date-time="formatDateTime"
    />
    <DashboardQuotaPanel
      v-if="isAdmin"
      :quota="dashboardQuota"
      :format-bytes="formatBytes"
      :quota-policy-percent="quotaPolicyPercent"
    />
    <DashboardActivityPanel
      v-if="isAdmin"
      :logs="auditLogs"
      :format-date-time="formatDateTime"
    />
  </section>
</template>

<script setup>
import { computed } from 'vue'
import DashboardActivityPanel from './DashboardActivityPanel.vue'
import DashboardQuotaPanel from './DashboardQuotaPanel.vue'
import DashboardSharePanel from './DashboardSharePanel.vue'
import { summarizeAccessKeys } from '../../utils/accessKeys.js'

const props = defineProps({
  dashboardEditMode: { type: Boolean, required: true },
  dashboardWidgetToAdd: { type: String, required: true },
  availableDashboardWidgetOptions: { type: Array, required: true },
  dashboardLayoutPresets: { type: Array, required: true },
  dashboardLayoutPresetToApply: { type: String, required: true },
  dashboardLayoutPresetForm: { type: Object, required: true },
  dashboardLayoutDefaults: { type: Array, required: true },
  dashboardLayoutDefaultForm: { type: Object, required: true },
  dashboardLayoutDefaultTargetOptions: { type: Array, required: true },
  canCreateDashboardLayoutPreset: { type: Boolean, required: true },
  canDeleteDashboardLayoutPreset: { type: Boolean, required: true },
  canUpdateDashboardLayoutPreset: { type: Boolean, required: true },
  canExportDashboardLayoutPreset: { type: Boolean, required: true },
  canImportDashboardLayoutPreset: { type: Boolean, required: true },
  canExportDashboardLayoutPresetBundle: { type: Boolean, required: true },
  canImportDashboardLayoutPresetBundle: { type: Boolean, required: true },
  canManageDashboardLayoutDefaults: { type: Boolean, required: true },
  dashboardWidgets: { type: Array, required: true },
  visibleDashboardWidgets: { type: Array, required: true },
  dashboardWidgetDragIndex: { type: Number, required: true },
  dashboardWidgetDropIndex: { type: Number, required: true },
  dashboardLayoutSyncLabel: { type: String, required: true },
  dashboardLayoutPending: { type: Boolean, required: true },
  dashboardLoading: { type: Boolean, required: true },
  dashboardLoadError: { type: String, required: true },
  usagePercent: { type: Number, required: true },
  usage: { type: Object, required: true },
  selectedBucket: { type: String, required: true },
  objectViewMode: { type: String, required: true },
  health: { type: Object, required: true },
  storageBackendStatus: { type: Object, required: true },
  backupStatus: { type: Object, required: true },
  uploadState: { type: Object, required: true },
  dataFlowMonitoring: { type: Object, required: true },
  dataFlowRetention: { type: Object, required: true },
  dataFlowStorageStatus: { type: Object, required: true },
  dataFlowFilter: { type: Object, required: true },
  auditLogs: { type: Array, required: true },
  auditNextCursor: { type: String, required: true },
  objectShareAnalytics: { type: Object, required: true },
  dashboardQuota: { type: Object, required: true },
  accessKeys: { type: Array, required: true },
  users: { type: Array, required: true },
  organizations: { type: Array, required: true },
  lifecycleRules: { type: Array, required: true },
  lifecycleRuleConflicts: { type: Object, required: true },
  runtimeReadinessLabel: { type: String, required: true },
  dashboardReadiness: { type: Object, required: true },
  readinessCategoryFilter: { type: String, required: true },
  readinessCategoryOptions: { type: Array, required: true },
  readinessSeverityFilter: { type: String, required: true },
  readinessSeverityOptions: { type: Array, required: true },
  visibleReadinessItems: { type: Array, required: true },
  nextActionLabel: { type: String, required: true },
  retentionPolicy: { type: Object, required: true },
  executionLogRetention: { type: Object, required: true },
  storageExpansionSummary: { type: Object, required: true },
  storageExpansionRequests: { type: Array, required: true },
  storageExpansionExecutions: { type: Array, required: true },
  bucketObjectsLabel: { type: String, required: true },
  isAdmin: { type: Boolean, required: true },
  dashboardWidgetTitle: { type: Function, required: true },
  dashboardWidgetSizeLabel: { type: Function, required: true },
  dashboardWidgetTone: { type: Function, required: true },
  dashboardWidgetToneLabel: { type: Function, required: true },
  dashboardWidgetRefreshIntervalLabel: { type: Function, required: true },
  dashboardWidgetAccessLabel: { type: Function, required: true },
  dashboardWidgetConfigOptions: { type: Function, required: true },
  dashboardWidgetOptionValue: { type: Function, required: true },
  dashboardSections: { type: Array, required: true },
  dashboardWidgetSections: { type: Array, required: true },
  dashboardWidgetSection: { type: Function, required: true },
  dashboardSectionCollapsed: { type: Function, required: true },
  dashboardWidgetSectionLabel: { type: Function, required: true },
  formatBytes: { type: Function, required: true },
  formatCount: { type: Function, required: true },
  statusClass: { type: Function, required: true },
  quotaPolicyPercent: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
})

defineEmits([
  'toggle-dashboard-edit-mode',
  'retry-dashboard-load',
  'update-widget-to-add',
  'update-dashboard-layout-preset',
  'update-dashboard-layout-preset-name',
  'update-dashboard-layout-preset-description',
  'update-dashboard-layout-default-target-type',
  'update-dashboard-layout-default-target-id',
  'update-dashboard-layout-default-preset-id',
  'reset-dashboard-widgets',
  'add-dashboard-widget',
  'add-dashboard-widget-by-id',
  'apply-dashboard-layout-preset',
  'create-dashboard-layout-preset',
  'update-custom-dashboard-layout-preset',
  'delete-dashboard-layout-preset',
  'export-dashboard-layout-preset',
  'import-dashboard-layout-preset',
  'export-dashboard-layout-preset-bundle',
  'import-dashboard-layout-preset-bundle',
  'save-dashboard-layout-default',
  'delete-dashboard-layout-default',
  'move-dashboard-widget',
  'start-dashboard-widget-drag',
  'hover-dashboard-widget-drag',
  'drop-dashboard-widget',
  'end-dashboard-widget-drag',
  'move-dashboard-widget-section',
  'toggle-dashboard-section',
  'toggle-dashboard-widget-size',
  'update-dashboard-widget-section',
  'update-dashboard-widget-option',
  'toggle-dashboard-widget',
  'remove-dashboard-widget',
  'load-selected-bucket-details',
  'run-object-retention-purge',
  'run-storage-expansion-execution-log-retention',
  'open-readiness-target',
  'update-readiness-category-filter',
  'update-readiness-severity-filter',
  'refresh-dashboard-readiness',
  'update-data-flow-filter',
  'refresh-data-flow-monitoring',
  'export-data-flow-csv',
  'export-data-flow-daily-rollup-csv',
  'materialize-data-flow-daily-rollup',
  'load-materialized-data-flow-daily-rollup',
  'export-materialized-data-flow-daily-rollup-csv',
  'load-data-flow-monthly-rollup',
  'export-data-flow-monthly-rollup-csv',
  'materialize-data-flow-monthly-rollup',
  'load-materialized-data-flow-monthly-rollup',
  'export-materialized-data-flow-monthly-rollup-csv',
  'refresh-data-flow-retention',
  'run-data-flow-retention',
  'reset-data-flow-filter',
])

const dashboardWidgetCategoryOrder = [
  'STORAGE',
  'OBJECTS',
  'OPERATIONS',
  'SECURITY',
  'GOVERNANCE',
  'AUDIT',
  'SHARING',
  'IDENTITY',
  'WORKSPACE',
  'CUSTOM',
]
const dashboardWidgetCategoryLabels = {
  STORAGE: 'Storage',
  OBJECTS: 'Objects',
  OPERATIONS: 'Operations',
  SECURITY: 'Security',
  GOVERNANCE: 'Governance',
  AUDIT: 'Audit',
  SHARING: 'Sharing',
  IDENTITY: 'Identity',
  WORKSPACE: 'Workspace',
  CUSTOM: 'Custom',
}

const availableDashboardWidgetGroups = computed(() => {
  const groups = new Map()
  for (const widget of props.availableDashboardWidgetOptions) {
    const category = String(widget.category || 'CUSTOM').toUpperCase()
    if (!groups.has(category)) {
      groups.set(category, { category, widgets: [] })
    }
    groups.get(category).widgets.push(widget)
  }
  return [...groups.values()]
    .map((group) => ({
      ...group,
      widgets: [...group.widgets].sort((left, right) => left.title.localeCompare(right.title)),
    }))
    .sort((left, right) => categoryRank(left.category) - categoryRank(right.category) || left.category.localeCompare(right.category))
})

const visibleDashboardWidgetSections = computed(() => {
  const knownSections = new Map(props.dashboardWidgetSections.map((section) => [section.id, section]))
  const savedSections = new Map(props.dashboardSections.map((section) => [section.id, section]))
  const groups = []
  for (const widget of props.visibleDashboardWidgets) {
    const sectionId = props.dashboardWidgetSection(widget)
    let group = groups.find((item) => item.id === sectionId)
    if (!group) {
      group = { ...(knownSections.get(sectionId) || { id: sectionId, label: props.dashboardWidgetSectionLabel(sectionId) }), widgets: [] }
      groups.push(group)
    }
    group.widgets.push(widget)
  }
  return groups.map((group, index) => ({
    ...group,
    index,
    collapsed: savedSections.get(group.id)?.collapsed === true || props.dashboardSectionCollapsed(group.id),
  }))
})

const accessKeySummary = computed(() => summarizeAccessKeys(props.accessKeys))
const dataFlowTraffic = computed(() => props.dataFlowMonitoring?.traffic || {})
const dataFlowOperations = computed(() => props.dataFlowMonitoring?.operations || {})
const dataFlowTopBuckets = computed(() => (
  Array.isArray(props.dataFlowMonitoring?.topBuckets) ? props.dataFlowMonitoring.topBuckets.slice(0, 5) : []
))
const dataFlowTrendPoints = computed(() => (
  Array.isArray(props.dataFlowMonitoring?.trendPoints) ? props.dataFlowMonitoring.trendPoints.slice(0, 8) : []
))
const dataFlowTrendMaxCount = computed(() => Math.max(
  1,
  ...dataFlowTrendPoints.value.map((point) => Number(point.totalCount || 0)),
))
const dataFlowDailyRollup = computed(() => props.dataFlowMonitoring?.dailyRollup || {})
const dataFlowDailyRollupPoints = computed(() => (
  Array.isArray(dataFlowDailyRollup.value.points) ? dataFlowDailyRollup.value.points.slice(0, 8) : []
))
const dataFlowMonthlyRollup = computed(() => props.dataFlowMonitoring?.monthlyRollup || {})
const dataFlowMonthlyRollupPoints = computed(() => (
  Array.isArray(dataFlowMonthlyRollup.value.points) ? dataFlowMonthlyRollup.value.points.slice(0, 8) : []
))
const dataFlowRecentEvents = computed(() => (
  Array.isArray(props.dataFlowMonitoring?.recentEvents) ? props.dataFlowMonitoring.recentEvents.slice(0, 5) : []
))
const dataFlowRetention = computed(() => props.dataFlowRetention || {})
const dataFlowEventRetention = computed(() => dataFlowRetention.value.eventRetention || {})
const dataFlowDailyRollupRetention = computed(() => dataFlowRetention.value.dailyRollupRetention || {})
const dataFlowMonthlyRollupRetention = computed(() => dataFlowRetention.value.monthlyRollupRetention || {})
const storageBackendStatus = computed(() => props.storageBackendStatus || {})
const dataFlowStorageStatus = computed(() => props.dataFlowStorageStatus || {})
const dataFlowRetentionEventLabel = computed(() => dataFlowRetentionPolicyLabel(dataFlowEventRetention.value))
const dataFlowRetentionRollupLabel = computed(() => dataFlowRetentionPolicyLabel(dataFlowDailyRollupRetention.value))
const dataFlowRetentionMonthlyRollupLabel = computed(() => dataFlowRetentionPolicyLabel(dataFlowMonthlyRollupRetention.value))
const dataFlowRetentionDeletedLabel = computed(() => (
  `${props.formatCount(dataFlowEventRetention.value.deletedCount || 0)} events / ${props.formatCount(dataFlowDailyRollupRetention.value.deletedCount || 0)} daily / ${props.formatCount(dataFlowMonthlyRollupRetention.value.deletedCount || 0)} monthly`
))
const dataFlowRetentionFailureLabel = computed(() => (
  `${props.formatCount(dataFlowEventRetention.value.failedRunCount || 0)} events / ${props.formatCount(dataFlowDailyRollupRetention.value.failedRunCount || 0)} daily / ${props.formatCount(dataFlowMonthlyRollupRetention.value.failedRunCount || 0)} monthly`
))
const dataFlowStorageStatusLabel = computed(() => (
  `${dataFlowStorageStatus.value.readiness || 'unknown'} / ${dataFlowStorageStatus.value.metadataMode || '-'} / ${dataFlowStorageStatus.value.repositoryHealthy ? 'healthy' : 'unhealthy'}`
))
const storageBackendStatusLabel = computed(() => (
  `${storageBackendStatus.value.readiness || 'unknown'} / ${storageBackendCapacityLabel.value} / ${props.formatCount(storageBackendStatus.value.objectCount || 0)} objects`
))
const storageBackendCapacityLabel = computed(() => (
  storageBackendStatus.value.directStorageMetricsEnabled
    ? `${props.formatBytes(storageBackendStatus.value.usedBytes || 0)} used from direct metrics`
    : storageBackendStatus.value.capacitySource === 'storage_backend_telemetry_evidence'
      ? `${props.formatBytes(storageBackendStatus.value.usedBytes || 0)} used from telemetry evidence`
      : `${props.formatBytes(storageBackendStatus.value.usedBytes || 0)} metadata used`
))
const dataFlowStorageRowsLabel = computed(() => (
  `${props.formatCount(dataFlowStorageStatus.value.eventRowCount || 0)} events / ${props.formatCount(dataFlowStorageStatus.value.dailyRollupRowCount || 0)} daily / ${props.formatCount(dataFlowStorageStatus.value.monthlyRollupRowCount || 0)} monthly`
))
const dataFlowStorageWindowLabel = computed(() => (
  `${props.formatCount(dataFlowStorageStatus.value.summaryEventScanLimit || 0)} scan / ${dataFlowStorageStatus.value.dailyRollupWindowLimitDays || '-'}d / ${dataFlowStorageStatus.value.monthlyRollupWindowLimitMonths || '-'}mo / ${dataFlowStorageStatus.value.partitionedOrTimeSeriesStoreEnabled ? 'partitioned' : 'aggregate store'}`
))

function dataFlowRetentionPolicyLabel(policy = {}) {
  if (!policy.enabled) {
    return 'Off'
  }
  const days = Number(policy.retentionDays || 0)
  const batch = Number(policy.batchSize || 0)
  const jobState = policy.jobAvailable ? 'ready' : 'job missing'
  return `${days || '-'}d / ${props.formatCount(batch)} batch / ${jobState}`
}

function dataFlowTrendWidth(point) {
  const totalCount = Math.max(0, Number(point?.totalCount || 0))
  if (totalCount === 0) {
    return '4%'
  }
  return `${Math.max(4, Math.round((totalCount / dataFlowTrendMaxCount.value) * 100))}%`
}
const dataFlowTrafficLabel = computed(() => (
  `${props.formatBytes(dataFlowTraffic.value.uploadedBytes || 0)} up / ${props.formatBytes(dataFlowTraffic.value.downloadedBytes || 0)} down / ${props.formatBytes(dataFlowTraffic.value.copiedBytes || 0)} copy`
))
const dataFlowOperationLabel = computed(() => (
  `${props.formatCount(dataFlowOperations.value.uploadCount || 0)} uploads / ${props.formatCount(dataFlowOperations.value.downloadCount || 0)} downloads / ${props.formatCount(dataFlowOperations.value.copyCount || 0)} copies / ${props.formatCount(dataFlowOperations.value.failureCount || 0)} failed / ${props.formatCount(dataFlowOperations.value.cancelCount || 0)} cancelled`
))
const dataFlowStatusLabel = computed(() => (
  Number(dataFlowOperations.value.failureCount || 0) > 0 || Number(dataFlowOperations.value.cancelCount || 0) > 0 ? 'CHECK' : 'CLEAR'
))
const dataFlowStatusClass = computed(() => (
  dataFlowStatusLabel.value === 'CHECK' ? 'mock' : 'up'
))

const storageExpansionHasSummary = computed(() => (
  Number(props.storageExpansionSummary.requestCount || 0) > 0
  || Number(props.storageExpansionSummary.executionCount || 0) > 0
  || Boolean(props.storageExpansionSummary.latestRequest)
))

const storageExpansionRequestCount = computed(() => (
  storageExpansionHasSummary.value ? Number(props.storageExpansionSummary.requestCount || 0) : props.storageExpansionRequests.length
))

const storageExpansionOpenRequestCount = computed(() => (
  storageExpansionHasSummary.value
    ? Number(props.storageExpansionSummary.openRequestCount || 0)
    : props.storageExpansionRequests.filter((request) => (
      request.status === 'PLANNED' || request.status === 'APPROVED'
    )).length
))

const storageExpansionExecutionCount = computed(() => (
  storageExpansionHasSummary.value ? Number(props.storageExpansionSummary.executionCount || 0) : props.storageExpansionExecutions.length
))

const operationsReadinessItems = computed(() => {
  const items = Array.isArray(props.dashboardReadiness.items) ? props.dashboardReadiness.items : []
  return items.filter((item) => String(item.category || '').toUpperCase() === 'OPERATIONS')
})

const operationsReadinessPrimaryMessage = computed(() => (
  operationsReadinessItems.value[0]?.message || 'Operations readiness evidence is ready.'
))

const operationsEvidencePlanItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_EVIDENCE_PLAN') || null
))

const operationsEvidenceInvocationItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_EVIDENCE_PLAN_INVOCATION') || null
))

const operationsInvocationUnblockPlanItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_INVOCATION_UNBLOCK_PLAN') || null
))

const operationsDispatchPreflightItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_DISPATCH_PREFLIGHT') || null
))

const operationsWorkflowRunIdPlanItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_WORKFLOW_RUN_ID_PLAN') || null
))

const operationsArtifactCollectionPlanItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_ARTIFACT_COLLECTION_PLAN') || null
))

const operationsReadinessArtifactImportItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_READINESS_ARTIFACT_IMPORT') || null
))

const operationsReadinessFinalizeItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_READINESS_FINALIZER') || null
))

const operationsEvidenceHandoffItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_EVIDENCE_HANDOFF') || null
))

const operationsHandoffPackageItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_HANDOFF_PACKAGE') || null
))

const dataFlowStoragePlanItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'DATA_FLOW_STORAGE_PLAN') || null
))

const minioBucketCorsVerificationItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'MINIO_BUCKET_CORS_VERIFICATION') || null
))

const operationsReadinessConvergenceItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'OPERATIONS_READINESS_CONVERGENCE') || null
))

const kubernetesOperationsReportSyncItem = computed(() => (
  operationsReadinessItems.value.find((item) => item.code === 'KUBERNETES_OPERATIONS_REPORT_SYNC') || null
))

const operationsEvidencePlanActions = computed(() => {
  const actions = props.dashboardReadiness.operationsEvidencePlan?.actions
  return Array.isArray(actions) ? actions : []
})

const operationsEvidenceInvocation = computed(() => (
  props.dashboardReadiness.operationsEvidenceInvocation || {}
))

const operationsEvidenceInvocationActions = computed(() => {
  const actions = operationsEvidenceInvocation.value?.actions
  return Array.isArray(actions) ? actions : []
})

const operationsInvocationUnblockPlan = computed(() => (
  props.dashboardReadiness.operationsInvocationUnblockPlan || {}
))

const operationsInvocationUnblockActions = computed(() => {
  const actions = operationsInvocationUnblockPlan.value?.actions
  return Array.isArray(actions) ? actions : []
})

const operationsDispatchPreflight = computed(() => (
  props.dashboardReadiness.operationsDispatchPreflight || {}
))

const operationsDispatchPreflightChecks = computed(() => {
  const checks = operationsDispatchPreflight.value?.checks
  return Array.isArray(checks) ? checks : []
})

const operationsDispatchPreflightInputs = computed(() => {
  const inputs = operationsDispatchPreflight.value?.requiredInputs
  return Array.isArray(inputs) ? inputs : []
})

const operationsDispatchPreflightWorkflowFiles = computed(() => {
  const workflows = operationsDispatchPreflight.value?.workflowFiles
  return Array.isArray(workflows) ? workflows : []
})

const operationsDispatchPreflightSelectedOrderSummary = computed(() => {
  const orders = operationsDispatchPreflight.value?.selectedActionOrders
  return Array.isArray(orders) && orders.length > 0 ? orders.slice(0, 8).join(', ') : ''
})

const operationsDispatchPreflightSourceSummary = computed(() => {
  const preflight = operationsDispatchPreflight.value || {}
  return [
    preflight.sourceResult && `result=${preflight.sourceResult}`,
    preflight.sourceUnblockPlan && `plan=${preflight.sourceUnblockPlan}`,
    preflight.requiredInputCount && `inputs=${preflight.requiredInputCount}`,
  ].filter(Boolean).join(' / ')
})

const operationsWorkflowRunIdPlan = computed(() => (
  props.dashboardReadiness.operationsWorkflowRunIdPlan || {}
))

const operationsWorkflowRunIdPlanWorkflows = computed(() => {
  const workflows = operationsWorkflowRunIdPlan.value?.workflows
  return Array.isArray(workflows) ? workflows : []
})

const operationsWorkflowRunIdPlanSourceSummary = computed(() => {
  const plan = operationsWorkflowRunIdPlan.value || {}
  return [
    plan.invocationResult && `invocation=${plan.invocationResult}`,
    plan.sourceInvocationReport && `source=${plan.sourceInvocationReport}`,
    plan.queryMode && `query=${plan.queryMode}`,
    plan.limit && `limit=${plan.limit}`,
  ].filter(Boolean).join(' / ')
})

const operationsWorkflowRunIdPlanTargetSummary = computed(() => {
  const plan = operationsWorkflowRunIdPlan.value || {}
  return [
    plan.branch && `branch=${plan.branch}`,
    plan.imageSigningVersion && `image=${plan.imageSigningVersion}`,
    plan.commitSha && `commit=${plan.commitSha}`,
  ].filter(Boolean).join(' / ')
})

const operationsArtifactCollectionPlan = computed(() => (
  props.dashboardReadiness.operationsArtifactCollectionPlan || {}
))

const operationsArtifactCollectionArtifacts = computed(() => {
  const artifacts = operationsArtifactCollectionPlan.value?.artifacts
  return Array.isArray(artifacts) ? artifacts : []
})

const operationsArtifactCollectionPlanSourceSummary = computed(() => {
  const plan = operationsArtifactCollectionPlan.value || {}
  return [
    plan.invocationResult && `invocation=${plan.invocationResult}`,
    plan.invocationSummary && `summary=${plan.invocationSummary}`,
    plan.sourceInvocationReport && `source=${plan.sourceInvocationReport}`,
  ].filter(Boolean).join(' / ')
})

const operationsReadinessArtifactImport = computed(() => (
  props.dashboardReadiness.operationsReadinessArtifactImport || {}
))

const operationsReadinessArtifactImportEntries = computed(() => {
  const entries = operationsReadinessArtifactImport.value?.entries
  return Array.isArray(entries) ? entries : []
})

const operationsReadinessFinalize = computed(() => (
  props.dashboardReadiness.operationsReadinessFinalize || {}
))

const operationsReadinessFinalizeCommands = computed(() => {
  const commands = operationsReadinessFinalize.value?.commands
  return Array.isArray(commands) ? commands : []
})

const operationsReadinessFinalizeSteps = computed(() => {
  const steps = operationsReadinessFinalize.value?.steps
  return Array.isArray(steps) ? steps : []
})

const operationsReadinessFinalizeGaps = computed(() => {
  const gaps = operationsReadinessFinalize.value?.gaps
  return Array.isArray(gaps) ? gaps : []
})

const operationsReadinessFinalizeContextSummary = computed(() => {
  const finalizer = operationsReadinessFinalize.value || {}
  return [
    finalizer.namespace && `namespace=${finalizer.namespace}`,
    finalizer.sourceNamespace && `source=${finalizer.sourceNamespace}`,
    finalizer.restoreNamespace && `restore=${finalizer.restoreNamespace}`,
    finalizer.backupTimestamp && `backup=${finalizer.backupTimestamp}`,
    finalizer.readinessSummary && `readiness=${finalizer.readinessSummary}`,
  ].filter(Boolean).join(' / ')
})

const operationsReadinessFinalizeSelectedStepSummary = computed(() => {
  const selected = operationsReadinessFinalize.value?.selectedSteps
  if (!selected || typeof selected !== 'object') {
    return ''
  }
  return Object.entries(selected)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 8)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const operationsReadinessFinalizePathSummary = computed(() => {
  const paths = operationsReadinessFinalize.value?.paths
  if (!paths || typeof paths !== 'object') {
    return ''
  }
  return Object.entries(paths)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const operationsEvidenceHandoff = computed(() => (
  props.dashboardReadiness.operationsEvidenceHandoff || {}
))

const operationsEvidenceHandoffNextStep = computed(() => (
  operationsEvidenceHandoff.value?.nextStep || {}
))

const operationsEvidenceHandoffStages = computed(() => {
  const stages = operationsEvidenceHandoff.value?.stages
  return Array.isArray(stages) ? stages : []
})

const operationsHandoffPackage = computed(() => (
  props.dashboardReadiness.operationsHandoffPackage || {}
))

const operationsHandoffPackageEvidenceRefSummary = computed(() => {
  const refs = operationsHandoffPackage.value?.evidenceRefs
  if (!refs || typeof refs !== 'object') {
    return ''
  }
  return Object.entries(refs)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const operationsHandoffPackageReadinessSnapshot = computed(() => (
  operationsHandoffPackage.value?.operationsReadinessSnapshot || {}
))

const operationsHandoffPackageConvergenceSnapshot = computed(() => (
  operationsHandoffPackage.value?.operationsConvergenceSnapshot || {}
))

const operationsHandoffPackageDataFlowStoragePlanSnapshot = computed(() => (
  operationsHandoffPackage.value?.dataFlowStoragePlanSnapshot || {}
))

const operationsHandoffPackageDataFlowQueryPlanSnapshot = computed(() => (
  operationsHandoffPackageDataFlowStoragePlanSnapshot.value?.queryPlanEvidence || {}
))

const operationsHandoffPackageDataFlowStorageTransitionRunbookSnapshot = computed(() => (
  operationsHandoffPackage.value?.dataFlowStorageTransitionRunbookSnapshot || {}
))

const operationsHandoffPackageSecretRotationSnapshot = computed(() => (
  operationsHandoffPackage.value?.secretRotationSnapshot || {}
))

const operationsHandoffPackageCommercialIntegrationSnapshot = computed(() => (
  operationsHandoffPackage.value?.commercialIntegrationSnapshot || {}
))

const operationsHandoffPackageCommercialApprovalSnapshot = computed(() => (
  operationsHandoffPackage.value?.commercialApprovalSnapshot || {}
))

const operationsHandoffPackageEnterpriseAuthSmokeSnapshot = computed(() => (
  operationsHandoffPackage.value?.enterpriseAuthSmokeSnapshot || {}
))

const operationsHandoffPackageMonitoringThresholdSnapshot = computed(() => (
  operationsHandoffPackage.value?.monitoringThresholdSnapshot || {}
))

const operationsHandoffPackageEnterpriseAuthSmokeScopeOutSummary = computed(() => {
  const scopeOut = operationsHandoffPackageEnterpriseAuthSmokeSnapshot.value?.scopeOut
  if (!scopeOut || typeof scopeOut !== 'object') {
    return ''
  }
  if (scopeOut.accepted === 'true' || scopeOut.accepted === true) {
    return `${scopeOut.reference || 'approval ref missing'} / ${scopeOut.reason || 'reason missing'}`
  }
  return ''
})

const operationsHandoffPackageChecks = computed(() => {
  const checks = operationsHandoffPackage.value?.checks
  return Array.isArray(checks) ? checks : []
})

const storageExpansionFinalize = computed(() => (
  props.dashboardReadiness.storageExpansionFinalize || {}
))

const storageExpansionFinalizeSteps = computed(() => {
  const steps = storageExpansionFinalize.value?.steps
  return Array.isArray(steps) ? steps : []
})

const storageExpansionFinalizeGaps = computed(() => {
  const gaps = storageExpansionFinalize.value?.gaps
  return Array.isArray(gaps) ? gaps : []
})

const storageExpansionFinalizeEvidenceSummary = computed(() => {
  const evidence = storageExpansionFinalize.value?.evidence
  if (!evidence || typeof evidence !== 'object') {
    return ''
  }
  return Object.entries(evidence)
    .filter(([, value]) => value)
    .slice(0, 4)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const storageExpansionFinalizeWindowSummary = computed(() => {
  const startedAt = storageExpansionFinalize.value?.startedAt || ''
  const completedAt = storageExpansionFinalize.value?.completedAt || ''
  return [startedAt && `start=${startedAt}`, completedAt && `complete=${completedAt}`]
    .filter(Boolean)
    .join(' / ')
})

const kubernetesHaDrReadiness = computed(() => (
  props.dashboardReadiness.kubernetesHaDrReadiness || {}
))

const kubernetesHaDrInputSummary = computed(() => {
  const readiness = kubernetesHaDrReadiness.value || {}
  const parts = []
  if (readiness.kubectlPath) {
    parts.push(`kubectl=${readiness.kubectlPath}`)
  }
  if (readiness.restoreManifestPath) {
    parts.push(`restoreManifest=${readiness.restoreManifestPath}`)
  }
  if (readiness.generatedAt) {
    parts.push(`generated=${readiness.generatedAt}`)
  }
  return parts.join(' / ')
})

const kubernetesHaDrChecks = computed(() => {
  const checks = kubernetesHaDrReadiness.value?.checks
  return Array.isArray(checks) ? checks : []
})

const kubernetesDrFinalize = computed(() => (
  props.dashboardReadiness.kubernetesDrFinalize || {}
))

const kubernetesDrFinalizeSteps = computed(() => {
  const steps = kubernetesDrFinalize.value?.steps
  return Array.isArray(steps) ? steps : []
})

const kubernetesDrFinalizeGaps = computed(() => {
  const gaps = kubernetesDrFinalize.value?.gaps
  return Array.isArray(gaps) ? gaps : []
})

const kubernetesDrFinalizeCommands = computed(() => {
  const commands = kubernetesDrFinalize.value?.commands
  return Array.isArray(commands) ? commands : []
})

const kubernetesDrFinalizeCommandSummary = computed(() => (
  kubernetesDrFinalizeCommands.value
    .filter((command) => command?.name)
    .slice(0, 3)
    .map((command) => command.name)
    .join(' / ')
))

const kubernetesDrFinalizeWindowSummary = computed(() => {
  const startedAt = kubernetesDrFinalize.value?.startedAt || ''
  const completedAt = kubernetesDrFinalize.value?.completedAt || ''
  return [startedAt && `start=${startedAt}`, completedAt && `complete=${completedAt}`]
    .filter(Boolean)
    .join(' / ')
})

const kubernetesDrFinalizeOptionSummary = computed(() => {
  const finalize = kubernetesDrFinalize.value || {}
  return [
    `serverDryRun=${finalize.serverDryRunOnly ? 'yes' : 'no'}`,
    `backupDrill=${finalize.runBackupDrill ? 'yes' : 'no'}`,
    `restoreSmoke=${finalize.runRestoreSmoke ? 'yes' : 'no'}`,
    `evidenceRequest=${finalize.writeEvidenceRequest ? 'yes' : 'no'}`,
    `submitEvidence=${finalize.submitEvidence ? 'yes' : 'no'}`,
    `s3Smoke=${finalize.runS3ClientSmoke ? 'yes' : 'no'}`,
  ].join(' / ')
})

const iamRbacEvidence = computed(() => (
  props.dashboardReadiness.iamRbacEvidence || {}
))

const iamRbacEvidenceCommands = computed(() => {
  const commands = iamRbacEvidence.value?.commands
  return Array.isArray(commands) ? commands : []
})

const iamRbacEvidenceSteps = computed(() => {
  const steps = iamRbacEvidence.value?.steps
  return Array.isArray(steps) ? steps : []
})

const iamRbacEvidenceGaps = computed(() => {
  const gaps = iamRbacEvidence.value?.gaps
  return Array.isArray(gaps) ? gaps : []
})

const iamRbacEvidenceCommandSummary = computed(() => (
  iamRbacEvidenceCommands.value
    .filter((command) => command?.name)
    .slice(0, 3)
    .map((command) => command.name)
    .join(' / ')
))

const iamRbacEvidenceWindowSummary = computed(() => {
  const startedAt = iamRbacEvidence.value?.startedAt || ''
  const completedAt = iamRbacEvidence.value?.completedAt || ''
  return [startedAt && `start=${startedAt}`, completedAt && `complete=${completedAt}`]
    .filter(Boolean)
    .join(' / ')
})

const iamRbacEvidenceRunCommandSummary = computed(() => {
  const powerShell = iamRbacEvidence.value?.powerShellCommand ? 'PowerShell ready' : ''
  const gradle = iamRbacEvidence.value?.gradleCommand ? 'Gradle ready' : ''
  return [powerShell, gradle].filter(Boolean).join(' / ')
})

const securityEvidence = computed(() => (
  props.dashboardReadiness.securityEvidence || {}
))

const securityEvidenceChecks = computed(() => {
  const checks = securityEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const securityEvidenceImageSummary = computed(() => {
  const imageSigning = securityEvidence.value?.imageSigning || {}
  const images = securityEvidence.value?.images || {}
  const backend = imageSigning.backendDigest || images.backendDigest || ''
  const frontend = imageSigning.frontendDigest || images.frontendDigest || ''
  const version = imageSigning.version || ''
  const parts = []
  if (version) {
    parts.push(`version ${version}`)
  }
  if (backend) {
    parts.push(`backend ${backend}`)
  }
  if (frontend) {
    parts.push(`frontend ${frontend}`)
  }
  return parts.join(' / ')
})

const securityEvidenceSignatureSummary = computed(() => {
  const imageSigning = securityEvidence.value?.imageSigning || {}
  if (!imageSigning.result) {
    return ''
  }
  return [
    `backend version=${imageSigning.backendVersionSignatureVerified ? 'yes' : 'no'}`,
    `backend sha=${imageSigning.backendShaSignatureVerified ? 'yes' : 'no'}`,
    `frontend version=${imageSigning.frontendVersionSignatureVerified ? 'yes' : 'no'}`,
    `frontend sha=${imageSigning.frontendShaSignatureVerified ? 'yes' : 'no'}`,
    imageSigning.signingMode && `mode=${imageSigning.signingMode}`,
  ].filter(Boolean).join(' / ')
})

const securityEvidenceContainerSummary = computed(() => {
  const container = securityEvidence.value?.containerSecurity || {}
  if (!container.result && !container.artifactName && !container.backendImage && !container.frontendImage) {
    return ''
  }
  const backendPackages = container.backendSbomPackageCount || 0
  const frontendPackages = container.frontendSbomPackageCount || 0
  const severity = container.severity || 'CRITICAL,HIGH'
  return [
    `scan ${severity}`,
    `ignore-unfixed ${container.ignoreUnfixed ? 'yes' : 'no'}`,
    `backend scan ${container.backendScanPassed ? 'pass' : 'pending'}`,
    `frontend scan ${container.frontendScanPassed ? 'pass' : 'pending'}`,
    `backend SBOM ${container.backendSbomValid ? 'valid' : 'pending'} (${backendPackages})`,
    `frontend SBOM ${container.frontendSbomValid ? 'valid' : 'pending'} (${frontendPackages})`,
  ].join(' / ')
})

const securityEvidenceSourceSummary = computed(() => {
  const source = securityEvidence.value?.source
  if (!source || typeof source !== 'object') {
    return ''
  }
  return Object.entries(source)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const securityEvidencePromotedSummary = computed(() => {
  const promoted = securityEvidence.value?.promoted
  if (!promoted || typeof promoted !== 'object') {
    return ''
  }
  return Object.entries(promoted)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const secretRotationEvidence = computed(() => (
  props.dashboardReadiness.secretRotationEvidence || {}
))

const secretRotationEvidenceRefSummary = computed(() => {
  const refs = secretRotationEvidence.value?.evidenceRefs
  if (!refs || typeof refs !== 'object') {
    return ''
  }
  return Object.entries(refs)
    .filter(([, value]) => value)
    .slice(0, 4)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const secretRotationWindowSummary = computed(() => {
  const window = secretRotationEvidence.value?.rotationWindow
  if (!window || typeof window !== 'object') {
    return ''
  }
  return Object.entries(window)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const secretRotationConfirmationSummary = computed(() => {
  const confirmations = secretRotationEvidence.value?.confirmations
  if (!confirmations || typeof confirmations !== 'object') {
    return ''
  }
  return Object.entries(confirmations)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 6)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const secretRotationEvidenceRotations = computed(() => {
  const rotations = secretRotationEvidence.value?.rotations
  return Array.isArray(rotations) ? rotations : []
})

const secretRotationEvidenceChecks = computed(() => {
  const checks = secretRotationEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const commercialIntegrationEvidence = computed(() => (
  props.dashboardReadiness.commercialIntegrationEvidence || {}
))

const commercialIntegrationAdapterSummary = computed(() => {
  const evidence = commercialIntegrationEvidence.value || {}
  const reviewed = evidence.paymentProviderAdapterReadinessReviewed ? 'yes' : 'no'
  const webhookCount = evidence.paymentProviderAdapterWebhookReadyProfileCount || 0
  const nativeCount = evidence.paymentProviderAdapterNativeReadyProfileCount || 0
  return `reviewed=${reviewed} / webhook-ready ${webhookCount} / native-ready ${nativeCount}`
})

const commercialIntegrationEvidenceChecks = computed(() => {
  const checks = commercialIntegrationEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const commercialApprovalEvidence = computed(() => (
  props.dashboardReadiness.commercialApprovalEvidence || {}
))

const commercialApprovalEvidenceRefSummary = computed(() => {
  const refs = commercialApprovalEvidence.value?.evidenceRefs
  if (!refs || typeof refs !== 'object') {
    return ''
  }
  return Object.entries(refs)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const commercialApprovalConfirmationSummary = computed(() => {
  const confirmations = commercialApprovalEvidence.value?.confirmations
  if (!confirmations || typeof confirmations !== 'object') {
    return ''
  }
  return Object.entries(confirmations)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 6)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const commercialApprovalEvidenceChecks = computed(() => {
  const checks = commercialApprovalEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const enterpriseAuthSmokeEvidence = computed(() => (
  props.dashboardReadiness.enterpriseAuthSmokeEvidence || {}
))

const enterpriseAuthSmokeInputSummary = computed(() => {
  const inputs = enterpriseAuthSmokeEvidence.value?.inputs
  if (!inputs || typeof inputs !== 'object') {
    return ''
  }
  return Object.entries(inputs)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 6)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const enterpriseAuthSmokeScopeOutSummary = computed(() => {
  const scopeOut = enterpriseAuthSmokeEvidence.value?.scopeOut
  if (!scopeOut || typeof scopeOut !== 'object') {
    return ''
  }
  if (scopeOut.accepted === 'true' || scopeOut.accepted === true) {
    return `${scopeOut.reference || 'approval ref missing'} / ${scopeOut.reason || 'reason missing'}`
  }
  return ''
})

const enterpriseAuthSmokeEvidenceChecks = computed(() => {
  const checks = enterpriseAuthSmokeEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const dataFlowStoragePlan = computed(() => (
  props.dashboardReadiness.dataFlowStoragePlan || {}
))

const dataFlowQueryPlanEvidence = computed(() => (
  dataFlowStoragePlan.value?.queryPlanEvidence || {}
))

const dataFlowStoragePlanChecks = computed(() => {
  const checks = dataFlowStoragePlan.value?.checks
  return Array.isArray(checks) ? checks : []
})

const dataFlowStorageTransitionRunbook = computed(() => (
  props.dashboardReadiness.dataFlowStorageTransitionRunbook || {}
))

const dataFlowStorageTransitionRunbookConfirmationSummary = computed(() => {
  const confirmations = dataFlowStorageTransitionRunbook.value?.confirmations
  if (!confirmations || typeof confirmations !== 'object') {
    return ''
  }
  return Object.entries(confirmations)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 8)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const dataFlowStorageTransitionRunbookChecks = computed(() => {
  const checks = dataFlowStorageTransitionRunbook.value?.topFailedChecks
  return Array.isArray(checks) ? checks : []
})

const storageBackendTelemetryEvidence = computed(() => (
  props.dashboardReadiness.storageBackendTelemetryEvidence || {}
))

const monitoringThresholdEvidence = computed(() => (
  props.dashboardReadiness.monitoringThresholdEvidence || {}
))

const monitoringThresholdEvidenceRefSummary = computed(() => {
  const refs = monitoringThresholdEvidence.value?.evidenceRefs
  if (!refs || typeof refs !== 'object') {
    return ''
  }
  return Object.entries(refs)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const monitoringThresholdReviewWindowSummary = computed(() => {
  const reviewWindow = monitoringThresholdEvidence.value?.reviewWindow
  if (!reviewWindow || typeof reviewWindow !== 'object') {
    return ''
  }
  return Object.entries(reviewWindow)
    .filter(([, value]) => value)
    .slice(0, 5)
    .map(([key, value]) => `${key}=${value}`)
    .join(' / ')
})

const monitoringThresholdRouteSummary = computed(() => {
  const routes = monitoringThresholdEvidence.value?.routes
  return Array.isArray(routes) ? routes.filter(Boolean).slice(0, 5).join(' / ') : ''
})

const monitoringThresholdMissingAlertSummary = computed(() => {
  const missingAlerts = monitoringThresholdEvidence.value?.missingAlerts
  return Array.isArray(missingAlerts) ? missingAlerts.filter(Boolean).slice(0, 5).join(' / ') : ''
})

const monitoringThresholdConfirmationSummary = computed(() => {
  const confirmations = monitoringThresholdEvidence.value?.confirmations
  if (!confirmations || typeof confirmations !== 'object') {
    return ''
  }
  return Object.entries(confirmations)
    .filter(([, value]) => typeof value === 'boolean')
    .slice(0, 6)
    .map(([key, value]) => `${key}=${value ? 'yes' : 'no'}`)
    .join(' / ')
})

const monitoringThresholdEvidenceChecks = computed(() => {
  const checks = monitoringThresholdEvidence.value?.checks
  return Array.isArray(checks) ? checks : []
})

const minioBucketCorsVerification = computed(() => (
  props.dashboardReadiness.minioBucketCorsVerification || {}
))

const minioBucketCorsChecks = computed(() => {
  const checks = minioBucketCorsVerification.value?.checks
  return Array.isArray(checks) ? checks : []
})

const minioBucketCorsExposeSummary = computed(() => {
  const exposeHeaders = minioBucketCorsVerification.value?.exposeHeaders
  return Array.isArray(exposeHeaders) ? exposeHeaders.slice(0, 6).join(' / ') : ''
})

const minioBucketCorsAllowedHeadersSummary = computed(() => {
  const allowedHeaders = minioBucketCorsVerification.value?.allowedHeaders
  return Array.isArray(allowedHeaders) ? allowedHeaders.slice(0, 6).join(' / ') : ''
})

const minioBucketCorsMaxAgeSummary = computed(() => {
  const maxAgeSeconds = minioBucketCorsVerification.value?.maxAgeSeconds
  return Array.isArray(maxAgeSeconds) ? maxAgeSeconds.slice(0, 6).join(' / ') : ''
})

const minioBucketCorsOperatorCommands = computed(() => {
  const commands = minioBucketCorsVerification.value?.operatorCommands || {}
  return [
    { name: 'collectAndVerify', label: 'Collect Verify', command: commands.collectAndVerify },
    { name: 'collectWithMc', label: 'Collect with mc', command: commands.collectWithMc },
    { name: 'verifyFromFile', label: 'Verify File', command: commands.verifyFromFile },
  ].filter((command) => command.command)
})

const operationsReadinessConvergence = computed(() => (
  props.dashboardReadiness.operationsReadinessConvergence || {}
))

const operationsReadinessConvergenceBottleneck = computed(() => (
  operationsReadinessConvergence.value?.currentBottleneck || {}
))

const operationsReadinessConvergenceCommands = computed(() => {
  const commands = operationsReadinessConvergence.value?.recommendedCommands
  return Array.isArray(commands) ? commands : []
})

const kubernetesOperationsReportSync = computed(() => (
  props.dashboardReadiness.kubernetesOperationsReportSync || {}
))

const kubernetesOperationsReportSyncChecks = computed(() => {
  const checks = kubernetesOperationsReportSync.value?.checks
  return Array.isArray(checks) ? checks : []
})

function hasReadinessRemediation(item) {
  return Boolean(
    item?.remediationCommand
    || item?.remediationWorkflow
    || item?.remediationWorkflowCommand
    || item?.remediationNote
    || item?.evidencePath
  )
}

function evidencePlanActionCommand(action) {
  return action?.recommendedCommand || action?.workflowCommand || action?.localCommand || ''
}

function formatEvidencePlanActionMeta(action) {
  const inputs = Array.isArray(action?.operatorInputs) && action.operatorInputs.length > 0
    ? `inputs ${action.operatorInputs.join(', ')}`
    : 'inputs none'
  const approval = action?.requiresOperatorApproval ? 'approval required' : 'approval not flagged'
  const kubeconfig = action?.requiresKubeconfigSecret ? 'kubeconfig required' : 'kubeconfig not detected'
  return `${action?.category || 'operations'} / ${inputs} / ${approval} / ${kubeconfig}`
}

function formatEvidenceInvocationActionMeta(action) {
  const unresolved = Array.isArray(action?.unresolvedPlaceholders) && action.unresolvedPlaceholders.length > 0
    ? `unresolved ${action.unresolvedPlaceholders.join(', ')}`
    : 'unresolved none'
  const invalid = Array.isArray(action?.invalidPlaceholders) && action.invalidPlaceholders.length > 0
    ? `invalid ${action.invalidPlaceholders.join(', ')}`
    : 'invalid none'
  const approval = action?.requiresOperatorApproval ? 'approval required' : 'approval not flagged'
  const kubeconfig = action?.requiresKubeconfigSecret ? 'kubeconfig required' : 'kubeconfig not detected'
  return `${action?.category || 'operations'} / ${action?.commandMode || 'command'} / ${unresolved} / ${invalid} / ${approval} / ${kubeconfig}`
}

function formatInvocationBlockReasons(action) {
  const reasons = Array.isArray(action?.blockReasons) ? action.blockReasons : []
  return reasons.length > 0 ? `Blocked: ${reasons.join(', ')}` : ''
}

function formatInvocationUnblockConfirmationMeta() {
  const needs = []
  if (operationsInvocationUnblockPlan.value?.needsKubeconfigSecretConfirmation) {
    needs.push('kubeconfig secret confirmation')
  }
  if (operationsInvocationUnblockPlan.value?.needsOperatorApprovalConfirmation) {
    needs.push('operator approval')
  }
  if (operationsInvocationUnblockPlan.value?.decisionRule) {
    needs.push(operationsInvocationUnblockPlan.value.decisionRule)
  }
  return needs.join(' / ')
}

function formatInvocationUnblockActionMeta(action) {
  const approval = action?.needsOperatorApprovalConfirmation ? 'approval required' : 'approval not flagged'
  const kubeconfig = action?.needsKubeconfigSecretConfirmation ? 'kubeconfig required' : 'kubeconfig not detected'
  const ambiguous = action?.ambiguousRepeatedPlaceholders ? 'ambiguous placeholders' : 'placeholders mapped'
  const invalid = Array.isArray(action?.invalidPlaceholders) && action.invalidPlaceholders.length > 0
    ? `invalid ${action.invalidPlaceholders.join(', ')}`
    : 'invalid none'
  return `${action?.category || 'operations'} / ${approval} / ${kubeconfig} / ${ambiguous} / ${invalid}`
}

function formatInvocationUnblockInputs(action) {
  const inputs = Array.isArray(action?.requiredInputs) ? action.requiredInputs : []
  if (inputs.length === 0) {
    const reasons = Array.isArray(action?.blockReasons) ? action.blockReasons : []
    return reasons.length > 0 ? `Blocked: ${reasons.join(', ')}` : ''
  }
  return `Inputs: ${inputs.map((input) => `${input.parameter || input.placeholder}=${input.valueTemplate || '<value>'}`).join(', ')}`
}

function formatDispatchPreflightSecrets() {
  const secrets = Array.isArray(operationsDispatchPreflight.value?.requiredGitHubSecrets)
    ? operationsDispatchPreflight.value.requiredGitHubSecrets
    : []
  return secrets.length > 0 ? `Secrets: ${secrets.join(', ')}` : ''
}

function formatDispatchPreflightInputMeta(input) {
  const action = input?.actionOrder ? `action ${input.actionOrder}` : 'action unknown'
  const placeholder = input?.placeholder || 'placeholder unknown'
  const preview = input?.valuePreview ? `value ${input.valuePreview}` : 'value required'
  const ambiguous = input?.ambiguousRepeatedPlaceholder ? 'ambiguous repeated placeholder' : 'single placeholder'
  const safety = input?.safeValue === false ? 'unsafe value' : 'safe value'
  const validity = input?.validValue === false ? 'invalid shape' : 'valid shape'
  return `${action} / ${placeholder} / ${preview} / ${ambiguous} / ${safety} / ${validity}`
}

function formatDispatchPreflightWorkflowMeta(workflow) {
  const secrets = Array.isArray(workflow?.requiredSecrets) && workflow.requiredSecrets.length > 0
    ? `secrets ${workflow.requiredSecrets.join(', ')}`
    : 'secrets none'
  const action = workflow?.actionOrder ? `action ${workflow.actionOrder}` : 'action unknown'
  return `${action} / ${secrets}`
}

function formatWorkflowRunIdMeta(workflow) {
  const recommended = workflow?.recommendedRunId ? `recommended ${workflow.recommendedRunId}` : 'no successful run'
  const candidates = Number(workflow?.candidateCount || 0)
  const branch = operationsWorkflowRunIdPlan.value?.branch || 'branch unknown'
  return `${workflow?.group || 'operations'} / ${branch} / ${candidates} candidates / ${recommended}`
}

function formatArtifactCollectionMeta(artifact) {
  const required = artifact?.requiredForReadiness ? 'required' : 'source'
  const runId = artifact?.runId ? `run ${artifact.runId}` : 'run id missing'
  const workflow = artifact?.workflow || 'workflow unknown'
  return `${workflow} / ${required} / ${runId}`
}

function formatArtifactImportEntryMeta(entry) {
  const file = entry?.fileName || 'file unknown'
  const detail = entry?.detail || 'detail unavailable'
  const destination = entry?.destinationPath ? `dest ${entry.destinationPath}` : 'not promoted'
  return `${file} / ${detail} / ${destination}`
}

function formatReadinessFinalizeCommandMeta(command) {
  const script = command?.script || 'script unknown'
  const args = Array.isArray(command?.arguments) ? command.arguments.length : 0
  const shell = operationsReadinessFinalize.value?.powerShellCommand || 'shell unknown'
  return `${script} / ${args} args / ${shell}`
}

function formatReadinessFinalizeStepMeta(step) {
  const exitCode = Number(step?.exitCode || 0)
  const script = step?.script || 'script unknown'
  return `${script} / exit ${exitCode}`
}

function formatEvidenceHandoffStageState(stage) {
  if (stage?.ready) return 'ready'
  if (stage?.exists) return 'needs action'
  return 'missing'
}

function formatEvidenceHandoffStageMeta(stage) {
  const summary = stage?.summary || 'summary unavailable'
  const result = stage?.result || 'unknown'
  return `${result} / ${summary}`
}

function formatKubernetesReportSyncCheckMeta(check) {
  const summary = check?.summary || 'summary unavailable'
  const exitCode = Number(check?.exitCode || 0)
  return `${summary} / exit ${exitCode}`
}

async function copyReadinessRemediationCommand(command) {
  if (!command) return
  try {
    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(command)
      return
    }
    fallbackCopyText(command)
  } catch {
    fallbackCopyText(command)
  }
}

function fallbackCopyText(text) {
  if (typeof document === 'undefined') return
  const textarea = document.createElement('textarea')
  textarea.value = text
  textarea.setAttribute('readonly', 'readonly')
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  document.body.appendChild(textarea)
  textarea.select()
  try {
    document.execCommand('copy')
  } finally {
    document.body.removeChild(textarea)
  }
}

const storageExpansionIssueExecutionCount = computed(() => (
  Number(props.storageExpansionSummary.failedExecutionCount || 0)
  + Number(props.storageExpansionSummary.timedOutExecutionCount || 0)
))

const storageExpansionOpenCapacityBytes = computed(() => (
  storageExpansionHasSummary.value
    ? Number(props.storageExpansionSummary.openRequestedCapacityBytes || 0)
    : props.storageExpansionRequests
      .filter((request) => request.status === 'PLANNED' || request.status === 'APPROVED')
      .reduce((total, request) => total + Number(request.requestedCapacityBytes || 0), 0)
))

const latestStorageExpansionRequests = computed(() => {
  if (props.storageExpansionRequests.length > 0) return props.storageExpansionRequests.slice(0, 3)
  return props.storageExpansionSummary.latestRequest ? [props.storageExpansionSummary.latestRequest] : []
})

const recentStorageExpansionExecutions = computed(() => {
  if (Array.isArray(props.storageExpansionSummary.recentExecutions) && props.storageExpansionSummary.recentExecutions.length > 0) {
    return props.storageExpansionSummary.recentExecutions.slice(0, 5)
  }
  return props.storageExpansionExecutions.slice(0, 5)
})

function categoryRank(category) {
  const index = dashboardWidgetCategoryOrder.indexOf(category)
  return index === -1 ? dashboardWidgetCategoryOrder.length : index
}

function dashboardWidgetCategoryLabel(category) {
  return dashboardWidgetCategoryLabels[category] || category
}

function categoryTestId(category) {
  return String(category || 'custom').toLowerCase().replace(/[^a-z0-9-]+/g, '-')
}

function storageExpansionStatusCount(status) {
  if (storageExpansionHasSummary.value) {
    if (status === 'APPLIED') return Number(props.storageExpansionSummary.appliedRequestCount || 0)
    if (status === 'REJECTED') return Number(props.storageExpansionSummary.rejectedRequestCount || 0)
  }
  return props.storageExpansionRequests.filter((request) => request.status === status).length
}
</script>
