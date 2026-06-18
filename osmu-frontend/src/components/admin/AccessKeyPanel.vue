<template>
  <article class="panel" data-testid="access-key-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Access Keys</p>
        <h3>S3 접근 키</h3>
      </div>
    </div>
    <form class="access-key-form" data-testid="access-key-form" @submit.prevent="$emit('create-access-key')">
      <input data-testid="access-key-name-input" v-model="accessKeyForm.name" placeholder="local-dev-key" />
      <input data-testid="access-key-expires-at-input" v-model="accessKeyForm.expiresAt" type="datetime-local" aria-label="Access key expiration" />
      <div class="scope-builder">
        <select data-testid="access-key-bucket-select" v-model="accessKeyForm.scopeBucket">
          <option value="">Bucket</option>
          <option v-for="bucket in buckets" :key="bucket.name" :value="bucket.name">{{ bucket.name }}</option>
        </select>
        <div class="permission-row">
          <label class="check"><input data-testid="access-key-permission-read" v-model="accessKeyForm.scopePermissions" type="checkbox" value="READ" />READ</label>
          <label class="check"><input data-testid="access-key-permission-write" v-model="accessKeyForm.scopePermissions" type="checkbox" value="WRITE" />WRITE</label>
          <label class="check"><input data-testid="access-key-permission-delete" v-model="accessKeyForm.scopePermissions" type="checkbox" value="DELETE" />DELETE</label>
          <label class="check"><input data-testid="access-key-permission-admin" v-model="accessKeyForm.scopePermissions" type="checkbox" value="ADMIN" />ADMIN</label>
        </div>
        <button
          data-testid="access-key-scope-add-button"
          type="button"
          class="ghost"
          :disabled="!accessKeyForm.scopeBucket || accessKeyForm.scopePermissions.length === 0"
          @click="$emit('add-access-key-scope')"
        >
          추가
        </button>
      </div>
      <button data-testid="access-key-create-button" type="submit" :disabled="!isLoggedIn || accessKeyForm.scopes.length === 0">발급</button>
    </form>
    <p class="form-help" data-testid="access-key-scope-rule">
      Access Key 발급에는 최소 1개 bucket scope와 permission이 필요합니다.
    </p>
    <ul v-if="accessKeyForm.scopes.length > 0" class="scope-list" data-testid="access-key-scope-list">
      <li v-for="scope in accessKeyForm.scopes" :key="scope.bucketName">
        <span>{{ scope.bucketName }} / {{ scope.permissions.join(', ') }}</span>
        <button data-testid="access-key-scope-remove-button" type="button" class="danger" @click="$emit('remove-access-key-scope', scope.bucketName)">제거</button>
      </li>
    </ul>
    <p class="form-help warning" data-testid="access-key-secret-warning">
      Secret Key는 생성 또는 Rotate 직후 1회만 표시됩니다. 분실하면 기존 Secret을 조회할 수 없고 Rotate로 재발급해야 합니다.
    </p>
    <p v-if="newSecretKey" class="secret-box" data-testid="access-key-secret-box">
      Secret Key: {{ newSecretKey }}
    </p>
    <div class="compact-metrics access-key-usage-metrics" data-testid="access-key-usage-analysis">
      <span data-testid="access-key-usage-total">
        Total S3 uses
        <b>{{ formatUsageCount(accessKeyUsageAnalysis.totalUsageCount) }}</b>
      </span>
      <span data-testid="access-key-usage-used-keys">
        Used keys
        <b>{{ accessKeyUsageAnalysis.usedKeyCount }}/{{ accessKeySummary.totalCount }}</b>
      </span>
      <span data-testid="access-key-usage-latest">
        Latest use
        <b>{{ formatLastUsedAt(accessKeyUsageAnalysis.latestUsedAt) }}</b>
      </span>
      <span data-testid="access-key-usage-top-key">
        Top key
        <b>{{ accessKeyUsageAnalysis.mostUsedKeyName }} / {{ formatUsageCount(accessKeyUsageAnalysis.mostUsedKeyUsageCount) }}</b>
      </span>
    </div>
    <div class="access-key-filter-row" data-testid="access-key-filter-row" role="toolbar" aria-label="Access key filters">
      <button data-testid="access-key-filter-all" type="button" :class="filterButtonClass('ALL')" @click="setAccessKeyFilter('ALL')">All {{ filterCount('ALL') }}</button>
      <button data-testid="access-key-filter-active" type="button" :class="filterButtonClass('ACTIVE')" @click="setAccessKeyFilter('ACTIVE')">Active {{ filterCount('ACTIVE') }}</button>
      <button data-testid="access-key-filter-expired" type="button" :class="filterButtonClass('EXPIRED')" @click="setAccessKeyFilter('EXPIRED')">Expired {{ filterCount('EXPIRED') }}</button>
      <button data-testid="access-key-filter-expiring" type="button" :class="filterButtonClass('EXPIRING')" @click="setAccessKeyFilter('EXPIRING')">Expiring {{ filterCount('EXPIRING') }}</button>
      <button data-testid="access-key-filter-unused" type="button" :class="filterButtonClass('UNUSED')" @click="setAccessKeyFilter('UNUSED')">Unused {{ filterCount('UNUSED') }}</button>
      <button data-testid="access-key-filter-inactive" type="button" :class="filterButtonClass('INACTIVE')" @click="setAccessKeyFilter('INACTIVE')">Inactive {{ filterCount('INACTIVE') }}</button>
    </div>
    <div class="access-key-cleanup-row" data-testid="access-key-cleanup-row">
      <span data-testid="access-key-cleanup-summary">{{ selectedCleanupCandidateIds.length }} selected / {{ cleanupCandidateIds.length }} cleanup candidates</span>
      <span class="access-key-cleanup-actions">
        <button
          data-testid="access-key-cleanup-export-button"
          type="button"
          class="ghost"
          :disabled="cleanupCandidateIds.length === 0"
          @click="handleExportCleanupPreview"
        >
          Export preview
        </button>
        <button
          data-testid="access-key-cleanup-button"
          type="button"
          class="danger"
          :disabled="selectedCleanupCandidateIds.length === 0"
          @click="$emit('bulk-disable-access-keys', selectedCleanupCandidateIds)"
        >
          Bulk disable
        </button>
      </span>
    </div>
    <ul v-if="cleanupCandidates.length > 0" class="access-key-cleanup-preview" data-testid="access-key-cleanup-preview">
      <li v-for="candidate in cleanupCandidates" :key="candidate.id" data-testid="access-key-cleanup-candidate">
        <label class="check access-key-cleanup-choice">
          <input
            v-model="cleanupSelection[candidate.id]"
            data-testid="access-key-cleanup-candidate-checkbox"
            type="checkbox"
          />
          <span class="access-key-cleanup-candidate-copy">
            <b>{{ candidate.name }}</b>
            <small>#{{ candidate.id }} / {{ candidate.detail }}</small>
          </span>
        </label>
        <strong :class="['action-hint', candidate.tone]">{{ candidate.label }}</strong>
      </li>
    </ul>
    <ul class="compact-list" data-testid="access-key-list">
      <li v-for="key in filteredAccessKeys" :key="key.id">
        <span class="list-main">
          <b>{{ key.name }}</b>
          <small>{{ key.policyName }} / {{ formatKeyScope(key) }}</small>
          <small data-testid="access-key-expires-at">Expires: {{ formatExpiresAt(key.expiresAt) }}</small>
          <small data-testid="access-key-rotation-grace">Rotation grace: {{ formatRotationGrace(key.rotationGraceExpiresAt) }}</small>
          <small data-testid="access-key-last-used">Last used: {{ formatLastUsedAt(key.lastUsedAt) }}</small>
          <small data-testid="access-key-usage-count">S3 uses: {{ formatUsageCount(key.usageCount) }}</small>
          <small data-testid="access-key-action-hint" :class="['action-hint', accessKeyActionTone(key)]">
            {{ accessKeyActionLabel(key) }}
          </small>
        </span>
        <span class="key-actions">
          <strong>{{ key.status }}</strong>
          <button type="button" class="ghost" data-testid="access-key-rotate-button" :disabled="key.status !== 'ACTIVE'" @click="$emit('rotate-access-key', key.id)">Rotate</button>
          <button type="button" class="danger" data-testid="access-key-delete-button" :disabled="key.status !== 'ACTIVE'" @click="$emit('delete-access-key', key.id)">비활성화</button>
        </span>
      </li>
      <li v-if="filteredAccessKeys.length === 0" class="empty" data-testid="access-key-filter-empty">{{ accessKeyEmptyLabel }}</li>
    </ul>
  </article>
</template>

<script setup>
import { computed, reactive, ref, watch } from 'vue'
import {
  accessKeyCleanupCandidates,
  accessKeyOperationalAction,
  analyzeAccessKeyUsage,
  buildAccessKeyCleanupExport,
  filterAccessKeys,
  summarizeAccessKeys,
} from '../../utils/accessKeys.js'

const props = defineProps({
  accessKeyForm: { type: Object, required: true },
  buckets: { type: Array, required: true },
  isLoggedIn: { type: Boolean, required: true },
  newSecretKey: { type: String, required: true },
  accessKeys: { type: Array, required: true },
  formatKeyScope: { type: Function, required: true },
})

const accessKeyFilter = ref('ALL')
const cleanupSelection = reactive({})
const filteredAccessKeys = computed(() => filterAccessKeys(props.accessKeys, accessKeyFilter.value))
const accessKeySummary = computed(() => summarizeAccessKeys(props.accessKeys))
const accessKeyUsageAnalysis = computed(() => analyzeAccessKeyUsage(props.accessKeys))
const cleanupCandidates = computed(() => accessKeyCleanupCandidates(props.accessKeys))
const cleanupCandidateIds = computed(() => cleanupCandidates.value.map((candidate) => candidate.id))
const selectedCleanupCandidates = computed(() => cleanupCandidates.value.filter((candidate) => cleanupCandidateSelected(candidate.id)))
const selectedCleanupCandidateIds = computed(() => selectedCleanupCandidates.value.map((candidate) => candidate.id))
const accessKeyEmptyLabel = computed(() => (
  accessKeyFilter.value === 'ALL' ? 'Access Key 없음' : `${accessKeyFilter.value} Access Key 없음`
))

watch(cleanupCandidates, (candidates) => {
  const candidateIds = new Set(candidates.map((candidate) => String(candidate.id)))
  for (const id of Object.keys(cleanupSelection)) {
    if (!candidateIds.has(id)) {
      delete cleanupSelection[id]
    }
  }
  for (const candidate of candidates) {
    const id = String(candidate.id)
    if (cleanupSelection[id] === undefined) {
      cleanupSelection[id] = true
    }
  }
}, { immediate: true })

function setAccessKeyFilter(filter) {
  accessKeyFilter.value = filter
}

function filterButtonClass(filter) {
  return ['ghost', { active: accessKeyFilter.value === filter }]
}

function filterCount(filter) {
  if (filter === 'ALL') return accessKeySummary.value.totalCount
  if (filter === 'ACTIVE') return accessKeySummary.value.activeCount
  if (filter === 'EXPIRED') return accessKeySummary.value.expiredCount
  if (filter === 'EXPIRING') return accessKeySummary.value.expiringSoonCount
  if (filter === 'UNUSED') return accessKeySummary.value.unusedCount
  if (filter === 'INACTIVE') return accessKeySummary.value.inactiveCount
  return 0
}

function accessKeyActionLabel(key) {
  const action = accessKeyOperationalAction(key)
  return `${action.label}: ${action.detail}`
}

function accessKeyActionTone(key) {
  return accessKeyOperationalAction(key).tone
}

function cleanupCandidateSelected(id) {
  return cleanupSelection[String(id)] !== false
}

function handleExportCleanupPreview() {
  const payload = buildAccessKeyCleanupExport(props.accessKeys, Date.now(), {
    selectedIds: selectedCleanupCandidateIds.value,
  })
  downloadJsonFile(`osmu-access-key-cleanup-${payload.generatedAt.slice(0, 10)}.json`, payload)
}

defineEmits([
  'create-access-key',
  'add-access-key-scope',
  'remove-access-key-scope',
  'rotate-access-key',
  'delete-access-key',
  'bulk-disable-access-keys',
])

function formatLastUsedAt(value) {
  return value ? new Date(value).toLocaleString() : '사용 없음'
}

function formatExpiresAt(value) {
  return value ? new Date(value).toLocaleString() : '만료 없음'
}

function formatRotationGrace(value) {
  if (!value) return '없음'
  const expiresAt = new Date(value)
  return expiresAt.getTime() > Date.now()
    ? `Old secret allowed until ${expiresAt.toLocaleString()}`
    : `Expired ${expiresAt.toLocaleString()}`
}

function formatUsageCount(value) {
  return Math.max(0, Number(value || 0)).toLocaleString()
}

function downloadJsonFile(filename, payload) {
  const blob = new Blob([`${JSON.stringify(payload, null, 2)}\n`], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
</script>
