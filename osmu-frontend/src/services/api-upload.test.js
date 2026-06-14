import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  uploadObject,
} from './api.js'

test('uploadObject aborts in-flight XHR and can retry the same file afterward', async () => {
  const xhrMock = installMockXhr([
    { defer: true },
    {
      status: 200,
      text: JSON.stringify({ data: { key: 'docs/retry.txt', sizeBytes: 5 } }),
      progress: { loaded: 5, total: 5 },
    },
  ])
  const abortController = new AbortController()
  const progressEvents = []

  try {
    const firstAttempt = uploadObject(
      'media',
      'docs/retry.txt',
      new Blob(['hello'], { type: 'text/plain' }),
      'project=osmu',
      (progress) => progressEvents.push(progress),
      { signal: abortController.signal },
    )
    abortController.abort()

    await assert.rejects(firstAttempt, /Upload aborted/)
    assert.equal(xhrMock.calls[0].aborted, true)
    assert.equal(xhrMock.calls[0].method, 'POST')
    assert.equal(xhrMock.calls[0].url, 'http://localhost:8080/api/buckets/media/objects')
    assert.equal(xhrMock.calls[0].body.get('key'), 'docs/retry.txt')
    assert.equal(xhrMock.calls[0].body.get('tags'), 'project=osmu')

    const retryResult = await uploadObject(
      'media',
      'docs/retry.txt',
      new Blob(['hello'], { type: 'text/plain' }),
      'project=osmu',
      (progress) => progressEvents.push(progress),
    )

    assert.equal(retryResult.data.key, 'docs/retry.txt')
    assert.equal(progressEvents.at(-1).percent, 100)
    assert.equal(xhrMock.calls.length, 2)
    assert.equal(xhrMock.calls[1].aborted, false)
  } finally {
    cleanupRuntime(xhrMock)
  }
})

function installMockXhr(responses) {
  const previousXhr = globalThis.XMLHttpRequest
  const calls = []

  class MockXMLHttpRequest {
    constructor() {
      this.headers = {}
      this.upload = {}
      this.status = 0
      this.responseText = ''
      this.aborted = false
      this.response = responses.shift()
      calls.push(this)
    }

    open(method, url) {
      this.method = method
      this.url = url
    }

    setRequestHeader(name, value) {
      this.headers[name] = value
    }

    getResponseHeader(name) {
      return this.response?.headers?.[name] ?? null
    }

    send(body) {
      this.body = body
      if (this.response?.defer) {
        return
      }
      if (this.response?.progress) {
        this.upload.onprogress?.({
          lengthComputable: true,
          loaded: this.response.progress.loaded,
          total: this.response.progress.total,
        })
      }
      this.status = this.response?.status ?? 200
      this.responseText = this.response?.text ?? ''
      this.onload?.()
    }

    abort() {
      this.aborted = true
      this.onabort?.()
    }
  }

  globalThis.XMLHttpRequest = MockXMLHttpRequest
  return {
    calls,
    restore() {
      globalThis.XMLHttpRequest = previousXhr
    },
  }
}

function cleanupRuntime(xhrMock) {
  clearAuthTokens()
  xhrMock.restore()
}
