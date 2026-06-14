import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  deleteQuotaPolicy,
  getQuotaPolicies,
  getQuotaPolicyHistory,
  saveQuotaPolicy,
} from './api.js'

test('quota policy wrappers use admin quota policy endpoints', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { targetType: 'USER', targetId: 7, quotaBytes: 1024 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await getQuotaPolicies()
    await getQuotaPolicyHistory(25)
    await saveQuotaPolicy('USER', 7, 1024, 'pilot quota')
    await deleteQuotaPolicy('USER', 7, 'pilot cleanup')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/quota-policies')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/quota-policies/history?limit=25')

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/admin/quota-policies/USER/7')
    assert.equal(fetchMock.calls[2].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), { quotaBytes: 1024, reason: 'pilot quota' })

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/admin/quota-policies/USER/7?reason=pilot%20cleanup')
    assert.equal(fetchMock.calls[3].options.method, 'DELETE')
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
