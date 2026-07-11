import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  getObjectLifecycleRules,
} from './api.js'

test('lifecycle rule wrapper serializes filters and composite cursor', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: null }),
    () => jsonResponse({ items: [], nextCursor: null }),
  ])

  try {
    await getObjectLifecycleRules()
    await getObjectLifecycleRules({
      status: 'DISABLED',
      targetType: 'TRASH_OBJECT',
      cursor: 'cursor-token',
      limit: 25,
    })

    assert.equal(
      fetchMock.calls[0].url,
      'http://localhost:8080/api/admin/object-lifecycle/rules?status=ALL&targetType=ALL&limit=50',
    )
    assert.equal(
      fetchMock.calls[1].url,
      'http://localhost:8080/api/admin/object-lifecycle/rules?status=DISABLED&targetType=TRASH_OBJECT&cursor=cursor-token&limit=25',
    )
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

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
