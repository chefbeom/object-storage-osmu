export const ACCESS_KEY_PERMISSION_ORDER = ['READ', 'WRITE', 'DELETE', 'ADMIN']
export const ACCESS_KEY_FILTERS = ['ALL', 'ACTIVE', 'EXPIRED', 'EXPIRING', 'UNUSED', 'INACTIVE']
export const ACCESS_KEY_CLEANUP_EXPORT_SCHEMA_VERSION = 'osmu.access-key-cleanup-preview.v1'

export function mergePermissions(current, next) {
  const values = new Set([...(current ?? []), ...(next ?? [])])
  return ACCESS_KEY_PERMISSION_ORDER.filter((permission) => values.has(permission))
}

export function upsertAccessKeyScope(scopes, bucketName, permissions) {
  if (!bucketName || !permissions?.length) {
    return [...scopes]
  }
  const nextPermissions = mergePermissions([], permissions)
  const existing = scopes.find((scope) => scope.bucketName === bucketName)
  if (!existing) {
    return [...scopes, { bucketName, permissions: nextPermissions }]
  }
  return scopes.map((scope) => (
    scope.bucketName === bucketName
      ? { ...scope, permissions: mergePermissions(scope.permissions, nextPermissions) }
      : scope
  ))
}

export function removeAccessKeyScope(scopes, bucketName) {
  return scopes.filter((scope) => scope.bucketName !== bucketName)
}

export function formatKeyScope(key) {
  if (key.bucketScopes?.length) {
    return key.bucketScopes
      .map((scope) => `${scope.bucketName}: ${scope.permissions?.join('+')}`)
      .join(', ')
  }
  return `${key.allowedBuckets?.join(', ')} / ${key.permissions?.join(', ')}`
}

export function summarizeAccessKeys(keys, now = Date.now(), options = {}) {
  const items = Array.isArray(keys) ? keys : []
  const expiringSoonMs = daysToMs(options.expiringSoonDays ?? 7)
  const staleMs = daysToMs(options.staleDays ?? 30)
  const activeKeys = items.filter((key) => key?.status === 'ACTIVE')
  const summary = {
    totalCount: items.length,
    activeCount: activeKeys.length,
    inactiveCount: items.filter((key) => key?.status && key.status !== 'ACTIVE').length,
    expiredCount: 0,
    expiringSoonCount: 0,
    neverUsedCount: 0,
    staleCount: 0,
    unusedCount: 0,
  }

  for (const key of activeKeys) {
    const expiresAt = timestampValue(key.expiresAt)
    if (expiresAt !== null) {
      if (expiresAt <= now) {
        summary.expiredCount += 1
      } else if (expiresAt <= now + expiringSoonMs) {
        summary.expiringSoonCount += 1
      }
    }

    const lastUsedAt = timestampValue(key.lastUsedAt)
    if (lastUsedAt === null) {
      summary.neverUsedCount += 1
    } else if (lastUsedAt <= now - staleMs) {
      summary.staleCount += 1
    }
  }

  summary.unusedCount = summary.neverUsedCount + summary.staleCount
  return summary
}

export function analyzeAccessKeyUsage(keys) {
  const items = Array.isArray(keys) ? keys : []
  let totalUsageCount = 0
  let mostUsedKey = null
  let latestUsedAt = null
  let usedKeyCount = 0
  let neverUsedCount = 0

  for (const key of items) {
    const usageCount = accessKeyUsageCount(key)
    const lastUsedAt = timestampValue(key?.lastUsedAt)
    totalUsageCount += usageCount
    if (usageCount > 0 || lastUsedAt !== null) {
      usedKeyCount += 1
    } else {
      neverUsedCount += 1
    }
    if (!mostUsedKey || usageCount > accessKeyUsageCount(mostUsedKey)) {
      mostUsedKey = key
    }
    if (lastUsedAt !== null && (latestUsedAt === null || lastUsedAt > latestUsedAt)) {
      latestUsedAt = lastUsedAt
    }
  }

  const topKey = totalUsageCount > 0 ? mostUsedKey : null
  return {
    totalUsageCount,
    usedKeyCount,
    neverUsedCount,
    latestUsedAt: latestUsedAt === null ? null : new Date(latestUsedAt).toISOString(),
    mostUsedKeyName: topKey?.name || (topKey?.id === undefined ? '-' : `#${topKey.id}`),
    mostUsedKeyUsageCount: topKey ? accessKeyUsageCount(topKey) : 0,
  }
}

export function filterAccessKeys(keys, filter = 'ALL', now = Date.now(), options = {}) {
  const selectedFilter = ACCESS_KEY_FILTERS.includes(filter) ? filter : 'ALL'
  const items = Array.isArray(keys) ? keys : []
  return items.filter((key) => accessKeyMatchesFilter(key, selectedFilter, now, options))
}

export function accessKeyMatchesFilter(key, filter = 'ALL', now = Date.now(), options = {}) {
  const selectedFilter = ACCESS_KEY_FILTERS.includes(filter) ? filter : 'ALL'
  if (selectedFilter === 'ALL') {
    return true
  }
  if (selectedFilter === 'ACTIVE') {
    return key?.status === 'ACTIVE'
  }
  if (selectedFilter === 'INACTIVE') {
    return key?.status && key.status !== 'ACTIVE'
  }
  if (key?.status !== 'ACTIVE') {
    return false
  }
  const expiringSoonMs = daysToMs(options.expiringSoonDays ?? 7)
  const staleMs = daysToMs(options.staleDays ?? 30)
  const expiresAt = timestampValue(key.expiresAt)
  const lastUsedAt = timestampValue(key.lastUsedAt)
  if (selectedFilter === 'EXPIRED') {
    return expiresAt !== null && expiresAt <= now
  }
  if (selectedFilter === 'EXPIRING') {
    return expiresAt !== null && expiresAt > now && expiresAt <= now + expiringSoonMs
  }
  if (selectedFilter === 'UNUSED') {
    return lastUsedAt === null || lastUsedAt <= now - staleMs
  }
  return true
}

export function accessKeyOperationalAction(key, now = Date.now(), options = {}) {
  const status = key?.status || 'UNKNOWN'
  if (status !== 'ACTIVE') {
    return {
      type: 'NONE',
      tone: 'muted',
      label: 'No action',
      detail: 'Inactive key is already blocked',
    }
  }

  const expiringSoonMs = daysToMs(options.expiringSoonDays ?? 7)
  const staleMs = daysToMs(options.staleDays ?? 30)
  const expiresAt = timestampValue(key.expiresAt)
  const lastUsedAt = timestampValue(key.lastUsedAt)

  if (expiresAt !== null && expiresAt <= now) {
    return {
      type: 'DISABLE_EXPIRED',
      tone: 'danger',
      label: 'Disable expired',
      detail: 'Expired active key cannot authenticate and should be cleaned up',
    }
  }
  if (expiresAt !== null && expiresAt <= now + expiringSoonMs) {
    return {
      type: 'ROTATE_EXPIRING',
      tone: 'warning',
      label: 'Rotate soon',
      detail: 'Key expires within the configured warning window',
    }
  }
  if (lastUsedAt === null) {
    return {
      type: 'REVIEW_NEVER_USED',
      tone: 'warning',
      label: 'Review unused',
      detail: 'Key has never been used; disable it if no client owns it',
    }
  }
  if (lastUsedAt <= now - staleMs) {
    return {
      type: 'REVIEW_STALE',
      tone: 'warning',
      label: 'Review stale',
      detail: 'Key has not been used recently; confirm owner or disable',
    }
  }
  return {
    type: 'NONE',
    tone: 'ok',
    label: 'No action',
    detail: 'Recent active usage detected',
  }
}

export function accessKeyCleanupCandidateIds(keys, now = Date.now(), options = {}) {
  return accessKeyCleanupCandidates(keys, now, options).map((candidate) => candidate.id)
}

export function accessKeyCleanupCandidates(keys, now = Date.now(), options = {}) {
  const cleanupTypes = new Set(options.cleanupTypes ?? ['DISABLE_EXPIRED', 'REVIEW_NEVER_USED', 'REVIEW_STALE'])
  const items = Array.isArray(keys) ? keys : []
  return items
    .map((key) => ({ key, action: accessKeyOperationalAction(key, now, options) }))
    .filter(({ key, action }) => key?.id !== undefined && key?.id !== null && cleanupTypes.has(action.type))
    .map(({ key, action }) => ({
      id: key.id,
      name: key.name || `#${key.id}`,
      actionType: action.type,
      tone: action.tone,
      label: action.label,
      detail: action.detail,
    }))
}

export function buildAccessKeyCleanupExport(keys, now = Date.now(), options = {}) {
  const candidates = accessKeyCleanupCandidates(keys, now, options)
  const selectedIds = new Set((options.selectedIds ?? candidates.map((candidate) => candidate.id)).map(String))
  const candidatesWithSelection = candidates.map((candidate) => ({
    ...candidate,
    selected: selectedIds.has(String(candidate.id)),
  }))
  const selectedCandidates = candidatesWithSelection.filter((candidate) => candidate.selected)
  const excludedCandidates = candidatesWithSelection.filter((candidate) => !candidate.selected)
  return {
    schemaVersion: ACCESS_KEY_CLEANUP_EXPORT_SCHEMA_VERSION,
    generatedAt: new Date(now).toISOString(),
    candidateCount: candidates.length,
    candidateIds: candidates.map((candidate) => candidate.id),
    selectedCount: selectedCandidates.length,
    selectedCandidateIds: selectedCandidates.map((candidate) => candidate.id),
    excludedCount: excludedCandidates.length,
    excludedCandidateIds: excludedCandidates.map((candidate) => candidate.id),
    candidates: candidatesWithSelection,
  }
}

function daysToMs(days) {
  return Math.max(0, Number(days) || 0) * 24 * 60 * 60 * 1000
}

function accessKeyUsageCount(key) {
  return Math.max(0, Number(key?.usageCount || 0))
}

function timestampValue(value) {
  if (!value) {
    return null
  }
  const timestamp = Date.parse(value)
  return Number.isFinite(timestamp) ? timestamp : null
}
