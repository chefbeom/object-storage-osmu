import assert from 'node:assert/strict'
import test from 'node:test'
import {
  ApiClientError,
  clearAuthTokens,
  createMultipartUpload,
  createPresignedUploadUrl,
  getObjects,
  updateObjectTags,
  uploadObject,
  uploadObjectMultipart,
} from './api.js'

test('object tag validation blocks API calls before network work starts', async () => {
  const fetchMock = installBlockingFetch()

  try {
    await assertValidationError(() => getObjects('media', { tag: 'bad key=value' }))
    await assertValidationError(() => uploadObject('media', 'bad.txt', new Blob(['bad']), 'bad key=value'))
    await assertValidationError(() => createPresignedUploadUrl('media', {
      key: 'bad.txt',
      contentType: 'text/plain',
      sizeBytes: 3,
      tags: 'bad key=value',
    }))
    await assertValidationError(() => createMultipartUpload('media', {
      key: 'bad.bin',
      contentType: 'application/octet-stream',
      sizeBytes: 10,
      partSizeBytes: 5,
      tags: 'bad key=value',
    }))
    await assertValidationError(() => uploadObjectMultipart('media', 'bad.bin', {}, 'bad key=value'))
    await assertValidationError(() => updateObjectTags('media', {
      key: 'bad.txt',
      tags: { 'bad key': 'value' },
    }))

    assert.equal(fetchMock.calls.length, 0)
  } finally {
    cleanupFetch(fetchMock)
  }
})

async function assertValidationError(action) {
  try {
    await action()
  } catch (error) {
    assert.ok(error instanceof ApiClientError)
    assert.equal(error.code, 'VALIDATION_ERROR')
    assert.equal(error.status, 400)
    assert.match(error.message, /can contain/)
    return
  }
  assert.fail('Expected validation error')
}

function installBlockingFetch() {
  const previousFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options })
    throw new Error(`Unexpected fetch call: ${url}`)
  }
  return {
    calls,
    restore() {
      globalThis.fetch = previousFetch
    },
  }
}

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
