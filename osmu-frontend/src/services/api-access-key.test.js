import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  createAccessKey,
  deleteAccessKey,
  getAccessKeys,
} from './api.js'

test('access key wrappers preserve multi bucket scopes and revoke by id', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 1, accessKey: 'AKIAOSMU', secretKey: 'secret-once' } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await getAccessKeys()
    await createAccessKey({
      name: 'local-dev-key',
      bucketScopes: [
        { bucketName: 'media', permissions: ['READ', 'WRITE'] },
        { bucketName: 'archive', permissions: ['READ'] },
      ],
      expiresAt: null,
    })
    await deleteAccessKey(42)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/access-keys')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/access-keys')
    assert.equal(fetchMock.calls[1].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      name: 'local-dev-key',
      bucketScopes: [
        { bucketName: 'media', permissions: ['READ', 'WRITE'] },
        { bucketName: 'archive', permissions: ['READ'] },
      ],
      expiresAt: null,
    })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/access-keys/42')
    assert.equal(fetchMock.calls[2].options.method, 'DELETE')
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
