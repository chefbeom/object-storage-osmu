import assert from 'node:assert/strict'
import test from 'node:test'
import {
  deleteStoredMultipartUploadSession,
  getStoredMultipartUploadSessions,
} from './api.js'

const SESSION_PREFIX = 'osmu.multipartUpload.'

test('getStoredMultipartUploadSessions filters and sorts pending sessions', () => {
  const storage = installSessionStorage()
  const now = Date.now()
  writeSession(storage, 'old', {
    bucketName: 'media',
    key: 'video/a.mp4',
    fileName: 'a.mp4',
    fileSize: 10,
    partSizeBytes: 5,
    uploadId: 'upload-old',
    completedParts: [{ partNumber: 1, etag: '"a"' }],
    updatedAt: new Date(now - 10_000).toISOString(),
    expiresAt: new Date(now + 60_000).toISOString(),
  })
  writeSession(storage, 'new', {
    bucketName: 'media',
    key: 'video/b.mp4',
    fileName: 'b.mp4',
    fileSize: 20,
    partSizeBytes: 5,
    uploadId: 'upload-new',
    completedParts: [],
    updatedAt: new Date(now).toISOString(),
    expiresAt: new Date(now + 120_000).toISOString(),
  })
  writeSession(storage, 'other-bucket', {
    bucketName: 'archive',
    key: 'video/c.mp4',
    fileName: 'c.mp4',
    fileSize: 30,
    partSizeBytes: 5,
    uploadId: 'upload-other',
    completedParts: [],
    updatedAt: new Date(now + 10_000).toISOString(),
  })

  try {
    const sessions = getStoredMultipartUploadSessions({ bucketName: 'media' })

    assert.deepEqual(sessions.map((session) => session.uploadId), ['upload-new', 'upload-old'])
    assert.equal(sessions[0].storageKey, `${SESSION_PREFIX}new`)
    assert.equal(sessions[0].expired, false)
  } finally {
    cleanupSessionStorage()
  }
})

test('getStoredMultipartUploadSessions marks expired and prunes stale local sessions', () => {
  const storage = installSessionStorage()
  const now = Date.now()
  writeSession(storage, 'expired-visible', {
    bucketName: 'media',
    key: 'video/visible.mp4',
    fileName: 'visible.mp4',
    fileSize: 10,
    partSizeBytes: 5,
    uploadId: 'upload-visible',
    completedParts: [],
    updatedAt: new Date(now).toISOString(),
    expiresAt: new Date(now - 60_000).toISOString(),
  })
  writeSession(storage, 'expired-stale', {
    bucketName: 'media',
    key: 'video/stale.mp4',
    fileName: 'stale.mp4',
    fileSize: 10,
    partSizeBytes: 5,
    uploadId: 'upload-stale',
    completedParts: [],
    updatedAt: new Date(now - 90_000_000).toISOString(),
    expiresAt: new Date(now - 90_000_000).toISOString(),
  })
  storage.setItem(`${SESSION_PREFIX}broken`, '{not-json')
  storage.setItem('unrelated', 'keep-me')

  try {
    const sessions = getStoredMultipartUploadSessions({ bucketName: 'media' })

    assert.deepEqual(sessions.map((session) => session.uploadId), ['upload-visible'])
    assert.equal(sessions[0].expired, true)
    assert.equal(storage.getItem(`${SESSION_PREFIX}expired-stale`), null)
    assert.equal(storage.getItem(`${SESSION_PREFIX}broken`), null)
    assert.equal(storage.getItem('unrelated'), 'keep-me')
  } finally {
    cleanupSessionStorage()
  }
})

test('deleteStoredMultipartUploadSession removes one local resume session', () => {
  const storage = installSessionStorage()
  writeSession(storage, 'delete-me', {
    bucketName: 'media',
    key: 'video/delete.mp4',
    fileName: 'delete.mp4',
    fileSize: 10,
    partSizeBytes: 5,
    uploadId: 'upload-delete',
    completedParts: [],
  })

  try {
    deleteStoredMultipartUploadSession(`${SESSION_PREFIX}delete-me`)

    assert.equal(storage.getItem(`${SESSION_PREFIX}delete-me`), null)
  } finally {
    cleanupSessionStorage()
  }
})

function writeSession(storage, key, session) {
  storage.setItem(`${SESSION_PREFIX}${key}`, JSON.stringify(session))
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

function cleanupSessionStorage() {
  delete globalThis.window
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
