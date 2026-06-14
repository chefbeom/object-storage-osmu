import assert from 'node:assert/strict'
import test from 'node:test'
import {
  applyUploadProgress,
  beginUploadState,
  canStartUpload,
  completeUploadState,
  failUploadState,
  finishUploadState,
  markUploadResumeState,
  resetUploadStateForFile,
} from './uploads.js'

test('upload state tracks progress and blocks duplicate starts while active', () => {
  const state = createUploadState()

  assert.equal(canStartUpload(state), true)
  beginUploadState(state, 1000, 'Multipart upload')

  assert.equal(canStartUpload(state), false)
  assert.equal(state.active, true)
  assert.equal(state.totalBytes, 1000)
  assert.equal(state.message, 'Multipart upload')
  assert.equal(state.retryable, false)

  applyUploadProgress(state, { loaded: 512, total: 1000, percent: 51 })
  assert.equal(state.loadedBytes, 512)
  assert.equal(state.percent, 51)

  completeUploadState(state)
  finishUploadState(state)
  assert.equal(state.percent, 100)
  assert.equal(state.active, false)
  assert.equal(canStartUpload(state), true)
})

test('upload state marks retry and resume states', () => {
  const state = createUploadState()

  resetUploadStateForFile(state, { resumeReady: true })
  assert.equal(state.message, 'Multipart resume ready')
  assert.equal(state.retryable, false)

  beginUploadState(state, 2048)
  markUploadResumeState(state, 1024)
  assert.equal(state.message, 'Multipart resume')

  failUploadState(state, 'Network failed')
  finishUploadState(state)
  assert.equal(state.active, false)
  assert.equal(state.retryable, true)
  assert.equal(state.message, 'Network failed')
})

function createUploadState() {
  return {
    active: false,
    loadedBytes: 0,
    totalBytes: 0,
    percent: 0,
    message: '',
    retryable: false,
  }
}
