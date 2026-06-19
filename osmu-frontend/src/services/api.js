import { validateObjectTagInput, validateObjectTagMap } from '../utils/tags.js'

const env = import.meta.env ?? {}
const API_BASE_URL = env.VITE_API_BASE_URL ?? 'http://localhost:8080/api'
export const MULTIPART_UPLOAD_THRESHOLD_BYTES = 128 * 1024 * 1024
const MULTIPART_UPLOAD_PART_SIZE_BYTES = 64 * 1024 * 1024
export const MULTIPART_UPLOAD_CONCURRENCY = normalizeConcurrency(env.VITE_MULTIPART_UPLOAD_CONCURRENCY ?? 4)
export const MULTIPART_UPLOAD_PART_RETRIES = normalizeRetryCount(env.VITE_MULTIPART_UPLOAD_PART_RETRIES ?? 2)
export const MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS = normalizeRetryDelay(env.VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS ?? 500)
const MULTIPART_UPLOAD_SESSION_STORAGE_PREFIX = 'osmu.multipartUpload.'
const MULTIPART_UPLOAD_EXPIRED_SESSION_GRACE_MS = 24 * 60 * 60 * 1000
let accessToken = null
let refreshToken = null
let authStateListener = null

export class ApiClientError extends Error {
  constructor(message, { code = null, requestId = null, status = null } = {}) {
    super(message)
    this.name = 'ApiClientError'
    this.code = code
    this.requestId = requestId
    this.status = status
  }
}

export function setAccessToken(token) {
  accessToken = token
  notifyAuthStateChange()
}

export function setRefreshToken(token) {
  refreshToken = token
  notifyAuthStateChange()
}

export function setAuthTokens(tokens) {
  accessToken = tokens?.accessToken ?? null
  refreshToken = tokens?.refreshToken ?? null
  notifyAuthStateChange()
}

export function clearAccessToken(reason = '') {
  accessToken = null
  notifyAuthStateChange(reason)
}

export function clearAuthTokens(reason = '') {
  accessToken = null
  refreshToken = null
  notifyAuthStateChange(reason)
}

export function setAuthStateListener(listener) {
  authStateListener = listener
}

function notifyAuthStateChange(reason = '') {
  authStateListener?.({ accessToken, refreshToken, reason })
}

async function request(path, options = {}) {
  const headers = new Headers(options.headers ?? {})
  applyAuthorization(headers)
  let body = options.body

  if (body && !(body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(body)
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
    body,
  })

  if (response.status === 401 && options.retry !== false && refreshToken && path !== '/auth/refresh') {
    const refreshed = await refreshSession().catch(() => null)
    if (refreshed) {
      return request(path, { ...options, retry: false })
    }
  }

  if (!response.ok) {
    const payload = await response.json().catch(() => null)
    throw apiError(response, payload)
  }

  if (response.status === 204) {
    return null
  }

  return response.json()
}

async function textRequest(path, options = {}) {
  const headers = new Headers(options.headers ?? {})
  applyAuthorization(headers)

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  })

  if (response.status === 401 && options.retry !== false && refreshToken && path !== '/auth/refresh') {
    const refreshed = await refreshSession().catch(() => null)
    if (refreshed) {
      return textRequest(path, { ...options, retry: false })
    }
  }

  const text = await response.text()
  if (!response.ok) {
    throw apiError(response, parseJson(text) ?? parseS3ErrorXml(text))
  }

  return text
}

async function download(path, options = {}) {
  const headers = new Headers()
  applyAuthorization(headers)

  const response = await fetch(`${API_BASE_URL}${path}`, { headers })

  if (response.status === 401 && options.retry !== false && refreshToken) {
    const refreshed = await refreshSession().catch(() => null)
    if (refreshed) {
      return download(path, { retry: false })
    }
  }

  if (!response.ok) {
    const payload = await response.json().catch(() => null)
    throw apiError(response, payload)
  }

  return response.blob()
}

async function upload(path, body, onProgress, options = {}) {
  const response = await uploadOnce(path, body, onProgress, options.signal)

  if (response.status === 401 && options.retry !== false && refreshToken) {
    if (options.signal?.aborted) {
      throw new Error('Upload aborted')
    }
    const refreshed = await refreshSession().catch(() => null)
    if (refreshed) {
      return upload(path, body, onProgress, { ...options, retry: false })
    }
  }

  if (response.status < 200 || response.status >= 300) {
    const payload = parseJson(response.text)
    throw apiError(response, payload)
  }

  if (response.status === 204 || !response.text) {
    return null
  }

  return JSON.parse(response.text)
}

function uploadOnce(path, body, onProgress, signal) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new Error('Upload aborted'))
      return
    }

    const xhr = new XMLHttpRequest()
    const abortUpload = () => xhr.abort()
    const cleanup = () => signal?.removeEventListener('abort', abortUpload)

    xhr.open('POST', `${API_BASE_URL}${path}`)
    if (accessToken) {
      xhr.setRequestHeader('Authorization', `Bearer ${accessToken}`)
    }
    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable || !onProgress) {
        return
      }
      onProgress({
        loaded: event.loaded,
        total: event.total,
        percent: Math.round((event.loaded / event.total) * 100),
      })
    }
    xhr.onload = () => {
      cleanup()
      resolve({
        status: xhr.status,
        text: xhr.responseText,
        requestId: xhr.getResponseHeader('X-Request-Id'),
      })
    }
    xhr.onerror = () => {
      cleanup()
      reject(new Error('Network error'))
    }
    xhr.onabort = () => {
      cleanup()
      reject(new Error('Upload aborted'))
    }
    signal?.addEventListener('abort', abortUpload, { once: true })
    xhr.send(body)
  })
}

function parseJson(text) {
  if (!text) {
    return null
  }
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

function parseS3ErrorXml(text) {
  if (!text?.trim().startsWith('<')) {
    return null
  }
  const code = xmlElementText(text, 'Code')
  const message = xmlElementText(text, 'Message')
  const requestId = xmlElementText(text, 'RequestId')
  if (!code && !message && !requestId) {
    return null
  }
  return { error: { code, message, requestId } }
}

function xmlElementText(text, tagName) {
  const match = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'i').exec(text)
  return match ? decodeXmlText(match[1].trim()) : null
}

function decodeXmlText(text) {
  return text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
}

function applyAuthorization(headers) {
  if (accessToken) {
    headers.set('Authorization', `Bearer ${accessToken}`)
  }
}

function apiError(response, payload = null) {
  const status = response.status
  const code = payload?.error?.code ?? null
  const requestId = payload?.error?.requestId ?? response.headers?.get?.('X-Request-Id') ?? response.requestId ?? null
  const message = payload?.error?.message ?? `HTTP ${status}`
  return new ApiClientError(message, { code, requestId, status })
}

function authFailureReason(response) {
  return response.status === 401 || response.status === 403 ? 'session-expired' : 'session-invalid'
}

function assertValidObjectTagInput(tags) {
  const error = validateObjectTagInput(tags)
  if (error) {
    throw new ApiClientError(error, { code: 'VALIDATION_ERROR', status: 400 })
  }
}

function assertValidObjectTagPayload(payload) {
  const tags = payload?.tags
  const error = typeof tags === 'string'
    ? validateObjectTagInput(tags)
    : validateObjectTagMap(tags)
  if (error) {
    throw new ApiClientError(error, { code: 'VALIDATION_ERROR', status: 400 })
  }
}

export function getHealth() {
  return request('/health')
}

export function getStorageHealth() {
  return request('/storage/health')
}

export function getDatabaseHealth() {
  return request('/database/health')
}

export function login(loginId, password) {
  return request('/auth/login', {
    method: 'POST',
    body: { loginId, password },
  })
}

export function loginWithLdap(loginId, password) {
  return request('/auth/ldap/login', {
    method: 'POST',
    body: { loginId, password },
  })
}

export function getOidcAuthorizationRequest() {
  return request('/auth/oidc/authorize')
}

export function completeOidcCallback(code, state) {
  const query = new URLSearchParams()
  appendQuery(query, 'code', code)
  appendQuery(query, 'state', state)
  return request(`/auth/oidc/callback?${query.toString()}`)
}

export async function refreshSession() {
  if (!refreshToken) {
    return null
  }

  const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
  })

  if (!response.ok) {
    clearAuthTokens(authFailureReason(response))
    return null
  }

  const payload = await response.json()
  setAuthTokens(payload.data)
  return payload
}

export async function logout() {
  try {
    return await request('/auth/logout', {
      method: 'POST',
      body: refreshToken ? { refreshToken } : {},
      retry: false,
    })
  } finally {
    clearAuthTokens('logout')
  }
}

export function getCurrentUser() {
  return request('/users/me')
}

export function getS3ClientConfig() {
  return request('/developer/s3-client-config')
}

export function getBuckets() {
  return request('/buckets')
}

export function createBucket(payload) {
  return request('/buckets', {
    method: 'POST',
    body: payload,
  })
}

export function deleteBucket(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}`, {
    method: 'DELETE',
  })
}

export function syncBucketUsage(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/sync`, {
    method: 'POST',
  })
}

export function getBucketLifecycleS3Xml(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/lifecycle`)
}

export function putBucketLifecycleS3Xml(bucketName, xml) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/lifecycle`, {
    method: 'PUT',
    body: { xml },
  })
}

export function deleteBucketLifecycleS3Xml(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/lifecycle`, {
    method: 'DELETE',
  })
}

export function getBucketTags(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/tags`)
}

export function putBucketTags(bucketName, tags) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/tags`, {
    method: 'PUT',
    body: { tags },
  })
}

export function deleteBucketTags(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/tags`, {
    method: 'DELETE',
  })
}

export function getBucketTagsS3Xml(bucketName) {
  return textRequest(`/s3/${encodeURIComponent(bucketName)}?tagging`, {
    headers: { Accept: 'application/xml' },
  })
}

export function putBucketTagsS3Xml(bucketName, xml) {
  return textRequest(`/s3/${encodeURIComponent(bucketName)}?tagging`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/xml' },
    body: xml,
  })
}

export function deleteBucketTagsS3Xml(bucketName) {
  return textRequest(`/s3/${encodeURIComponent(bucketName)}?tagging`, {
    method: 'DELETE',
  })
}

export function getBucketPermissions(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/permissions`)
}

export function grantBucketPermissions(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/permissions`, {
    method: 'POST',
    body: payload,
  })
}

export function revokeBucketPermission(bucketName, permissionId) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/permissions/${encodeURIComponent(permissionId)}`, {
    method: 'DELETE',
  })
}

export function getStorageProfiles() {
  return request('/storage-profiles')
}

export function getStorageProfileRequests() {
  return request('/storage-profile-requests')
}

export function getBucketStorageProfile(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/storage-profile`)
}

export function createStorageProfileRequest(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/storage-profile-requests`, {
    method: 'POST',
    body: payload,
  })
}

export function getObjects(bucketName, options = {}) {
  const normalizedOptions = typeof options === 'string' ? { prefix: options } : options
  const { prefix = '', delimiter = '', search = '', tag = '', cursor = '', limit, deleted = false } = normalizedOptions
  const params = new URLSearchParams()
  const trimmedPrefix = prefix.trim()
  const trimmedSearch = search.trim()
  const trimmedTag = tag.trim()
  if (trimmedPrefix) {
    params.set('prefix', trimmedPrefix)
  }
  if (delimiter) {
    params.set('delimiter', delimiter)
  }
  if (trimmedSearch) {
    params.set('search', trimmedSearch)
  }
  if (trimmedTag) {
    assertValidObjectTagInput(trimmedTag)
    params.set('tag', trimmedTag)
  }
  if (cursor) {
    params.set('cursor', cursor)
  }
  if (limit) {
    params.set('limit', String(limit))
  }
  if (deleted) {
    params.set('deleted', 'true')
  }
  const query = params.toString()
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects${query ? `?${query}` : ''}`)
}

export function uploadObject(bucketName, key, file, tags, onProgress, options = {}) {
  assertValidObjectTagInput(tags)
  const body = new FormData()
  body.append('key', key)
  if (tags?.trim()) {
    body.append('tags', tags.trim())
  }
  body.append('file', file)

  return upload(`/buckets/${encodeURIComponent(bucketName)}/objects`, body, onProgress, options)
}

export function createPresignedUploadUrl(bucketName, payload) {
  assertValidObjectTagPayload(payload)
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/presigned-upload`, {
    method: 'POST',
    body: payload,
  })
}

export function completePresignedUpload(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/presigned-upload/complete`, {
    method: 'POST',
    body: payload,
  })
}

export function createMultipartUpload(bucketName, payload) {
  assertValidObjectTagPayload(payload)
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/multipart-upload`, {
    method: 'POST',
    body: payload,
  })
}

export function refreshMultipartUpload(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/multipart-upload/refresh`, {
    method: 'POST',
    body: payload,
  })
}

export function listMultipartUploadParts(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/multipart-upload/parts`, {
    method: 'POST',
    body: payload,
  })
}

export function getStoredMultipartUploadSessions(filters = {}) {
  const storage = browserSessionStorage()
  if (!storage) {
    return []
  }
  const sessions = []
  const storageKeys = []
  for (let index = 0; index < storage.length; index += 1) {
    storageKeys.push(storage.key(index))
  }
  for (const storageKey of storageKeys) {
    if (!storageKey?.startsWith(MULTIPART_UPLOAD_SESSION_STORAGE_PREFIX)) {
      continue
    }
    try {
      const session = JSON.parse(storage.getItem(storageKey) || 'null')
      if (!isStoredMultipartUploadSession(session)) {
        continue
      }
      if (filters.bucketName && session.bucketName !== filters.bucketName) {
        continue
      }
      if (filters.key && session.key !== filters.key) {
        continue
      }
      if (isPrunableExpiredMultipartUploadSession(session)) {
        clearMultipartUploadSession(storageKey)
        continue
      }
      sessions.push({
        ...session,
        storageKey,
        expired: isExpiredMultipartUploadSession(session),
      })
    } catch {
      clearMultipartUploadSession(storageKey)
    }
  }
  return sessions.sort((left, right) => timestampValue(right.updatedAt) - timestampValue(left.updatedAt))
}

export function getStoredMultipartUploadSessionForFile(bucketName, key, file, tags, partSizeBytes = MULTIPART_UPLOAD_PART_SIZE_BYTES) {
  const storageKey = multipartUploadSessionStorageKey(bucketName, key, file, tags, partSizeBytes)
  const session = readMultipartUploadSession(storageKey, bucketName, key, file, tags, partSizeBytes)
  return session ? { ...session, storageKey, expired: isExpiredMultipartUploadSession(session) } : null
}

export function deleteStoredMultipartUploadSession(storageKey) {
  clearMultipartUploadSession(storageKey)
}

export function completeMultipartUpload(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/multipart-upload/complete`, {
    method: 'POST',
    body: payload,
  })
}

export function abortMultipartUpload(bucketName, payload) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/multipart-upload/abort`, {
    method: 'POST',
    body: payload,
    retry: false,
  })
}

export async function uploadObjectMultipart(bucketName, key, file, tags, onProgress, options = {}) {
  assertValidObjectTagInput(tags)
  let upload = null
  const completedParts = []
  let completedBytes = 0
  const partProgress = new Map()
  const partAbortController = new AbortController()
  const combinedSignal = combineAbortSignals(options.signal, partAbortController.signal)
  const concurrency = normalizeConcurrency(options.concurrency ?? MULTIPART_UPLOAD_CONCURRENCY)
  const partRetries = normalizeRetryCount(options.partRetries ?? MULTIPART_UPLOAD_PART_RETRIES)
  const retryBaseDelayMs = normalizeRetryDelay(options.retryBaseDelayMs ?? MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS)
  const requestedPartSizeBytes = options.partSizeBytes ?? MULTIPART_UPLOAD_PART_SIZE_BYTES
  const resumeStorageKey = multipartUploadSessionStorageKey(bucketName, key, file, tags, requestedPartSizeBytes)
  let resumeSession = options.resume === false
    ? null
    : readMultipartUploadSession(resumeStorageKey, bucketName, key, file, tags, requestedPartSizeBytes)

  const reportMultipartProgress = () => {
    const activeBytes = Array.from(partProgress.values()).reduce((total, loaded) => total + loaded, 0)
    reportUploadProgress(onProgress, completedBytes + activeBytes, file.size)
  }

  const persistMultipartProgress = () => {
    if (options.resume === false || !upload?.uploadId) {
      return
    }
    writeMultipartUploadSession(resumeStorageKey, {
      bucketName,
      key,
      tags: normalizeMultipartTags(tags),
      fileName: file.name,
      fileSize: file.size,
      fileLastModified: file.lastModified ?? 0,
      contentType: multipartContentType(file),
      uploadId: upload.uploadId,
      partSizeBytes: upload.partSizeBytes ?? requestedPartSizeBytes,
      partCount: upload.partCount ?? upload.parts?.length ?? 0,
      expiresAt: upload.expiresAt ?? resumeSession?.expiresAt ?? null,
      completedParts: sortedCompletedParts(completedParts),
    })
  }

  try {
    if (resumeSession) {
      const refreshed = await refreshStoredMultipartUpload(bucketName, key, resumeSession, resumeStorageKey)
      upload = refreshed?.upload ?? null
      if (upload) {
        restoreCompletedParts(completedParts, refreshed.completedParts, upload.parts)
        completedBytes = completedBytesForParts(completedParts, upload.parts)
        persistMultipartProgress()
        options.onResume?.({ upload, completedParts: sortedCompletedParts(completedParts), completedBytes })
        reportMultipartProgress()
      } else {
        resumeSession = null
      }
    }

    if (!upload) {
      const createResult = await createMultipartUpload(bucketName, {
        key,
        tags,
        contentType: multipartContentType(file),
        sizeBytes: file.size,
        partSizeBytes: requestedPartSizeBytes,
        expiresInSeconds: 900,
      })
      upload = createResult.data
      persistMultipartProgress()
    }

    const completedPartNumbers = new Set(completedParts.map((part) => part.partNumber))
    const partUploads = upload.parts
      .filter((part) => !completedPartNumbers.has(part.partNumber))
      .map((part) => ({
        part,
        blob: file.slice(part.startByte, part.endByte + 1),
      }))

    await uploadWithConcurrency(partUploads, concurrency, async ({ part, blob }) => {
      if (combinedSignal.signal?.aborted) {
        throw new Error('Upload aborted')
      }
      const etag = await uploadPresignedPartWithRetry(
        part.url,
        blob,
        (progress) => {
          partProgress.set(part.partNumber, progress.loaded)
          reportMultipartProgress()
        },
        combinedSignal.signal,
        {
          maxRetries: partRetries,
          retryBaseDelayMs,
          onRetry: () => {
            partProgress.set(part.partNumber, 0)
            reportMultipartProgress()
          },
        },
      )
      partProgress.delete(part.partNumber)
      if (upsertCompletedPart(completedParts, { partNumber: part.partNumber, etag })) {
        completedBytes += blob.size
      }
      persistMultipartProgress()
      reportMultipartProgress()
    })

    const result = await completeMultipartUpload(bucketName, {
      uploadId: upload.uploadId,
      key,
      parts: sortedCompletedParts(completedParts),
    })
    clearMultipartUploadSession(resumeStorageKey)
    return result
  } catch (error) {
    const aborted = options.signal?.aborted || combinedSignal.signal?.aborted || error?.message === 'Upload aborted'
    partAbortController.abort()
    if (upload?.uploadId && aborted) {
      await abortMultipartUpload(bucketName, { uploadId: upload.uploadId, key }).catch(() => null)
      clearMultipartUploadSession(resumeStorageKey)
    } else if (upload?.uploadId) {
      persistMultipartProgress()
    }
    throw error
  } finally {
    combinedSignal.cleanup()
  }
}

async function refreshStoredMultipartUpload(bucketName, key, session, storageKey) {
  try {
    const [refreshResult, partsResult] = await Promise.all([
      refreshMultipartUpload(bucketName, {
        uploadId: session.uploadId,
        key,
        expiresInSeconds: 900,
      }),
      listMultipartUploadParts(bucketName, {
        uploadId: session.uploadId,
        key,
      }),
    ])
    return {
      upload: refreshResult.data,
      completedParts: mergeCompletedParts(session.completedParts, partsResult.data.parts),
    }
  } catch (error) {
    if (error instanceof ApiClientError && [401, 404, 409].includes(error.status)) {
      clearMultipartUploadSession(storageKey)
      return null
    }
    throw error
  }
}

function multipartUploadSessionStorageKey(bucketName, key, file, tags, partSizeBytes) {
  const identity = JSON.stringify({
    bucketName,
    key,
    tags: normalizeMultipartTags(tags),
    fileName: file.name,
    fileSize: file.size,
    fileLastModified: file.lastModified ?? 0,
    contentType: multipartContentType(file),
    partSizeBytes,
  })
  return `${MULTIPART_UPLOAD_SESSION_STORAGE_PREFIX}${hashString(identity)}`
}

function readMultipartUploadSession(storageKey, bucketName, key, file, tags, partSizeBytes) {
  const storage = browserSessionStorage()
  if (!storage) {
    return null
  }
  try {
    const session = JSON.parse(storage.getItem(storageKey) || 'null')
    if (!isMatchingMultipartUploadSession(session, bucketName, key, file, tags, partSizeBytes)) {
      return null
    }
    if (isExpiredMultipartUploadSession(session)) {
      return null
    }
    return session
  } catch {
    clearMultipartUploadSession(storageKey)
    return null
  }
}

function writeMultipartUploadSession(storageKey, session) {
  const storage = browserSessionStorage()
  if (!storage) {
    return
  }
  try {
    storage.setItem(storageKey, JSON.stringify({
      ...session,
      updatedAt: new Date().toISOString(),
    }))
  } catch {
    clearMultipartUploadSession(storageKey)
  }
}

function clearMultipartUploadSession(storageKey) {
  const storage = browserSessionStorage()
  if (!storage) {
    return
  }
  try {
    storage.removeItem(storageKey)
  } catch {
    // Ignore storage cleanup failures.
  }
}

function browserSessionStorage() {
  if (typeof window === 'undefined') {
    return null
  }
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}

function isMatchingMultipartUploadSession(session, bucketName, key, file, tags, partSizeBytes) {
  return Boolean(session?.uploadId)
    && session.bucketName === bucketName
    && session.key === key
    && session.tags === normalizeMultipartTags(tags)
    && session.fileName === file.name
    && session.fileSize === file.size
    && session.fileLastModified === (file.lastModified ?? 0)
    && session.contentType === multipartContentType(file)
    && session.partSizeBytes === partSizeBytes
    && Array.isArray(session.completedParts)
}

function isStoredMultipartUploadSession(session) {
  return Boolean(session?.uploadId)
    && typeof session.bucketName === 'string'
    && typeof session.key === 'string'
    && typeof session.fileName === 'string'
    && Number.isFinite(Number(session.fileSize))
    && Number.isFinite(Number(session.partSizeBytes))
    && Array.isArray(session.completedParts)
}

function isExpiredMultipartUploadSession(session) {
  if (!session?.expiresAt) {
    return false
  }
  const expiresAt = Date.parse(session.expiresAt)
  return Number.isFinite(expiresAt) && expiresAt <= Date.now()
}

function isPrunableExpiredMultipartUploadSession(session) {
  if (!session?.expiresAt) {
    return false
  }
  const expiresAt = Date.parse(session.expiresAt)
  return Number.isFinite(expiresAt) && expiresAt + MULTIPART_UPLOAD_EXPIRED_SESSION_GRACE_MS <= Date.now()
}

function timestampValue(value) {
  const timestamp = Date.parse(value || '')
  return Number.isFinite(timestamp) ? timestamp : 0
}

function restoreCompletedParts(target, storedParts, currentParts) {
  const validPartNumbers = new Set(currentParts.map((part) => part.partNumber))
  const restored = new Map()
  for (const part of storedParts ?? []) {
    const partNumber = Number(part.partNumber)
    const etag = typeof part.etag === 'string' ? part.etag.trim() : ''
    if (validPartNumbers.has(partNumber) && etag && !restored.has(partNumber)) {
      restored.set(partNumber, { partNumber, etag })
    }
  }
  target.splice(0, target.length, ...Array.from(restored.values()).sort(comparePartNumber))
}

function mergeCompletedParts(localParts, serverParts) {
  const merged = new Map()
  for (const part of localParts ?? []) {
    const partNumber = Number(part.partNumber)
    const etag = typeof part.etag === 'string' ? part.etag.trim() : ''
    if (Number.isInteger(partNumber) && partNumber > 0 && etag) {
      merged.set(partNumber, { partNumber, etag })
    }
  }
  for (const part of serverParts ?? []) {
    const partNumber = Number(part.partNumber)
    const etag = typeof part.etag === 'string' ? part.etag.trim() : ''
    if (Number.isInteger(partNumber) && partNumber > 0 && etag) {
      merged.set(partNumber, { partNumber, etag })
    }
  }
  return Array.from(merged.values()).sort(comparePartNumber)
}

function upsertCompletedPart(completedParts, nextPart) {
  const existingIndex = completedParts.findIndex((part) => part.partNumber === nextPart.partNumber)
  if (existingIndex >= 0) {
    completedParts[existingIndex] = nextPart
    return false
  }
  completedParts.push(nextPart)
  return true
}

function completedBytesForParts(completedParts, allParts) {
  const byteSizeByPart = new Map(allParts.map((part) => [part.partNumber, multipartPartByteSize(part)]))
  return completedParts.reduce((total, part) => total + (byteSizeByPart.get(part.partNumber) ?? 0), 0)
}

function multipartPartByteSize(part) {
  const startByte = Number(part.startByte)
  const endByte = Number(part.endByte)
  if (!Number.isFinite(startByte) || !Number.isFinite(endByte) || endByte < startByte) {
    return 0
  }
  return endByte - startByte + 1
}

function sortedCompletedParts(completedParts) {
  return [...completedParts].sort(comparePartNumber)
}

function comparePartNumber(left, right) {
  return left.partNumber - right.partNumber
}

function normalizeMultipartTags(tags) {
  return tags?.trim() ?? ''
}

function multipartContentType(file) {
  return file.type || 'application/octet-stream'
}

function hashString(value) {
  let hash = 0
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0
  }
  return Math.abs(hash).toString(36)
}

export function updateObjectTags(bucketName, payload) {
  assertValidObjectTagPayload(payload)
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/tags`, {
    method: 'PUT',
    body: payload,
  })
}

export function getObjectMetadata(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/metadata/${encodeObjectKey(key)}`)
}

export function listObjectVersions(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/versions/${encodeObjectKey(key)}`)
}

export function restoreObjectVersion(bucketName, key, versionId) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/versions/${encodeURIComponent(versionId)}/restore/${encodeObjectKey(key)}`, {
    method: 'POST',
  })
}

export function downloadObjectVersion(bucketName, key, versionId) {
  return download(`/buckets/${encodeURIComponent(bucketName)}/objects/versions/${encodeURIComponent(versionId)}/download/${encodeObjectKey(key)}`)
}

export function deleteObjectVersion(bucketName, key, versionId) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/versions/${encodeURIComponent(versionId)}/delete/${encodeObjectKey(key)}`, {
    method: 'DELETE',
  })
}

export function createPresignedDownloadUrl(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/presigned-download`, {
    method: 'POST',
    body: { key, expiresInSeconds: 900 },
  })
}

export function createObjectShareLink(bucketName, key, options = {}) {
  const body = {
    key,
    expiresInSeconds: options.expiresInSeconds ?? 3600,
  }
  if (options.note?.trim()) {
    body.note = options.note.trim()
  }
  if (options.maxDownloads !== undefined && options.maxDownloads !== null && options.maxDownloads !== '') {
    body.maxDownloads = Number(options.maxDownloads)
  }
  if (options.password?.trim()) {
    body.password = options.password.trim()
  }
  if (options.allowedIpCidrs?.trim()) {
    body.allowedIpCidrs = options.allowedIpCidrs.trim()
  }
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/share-links`, {
    method: 'POST',
    body,
  })
}

export function getObjectShareLinks(bucketName, key = '', limit = 50) {
  const query = new URLSearchParams()
  appendQuery(query, 'key', key)
  appendQuery(query, 'limit', limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/share-links${suffix}`)
}

export function deleteObjectShareLink(bucketName, linkId) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/share-links/${encodeURIComponent(linkId)}`, {
    method: 'DELETE',
  })
}

export function cleanupObjectShareLinks(bucketName) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/share-links/cleanup`, {
    method: 'POST',
  })
}

export function deleteObject(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/${encodeObjectKey(key)}`, {
    method: 'DELETE',
  })
}

export function restoreObject(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/restore/${encodeObjectKey(key)}`, {
    method: 'POST',
  })
}

export function purgeObject(bucketName, key) {
  return request(`/buckets/${encodeURIComponent(bucketName)}/objects/purge/${encodeObjectKey(key)}`, {
    method: 'POST',
  })
}

export function downloadObject(bucketName, key) {
  return download(`/buckets/${encodeURIComponent(bucketName)}/objects/${encodeObjectKey(key)}`)
}

export function getAccessKeys() {
  return request('/access-keys')
}

export function createAccessKey(payload) {
  return request('/access-keys', {
    method: 'POST',
    body: payload,
  })
}

export function deleteAccessKey(keyId) {
  return request(`/access-keys/${encodeURIComponent(keyId)}`, {
    method: 'DELETE',
  })
}

export function bulkDisableAccessKeys(keyIds) {
  return request('/access-keys/bulk-disable', {
    method: 'POST',
    body: { keyIds },
  })
}

export function rotateAccessKey(keyId) {
  return request(`/access-keys/${encodeURIComponent(keyId)}/rotate`, {
    method: 'POST',
  })
}

export function getDashboardSummary() {
  return request('/admin/dashboard/summary')
}

export function getDashboardReadiness() {
  return request('/admin/dashboard/readiness')
}

export function getEnterpriseAuthPlan() {
  return request('/admin/security/enterprise-auth-plan')
}

export function previewEnterpriseAuthClaims(claims) {
  return request('/admin/security/enterprise-auth/claim-preview', {
    method: 'POST',
    body: { claims },
  })
}

export function provisionEnterpriseAuthUser(payload) {
  return request('/admin/security/enterprise-auth/jit-provision', {
    method: 'POST',
    body: payload,
  })
}

export function getDataFlowMonitoring(filters = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'bucketName', filters.bucketName)
  appendQuery(query, 'actorId', filters.actorId)
  appendQuery(query, 'source', filters.source)
  appendQuery(query, 'operation', filters.operation)
  appendQuery(query, 'status', filters.status)
  appendQuery(query, 'from', filters.from)
  appendQuery(query, 'to', filters.to)
  appendQuery(query, 'limit', filters.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/monitoring/data-flow${suffix}`)
}

export function downloadDataFlowMonitoringCsv(filters = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'bucketName', filters.bucketName)
  appendQuery(query, 'actorId', filters.actorId)
  appendQuery(query, 'source', filters.source)
  appendQuery(query, 'operation', filters.operation)
  appendQuery(query, 'status', filters.status)
  appendQuery(query, 'from', filters.from)
  appendQuery(query, 'to', filters.to)
  appendQuery(query, 'limit', filters.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return download(`/admin/monitoring/data-flow/export.csv${suffix}`)
}

export function getChargebackPreview(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-preview${suffix}`)
}

export function downloadChargebackPreviewCsv(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return download(`/admin/billing/chargeback-preview/export.csv${suffix}`)
}

export function downloadChargebackInvoiceDraftCsv(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return download(`/admin/billing/chargeback-invoice-draft/export.csv${suffix}`)
}

export function getChargebackAlerts(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-alerts${suffix}`)
}

export function getChargebackAlertNotificationPreview(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  appendQuery(query, 'notificationChannel', options.notificationChannel)
  appendQuery(query, 'notificationTarget', options.notificationTarget)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-alert-notifications/preview${suffix}`)
}

export function queueChargebackAlertNotifications(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  appendQuery(query, 'notificationChannel', options.notificationChannel)
  appendQuery(query, 'notificationTarget', options.notificationTarget)
  appendQuery(query, 'reason', options.reason)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-alert-notifications/outbox${suffix}`, {
    method: 'POST',
  })
}

export function getChargebackAlertNotificationOutbox(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'limit', options.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-alert-notifications/outbox${suffix}`)
}

export function createChargebackInvoiceDrafts(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'from', options.from)
  appendQuery(query, 'to', options.to)
  appendQuery(query, 'currency', options.currency)
  appendQuery(query, 'storageGbMonthRate', options.storageGbMonthRate)
  appendQuery(query, 'ingressGbRate', options.ingressGbRate)
  appendQuery(query, 'egressGbRate', options.egressGbRate)
  appendQuery(query, 'internalGbRate', options.internalGbRate)
  appendQuery(query, 'operationThousandRate', options.operationThousandRate)
  appendQuery(query, 'eventScanLimit', options.eventScanLimit)
  appendQuery(query, 'reason', options.reason)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-invoice-drafts${suffix}`, {
    method: 'POST',
  })
}

export function getChargebackInvoiceDrafts(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'status', options.status)
  appendQuery(query, 'limit', options.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-invoice-drafts${suffix}`)
}

export function approveChargebackInvoiceDraft(invoiceId, options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'approvalNote', options.approvalNote)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/chargeback-invoice-drafts/${encodeURIComponent(invoiceId)}/approve${suffix}`, {
    method: 'POST',
  })
}

export function createBillingPricingPolicyProposal(payload) {
  return request('/admin/billing/pricing-policy-proposals', {
    method: 'POST',
    body: payload,
  })
}

export function getBillingPricingPolicyProposals(options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'status', options.status)
  appendQuery(query, 'limit', options.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/pricing-policy-proposals${suffix}`)
}

export function approveBillingPricingPolicyProposal(proposalId, options = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'approvalNote', options.approvalNote)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/billing/pricing-policy-proposals/${encodeURIComponent(proposalId)}/approve${suffix}`, {
    method: 'POST',
  })
}

export function getBillingPricingPolicy() {
  return request('/admin/billing/pricing-policy')
}

export function saveBillingPricingPolicy(payload) {
  return request('/admin/billing/pricing-policy', {
    method: 'PUT',
    body: payload,
  })
}

export function getDashboardLayout(scope = 'main') {
  return request(`/dashboard/layout?scope=${encodeURIComponent(scope)}`)
}

export function getDashboardLayoutPresets() {
  return request('/dashboard/layout/presets')
}

export function getDashboardWidgetCatalog() {
  return request('/dashboard/layout/widgets')
}

export function getDashboardLayoutDefaults() {
  return request('/dashboard/layout/defaults')
}

export function saveDashboardLayoutDefault(payload) {
  return request('/dashboard/layout/defaults', {
    method: 'PUT',
    body: payload,
  })
}

export function deleteDashboardLayoutDefault(targetType, targetId) {
  return request(`/dashboard/layout/defaults/${encodeURIComponent(targetType)}/${encodeURIComponent(targetId)}`, {
    method: 'DELETE',
  })
}

export function createDashboardLayoutPreset(payload) {
  return request('/dashboard/layout/presets', {
    method: 'POST',
    body: payload,
  })
}

export function updateDashboardLayoutPreset(presetId, payload) {
  return request(`/dashboard/layout/presets/${encodeURIComponent(presetId)}`, {
    method: 'PATCH',
    body: payload,
  })
}

export function exportDashboardLayoutPreset(presetId) {
  return request(`/dashboard/layout/presets/${encodeURIComponent(presetId)}/export`)
}

export function exportDashboardLayoutPresetBundle() {
  return request('/dashboard/layout/preset-bundle/export')
}

export function importDashboardLayoutPreset(payload) {
  return request('/dashboard/layout/presets/import', {
    method: 'POST',
    body: payload,
  })
}

export function importDashboardLayoutPresetBundle(payload) {
  return request('/dashboard/layout/preset-bundle/import', {
    method: 'POST',
    body: payload,
  })
}

export function saveDashboardLayout(widgets, scope = 'main', sections = [], schemaVersion = 'osmu.dashboard-layout.v1') {
  return request(`/dashboard/layout?scope=${encodeURIComponent(scope)}`, {
    method: 'PUT',
    body: { widgets, sections, schemaVersion },
  })
}

export function applyDashboardLayoutPreset(presetId, scope = 'main') {
  return request(`/dashboard/layout/presets/${encodeURIComponent(presetId)}?scope=${encodeURIComponent(scope)}`, {
    method: 'PUT',
  })
}

export function deleteDashboardLayoutPreset(presetId) {
  return request(`/dashboard/layout/presets/${encodeURIComponent(presetId)}`, {
    method: 'DELETE',
  })
}

export function deleteDashboardLayout(scope = 'main') {
  return request(`/dashboard/layout?scope=${encodeURIComponent(scope)}`, {
    method: 'DELETE',
  })
}

export function getUsage() {
  return request('/admin/usage')
}

export function getQuotaPolicies() {
  return request('/admin/quota-policies')
}

export function getQuotaPolicyHistory(limit = 50) {
  return request(`/admin/quota-policies/history?limit=${encodeURIComponent(limit)}`)
}

export function saveQuotaPolicy(targetType, targetId, quotaBytes, reason = '') {
  const body = { quotaBytes }
  if (reason) {
    body.reason = reason
  }
  return request(`/admin/quota-policies/${encodeURIComponent(targetType)}/${encodeURIComponent(targetId)}`, {
    method: 'PUT',
    body,
  })
}

export function deleteQuotaPolicy(targetType, targetId, reason = '') {
  const query = reason ? `?reason=${encodeURIComponent(reason)}` : ''
  return request(`/admin/quota-policies/${encodeURIComponent(targetType)}/${encodeURIComponent(targetId)}${query}`, {
    method: 'DELETE',
  })
}

export function getStorageExpansionRequests() {
  return request('/admin/storage-expansion/requests')
}

export function getAdminStorageProfileRequests() {
  return request('/admin/storage-profile-requests')
}

export function updateStorageProfileRequestStatus(requestId, status, adminNote = '') {
  const body = { status }
  if (adminNote) {
    body.adminNote = adminNote
  }
  return request(`/admin/storage-profile-requests/${encodeURIComponent(requestId)}/status`, {
    method: 'PATCH',
    body,
  })
}

export function applyStorageProfileRequest(requestId) {
  return request(`/admin/storage-profile-requests/${encodeURIComponent(requestId)}/apply`, {
    method: 'POST',
  })
}

export function getStorageExpansionSummary() {
  return request('/admin/storage-expansion/summary')
}

export function getStorageExpansionRunnerPreflight() {
  return request('/admin/storage-expansion/runner-preflight')
}

export function createStorageExpansionRequest(payload) {
  return request('/admin/storage-expansion/requests', {
    method: 'POST',
    body: payload,
  })
}

export function getStorageExpansionRequestManifest(requestId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/manifest`)
}

export function downloadStorageExpansionManifestArtifact(requestId, artifact) {
  return textRequest(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/manifest/${encodeURIComponent(artifact)}`)
}

export function createStorageExpansionExecutionPlan(requestId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/execution-plan`, {
    method: 'POST',
  })
}

export function createStorageExpansionGitOpsPlan(requestId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/gitops-plan`, {
    method: 'POST',
  })
}

export function downloadStorageExpansionGitOpsArtifactBundle(requestId) {
  return download(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/gitops-artifacts/bundle`)
}

export function recordStorageExpansionDryRunExecution(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/dry-run-execution`, {
    method: 'POST',
    body: payload,
  })
}

export function runStorageExpansionDryRunExecution(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/dry-run-runner`, {
    method: 'POST',
    body: payload,
  })
}

export function runStorageExpansionApplyExecution(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/apply-runner`, {
    method: 'POST',
    body: payload,
  })
}

export function runStorageExpansionRollbackExecution(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/rollback-runner`, {
    method: 'POST',
    body: payload,
  })
}

export function runStorageExpansionGitOpsPrExecution(requestId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/gitops-pr-runner`, {
    method: 'POST',
  })
}

export function recordStorageExpansionGitOpsPrExecution(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/gitops-pr-execution`, {
    method: 'POST',
    body: payload,
  })
}

export function getStorageExpansionExecutions(requestId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/executions`)
}

export function createStorageExpansionExecutionRecord(requestId, payload) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/executions`, {
    method: 'POST',
    body: payload,
  })
}

export function applyStorageExpansionExecutionRecord(requestId, executionId) {
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/executions/${encodeURIComponent(executionId)}/apply`, {
    method: 'POST',
  })
}

export function updateStorageExpansionRequestStatus(requestId, status, appliedEvidence = '') {
  const body = { status }
  if (appliedEvidence) {
    body.appliedEvidence = appliedEvidence
  }
  return request(`/admin/storage-expansion/requests/${encodeURIComponent(requestId)}/status`, {
    method: 'PATCH',
    body,
  })
}

export function getStorageExpansionExecutionLogRetentionStatus() {
  return request('/admin/storage-expansion/execution-log-retention/status')
}

export function runStorageExpansionExecutionLogRetention() {
  return request('/admin/storage-expansion/execution-log-retention/run', {
    method: 'POST',
  })
}

export function getObjectSharePolicy() {
  return request('/admin/object-share-policy')
}

export function saveObjectSharePolicy(payload) {
  return request('/admin/object-share-policy', {
    method: 'PUT',
    body: payload,
  })
}

export function getObjectShareAnalytics(limit = 10, filters = {}) {
  const params = new URLSearchParams()
  params.set('limit', String(limit))
  if (filters.bucketName) {
    params.set('bucketName', filters.bucketName)
  }
  if (filters.status) {
    params.set('status', filters.status)
  }
  return request(`/admin/object-share-analytics?${params.toString()}`)
}

export function getObjectRetentionStatus() {
  return request('/admin/object-retention/status')
}

export function getBackupStatus() {
  return request('/admin/backup/status')
}

export function getBackupRestoreDrillEvidence(filters = {}) {
  const params = new URLSearchParams()
  if (filters.result) {
    params.set('result', filters.result)
  }
  if (filters.limit) {
    params.set('limit', String(filters.limit))
  }
  const query = params.toString()
  return request(`/admin/backup/restore-drill-evidence${query ? `?${query}` : ''}`)
}

export function updateObjectRetentionPolicy(payload) {
  return request('/admin/object-retention/policy', {
    method: 'PUT',
    body: payload,
  })
}

export function runObjectRetentionPurge() {
  return request('/admin/object-retention/purge', {
    method: 'POST',
  })
}

export function getObjectLifecycleRules() {
  return request('/admin/object-lifecycle/rules')
}

export function getObjectLifecycleConflicts() {
  return request('/admin/object-lifecycle/conflicts')
}

export function getObjectLifecycleS3Xml() {
  return request('/admin/object-lifecycle/s3-xml')
}

export function importObjectLifecycleS3Xml(xml) {
  return request('/admin/object-lifecycle/s3-xml', {
    method: 'POST',
    body: { xml },
  })
}

export function saveObjectLifecycleRule(payload) {
  return request('/admin/object-lifecycle/rules', {
    method: 'POST',
    body: payload,
  })
}

export function deleteObjectLifecycleRule(ruleId) {
  return request(`/admin/object-lifecycle/rules/${encodeURIComponent(ruleId)}`, {
    method: 'DELETE',
  })
}

export function dryRunObjectLifecycleRule(ruleId, limit = 50) {
  const query = new URLSearchParams()
  appendQuery(query, 'limit', limit)
  const suffix = query.toString() ? `?${query}` : ''
  return request(`/admin/object-lifecycle/rules/${encodeURIComponent(ruleId)}/dry-run${suffix}`)
}

export function getAuditLogs(filters = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'eventType', filters.eventType)
  appendQuery(query, 'actorId', filters.actorId)
  appendQuery(query, 'requestId', filters.requestId)
  appendQuery(query, 'targetType', filters.targetType)
  appendQuery(query, 'targetId', filters.targetId)
  appendQuery(query, 'result', filters.result)
  appendQuery(query, 'cursor', filters.cursor)
  appendQuery(query, 'from', filters.from)
  appendQuery(query, 'to', filters.to)
  appendQuery(query, 'limit', filters.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/audit-logs${suffix}`)
}

export function downloadAuditLogsCsv(filters = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'eventType', filters.eventType)
  appendQuery(query, 'actorId', filters.actorId)
  appendQuery(query, 'requestId', filters.requestId)
  appendQuery(query, 'targetType', filters.targetType)
  appendQuery(query, 'targetId', filters.targetId)
  appendQuery(query, 'result', filters.result)
  appendQuery(query, 'cursor', filters.cursor)
  appendQuery(query, 'from', filters.from)
  appendQuery(query, 'to', filters.to)
  appendQuery(query, 'limit', filters.limit)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return download(`/admin/audit-logs/export.csv${suffix}`)
}

export function getUsers(filters = {}) {
  const query = new URLSearchParams()
  appendQuery(query, 'keyword', filters.keyword)
  appendQuery(query, 'status', filters.status)
  appendQuery(query, 'limit', filters.limit)
  appendQuery(query, 'cursor', filters.cursor)
  const suffix = query.toString() ? `?${query.toString()}` : ''
  return request(`/admin/users${suffix}`)
}

export function getOrganizations() {
  return request('/admin/organizations')
}

export function getTeams(filters = {}) {
  const params = new URLSearchParams()
  if (filters.organizationId) params.set('organizationId', filters.organizationId)
  const query = params.toString()
  return request(`/admin/teams${query ? `?${query}` : ''}`)
}

export function createTeam(payload) {
  return request('/admin/teams', {
    method: 'POST',
    body: payload,
  })
}

export function updateTeamMembers(teamId, memberIds) {
  return request(`/admin/teams/${encodeURIComponent(teamId)}/members`, {
    method: 'PUT',
    body: { memberIds },
  })
}

export function deleteTeam(teamId) {
  return request(`/admin/teams/${encodeURIComponent(teamId)}`, {
    method: 'DELETE',
  })
}

export function getOrganizationUsage() {
  return request('/admin/organizations/usage')
}

export function createOrganization(payload) {
  return request('/admin/organizations', {
    method: 'POST',
    body: payload,
  })
}

export function deleteOrganization(organizationId) {
  return request(`/admin/organizations/${encodeURIComponent(organizationId)}`, {
    method: 'DELETE',
  })
}

export function createUser(payload) {
  return request('/admin/users', {
    method: 'POST',
    body: payload,
  })
}

export function updateUserStatus(userId, status) {
  return request(`/admin/users/${encodeURIComponent(userId)}/status`, {
    method: 'PATCH',
    body: { status },
  })
}

function encodeObjectKey(key) {
  return key.split('/').map(encodeURIComponent).join('/')
}

function uploadPresignedPart(url, blob, onProgress, signal) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new Error('Upload aborted'))
      return
    }

    const xhr = new XMLHttpRequest()
    const abortUpload = () => xhr.abort()
    const cleanup = () => signal?.removeEventListener('abort', abortUpload)

    xhr.open('PUT', url)
    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable || !onProgress) {
        return
      }
      onProgress({ loaded: event.loaded, total: event.total })
    }
    xhr.onload = () => {
      cleanup()
      if (xhr.status < 200 || xhr.status >= 300) {
        reject(new ApiClientError(`Multipart part upload failed: HTTP ${xhr.status}`, { status: xhr.status }))
        return
      }
      const etag = xhr.getResponseHeader('ETag')
      if (!etag) {
        reject(new ApiClientError('Multipart part upload did not expose ETag.', { code: 'STORAGE_ERROR', status: xhr.status }))
        return
      }
      resolve(etag)
    }
    xhr.onerror = () => {
      cleanup()
      reject(new Error('Network error'))
    }
    xhr.onabort = () => {
      cleanup()
      reject(new Error('Upload aborted'))
    }
    signal?.addEventListener('abort', abortUpload, { once: true })
    xhr.send(blob)
  })
}

async function uploadPresignedPartWithRetry(url, blob, onProgress, signal, options = {}) {
  const maxRetries = normalizeRetryCount(options.maxRetries ?? MULTIPART_UPLOAD_PART_RETRIES)
  const retryBaseDelayMs = normalizeRetryDelay(options.retryBaseDelayMs ?? MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS)
  let attempt = 0

  while (true) {
    try {
      return await uploadPresignedPart(url, blob, onProgress, signal)
    } catch (error) {
      if (signal?.aborted || !isRetryablePartUploadError(error) || attempt >= maxRetries) {
        throw error
      }
      attempt += 1
      options.onRetry?.(attempt, error)
      await waitForRetry(backoffDelayMs(attempt, retryBaseDelayMs), signal)
    }
  }
}

function reportUploadProgress(onProgress, loaded, total) {
  onProgress?.({
    loaded,
    total,
    percent: total > 0 ? Math.round((loaded / total) * 100) : 0,
  })
}

function isRetryablePartUploadError(error) {
  if (error?.message === 'Upload aborted') {
    return false
  }
  if (error instanceof ApiClientError) {
    return error.status === 408 || error.status === 429 || error.status >= 500
  }
  return error?.message === 'Network error'
}

function backoffDelayMs(attempt, baseDelayMs) {
  return baseDelayMs * (2 ** Math.max(0, attempt - 1))
}

function waitForRetry(delayMs, signal) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new Error('Upload aborted'))
      return
    }

    const timeout = window.setTimeout(() => {
      cleanup()
      resolve()
    }, delayMs)
    const abort = () => {
      cleanup()
      reject(new Error('Upload aborted'))
    }
    const cleanup = () => {
      window.clearTimeout(timeout)
      signal?.removeEventListener('abort', abort)
    }
    signal?.addEventListener('abort', abort, { once: true })
  })
}

async function uploadWithConcurrency(items, concurrency, uploadItem) {
  let nextIndex = 0
  const workerCount = Math.min(concurrency, items.length)

  async function worker() {
    while (nextIndex < items.length) {
      const item = items[nextIndex]
      nextIndex += 1
      await uploadItem(item)
    }
  }

  await Promise.all(Array.from({ length: workerCount }, () => worker()))
}

function normalizeRetryCount(value) {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    return 2
  }
  return Math.min(5, Math.max(0, Math.floor(parsed)))
}

function normalizeRetryDelay(value) {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    return 500
  }
  return Math.min(5000, Math.max(100, Math.floor(parsed)))
}

function combineAbortSignals(...signals) {
  const activeSignals = signals.filter(Boolean)
  if (activeSignals.length === 0) {
    return { signal: null, cleanup: () => {} }
  }

  const controller = new AbortController()
  const abort = () => {
    if (!controller.signal.aborted) {
      controller.abort()
    }
  }

  for (const signal of activeSignals) {
    if (signal.aborted) {
      abort()
    } else {
      signal.addEventListener('abort', abort)
    }
  }

  return {
    signal: controller.signal,
    cleanup: () => activeSignals.forEach((signal) => signal.removeEventListener('abort', abort)),
  }
}

function normalizeConcurrency(value) {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    return 4
  }
  return Math.min(8, Math.max(1, Math.floor(parsed)))
}

function appendQuery(query, name, value) {
  if (value === null || value === undefined || value === '') {
    return
  }
  query.set(name, value)
}
