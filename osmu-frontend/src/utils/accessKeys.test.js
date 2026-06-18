import assert from 'node:assert/strict'
import test from 'node:test'
import {
  accessKeyCleanupCandidates,
  accessKeyCleanupCandidateIds,
  accessKeyMatchesFilter,
  accessKeyOperationalAction,
  analyzeAccessKeyUsage,
  buildAccessKeyCleanupExport,
  filterAccessKeys,
  formatKeyScope,
  mergePermissions,
  removeAccessKeyScope,
  summarizeAccessKeys,
  upsertAccessKeyScope,
} from './accessKeys.js'

test('mergePermissions keeps canonical permission order and removes duplicates', () => {
  assert.deepEqual(mergePermissions(['WRITE', 'READ'], ['ADMIN', 'READ']), ['READ', 'WRITE', 'ADMIN'])
})

test('upsertAccessKeyScope appends and merges multi bucket scopes', () => {
  const first = upsertAccessKeyScope([], 'bucket-a', ['WRITE', 'READ'])
  const second = upsertAccessKeyScope(first, 'bucket-b', ['READ'])
  const third = upsertAccessKeyScope(second, 'bucket-a', ['DELETE', 'READ'])

  assert.deepEqual(third, [
    { bucketName: 'bucket-a', permissions: ['READ', 'WRITE', 'DELETE'] },
    { bucketName: 'bucket-b', permissions: ['READ'] },
  ])
})

test('removeAccessKeyScope removes selected bucket scope', () => {
  assert.deepEqual(removeAccessKeyScope([
    { bucketName: 'bucket-a', permissions: ['READ'] },
    { bucketName: 'bucket-b', permissions: ['WRITE'] },
  ], 'bucket-a'), [
    { bucketName: 'bucket-b', permissions: ['WRITE'] },
  ])
})

test('formatKeyScope displays bucket scopes and legacy key scopes', () => {
  assert.equal(formatKeyScope({
    bucketScopes: [
      { bucketName: 'bucket-a', permissions: ['READ', 'WRITE'] },
      { bucketName: 'bucket-b', permissions: ['READ'] },
    ],
  }), 'bucket-a: READ+WRITE, bucket-b: READ')
  assert.equal(formatKeyScope({
    allowedBuckets: ['bucket-a', 'bucket-b'],
    permissions: ['READ', 'WRITE'],
  }), 'bucket-a, bucket-b / READ, WRITE')
})

test('summarizeAccessKeys counts active, expiring, expired, and unused keys', () => {
  const now = Date.parse('2026-06-15T00:00:00.000Z')
  const summary = summarizeAccessKeys([
    { status: 'ACTIVE', expiresAt: '2026-06-14T23:59:59.000Z', lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { status: 'ACTIVE', expiresAt: '2026-06-20T00:00:00.000Z', lastUsedAt: null },
    { status: 'ACTIVE', expiresAt: '2026-07-20T00:00:00.000Z', lastUsedAt: '2026-05-01T00:00:00.000Z' },
    { status: 'ACTIVE', expiresAt: null, lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { status: 'INACTIVE', expiresAt: '2026-06-16T00:00:00.000Z', lastUsedAt: null },
  ], now)

  assert.deepEqual(summary, {
    totalCount: 5,
    activeCount: 4,
    inactiveCount: 1,
    expiredCount: 1,
    expiringSoonCount: 1,
    neverUsedCount: 1,
    staleCount: 1,
    unusedCount: 2,
  })
})

test('analyzeAccessKeyUsage summarizes usage count and last used recency', () => {
  const analysis = analyzeAccessKeyUsage([
    { id: 1, name: 'media-app', usageCount: 8, lastUsedAt: '2026-06-14T12:00:00.000Z' },
    { id: 2, name: 'backup-job', usageCount: 12, lastUsedAt: '2026-06-15T03:00:00.000Z' },
    { id: 3, name: 'unused-key', usageCount: 0, lastUsedAt: null },
    { id: 4, name: 'legacy-key', lastUsedAt: '2026-06-01T00:00:00.000Z' },
  ])

  assert.deepEqual(analysis, {
    totalUsageCount: 20,
    usedKeyCount: 3,
    neverUsedCount: 1,
    latestUsedAt: '2026-06-15T03:00:00.000Z',
    mostUsedKeyName: 'backup-job',
    mostUsedKeyUsageCount: 12,
  })
})

test('filterAccessKeys applies operational filters using expiry and last used state', () => {
  const now = Date.parse('2026-06-15T00:00:00.000Z')
  const keys = [
    { id: 1, status: 'ACTIVE', expiresAt: '2026-06-14T23:59:59.000Z', lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { id: 2, status: 'ACTIVE', expiresAt: '2026-06-20T00:00:00.000Z', lastUsedAt: null },
    { id: 3, status: 'ACTIVE', expiresAt: '2026-07-20T00:00:00.000Z', lastUsedAt: '2026-05-01T00:00:00.000Z' },
    { id: 4, status: 'ACTIVE', expiresAt: null, lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { id: 5, status: 'INACTIVE', expiresAt: '2026-06-16T00:00:00.000Z', lastUsedAt: null },
  ]

  assert.deepEqual(filterAccessKeys(keys, 'EXPIRED', now).map((key) => key.id), [1])
  assert.deepEqual(filterAccessKeys(keys, 'EXPIRING', now).map((key) => key.id), [2])
  assert.deepEqual(filterAccessKeys(keys, 'UNUSED', now).map((key) => key.id), [2, 3])
  assert.deepEqual(filterAccessKeys(keys, 'INACTIVE', now).map((key) => key.id), [5])
  assert.equal(accessKeyMatchesFilter(keys[3], 'unknown', now), true)
})

test('accessKeyOperationalAction recommends cleanup and rotation actions', () => {
  const now = Date.parse('2026-06-15T00:00:00.000Z')

  assert.equal(accessKeyOperationalAction({
    status: 'ACTIVE',
    expiresAt: '2026-06-14T23:59:59.000Z',
    lastUsedAt: '2026-06-14T00:00:00.000Z',
  }, now).type, 'DISABLE_EXPIRED')
  assert.equal(accessKeyOperationalAction({
    status: 'ACTIVE',
    expiresAt: '2026-06-20T00:00:00.000Z',
    lastUsedAt: '2026-06-14T00:00:00.000Z',
  }, now).type, 'ROTATE_EXPIRING')
  assert.equal(accessKeyOperationalAction({
    status: 'ACTIVE',
    expiresAt: null,
    lastUsedAt: null,
  }, now).type, 'REVIEW_NEVER_USED')
  assert.equal(accessKeyOperationalAction({
    status: 'ACTIVE',
    expiresAt: null,
    lastUsedAt: '2026-05-01T00:00:00.000Z',
  }, now).type, 'REVIEW_STALE')
  assert.equal(accessKeyOperationalAction({
    status: 'INACTIVE',
    expiresAt: null,
    lastUsedAt: null,
  }, now).tone, 'muted')
})

test('accessKeyCleanupCandidateIds returns expired and unused active key ids', () => {
  const now = Date.parse('2026-06-15T00:00:00.000Z')
  const keys = [
    { id: 1, name: 'expired-key', status: 'ACTIVE', expiresAt: '2026-06-14T23:59:59.000Z', lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { id: 2, status: 'ACTIVE', expiresAt: '2026-06-20T00:00:00.000Z', lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { id: 3, name: 'never-used-key', status: 'ACTIVE', expiresAt: null, lastUsedAt: null },
    { id: 4, name: 'stale-key', status: 'ACTIVE', expiresAt: null, lastUsedAt: '2026-05-01T00:00:00.000Z' },
    { id: 5, status: 'ACTIVE', expiresAt: null, lastUsedAt: '2026-06-14T00:00:00.000Z' },
    { id: 6, status: 'INACTIVE', expiresAt: '2026-06-14T00:00:00.000Z', lastUsedAt: null },
  ]

  assert.deepEqual(accessKeyCleanupCandidateIds(keys, now), [1, 3, 4])
  assert.deepEqual(accessKeyCleanupCandidateIds(keys, now, { cleanupTypes: ['DISABLE_EXPIRED'] }), [1])
  assert.deepEqual(accessKeyCleanupCandidates(keys, now).map((candidate) => ({
    id: candidate.id,
    name: candidate.name,
    actionType: candidate.actionType,
    tone: candidate.tone,
  })), [
    { id: 1, name: 'expired-key', actionType: 'DISABLE_EXPIRED', tone: 'danger' },
    { id: 3, name: 'never-used-key', actionType: 'REVIEW_NEVER_USED', tone: 'warning' },
    { id: 4, name: 'stale-key', actionType: 'REVIEW_STALE', tone: 'warning' },
  ])
  assert.match(accessKeyCleanupCandidates(keys, now)[0].detail, /expired/i)
  assert.deepEqual(buildAccessKeyCleanupExport(keys, now), {
    schemaVersion: 'osmu.access-key-cleanup-preview.v1',
    generatedAt: '2026-06-15T00:00:00.000Z',
    candidateCount: 3,
    candidateIds: [1, 3, 4],
    selectedCount: 3,
    selectedCandidateIds: [1, 3, 4],
    excludedCount: 0,
    excludedCandidateIds: [],
    candidates: [
      {
        id: 1,
        name: 'expired-key',
        actionType: 'DISABLE_EXPIRED',
        tone: 'danger',
        label: 'Disable expired',
        detail: 'Expired active key cannot authenticate and should be cleaned up',
        selected: true,
      },
      {
        id: 3,
        name: 'never-used-key',
        actionType: 'REVIEW_NEVER_USED',
        tone: 'warning',
        label: 'Review unused',
        detail: 'Key has never been used; disable it if no client owns it',
        selected: true,
      },
      {
        id: 4,
        name: 'stale-key',
        actionType: 'REVIEW_STALE',
        tone: 'warning',
        label: 'Review stale',
        detail: 'Key has not been used recently; confirm owner or disable',
        selected: true,
      },
    ],
  })
  assert.deepEqual(buildAccessKeyCleanupExport(keys, now, { selectedIds: [1, 4] }), {
    schemaVersion: 'osmu.access-key-cleanup-preview.v1',
    generatedAt: '2026-06-15T00:00:00.000Z',
    candidateCount: 3,
    candidateIds: [1, 3, 4],
    selectedCount: 2,
    selectedCandidateIds: [1, 4],
    excludedCount: 1,
    excludedCandidateIds: [3],
    candidates: [
      {
        id: 1,
        name: 'expired-key',
        actionType: 'DISABLE_EXPIRED',
        tone: 'danger',
        label: 'Disable expired',
        detail: 'Expired active key cannot authenticate and should be cleaned up',
        selected: true,
      },
      {
        id: 3,
        name: 'never-used-key',
        actionType: 'REVIEW_NEVER_USED',
        tone: 'warning',
        label: 'Review unused',
        detail: 'Key has never been used; disable it if no client owns it',
        selected: false,
      },
      {
        id: 4,
        name: 'stale-key',
        actionType: 'REVIEW_STALE',
        tone: 'warning',
        label: 'Review stale',
        detail: 'Key has not been used recently; confirm owner or disable',
        selected: true,
      },
    ],
  })
})
