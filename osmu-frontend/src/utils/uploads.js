export function canStartUpload(uploadState) {
  return !uploadState.active
}

export function resetUploadStateForFile(uploadState, { resumeReady = false } = {}) {
  uploadState.retryable = false
  uploadState.message = resumeReady ? 'Multipart resume ready' : ''
}

export function beginUploadState(uploadState, fileSize, message = '') {
  uploadState.active = true
  uploadState.loadedBytes = 0
  uploadState.totalBytes = Number(fileSize || 0)
  uploadState.percent = 0
  uploadState.message = message
  uploadState.retryable = false
}

export function applyUploadProgress(uploadState, progress) {
  uploadState.loadedBytes = Number(progress.loaded || 0)
  uploadState.totalBytes = Number(progress.total || 0)
  uploadState.percent = Number(progress.percent || 0)
}

export function markUploadResumeState(uploadState, completedBytes) {
  uploadState.message = Number(completedBytes || 0) > 0 ? 'Multipart resume' : 'Multipart upload'
}

export function completeUploadState(uploadState) {
  uploadState.percent = 100
  uploadState.message = ''
  uploadState.retryable = false
}

export function failUploadState(uploadState, message) {
  uploadState.message = message
  uploadState.retryable = true
}

export function finishUploadState(uploadState) {
  uploadState.active = false
}
