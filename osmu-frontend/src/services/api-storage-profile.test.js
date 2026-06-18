import assert from 'node:assert/strict'
import test from 'node:test'
import {
  applyStorageProfileRequest,
  clearAuthTokens,
  createStorageProfileRequest,
  getAdminStorageProfileRequests,
  getBucketStorageProfile,
  getStorageProfileRequests,
  getStorageProfiles,
  updateStorageProfileRequestStatus,
} from './api.js'

test('storage profile wrappers map bucket request and admin apply endpoints', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { bucketName: 'media', assignment: { profile: { code: 'STANDARD' } } } }),
    () => jsonResponse({ data: { id: 1, requestedProfile: { code: 'PERFORMANCE' } } }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 1, status: 'APPROVED' } }),
    () => jsonResponse({ data: { id: 1, status: 'APPLIED' } }),
  ])

  try {
    await getStorageProfiles()
    await getBucketStorageProfile('media bucket')
    await createStorageProfileRequest('media bucket', {
      requestedProfile: 'PERFORMANCE',
      reason: 'video ingest',
    })
    await getStorageProfileRequests()
    await getAdminStorageProfileRequests()
    await updateStorageProfileRequestStatus(1, 'APPROVED', 'ok')
    await applyStorageProfileRequest(1)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/storage-profiles')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/storage-profile')
    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/storage-profile-requests')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), {
      requestedProfile: 'PERFORMANCE',
      reason: 'video ingest',
    })
    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/storage-profile-requests')
    assert.equal(fetchMock.calls[4].url, 'http://localhost:8080/api/admin/storage-profile-requests')
    assert.equal(fetchMock.calls[5].url, 'http://localhost:8080/api/admin/storage-profile-requests/1/status')
    assert.equal(fetchMock.calls[5].options.method, 'PATCH')
    assert.deepEqual(JSON.parse(fetchMock.calls[5].options.body), { status: 'APPROVED', adminNote: 'ok' })
    assert.equal(fetchMock.calls[6].url, 'http://localhost:8080/api/admin/storage-profile-requests/1/apply')
    assert.equal(fetchMock.calls[6].options.method, 'POST')
  } finally {
    cleanupFetch(fetchMock)
  }
})

function mockFetch(handlers) {
  const previousFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options })
    const handler = handlers.shift()
    assert.ok(handler, `Unexpected fetch call: ${url}`)
    return handler(url, options)
  }
  return {
    calls,
    restore() {
      globalThis.fetch = previousFetch
    },
  }
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
