import assert from 'node:assert/strict'
import test from 'node:test'
import {
  bulkDisableAccessKeys,
  clearAuthTokens,
  createAccessKey,
  deleteAccessKey,
  getAccessKeys,
  rotateAccessKey,
} from './api.js'

test('access key wrappers preserve multi bucket scopes, rotate secrets, and revoke by id', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 1, accessKey: 'AKIAOSMU', secretKey: 'secret-once' } }),
    () => jsonResponse({ data: { id: 1, accessKey: 'AKIAOSMU', secretKey: 'rotated-secret-once' } }),
    () => new Response(null, { status: 204 }),
    () => jsonResponse({ data: { requestedCount: 2, disabledCount: 2, skippedCount: 0, disabledKeyIds: [42, 43], skippedKeyIds: [] } }),
  ])

  try {
    await getAccessKeys()
    await createAccessKey({
      name: 'local-dev-key',
      bucketScopes: [
        { bucketName: 'media', permissions: ['READ', 'WRITE'] },
        { bucketName: 'archive', permissions: ['READ'] },
      ],
      expiresAt: '2026-06-30T12:00:00.000Z',
    })
    await rotateAccessKey(42)
    await deleteAccessKey(42)
    await bulkDisableAccessKeys([42, 43])

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/access-keys')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/access-keys')
    assert.equal(fetchMock.calls[1].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      name: 'local-dev-key',
      bucketScopes: [
        { bucketName: 'media', permissions: ['READ', 'WRITE'] },
        { bucketName: 'archive', permissions: ['READ'] },
      ],
      expiresAt: '2026-06-30T12:00:00.000Z',
    })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/access-keys/42/rotate')
    assert.equal(fetchMock.calls[2].options.method, 'POST')

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/access-keys/42')
    assert.equal(fetchMock.calls[3].options.method, 'DELETE')

    assert.equal(fetchMock.calls[4].url, 'http://localhost:8080/api/access-keys/bulk-disable')
    assert.equal(fetchMock.calls[4].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[4].options.body), { keyIds: [42, 43] })
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
