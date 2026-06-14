import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  getStoredMultipartUploadSessions,
  uploadObjectMultipart,
} from './api.js'

test('uploadObjectMultipart creates, uploads parts, completes, and clears local resume session', async () => {
  const storage = installSessionStorage()
  const xhrMock = installMockXhr(['"etag-1"', '"etag-2"'])
  const fetchMock = mockFetch([
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload')
      assert.equal(options.method, 'POST')
      assert.deepEqual(JSON.parse(options.body), {
        key: 'large/input.bin',
        tags: 'project=osmu',
        contentType: 'application/octet-stream',
        sizeBytes: 10,
        partSizeBytes: 5,
        expiresInSeconds: 900,
      })
      return jsonResponse({
        data: {
          uploadId: 'upload-1',
          key: 'large/input.bin',
          partSizeBytes: 5,
          partCount: 2,
          expiresAt: new Date(Date.now() + 900_000).toISOString(),
          parts: [
            { partNumber: 1, url: 'https://storage.local/part-1', startByte: 0, endByte: 4 },
            { partNumber: 2, url: 'https://storage.local/part-2', startByte: 5, endByte: 9 },
          ],
        },
      })
    },
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/complete')
      assert.equal(options.method, 'POST')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-1',
        key: 'large/input.bin',
        parts: [
          { partNumber: 1, etag: '"etag-1"' },
          { partNumber: 2, etag: '"etag-2"' },
        ],
      })
      return jsonResponse({ data: { key: 'large/input.bin', sizeBytes: 10 } })
    },
  ])
  const progressEvents = []

  try {
    const result = await uploadObjectMultipart(
      'media',
      'large/input.bin',
      testFile({ name: 'input.bin', size: 10, type: 'application/octet-stream', lastModified: 123 }),
      'project=osmu',
      (progress) => progressEvents.push(progress),
      { partSizeBytes: 5, concurrency: 1, partRetries: 0 },
    )

    assert.equal(result.data.key, 'large/input.bin')
    assert.deepEqual(xhrMock.calls.map((call) => call.url), [
      'https://storage.local/part-1',
      'https://storage.local/part-2',
    ])
    assert.deepEqual(xhrMock.calls.map((call) => call.body.size), [5, 5])
    assert.equal(progressEvents.at(-1).percent, 100)
    assert.deepEqual(getStoredMultipartUploadSessions({ bucketName: 'media' }), [])
    assert.equal(storage.length, 0)
  } finally {
    cleanupRuntime(fetchMock, xhrMock)
  }
})

test('uploadObjectMultipart retries transient part upload failure', async () => {
  installSessionStorage()
  const xhrMock = installMockXhr([
    { status: 500 },
    { status: 200, etag: '"etag-after-retry"' },
  ])
  const fetchMock = mockFetch([
    (url) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload')
      return jsonResponse({
        data: {
          uploadId: 'upload-retry',
          key: 'large/retry.bin',
          partSizeBytes: 5,
          partCount: 1,
          expiresAt: new Date(Date.now() + 900_000).toISOString(),
          parts: [
            { partNumber: 1, url: 'https://storage.local/retry-part-1', startByte: 0, endByte: 4 },
          ],
        },
      })
    },
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/complete')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-retry',
        key: 'large/retry.bin',
        parts: [
          { partNumber: 1, etag: '"etag-after-retry"' },
        ],
      })
      return jsonResponse({ data: { key: 'large/retry.bin', sizeBytes: 5 } })
    },
  ])

  try {
    await uploadObjectMultipart(
      'media',
      'large/retry.bin',
      testFile({ name: 'retry.bin', size: 5, type: 'application/octet-stream', lastModified: 456 }),
      '',
      null,
      { partSizeBytes: 5, concurrency: 1, partRetries: 1, retryBaseDelayMs: 100, retryJitterRatio: 0 },
    )

    assert.deepEqual(xhrMock.calls.map((call) => call.url), [
      'https://storage.local/retry-part-1',
      'https://storage.local/retry-part-1',
    ])
  } finally {
    cleanupRuntime(fetchMock, xhrMock)
  }
})

test('uploadObjectMultipart aborts remote session and clears local session when cancelled', async () => {
  const storage = installSessionStorage()
  const xhrMock = installMockXhr([])
  const controller = new AbortController()
  controller.abort()
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        uploadId: 'upload-abort',
        key: 'large/cancel.bin',
        partSizeBytes: 5,
        partCount: 1,
        expiresAt: new Date(Date.now() + 900_000).toISOString(),
        parts: [
          { partNumber: 1, url: 'https://storage.local/cancel-part-1', startByte: 0, endByte: 4 },
        ],
      },
    }),
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/abort')
      assert.equal(options.method, 'POST')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-abort',
        key: 'large/cancel.bin',
      })
      return jsonResponse({ data: { success: true } })
    },
  ])

  try {
    await assert.rejects(
      () => uploadObjectMultipart(
        'media',
        'large/cancel.bin',
        testFile({ name: 'cancel.bin', size: 5, type: 'application/octet-stream', lastModified: 789 }),
        '',
        null,
        { partSizeBytes: 5, signal: controller.signal },
      ),
      /Upload aborted/,
    )

    assert.equal(xhrMock.calls.length, 0)
    assert.equal(storage.length, 0)
  } finally {
    cleanupRuntime(fetchMock, xhrMock)
  }
})

test('uploadObjectMultipart resumes saved session and skips completed parts', async () => {
  const storage = installSessionStorage()
  const file = testFile({ name: 'resume.bin', size: 10, type: 'application/octet-stream', lastModified: 321 })
  const xhrMock = installMockXhr([
    { status: 200, etag: '"etag-local-1"' },
    { status: 400 },
  ])
  const fetchMock = mockFetch([
    (url) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload')
      return jsonResponse({
        data: {
          uploadId: 'upload-resume',
          key: 'large/resume.bin',
          partSizeBytes: 5,
          partCount: 2,
          expiresAt: new Date(Date.now() + 900_000).toISOString(),
          parts: [
            { partNumber: 1, url: 'https://storage.local/resume-part-1', startByte: 0, endByte: 4 },
            { partNumber: 2, url: 'https://storage.local/resume-part-2', startByte: 5, endByte: 9 },
          ],
        },
      })
    },
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/refresh')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-resume',
        key: 'large/resume.bin',
        expiresInSeconds: 900,
      })
      return jsonResponse({
        data: {
          uploadId: 'upload-resume',
          key: 'large/resume.bin',
          partSizeBytes: 5,
          partCount: 2,
          expiresAt: new Date(Date.now() + 900_000).toISOString(),
          parts: [
            { partNumber: 1, url: 'https://storage.local/resume-refresh-1', startByte: 0, endByte: 4 },
            { partNumber: 2, url: 'https://storage.local/resume-refresh-2', startByte: 5, endByte: 9 },
          ],
        },
      })
    },
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/parts')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-resume',
        key: 'large/resume.bin',
      })
      return jsonResponse({
        data: {
          parts: [
            { partNumber: 2, etag: '"etag-server-2"' },
          ],
        },
      })
    },
    (url, options) => {
      assert.equal(url, 'http://localhost:8080/api/buckets/media/objects/multipart-upload/complete')
      assert.deepEqual(JSON.parse(options.body), {
        uploadId: 'upload-resume',
        key: 'large/resume.bin',
        parts: [
          { partNumber: 1, etag: '"etag-local-1"' },
          { partNumber: 2, etag: '"etag-server-2"' },
        ],
      })
      return jsonResponse({ data: { key: 'large/resume.bin', sizeBytes: 10 } })
    },
  ])
  const resumeEvents = []

  try {
    await assert.rejects(
      () => uploadObjectMultipart(
        'media',
        'large/resume.bin',
        file,
        'project=osmu',
        null,
        { partSizeBytes: 5, concurrency: 1, partRetries: 0 },
      ),
      /HTTP 400/,
    )

    const savedSessions = getStoredMultipartUploadSessions({ bucketName: 'media' })
    assert.equal(savedSessions.length, 1)
    assert.deepEqual(savedSessions[0].completedParts, [
      { partNumber: 1, etag: '"etag-local-1"' },
    ])

    const result = await uploadObjectMultipart(
      'media',
      'large/resume.bin',
      file,
      'project=osmu',
      null,
      {
        partSizeBytes: 5,
        concurrency: 1,
        partRetries: 0,
        onResume: (event) => resumeEvents.push(event),
      },
    )

    assert.equal(result.data.key, 'large/resume.bin')
    assert.deepEqual(xhrMock.calls.map((call) => call.url), [
      'https://storage.local/resume-part-1',
      'https://storage.local/resume-part-2',
    ])
    assert.equal(resumeEvents.length, 1)
    assert.deepEqual(resumeEvents[0].completedParts, [
      { partNumber: 1, etag: '"etag-local-1"' },
      { partNumber: 2, etag: '"etag-server-2"' },
    ])
    assert.deepEqual(getStoredMultipartUploadSessions({ bucketName: 'media' }), [])
    assert.equal(storage.length, 0)
  } finally {
    cleanupRuntime(fetchMock, xhrMock)
  }
})

function testFile({ name, size, type, lastModified }) {
  return {
    name,
    size,
    type,
    lastModified,
    slice(start, end) {
      return new Blob([new Uint8Array(end - start)], { type })
    },
  }
}

function installSessionStorage() {
  const storage = createMemoryStorage()
  globalThis.window = {
    sessionStorage: storage,
    setTimeout,
    clearTimeout,
  }
  return storage
}

function createMemoryStorage() {
  const items = new Map()
  return {
    get length() {
      return items.size
    },
    key(index) {
      return Array.from(items.keys())[index] ?? null
    },
    getItem(key) {
      return items.has(key) ? items.get(key) : null
    },
    setItem(key, value) {
      items.set(key, String(value))
    },
    removeItem(key) {
      items.delete(key)
    },
    clear() {
      items.clear()
    },
  }
}

function installMockXhr(steps) {
  const previousXhr = globalThis.XMLHttpRequest
  const calls = []
  const pendingSteps = steps.map((step) => (
    typeof step === 'string' ? { status: 200, etag: step } : step
  ))
  class MockXhr {
    upload = {}
    #step = pendingSteps.shift() ?? { status: 200 }

    constructor() {
      this.status = this.#step.status ?? 200
      this.responseText = this.#step.responseText ?? ''
    }

    open(method, url) {
      this.method = method
      this.url = url
    }

    setRequestHeader() {}

    getResponseHeader(name) {
      return name.toLowerCase() === 'etag' ? (this.#step.etag ?? null) : null
    }

    send(body) {
      calls.push({ method: this.method, url: this.url, body })
      queueMicrotask(() => {
        if (this.#step.networkError) {
          this.onerror?.()
          return
        }
        if (this.#step.progress !== false) {
          this.upload.onprogress?.({ lengthComputable: true, loaded: body.size, total: body.size })
        }
        this.onload?.()
      })
    }

    abort() {
      this.onabort?.()
    }
  }
  globalThis.XMLHttpRequest = MockXhr
  return {
    calls,
    restore() {
      globalThis.XMLHttpRequest = previousXhr
    },
  }
}

function mockFetch(handlers) {
  const previousFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options })
    const handler = handlers.shift()
    assert.ok(handler, `Unexpected fetch call: ${url}`)
    return handler(String(url), options)
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

function cleanupRuntime(fetchMock, xhrMock) {
  clearAuthTokens()
  fetchMock.restore()
  xhrMock.restore()
  delete globalThis.window
}
