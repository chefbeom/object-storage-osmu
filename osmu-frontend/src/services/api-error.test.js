import assert from 'node:assert/strict'
import test from 'node:test'
import {
  ApiClientError,
  clearAuthTokens,
  getBuckets,
  getBucketTagsS3Xml,
} from './api.js'

test('API JSON errors keep status, code, message, and request id', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      error: {
        code: 'AUTHORIZATION_FAILED',
        message: 'Denied',
        requestId: 'req-json-1',
      },
    }, 403),
  ])

  try {
    await assert.rejects(() => getBuckets(), (error) => {
      assert.ok(error instanceof ApiClientError)
      assert.equal(error.status, 403)
      assert.equal(error.code, 'AUTHORIZATION_FAILED')
      assert.equal(error.message, 'Denied')
      assert.equal(error.requestId, 'req-json-1')
      return true
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('API errors use X-Request-Id header when JSON body omits request id', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Boom',
      },
    }, 500, { 'X-Request-Id': 'req-header-1' }),
  ])

  try {
    await assert.rejects(() => getBuckets(), (error) => {
      assert.ok(error instanceof ApiClientError)
      assert.equal(error.status, 500)
      assert.equal(error.code, 'INTERNAL_ERROR')
      assert.equal(error.message, 'Boom')
      assert.equal(error.requestId, 'req-header-1')
      return true
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('S3 XML errors map to ApiClientError fields', async () => {
  const fetchMock = mockFetch([
    () => new Response(
      '<Error><Code>AccessDenied</Code><Message>No &lt;access&gt;</Message><RequestId>req-s3-1</RequestId></Error>',
      {
        status: 403,
        headers: { 'Content-Type': 'application/xml' },
      },
    ),
  ])

  try {
    await assert.rejects(() => getBucketTagsS3Xml('media bucket'), (error) => {
      assert.ok(error instanceof ApiClientError)
      assert.equal(error.status, 403)
      assert.equal(error.code, 'AccessDenied')
      assert.equal(error.message, 'No <access>')
      assert.equal(error.requestId, 'req-s3-1')
      return true
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/s3/media%20bucket?tagging')
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

function jsonResponse(payload, status = 200, headers = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
