<template>
  <article v-if="isAdmin" class="panel" data-testid="storage-expansion-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Storage Expansion</p>
        <h3>MinIO Pool 증설 요청</h3>
      </div>
    </div>
    <form class="quota-form" data-testid="storage-expansion-form" @submit.prevent="$emit('create-storage-expansion-request')">
      <input data-testid="storage-expansion-capacity-input" v-model.number="storageExpansionForm.capacityGb" min="1" type="number" />
      <input data-testid="storage-expansion-server-count-input" v-model.number="storageExpansionForm.serverCount" min="4" max="32" type="number" />
      <input data-testid="storage-expansion-volumes-input" v-model.number="storageExpansionForm.volumesPerServer" min="1" max="16" type="number" />
      <input data-testid="storage-expansion-reason-input" v-model="storageExpansionForm.reason" placeholder="reason" />
      <button data-testid="storage-expansion-create-button" type="submit" :disabled="!storageExpansionForm.capacityGb">
        Request
      </button>
    </form>
    <div class="inline-form storage-expansion-apply-form">
      <input
        data-testid="storage-expansion-apply-evidence-input"
        :value="storageExpansionApplyEvidence"
        placeholder="apply evidence URL or command"
        @input="$emit('update-storage-expansion-apply-evidence', $event.target.value)"
      />
    </div>
    <section class="storage-expansion-preview" data-testid="storage-expansion-runner-preflight-panel">
      <div class="panel-head compact">
        <div>
          <p class="eyebrow">Runner Preflight</p>
          <h4>Server execution readiness</h4>
        </div>
        <div class="key-actions">
          <span :class="['status-pill', runnerPreflightStatusClass(storageExpansionRunnerPreflight.status)]">
            {{ storageExpansionRunnerPreflight.status }}
          </span>
          <button
            data-testid="storage-expansion-runner-preflight-refresh-button"
            type="button"
            class="ghost"
            @click="$emit('refresh-storage-expansion-runner-preflight')"
          >
            Refresh
          </button>
        </div>
      </div>
      <dl class="status-dl compact">
        <div>
          <dt>Enabled</dt>
          <dd>{{ storageExpansionRunnerPreflight.enabledRunnerCount || 0 }}</dd>
        </div>
        <div>
          <dt>Failed</dt>
          <dd>{{ storageExpansionRunnerPreflight.failedCheckCount || 0 }}</dd>
        </div>
      </dl>
      <ul class="compact-list" data-testid="storage-expansion-runner-preflight-list">
        <li v-for="check in storageExpansionRunnerPreflight.checks" :key="check.id">
          <span class="list-main">
            <b>{{ check.label }} / {{ check.status }}</b>
            <small>{{ check.detail || '-' }}</small>
            <small v-if="check.remediation" data-testid="storage-expansion-runner-preflight-remediation">
              {{ check.remediation }}
            </small>
            <small v-if="(check.commands || []).length">{{ check.commands.join(' | ') }}</small>
          </span>
        </li>
        <li v-if="(storageExpansionRunnerPreflight.checks || []).length === 0" class="empty">No runner preflight result</li>
      </ul>
    </section>
    <ul class="compact-list" data-testid="storage-expansion-list">
      <li v-for="request in storageExpansionRequests" :key="request.id">
        <span class="list-main">
          <b>{{ request.poolName }} / {{ request.status }}</b>
          <small>
            usable {{ formatBytes(request.estimatedUsableCapacityBytes) }}
            / raw {{ formatBytes(request.estimatedRawCapacityBytes) }}
            / {{ request.serverCount }} servers x {{ request.volumesPerServer }} PV
            / PV {{ formatBytes(request.volumeSizeBytes) }}
          </small>
          <small>{{ request.reason || '-' }}</small>
          <small v-if="request.appliedEvidence">
            applied {{ request.appliedBy || '-' }} / {{ formatDateTime(request.appliedAt) }} / {{ request.appliedEvidence }}
          </small>
        </span>
        <span class="key-actions">
          <button data-testid="storage-expansion-preview-button" type="button" class="ghost" @click="$emit('preview-storage-expansion-manifest', request)">Preview</button>
          <button data-testid="storage-expansion-execution-plan-button" type="button" class="ghost" :disabled="request.status !== 'APPROVED'" @click="$emit('create-storage-expansion-execution-plan', request)">Dry Run</button>
          <button data-testid="storage-expansion-gitops-plan-button" type="button" class="ghost" :disabled="request.status !== 'APPROVED'" @click="$emit('create-storage-expansion-gitops-plan', request)">GitOps</button>
          <button data-testid="storage-expansion-execution-history-button" type="button" class="ghost" @click="$emit('load-storage-expansion-executions', request)">History</button>
          <button data-testid="storage-expansion-approve-button" type="button" class="ghost" :disabled="request.status !== 'PLANNED'" @click="$emit('update-storage-expansion-status', { request, status: 'APPROVED' })">Approve</button>
          <button
            data-testid="storage-expansion-apply-button"
            type="button"
            class="ghost"
            :disabled="request.status !== 'APPROVED' || !storageExpansionApplyEvidence.trim()"
            @click="$emit('update-storage-expansion-status', { request, status: 'APPLIED', appliedEvidence: storageExpansionApplyEvidence })"
          >
            Apply
          </button>
          <button data-testid="storage-expansion-reject-button" type="button" class="danger" :disabled="!['PLANNED', 'APPROVED'].includes(request.status)" @click="$emit('update-storage-expansion-status', { request, status: 'REJECTED' })">Reject</button>
        </span>
      </li>
      <li v-if="storageExpansionRequests.length === 0" class="empty">증설 요청 없음</li>
    </ul>
    <section v-if="storageExpansionManifest" class="storage-expansion-preview" data-testid="storage-expansion-preview-panel">
      <div class="panel-head compact">
        <div>
          <p class="eyebrow">Manifest Preview</p>
          <h4>{{ storageExpansionManifest.poolName }} / {{ storageExpansionManifest.status }}</h4>
        </div>
        <div class="key-actions">
          <button data-testid="storage-expansion-download-tenant-button" type="button" class="ghost" @click="$emit('download-storage-expansion-manifest', 'tenant')">Tenant</button>
          <button data-testid="storage-expansion-download-helm-button" type="button" class="ghost" @click="$emit('download-storage-expansion-manifest', 'helm')">Helm</button>
          <button data-testid="storage-expansion-download-bundle-button" type="button" class="ghost" @click="$emit('download-storage-expansion-manifest', 'bundle')">Bundle</button>
        </div>
      </div>
      <textarea data-testid="storage-expansion-tenant-yaml" readonly :value="storageExpansionManifest.tenantPatchYaml"></textarea>
      <textarea data-testid="storage-expansion-helm-yaml" readonly :value="storageExpansionManifest.helmValuesPatchYaml"></textarea>
    </section>
    <section v-if="storageExpansionExecutionPlan" class="storage-expansion-preview" data-testid="storage-expansion-execution-plan-panel">
      <div class="panel-head compact">
        <div>
          <p class="eyebrow">Execution Dry Run</p>
          <h4>{{ storageExpansionExecutionPlan.poolName }} / {{ storageExpansionExecutionPlan.status }}</h4>
        </div>
      </div>
      <p class="digest-line" data-testid="storage-expansion-execution-digest">
        sha256: {{ storageExpansionExecutionPlan.artifactSha256 }}
      </p>
      <ul class="compact-list" data-testid="storage-expansion-preflight-list">
        <li v-for="check in storageExpansionExecutionPlan.preflightChecks" :key="check">{{ check }}</li>
      </ul>
      <textarea data-testid="storage-expansion-execution-commands" readonly :value="storageExpansionExecutionPlan.suggestedCommands.join('\n')"></textarea>
      <div class="inline-form storage-expansion-dry-run-form">
        <select data-testid="storage-expansion-dry-run-type-select" v-model="storageExpansionExecutionForm.dryRunType">
          <option value="KUBECTL_DIFF">KUBECTL_DIFF</option>
          <option value="HELM_DIFF">HELM_DIFF</option>
        </select>
        <select data-testid="storage-expansion-dry-run-result-select" v-model="storageExpansionExecutionForm.dryRunResult">
          <option value="SUCCESS">SUCCESS</option>
          <option value="FAILED">FAILED</option>
          <option value="SKIPPED">SKIPPED</option>
        </select>
        <input data-testid="storage-expansion-dry-run-url-input" v-model="storageExpansionExecutionForm.dryRunExternalUrl" placeholder="dry-run log URL" />
        <input data-testid="storage-expansion-dry-run-notes-input" v-model="storageExpansionExecutionForm.dryRunNotes" placeholder="dry-run notes" />
        <button
          data-testid="storage-expansion-dry-run-record-button"
          type="button"
          class="ghost"
          :disabled="!storageExpansionExecutionPlan.requestId || (storageExpansionExecutionForm.dryRunResult !== 'SKIPPED' && !storageExpansionExecutionForm.dryRunOutput.trim())"
          @click="$emit('record-storage-expansion-dry-run-execution')"
        >
          Record Dry Run
        </button>
        <button
          data-testid="storage-expansion-dry-run-runner-button"
          type="button"
          class="ghost"
          :disabled="!storageExpansionExecutionPlan.requestId"
          @click="$emit('run-storage-expansion-dry-run-execution')"
        >
          Run Server Dry Run
        </button>
        <select data-testid="storage-expansion-apply-run-type-select" v-model="storageExpansionExecutionForm.applyRunType">
          <option value="KUBECTL_APPLY">KUBECTL_APPLY</option>
          <option value="HELM_UPGRADE">HELM_UPGRADE</option>
        </select>
        <button
          data-testid="storage-expansion-apply-runner-button"
          type="button"
          class="ghost"
          :disabled="!storageExpansionExecutionPlan.requestId"
          @click="$emit('run-storage-expansion-apply-execution')"
        >
          Run Server Apply
        </button>
      </div>
      <textarea data-testid="storage-expansion-dry-run-output-input" v-model="storageExpansionExecutionForm.dryRunOutput" placeholder="kubectl diff / helm diff output"></textarea>
    </section>
    <section v-if="storageExpansionGitOpsPlan" class="storage-expansion-preview" data-testid="storage-expansion-gitops-plan-panel">
      <div class="panel-head compact">
        <div>
          <p class="eyebrow">GitOps PR Draft</p>
          <h4>{{ storageExpansionGitOpsPlan.poolName }} / {{ storageExpansionGitOpsPlan.status }}</h4>
        </div>
        <div class="key-actions">
          <button data-testid="storage-expansion-gitops-bundle-download-button" type="button" class="ghost" @click="$emit('download-storage-expansion-gitops-bundle')">ZIP</button>
          <button
            data-testid="storage-expansion-gitops-pr-runner-button"
            type="button"
            class="ghost"
            :disabled="!storageExpansionGitOpsPlan.requestId"
            @click="$emit('run-storage-expansion-gitops-pr-execution')"
          >
            Run PR
          </button>
        </div>
      </div>
      <p class="digest-line" data-testid="storage-expansion-gitops-branch">
        branch: {{ storageExpansionGitOpsPlan.branchName }}
      </p>
      <p class="digest-line" data-testid="storage-expansion-gitops-commit">
        commit: {{ storageExpansionGitOpsPlan.commitMessage }}
      </p>
      <ul class="compact-list" data-testid="storage-expansion-gitops-files">
        <li v-for="file in (storageExpansionGitOpsPlan.changedFiles || [])" :key="file">{{ file }}</li>
      </ul>
      <ul class="compact-list" data-testid="storage-expansion-gitops-review-list">
        <li v-for="item in (storageExpansionGitOpsPlan.reviewChecklist || [])" :key="item">{{ item }}</li>
      </ul>
      <textarea data-testid="storage-expansion-gitops-pr-body" readonly :value="storageExpansionGitOpsPlan.pullRequestBody"></textarea>
      <div class="inline-form storage-expansion-gitops-pr-form">
        <input data-testid="storage-expansion-gitops-pr-url-input" v-model="storageExpansionExecutionForm.gitOpsPrUrl" placeholder="GitOps PR URL" />
        <input data-testid="storage-expansion-gitops-merge-sha-input" v-model="storageExpansionExecutionForm.gitOpsMergeSha" placeholder="merge SHA" />
        <input data-testid="storage-expansion-gitops-pipeline-url-input" v-model="storageExpansionExecutionForm.gitOpsPipelineUrl" placeholder="pipeline URL" />
        <input data-testid="storage-expansion-gitops-notes-input" v-model="storageExpansionExecutionForm.gitOpsNotes" placeholder="GitOps notes" />
        <button
          data-testid="storage-expansion-gitops-pr-record-button"
          type="button"
          class="ghost"
          :disabled="!storageExpansionGitOpsPlan.requestId || !storageExpansionExecutionForm.gitOpsPrUrl.trim()"
          @click="$emit('record-storage-expansion-gitops-pr-execution')"
        >
          Record PR
        </button>
      </div>
    </section>
    <section class="storage-expansion-preview" data-testid="storage-expansion-execution-history-panel">
      <div class="panel-head compact">
        <div>
          <p class="eyebrow">Execution History</p>
          <h4>Dry-run / GitOps / Apply Evidence</h4>
        </div>
      </div>
      <form class="quota-form" data-testid="storage-expansion-execution-record-form" @submit.prevent="$emit('create-storage-expansion-execution-record')">
        <input data-testid="storage-expansion-execution-request-id-input" v-model.number="storageExpansionExecutionForm.requestId" min="1" type="number" placeholder="request id" />
        <select data-testid="storage-expansion-execution-type-select" v-model="storageExpansionExecutionForm.executionType">
          <option value="DRY_RUN">DRY_RUN</option>
          <option value="GITOPS_PR">GITOPS_PR</option>
          <option value="HELM_DIFF">HELM_DIFF</option>
          <option value="KUBECTL_DIFF">KUBECTL_DIFF</option>
          <option value="APPLY">APPLY</option>
          <option value="ROLLBACK">ROLLBACK</option>
        </select>
        <select data-testid="storage-expansion-execution-result-select" v-model="storageExpansionExecutionForm.result">
          <option value="SUCCESS">SUCCESS</option>
          <option value="FAILED">FAILED</option>
          <option value="SKIPPED">SKIPPED</option>
        </select>
        <input data-testid="storage-expansion-execution-command-input" v-model="storageExpansionExecutionForm.command" placeholder="command" />
        <input data-testid="storage-expansion-execution-artifact-input" v-model="storageExpansionExecutionForm.artifactSha256" placeholder="artifact sha256" />
        <input data-testid="storage-expansion-execution-url-input" v-model="storageExpansionExecutionForm.externalUrl" placeholder="external URL" />
        <input data-testid="storage-expansion-execution-notes-input" v-model="storageExpansionExecutionForm.notes" placeholder="notes" />
        <button data-testid="storage-expansion-execution-record-button" type="submit" :disabled="!storageExpansionExecutionForm.requestId">
          Record
        </button>
        <select data-testid="storage-expansion-rollback-type-select" v-model="storageExpansionExecutionForm.rollbackType">
          <option value="HELM_ROLLBACK">HELM_ROLLBACK</option>
          <option value="KUBECTL_ROLLOUT_UNDO">KUBECTL_ROLLOUT_UNDO</option>
        </select>
        <input data-testid="storage-expansion-rollback-revision-input" v-model.number="storageExpansionExecutionForm.rollbackHelmRevision" min="1" type="number" placeholder="helm revision" />
        <input data-testid="storage-expansion-rollback-target-input" v-model="storageExpansionExecutionForm.rollbackKubectlTarget" placeholder="kubectl target" />
        <button
          data-testid="storage-expansion-rollback-runner-button"
          type="button"
          class="ghost"
          :disabled="!storageExpansionExecutionForm.requestId"
          @click="$emit('run-storage-expansion-rollback-execution')"
        >
          Run Rollback
        </button>
      </form>
      <textarea data-testid="storage-expansion-execution-output-input" v-model="storageExpansionExecutionForm.output" placeholder="output summary"></textarea>
      <ul class="compact-list" data-testid="storage-expansion-execution-history-list">
        <li v-for="execution in storageExpansionExecutions" :key="execution.id">
          <span class="list-main">
            <b>{{ execution.executionType }} / {{ execution.result }}</b>
            <span
              v-if="executionFailureReason(execution)"
              class="execution-failure-reason"
              data-testid="storage-expansion-execution-failure-reason"
            >
              <span :class="['status-pill', executionFailureReasonClass(execution)]">
                {{ executionFailureReasonLabel(execution) }}
              </span>
              <small>{{ executionFailureReasonHint(execution) }}</small>
            </span>
            <small>{{ execution.command || '-' }}</small>
            <small>{{ execution.externalUrl || execution.artifactSha256 || execution.notes || '-' }}</small>
            <small>{{ execution.createdBy || '-' }} / {{ formatDateTime(execution.createdAt) }}</small>
          </span>
          <span class="key-actions">
            <button
              data-testid="storage-expansion-execution-apply-button"
              type="button"
              class="ghost"
              :disabled="execution.result !== 'SUCCESS' || !['APPLY', 'GITOPS_PR'].includes(execution.executionType)"
              @click="$emit('apply-storage-expansion-from-execution', execution)"
            >
              Apply
            </button>
          </span>
        </li>
        <li v-if="storageExpansionExecutions.length === 0" class="empty">No execution history</li>
      </ul>
    </section>
  </article>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  storageExpansionForm: { type: Object, required: true },
  storageExpansionRequests: { type: Array, required: true },
  storageExpansionManifest: { type: Object, default: null },
  storageExpansionExecutionPlan: { type: Object, default: null },
  storageExpansionGitOpsPlan: { type: Object, default: null },
  storageExpansionExecutions: { type: Array, required: true },
  storageExpansionExecutionForm: { type: Object, required: true },
  storageExpansionApplyEvidence: { type: String, required: true },
  storageExpansionRunnerPreflight: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
})

defineEmits([
  'create-storage-expansion-request',
  'preview-storage-expansion-manifest',
  'download-storage-expansion-manifest',
  'download-storage-expansion-gitops-bundle',
  'create-storage-expansion-execution-plan',
  'record-storage-expansion-dry-run-execution',
  'run-storage-expansion-dry-run-execution',
  'run-storage-expansion-apply-execution',
  'run-storage-expansion-rollback-execution',
  'create-storage-expansion-gitops-plan',
  'run-storage-expansion-gitops-pr-execution',
  'record-storage-expansion-gitops-pr-execution',
  'load-storage-expansion-executions',
  'create-storage-expansion-execution-record',
  'apply-storage-expansion-from-execution',
  'update-storage-expansion-apply-evidence',
  'refresh-storage-expansion-runner-preflight',
  'update-storage-expansion-status',
])

function runnerPreflightStatusClass(status) {
  if (status === 'READY') return 'up'
  if (status === 'FAILED') return 'down'
  return 'mock'
}

const gitOpsFailureReasonLabels = {
  AUTHENTICATION: 'Auth failed',
  AUTHORIZATION: 'Permission denied',
  BRANCH_PROTECTION: 'Branch protection',
  DIRTY_WORKTREE: 'Dirty worktree',
  NO_CHANGES: 'No changes',
  REPOSITORY_CONFIG: 'Repository config',
  TIMEOUT: 'Timeout',
  TOOL_MISSING: 'Tool missing',
  UNKNOWN: 'Unknown failure',
}

const gitOpsFailureReasonHints = {
  AUTHENTICATION: 'Check git/gh login or token.',
  AUTHORIZATION: 'Check repository permission or token scopes.',
  BRANCH_PROTECTION: 'Branch rule blocked push.',
  DIRTY_WORKTREE: 'Clean the GitOps repository before rerun.',
  NO_CHANGES: 'Manifest diff is empty.',
  REPOSITORY_CONFIG: 'Check GitOps repository path.',
  TIMEOUT: 'Inspect remote git latency or increase timeout.',
  TOOL_MISSING: 'Install git/gh or fix runner PATH.',
  UNKNOWN: 'Inspect command output.',
}

function executionFailureReason(execution) {
  const directReason = normalizeFailureReason(execution?.failureReason)
  if (directReason) {
    return directReason
  }
  const notes = String(execution?.notes || '')
  const match = notes.match(/(?:^|[,\s])failureReason=([A-Z_]+)/)
  return normalizeFailureReason(match?.[1])
}

function normalizeFailureReason(reason) {
  const normalized = String(reason || '').trim().toUpperCase().replace(/\s+/g, '_')
  if (!normalized || normalized === '-' || normalized === 'NONE' || normalized === 'NULL') {
    return ''
  }
  return normalized
}

function executionFailureReasonLabel(execution) {
  const reason = executionFailureReason(execution)
  return gitOpsFailureReasonLabels[reason] || reason.replaceAll('_', ' ')
}

function executionFailureReasonHint(execution) {
  const reason = executionFailureReason(execution)
  return gitOpsFailureReasonHints[reason] || 'Inspect command output.'
}

function executionFailureReasonClass(execution) {
  const reason = executionFailureReason(execution)
  if (['NO_CHANGES', 'DIRTY_WORKTREE'].includes(reason)) {
    return 'mock'
  }
  return 'down'
}
</script>
