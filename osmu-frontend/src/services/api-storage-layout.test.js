import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  createStorageLayoutPlan,
  getStorageLayoutCapabilities,
  getStorageLayoutPlans,
  simulateStorageLayoutPlan,
  updateStorageLayoutPlanStatus,
} from './api.js'

test('storage layout wrappers map capabilities, plan, status, and simulation endpoints', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: [] }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 8, status: 'PLANNED' } }),
    () => jsonResponse({ data: { id: 8, status: 'APPROVED' } }),
    () => jsonResponse({ data: { mode: 'DEVELOPMENT_SIMULATION' } }),
  ])

  try {
    await getStorageLayoutCapabilities()
    await getStorageLayoutPlans({ status: 'APPROVED', cursor: '8', limit: 25 })
    await createStorageLayoutPlan({ layoutCode: 'RAID6', storageClassName: 'osmu-storage' })
    await updateStorageLayoutPlanStatus(8, 'APPROVED', 'target review pending')
    await simulateStorageLayoutPlan(8)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/storage-layouts/capabilities')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/storage-layouts/plans?status=APPROVED&cursor=8&limit=25')
    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/admin/storage-layouts/plans')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), { layoutCode: 'RAID6', storageClassName: 'osmu-storage' })
    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/admin/storage-layouts/plans/8/status')
    assert.equal(fetchMock.calls[3].options.method, 'PATCH')
    assert.deepEqual(JSON.parse(fetchMock.calls[3].options.body), { status: 'APPROVED', adminNote: 'target review pending' })
    assert.equal(fetchMock.calls[4].url, 'http://localhost:8080/api/admin/storage-layouts/plans/8/simulate')
    assert.equal(fetchMock.calls[4].options.method, 'POST')
  } finally {
    clearAuthTokens()
    fetchMock.restore()
  }
})

function mockFetch(handlers) {
  const previousFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options })
    const handler = handlers.shift()
    assert.ok(handler, 'Unexpected fetch call: ' + url)
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