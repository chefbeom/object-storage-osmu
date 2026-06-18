<template>
  <section class="dashboard-config-panel panel" data-testid="dashboard-config-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Dashboard Palettes</p>
        <h3>대시보드 패널 구성</h3>
        <small data-testid="dashboard-layout-sync">{{ dashboardLayoutSyncLabel }}</small>
      </div>
      <button data-testid="dashboard-widget-reset-button" type="button" class="ghost" :disabled="dashboardLayoutPending" @click="$emit('reset-dashboard-widgets')">초기화</button>
    </div>
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
          <small>{{ widget.enabled ? '표시 중' : '숨김' }} · {{ dashboardWidgetSizeLabel(widget.size) }} · {{ dashboardWidgetToneLabel(widget) }}</small>
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
  </section>

  <section class="dashboard-widget-sections" data-testid="dashboard-widget-sections">
    <section
      v-for="section in visibleDashboardWidgetSections"
      :key="section.id"
      class="dashboard-widget-section"
      :data-testid="`dashboard-widget-section-${section.id}`"
    >
      <div class="dashboard-widget-section-head">
        <h3>{{ dashboardWidgetSectionLabel(section.id) }}</h3>
        <span class="section-actions">
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
          {{ operationsReadinessConvergence.readyStageCount }} of {{ operationsReadinessConvergence.stageCount }} stages ready
        </small>
        <small v-if="operationsReadinessConvergence.kubernetesReportSyncConfigMapName">
          report sync {{ operationsReadinessConvergence.kubernetesReportSyncConfigMapName }} /
          {{ operationsReadinessConvergence.kubernetesReportSyncReady ? 'applied' : 'not applied' }}
        </small>
        <small v-if="operationsReadinessConvergenceBottleneck.reason">
          {{ operationsReadinessConvergenceBottleneck.reason }}
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
          checks {{ kubernetesOperationsReportSync.checkCount || 0 }} /
          failed {{ kubernetesOperationsReportSync.failedCount || 0 }}
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
          {{ operationsDispatchPreflight.warningCheckCount }} warnings
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
          {{ operationsWorkflowRunIdPlan.missingWorkflowCount }} missing
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
          {{ operationsArtifactCollectionPlan.missingRequiredArtifactCount }} missing required
        </small>
        <div class="readiness-artifact-command-row">
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
          {{ operationsReadinessArtifactImport.importedCount }} imported /
          {{ operationsReadinessArtifactImport.failedCount }} failed /
          {{ operationsReadinessArtifactImport.selectedGroupCount }} groups
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
          readiness {{ operationsReadinessFinalize.readinessResult || 'unknown' }} /
          failed {{ operationsReadinessFinalize.failedCount }} /
          gaps {{ operationsReadinessFinalizeGaps.length }}
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
        <div class="data-flow-filter-actions">
          <button data-testid="data-flow-refresh-button" type="submit" class="ghost">Refresh</button>
          <button data-testid="data-flow-export-button" type="button" class="ghost" @click="$emit('export-data-flow-csv')">CSV</button>
          <button data-testid="data-flow-reset-button" type="button" class="ghost" @click="$emit('reset-data-flow-filter')">Reset</button>
        </div>
      </form>
      <dl class="status-dl compact">
        <div>
          <dt>Total Traffic</dt>
          <dd data-testid="data-flow-total-bytes">{{ formatBytes(dataFlowTraffic.totalBytes || 0) }}</dd>
        </div>
        <div>
          <dt>Upload / Download</dt>
          <dd>{{ formatBytes(dataFlowTraffic.uploadedBytes || 0) }} / {{ formatBytes(dataFlowTraffic.downloadedBytes || 0) }}</dd>
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
      <ul class="compact-list" data-testid="data-flow-top-buckets">
        <li v-if="dataFlowTopBuckets.length === 0">
          <span>
            <strong>No bucket traffic yet</strong>
            <small>uploads and downloads will appear here</small>
          </span>
        </li>
        <li v-for="bucket in dataFlowTopBuckets" :key="bucket.bucketName">
          <span>
            <strong>{{ bucket.bucketName }}</strong>
            <small>{{ formatBytes(bucket.totalBytes || 0) }} / {{ formatCount(bucket.uploadCount || 0) }} uploads / {{ formatCount(bucket.downloadCount || 0) }} downloads / {{ formatCount(bucket.listCount || 0) }} lists</small>
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
  usagePercent: { type: Number, required: true },
  usage: { type: Object, required: true },
  selectedBucket: { type: String, required: true },
  objectViewMode: { type: String, required: true },
  health: { type: Object, required: true },
  backupStatus: { type: Object, required: true },
  uploadState: { type: Object, required: true },
  dataFlowMonitoring: { type: Object, required: true },
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
const dataFlowRecentEvents = computed(() => (
  Array.isArray(props.dataFlowMonitoring?.recentEvents) ? props.dataFlowMonitoring.recentEvents.slice(0, 5) : []
))
const dataFlowTrafficLabel = computed(() => (
  `${props.formatBytes(dataFlowTraffic.value.uploadedBytes || 0)} up / ${props.formatBytes(dataFlowTraffic.value.downloadedBytes || 0)} down`
))
const dataFlowOperationLabel = computed(() => (
  `${props.formatCount(dataFlowOperations.value.uploadCount || 0)} uploads / ${props.formatCount(dataFlowOperations.value.downloadCount || 0)} downloads / ${props.formatCount(dataFlowOperations.value.failureCount || 0)} failed / ${props.formatCount(dataFlowOperations.value.cancelCount || 0)} cancelled`
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

const operationsWorkflowRunIdPlan = computed(() => (
  props.dashboardReadiness.operationsWorkflowRunIdPlan || {}
))

const operationsWorkflowRunIdPlanWorkflows = computed(() => {
  const workflows = operationsWorkflowRunIdPlan.value?.workflows
  return Array.isArray(workflows) ? workflows : []
})

const operationsArtifactCollectionPlan = computed(() => (
  props.dashboardReadiness.operationsArtifactCollectionPlan || {}
))

const operationsArtifactCollectionArtifacts = computed(() => {
  const artifacts = operationsArtifactCollectionPlan.value?.artifacts
  return Array.isArray(artifacts) ? artifacts : []
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
  const placeholders = Array.isArray(action?.unresolvedPlaceholders) && action.unresolvedPlaceholders.length > 0
    ? `unresolved ${action.unresolvedPlaceholders.join(', ')}`
    : 'unresolved none'
  const approval = action?.requiresOperatorApproval ? 'approval required' : 'approval not flagged'
  const kubeconfig = action?.requiresKubeconfigSecret ? 'kubeconfig required' : 'kubeconfig not detected'
  return `${action?.category || 'operations'} / ${action?.commandMode || 'command'} / ${placeholders} / ${approval} / ${kubeconfig}`
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
  return `${action?.category || 'operations'} / ${approval} / ${kubeconfig} / ${ambiguous}`
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
  return `${action} / ${placeholder} / ${preview} / ${ambiguous}`
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
