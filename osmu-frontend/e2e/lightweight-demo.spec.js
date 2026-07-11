import { expect, test } from '@playwright/test'
import { readFile } from 'node:fs/promises'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://localhost:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const developerLoginId = process.env.OSMU_DEVELOPER_LOGIN_ID || 'developer'
const developerPassword = process.env.OSMU_DEVELOPER_PASSWORD || 'password'
const developerBucketName = 'developer-e2e-bucket'
const expectOperationsConvergence = process.env.OSMU_EXPECT_OPERATIONS_CONVERGENCE === 'true'
const realMultipartFixtureEnabled = process.env.OSMU_BROWSER_REAL_MULTIPART_FIXTURE === 'true'
const realMultipartBucketName = process.env.OSMU_BROWSER_REAL_MULTIPART_BUCKET || ''
const realMultipartMinioPort = process.env.OSMU_MINIO_API_PORT || '9000'
const realMultipartPartDelayMs = Number(process.env.OSMU_BROWSER_REAL_MULTIPART_PART_DELAY_MS || 1500)
const realMultipartFileBytes = Number(process.env.OSMU_BROWSER_REAL_MULTIPART_FILE_BYTES || 12 * 1024 * 1024)

function parseTagInput(tags = '') {
  return String(tags)
    .split(',')
    .map((pair) => pair.trim())
    .filter(Boolean)
    .reduce((result, pair) => {
      const separatorIndex = pair.indexOf('=')
      if (separatorIndex > 0 && separatorIndex < pair.length - 1) {
        result[pair.slice(0, separatorIndex).trim()] = pair.slice(separatorIndex + 1).trim()
      }
      return result
    }, {})
}

function readRequestJson(request) {
  try {
    return request.postDataJSON() || {}
  } catch {
    return {}
  }
}

function normalizeApiPath(pathname) {
  const stripped = String(pathname || '').replace(/^\/api(?=\/|$)/, '') || '/'
  const collapsed = stripped.replace(/\/{2,}/g, '/')
  return collapsed.length > 1 ? collapsed.replace(/\/$/, '') : collapsed
}

async function expectAdminBucketContextReady(page) {
  await expect(
    page.getByTestId('admin-bucket-empty-state')
      .or(page.getByTestId('bucket-lifecycle-panel'))
      .first(),
  ).toBeVisible()
}

async function clearStoredBrowserSession(page) {
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
    for (const key of Object.keys(window.sessionStorage)) {
      if (key.startsWith('osmu.multipartUpload.')) {
        window.sessionStorage.removeItem(key)
      }
    }
  })
}

async function installRealMinioPartDelay(page) {
  const probe = { putCount: 0 }
  await page.route(`http://localhost:${realMultipartMinioPort}/**`, async (route) => {
    if (route.request().method() === 'PUT') {
      probe.putCount += 1
      if (realMultipartPartDelayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, realMultipartPartDelayMs))
      }
    }
    try {
      await route.continue()
    } catch (error) {
      if (!/abort|closed|Target/i.test(error?.message || '')) {
        throw error
      }
    }
  })
  return probe
}

function buildOperationalAccessKeys(now = Date.now()) {
  const isoAfterDays = (days) => new Date(now + days * 24 * 60 * 60 * 1000).toISOString()
  const isoBeforeDays = (days) => new Date(now - days * 24 * 60 * 60 * 1000).toISOString()
  return [
    {
      id: 11,
      name: 'expired-browser-key',
      accessKey: 'OSMUEXPIRED',
      secretKey: 'developer-e2e-super-secret',
      status: 'ACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoBeforeDays(1),
      lastUsedAt: isoBeforeDays(1),
      usageCount: 3,
    },
    {
      id: 12,
      name: 'expiring-browser-key',
      accessKey: 'OSMUEXPIRING',
      secretKey: 'developer-e2e-super-secret',
      status: 'ACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoAfterDays(2),
      lastUsedAt: isoBeforeDays(1),
      usageCount: 2,
    },
    {
      id: 13,
      name: 'unused-browser-key',
      accessKey: 'OSMUUNUSED',
      secretKey: 'developer-e2e-super-secret',
      status: 'ACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoAfterDays(30),
      lastUsedAt: null,
      usageCount: 0,
    },
    {
      id: 14,
      name: 'stale-browser-key',
      accessKey: 'OSMUSTALE',
      secretKey: 'developer-e2e-super-secret',
      status: 'ACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoAfterDays(30),
      lastUsedAt: isoBeforeDays(45),
      usageCount: 1,
    },
    {
      id: 15,
      name: 'healthy-browser-key',
      accessKey: 'OSMUHEALTHY',
      secretKey: 'developer-e2e-super-secret',
      status: 'ACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoAfterDays(30),
      lastUsedAt: isoBeforeDays(1),
      usageCount: 7,
    },
    {
      id: 16,
      name: 'inactive-browser-key',
      accessKey: 'OSMUINACTIVE',
      secretKey: 'developer-e2e-super-secret',
      status: 'INACTIVE',
      bucketScopes: [{ bucketName: developerBucketName, permissions: ['READ'] }],
      expiresAt: isoAfterDays(30),
      lastUsedAt: null,
      usageCount: 0,
    },
  ]
}

async function installDeveloperApiMocks(page, options = {}) {
  const developerUser = {
    id: 2001,
    loginId: developerLoginId,
    name: 'Developer User',
    role: 'USER',
    ...(options.user || {}),
  }
  const accessKeys = (options.accessKeys || []).map((key) => ({ ...key }))
  const adminActionFailures = (options.adminActionFailures || []).map((failure) => ({
    ...failure,
    remainingResponses: failure.remainingResponses ?? (failure.status === 401 ? 2 : 1),
  }))
  const objectPages = options.objectPages || [{ items: [], prefixes: [], nextCursor: '' }]
  const apiRequests = options.apiRequests
  const objectListRequests = options.objectListRequests
  const objectDownloadRequests = options.objectDownloadRequests
  const objectDownloadAuthFailures = new Set(options.objectDownloadAuthFailures || [])
  const objectDownloadAttempts = new Map()
  const authRefreshRequests = options.authRefreshRequests
  const unauthorizedPaths = options.unauthorizedPaths || []
  const objectMetadataByKey = options.objectMetadataByKey || {}
  const objectUploadRequests = options.objectUploadRequests
  const objectUploadAttempts = new Map()
  const objectUploadDelays = options.objectUploadDelays || []
  const objectUploadKey = options.objectUploadKey || ''
  const presignedUploadRequests = options.presignedUploadRequests
  const presignedUploadCompletes = options.presignedUploadCompletes
  const presignedUploads = new Map()
  const multipartUploadRequests = options.multipartUploadRequests
  const multipartRefreshRequests = options.multipartRefreshRequests
  const multipartPartsRequests = options.multipartPartsRequests
  const multipartCompleteRequests = options.multipartCompleteRequests
  const multipartAbortRequests = options.multipartAbortRequests
  const multipartPartUploadRequests = options.multipartPartUploadRequests
  const multipartPartUploadDelays = [...(options.multipartPartUploadDelays || [])]
  const multipartUploads = new Map()
  const multipartUploadedParts = new Map()
  let presignedUploadCounter = 0
  let multipartUploadCounter = 0
  let adminActionFailureIndex = 0

  await page.route('https://storage.local/**', async (route) => {
    const request = route.request()
    const method = request.method()
    const url = new URL(request.url())
    const corsHeaders = {
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'PUT,OPTIONS',
      'access-control-allow-headers': '*',
      'access-control-expose-headers': 'ETag',
    }
    if (method === 'OPTIONS') {
      return route.fulfill({ status: 204, headers: corsHeaders })
    }
    if (method === 'PUT' && url.pathname.startsWith('/multipart/')) {
      const [, , uploadId, partToken] = url.pathname.split('/')
      const partNumber = Number(partToken?.replace('part-', '') || 0)
      const etag = `"browser-${uploadId}-${partNumber}"`
      if (Array.isArray(multipartPartUploadRequests)) {
        multipartPartUploadRequests.push({ uploadId, partNumber })
      }
      const delayMs = Number(multipartPartUploadDelays.shift() || 0)
      if (delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs))
      }
      multipartUploadedParts.set(uploadId, [
        ...(multipartUploadedParts.get(uploadId) || []).filter((part) => part.partNumber !== partNumber),
        { partNumber, etag },
      ].sort((left, right) => left.partNumber - right.partNumber))
      return route.fulfill({
        status: 200,
        headers: {
          ...corsHeaders,
          ETag: etag,
        },
        body: '',
      })
    }
    return route.fulfill({ status: 404, headers: corsHeaders, body: '' })
  })

  await page.route('**/api/**', async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const path = normalizeApiPath(url.pathname)
    const method = request.method()
    if (Array.isArray(apiRequests)) {
      apiRequests.push({ method, path })
    }
    const json = (body, status = 200) => route.fulfill({
      status,
      contentType: 'application/json',
      body: JSON.stringify(body),
    })

    if (method === 'POST' && path === '/auth/login') {
      return json({
        data: {
          accessToken: 'developer-e2e-access',
          refreshToken: 'developer-e2e-refresh',
          user: developerUser,
        },
      })
    }

    if (method === 'POST' && path === '/auth/refresh') {
      if (Array.isArray(authRefreshRequests)) {
        authRefreshRequests.push(readRequestJson(request))
      }
      if (options.authRefreshFails) {
        return json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'refresh token expired',
          },
        }, 401)
      }
      return json({
        data: {
          accessToken: 'developer-e2e-access-refreshed',
          refreshToken: 'developer-e2e-refresh',
          user: developerUser,
        },
      })
    }

    if (method === 'POST' && path === '/admin/storage-expansion/requests' && adminActionFailureIndex < adminActionFailures.length) {
      const failure = adminActionFailures[adminActionFailureIndex]
      failure.remainingResponses -= 1
      if (failure.remainingResponses <= 0) {
        adminActionFailureIndex += 1
      }
      return json({
        error: {
          code: failure.code,
          message: failure.message || failure.code,
          requestId: failure.requestId,
        },
      }, failure.status)
    }

    if (method === 'GET' && path === '/users/me') {
      return json({ data: developerUser })
    }

    if (unauthorizedPaths.includes(path)) {
      return json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'access token expired',
        },
      }, 401)
    }

    if (method === 'GET' && ['/health', '/storage/health', '/database/health'].includes(path)) {
      return json({ data: { status: 'UP', storage: 'MOCK', database: 'MOCK' } })
    }

    if (method === 'GET' && path === '/developer/s3-client-config') {
      return json({
        data: {
          endpoint: 'http://localhost:8080/api/s3',
          region: 'us-east-1',
          signatureVersion: 'AWS4-HMAC-SHA256',
          virtualHostedStyleEnabled: true,
          virtualHostedStyleDomainSuffixes: ['localhost'],
        },
      })
    }

    if (method === 'GET' && path === '/buckets') {
      return json({
        items: [{
          id: 3001,
          name: developerBucketName,
          ownerType: 'USER',
          ownerId: developerUser.id,
          quotaBytes: 1073741824,
          usedBytes: 0,
          objectCount: 0,
        }],
      })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/objects`) {
      const requestDetails = {
        prefix: url.searchParams.get('prefix') || '',
        delimiter: url.searchParams.get('delimiter') || '',
        search: url.searchParams.get('search') || '',
        tag: url.searchParams.get('tag') || '',
        cursor: url.searchParams.get('cursor') || '',
        limit: url.searchParams.get('limit') || '',
        deleted: url.searchParams.get('deleted') || '',
      }
      if (Array.isArray(objectListRequests)) {
        objectListRequests.push(requestDetails)
      }
      const pageIndex = requestDetails.cursor ? Math.min(1, objectPages.length - 1) : 0
      const page = objectPages[pageIndex] || objectPages[0] || { items: [], prefixes: [], nextCursor: '' }
      return json({
        items: page.items || [],
        prefixes: page.prefixes || [],
        nextCursor: page.nextCursor || '',
      })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects`) {
      const attempt = (objectUploadAttempts.get(path) || 0) + 1
      objectUploadAttempts.set(path, attempt)
      if (Array.isArray(objectUploadRequests)) {
        objectUploadRequests.push({ attempt })
      }
      const delayMs = Number(objectUploadDelays[attempt - 1] || 0)
      if (delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs))
      }
      const uploadedKey = objectUploadKey || `browser-upload-${attempt}.txt`
      const firstPage = objectPages[0]
      if (firstPage && !firstPage.items?.some((item) => item.key === uploadedKey)) {
        firstPage.items = [
          ...(firstPage.items || []),
          {
            key: uploadedKey,
            sizeBytes: 13,
            contentType: 'text/plain',
            tags: { project: 'osmu' },
          },
        ]
      }
      try {
        return await json({ data: { key: uploadedKey } })
      } catch {
        return undefined
      }
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/multipart-upload`) {
      const body = readRequestJson(request)
      multipartUploadCounter += 1
      const uploadId = `browser-multipart-${multipartUploadCounter}`
      const partSizeBytes = Number(body.partSizeBytes || 32)
      const sizeBytes = Number(body.sizeBytes || 0)
      const partCount = Math.max(1, Math.ceil(sizeBytes / partSizeBytes))
      const parts = Array.from({ length: partCount }, (_, index) => {
        const partNumber = index + 1
        const startByte = index * partSizeBytes
        const endByte = Math.min(sizeBytes - 1, startByte + partSizeBytes - 1)
        return {
          partNumber,
          url: `https://storage.local/multipart/${uploadId}/part-${partNumber}`,
          startByte,
          endByte,
        }
      })
      const upload = {
        uploadId,
        key: body.key || `multipart-${multipartUploadCounter}.bin`,
        tags: body.tags || '',
        contentType: body.contentType || 'application/octet-stream',
        partSizeBytes,
        partCount,
        parts,
        expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      }
      multipartUploads.set(uploadId, upload)
      multipartUploadedParts.set(uploadId, [])
      if (Array.isArray(multipartUploadRequests)) {
        multipartUploadRequests.push({ ...body, uploadId })
      }
      return json({ data: upload })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/multipart-upload/refresh`) {
      const body = readRequestJson(request)
      const upload = multipartUploads.get(body.uploadId)
      if (Array.isArray(multipartRefreshRequests)) {
        multipartRefreshRequests.push({ ...body })
      }
      return json({ data: upload })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/multipart-upload/parts`) {
      const body = readRequestJson(request)
      if (Array.isArray(multipartPartsRequests)) {
        multipartPartsRequests.push({ ...body })
      }
      return json({ data: { parts: multipartUploadedParts.get(body.uploadId) || [] } })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/multipart-upload/complete`) {
      const body = readRequestJson(request)
      const upload = multipartUploads.get(body.uploadId) || {
        key: body.key,
        tags: '',
        contentType: 'application/octet-stream',
      }
      if (Array.isArray(multipartCompleteRequests)) {
        multipartCompleteRequests.push({ ...body })
      }
      const firstPage = objectPages[0]
      if (firstPage && !firstPage.items?.some((item) => item.key === upload.key)) {
        firstPage.items = [
          ...(firstPage.items || []),
          {
            key: upload.key,
            sizeBytes: Number(upload.partSizeBytes || 0) * Number(upload.partCount || 1),
            contentType: upload.contentType,
            tags: parseTagInput(upload.tags),
          },
        ]
      }
      return json({
        data: {
          key: upload.key,
          contentType: upload.contentType,
          tags: parseTagInput(upload.tags),
        },
      })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/multipart-upload/abort`) {
      const body = readRequestJson(request)
      if (Array.isArray(multipartAbortRequests)) {
        multipartAbortRequests.push({ ...body })
      }
      return json({ data: { success: true } })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/presigned-upload`) {
      const body = readRequestJson(request)
      presignedUploadCounter += 1
      const uploadId = `browser-presigned-${presignedUploadCounter}`
      const upload = {
        uploadId,
        key: body.key || `presigned-${presignedUploadCounter}.txt`,
        tags: body.tags || '',
        contentType: body.contentType || 'application/octet-stream',
      }
      presignedUploads.set(uploadId, upload)
      if (Array.isArray(presignedUploadRequests)) {
        presignedUploadRequests.push({ ...body, uploadId })
      }
      return json({
        data: {
          uploadId,
          key: upload.key,
          url: `https://storage.local/presigned/${uploadId}`,
          expiresAt: '2026-06-21T00:15:00Z',
        },
      })
    }

    if (method === 'POST' && path === `/buckets/${developerBucketName}/objects/presigned-upload/complete`) {
      const body = readRequestJson(request)
      const upload = presignedUploads.get(body.uploadId) || {
        uploadId: body.uploadId,
        key: body.key,
        tags: '',
        contentType: 'application/octet-stream',
      }
      const completedKey = upload.key || body.key || 'presigned-complete.txt'
      if (Array.isArray(presignedUploadCompletes)) {
        presignedUploadCompletes.push({ ...body })
      }
      const firstPage = objectPages[0]
      if (firstPage && !firstPage.items?.some((item) => item.key === completedKey)) {
        firstPage.items = [
          ...(firstPage.items || []),
          {
            key: completedKey,
            sizeBytes: 17,
            contentType: upload.contentType,
            tags: parseTagInput(upload.tags),
          },
        ]
      }
      return json({
        data: {
          key: completedKey,
          sizeBytes: 17,
          contentType: upload.contentType,
          tags: parseTagInput(upload.tags),
        },
      })
    }

    const objectMetadataPathPrefix = `/buckets/${developerBucketName}/objects/metadata/`
    if (method === 'GET' && path.startsWith(objectMetadataPathPrefix)) {
      const key = decodeURIComponent(path.slice(objectMetadataPathPrefix.length))
      return json({
        data: objectMetadataByKey[key] || {
          key,
          sizeBytes: 0,
          storageSizeBytes: 0,
          contentType: 'application/octet-stream',
          storageContentType: 'application/octet-stream',
          etag: 'mock-etag',
          storageEtag: 'mock-etag',
          checksums: {},
          storageChecksums: {},
          lastModifiedAt: '2026-06-21T00:00:00Z',
          storageLastModifiedAt: '2026-06-21T00:00:00Z',
          tags: {},
          storageTags: {},
          syncStatus: 'SYNCED',
        },
      })
    }

    const objectDownloadPathPrefix = `/buckets/${developerBucketName}/objects/`
    if (method === 'GET' && path.startsWith(objectDownloadPathPrefix)) {
      const key = decodeURIComponent(path.slice(objectDownloadPathPrefix.length))
      const authorization = request.headers().authorization || ''
      const attempt = (objectDownloadAttempts.get(key) || 0) + 1
      objectDownloadAttempts.set(key, attempt)
      if (Array.isArray(objectDownloadRequests)) {
        objectDownloadRequests.push({ key, authorization, attempt })
      }
      if (objectDownloadAuthFailures.has(key) && attempt === 1) {
        return json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'download token expired',
          },
        }, 401)
      }
      return route.fulfill({
        status: 200,
        contentType: 'text/plain',
        body: `download:${key}`,
      })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/permissions`) {
      return json({ items: [] })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/lifecycle`) {
      return json({ data: { xml: '', ruleCount: 0 } })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/tags`) {
      return json({ data: { tags: {}, tagCount: 0 } })
    }

    if (method === 'GET' && path === '/access-keys') {
      return json({ items: accessKeys.map(({ secretKey: _secretKey, ...key }) => key) })
    }

    if (method === 'POST' && path === '/access-keys') {
      const body = await request.postDataJSON()
      const created = {
        id: accessKeys.length + 1,
        name: body.name,
        accessKey: `OSMUDEVE2E${accessKeys.length + 1}`,
        secretKey: 'developer-e2e-secret',
        status: 'ACTIVE',
        bucketScopes: body.bucketScopes || [],
        expiresAt: body.expiresAt || null,
        lastUsedAt: null,
      }
      accessKeys.push(created)
      return json({ data: created })
    }

    if (method === 'POST' && path === '/access-keys/bulk-disable') {
      const body = await request.postDataJSON()
      const keyIds = Array.isArray(body.keyIds) ? body.keyIds.map((id) => Number(id)) : []
      const disabledKeyIds = []
      const skippedKeyIds = []
      for (const keyId of keyIds) {
        const key = accessKeys.find((item) => item.id === keyId)
        if (key?.status === 'ACTIVE') {
          key.status = 'INACTIVE'
          disabledKeyIds.push(keyId)
        } else {
          skippedKeyIds.push(keyId)
        }
      }
      return json({
        data: {
          requestedCount: keyIds.length,
          disabledCount: disabledKeyIds.length,
          skippedCount: skippedKeyIds.length,
          disabledKeyIds,
          skippedKeyIds,
        },
      })
    }

    const accessKeyDeleteMatch = path.match(/^\/access-keys\/(\d+)$/)
    if (method === 'DELETE' && accessKeyDeleteMatch) {
      const keyId = Number(accessKeyDeleteMatch[1])
      const key = accessKeys.find((item) => item.id === keyId)
      if (key) {
        key.status = 'INACTIVE'
      }
      return json({
        data: key
          ? {
            ...key,
            secretKey: undefined,
          }
          : null,
      })
    }

    if (method === 'GET' && path === '/dashboard/layout/widgets') {
      return json({ data: [] })
    }

    if (method === 'GET' && path === '/dashboard/layout') {
      return json({ data: { source: 'DEFAULT', widgets: [], sections: [] } })
    }

    if (method === 'GET' && path === '/dashboard/layout/presets') {
      return json({ data: [] })
    }

    return json({ data: null, items: [] })
  })
}

test('stale saved session returns to login redirect', async ({ page }) => {
  await page.addInitScript(() => {
    window.localStorage.setItem('osmu.auth.tokens', JSON.stringify({
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
    }))
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.route('**/api/**', async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith('/users/me')) {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'session expired',
          },
        }),
      })
      return
    }

    if (url.pathname.endsWith('/auth/refresh') || url.pathname.endsWith('/dashboard/layout/widgets')) {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'session expired',
          },
        }),
      })
      return
    }

    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        data: [],
        items: [],
      }),
    })
  })

  await page.goto(`${frontendBaseUrl}/dashboard`)

  await expect(page).toHaveURL(/\/login\?/)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page).toHaveURL(/redirect=(%2F|\/)dashboard/)
})

test('stored developer session opens developer console without login', async ({ page }) => {
  const apiRequests = []
  await installDeveloperApiMocks(page, { apiRequests })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.setItem('osmu.auth.tokens', JSON.stringify({
      accessToken: 'developer-stored-access',
      refreshToken: 'developer-stored-refresh',
    }))
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/developer`)

  await expect(page.getByTestId('login-form')).toHaveCount(0)
  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('developer-page')).toBeVisible()
  await expect(page.getByTestId('developer-s3-endpoint')).toContainText('/api/s3')
  await expect(page.getByTestId('developer-client-aws-cli')).toContainText(`s3://${developerBucketName}`)

  expect(apiRequests).toEqual(expect.arrayContaining([
    { method: 'GET', path: '/buckets' },
    { method: 'GET', path: '/access-keys' },
    { method: 'GET', path: '/developer/s3-client-config' },
  ]))
  const unrelatedRequests = apiRequests.filter(({ method, path }) => method === 'GET' && (
    path.startsWith('/admin/')
    || path.startsWith('/dashboard/layout')
    || ['/users', '/organizations', '/organization-usage', '/teams'].includes(path)
    || path.startsWith('/buckets/' + developerBucketName + '/')
  ))
  expect(unrelatedRequests).toEqual([])
})

test('developer login lands on S3 API console with access key controls', async ({ page }) => {
  await installDeveloperApiMocks(page)
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)

  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('login-mode-developer')).toBeChecked()
  await expect(page.getByTestId('login-submit-button')).toContainText('개발자 콘솔로 로그인')
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('developer-page')).toBeVisible()
  await expect(page.getByRole('link', { name: 'Admin' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Developer' })).toBeVisible()
  await expect(page.getByTestId('developer-s3-endpoint-panel')).toContainText('API 접속 정보')
  await expect(page.getByTestId('developer-s3-endpoint')).toContainText('/api/s3')
  await expect(page.getByTestId('developer-s3-signature')).toContainText('AWS4-HMAC-SHA256')
  await expect(page.getByTestId('developer-client-snippets-panel')).toContainText('S3 클라이언트 예시')
  await expect(page.getByTestId('developer-client-aws-cli')).toContainText(`s3://${developerBucketName}`)

  await page.getByTestId('access-key-name-input').fill('developer-browser-key')
  await page.getByTestId('access-key-bucket-select').selectOption(developerBucketName)
  await page.getByTestId('access-key-scope-add-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-scope-remove-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toHaveCount(0)
  await expect(page.getByTestId('access-key-create-button')).toBeDisabled()
  await page.getByTestId('access-key-scope-add-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-create-button').click()
  await expect(page.getByTestId('access-key-secret-box')).toContainText('developer-e2e-secret')
  await expect(page.getByTestId('status-alert')).toContainText('developer-browser-key Access Key 발급 완료')
  await expect(page.getByTestId('access-key-list')).toContainText('developer-browser-key')
  await expect(page.getByTestId('access-key-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-delete-button').first().click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Access Key')
  await page.getByTestId('confirm-cancel-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(page.getByTestId('access-key-list')).toContainText('ACTIVE')
  await page.getByTestId('access-key-delete-button').first().click()
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('비활성화 완료')
  await expect(page.getByTestId('access-key-list')).toContainText('INACTIVE')
})

test('developer object page size selection resets cursor and keeps limit on next page', async ({ page }) => {
  const objectListRequests = []
  await installDeveloperApiMocks(page, {
    objectListRequests,
    objectPages: [
      {
        items: [{
          key: 'page-size-first.txt',
          sizeBytes: 128,
          contentType: 'text/plain',
          tags: { project: 'osmu' },
        }],
        prefixes: ['page-size/'],
        nextCursor: 'page-size-cursor-2',
      },
      {
        items: [{
          key: 'page-size-second.txt',
          sizeBytes: 256,
          contentType: 'text/plain',
          tags: { project: 'osmu', stage: 'next' },
        }],
        prefixes: [],
        nextCursor: '',
      },
    ],
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page).toHaveURL(/\/objects$/)
  await expect(page.getByTestId('object-table')).toContainText('page-size-first.txt')

  objectListRequests.length = 0
  const firstPageLimitResponse = page.waitForResponse((response) => {
    const url = new URL(response.url())
    return url.pathname.endsWith(`/api/buckets/${developerBucketName}/objects`)
      && url.searchParams.get('limit') === '50'
      && !url.searchParams.has('cursor')
  })
  await page.getByTestId('object-list-limit-select').selectOption('50')
  await firstPageLimitResponse
  await expect(page.getByTestId('object-list-limit-select')).toHaveValue('50')
  await expect(page.getByTestId('object-table')).toContainText('page-size-first.txt')
  expect(objectListRequests[objectListRequests.length - 1]).toMatchObject({
    limit: '50',
    cursor: '',
  })

  const objectNextButton = page.getByTestId('object-next-button')
  await expect(objectNextButton).toBeEnabled()
  const nextPageLimitResponse = page.waitForResponse((response) => {
    const url = new URL(response.url())
    return url.pathname.endsWith(`/api/buckets/${developerBucketName}/objects`)
      && url.searchParams.get('limit') === '50'
      && url.searchParams.get('cursor') === 'page-size-cursor-2'
  })
  await objectNextButton.click()
  await nextPageLimitResponse
  await expect(page.getByTestId('object-table')).toContainText('page-size-second.txt')
  expect(objectListRequests[objectListRequests.length - 1]).toMatchObject({
    limit: '50',
    cursor: 'page-size-cursor-2',
  })
})

test('developer object download refreshes expired access token and retries once', async ({ page }) => {
  const authRefreshRequests = []
  const objectDownloadRequests = []
  const downloadKey = 'auth-refresh-download.txt'
  await installDeveloperApiMocks(page, {
    authRefreshRequests,
    objectDownloadRequests,
    objectDownloadAuthFailures: [downloadKey],
    objectPages: [{
      items: [{
        key: downloadKey,
        sizeBytes: 64,
        contentType: 'text/plain',
        tags: { project: 'osmu' },
      }],
      prefixes: [],
      nextCursor: '',
    }],
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-table')).toContainText(downloadKey)

  const retriedDownloadResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects/${downloadKey}`)
  ))
  await page.getByTestId('object-download-button').first().click()
  await retriedDownloadResponse

  await expect(page.getByTestId('status-alert')).toContainText(downloadKey)
  expect(authRefreshRequests).toHaveLength(1)
  expect(authRefreshRequests[0]).toMatchObject({ refreshToken: 'developer-e2e-refresh' })
  expect(objectDownloadRequests).toHaveLength(2)
  expect(objectDownloadRequests[0]).toMatchObject({
    key: downloadKey,
    authorization: 'Bearer developer-e2e-access',
    attempt: 1,
  })
  expect(objectDownloadRequests[1]).toMatchObject({
    key: downloadKey,
    authorization: 'Bearer developer-e2e-access-refreshed',
    attempt: 2,
  })
})

test('developer can cancel and retry single object upload', async ({ page }) => {
  const objectUploadRequests = []
  const retryKey = 'browser-retry.txt'
  await installDeveloperApiMocks(page, {
    objectUploadRequests,
    objectUploadDelays: [2000, 0],
    objectUploadKey: retryKey,
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await page.getByTestId('object-key-input').fill(retryKey)
  await page.getByTestId('object-tags-input').fill('project=osmu')
  await page.getByTestId('object-file-input').setInputFiles({
    name: retryKey,
    mimeType: 'text/plain',
    buffer: Buffer.from('retry payload'),
  })

  const firstUploadRequest = page.waitForRequest((request) => (
    request.method() === 'POST'
      && new URL(request.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects`)
  ))
  await page.getByTestId('object-upload-button').click()
  await firstUploadRequest
  await expect(page.getByTestId('object-upload-cancel-button')).toBeEnabled()
  await page.getByTestId('object-upload-cancel-button').click()

  await expect(page.getByTestId('object-upload-progress')).toBeVisible()
  await expect(page.getByTestId('object-upload-retry-button')).toBeEnabled()

  const retryUploadResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects`)
  ))
  await page.getByTestId('object-upload-retry-button').click()
  await retryUploadResponse

  await expect(page.getByTestId('status-alert')).toContainText(retryKey)
  await expect(page.getByTestId('object-table')).toContainText(retryKey)
  expect(objectUploadRequests).toHaveLength(2)
})

test('developer can pause and resume multipart object upload from pending session', async ({ page }) => {
  test.skip(process.env.OSMU_BROWSER_MULTIPART_FIXTURE !== 'true', 'Requires small multipart Vite fixture env.')

  const multipartUploadRequests = []
  const multipartRefreshRequests = []
  const multipartPartsRequests = []
  const multipartCompleteRequests = []
  const multipartAbortRequests = []
  const multipartPartUploadRequests = []
  const multipartKey = 'browser-multipart-pause.bin'
  await installDeveloperApiMocks(page, {
    multipartUploadRequests,
    multipartRefreshRequests,
    multipartPartsRequests,
    multipartCompleteRequests,
    multipartAbortRequests,
    multipartPartUploadRequests,
    multipartPartUploadDelays: [2000, 2000, 2000, 0, 0, 0],
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await page.getByTestId('object-key-input').fill(multipartKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=multipart')
  await page.getByTestId('object-file-input').setInputFiles({
    name: multipartKey,
    mimeType: 'application/octet-stream',
    buffer: Buffer.alloc(96, 7),
  })

  const createResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects/multipart-upload`)
  ))
  await page.getByTestId('object-upload-button').click()
  await createResponse
  await expect(page.getByTestId('object-upload-pause-button')).toBeEnabled()
  await page.getByTestId('object-upload-pause-button').click()

  await expect(page.getByTestId('status-alert')).toContainText('Multipart upload paused')
  await expect(page.getByTestId('object-upload-progress')).toContainText('Multipart upload paused')
  await expect(page.getByTestId('object-multipart-resume-panel')).toBeVisible()
  const pausedRow = page.getByTestId('object-multipart-resume-row').filter({ hasText: multipartKey })
  await expect(pausedRow).toBeVisible()
  await expect(pausedRow.getByTestId('object-multipart-resume-button')).toBeEnabled()
  await expect.poll(() => page.evaluate(() => (
    Object.keys(window.sessionStorage).filter((key) => key.startsWith('osmu.multipartUpload.')).length
  ))).toBe(1)
  expect(multipartAbortRequests).toHaveLength(0)

  const completeResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects/multipart-upload/complete`)
  ))
  await pausedRow.getByTestId('object-multipart-resume-button').click()
  await completeResponse

  await expect(page.getByTestId('status-alert')).toContainText(multipartKey)
  await expect(page.getByTestId('object-table')).toContainText(multipartKey)
  await expect.poll(() => page.evaluate(() => (
    Object.keys(window.sessionStorage).filter((key) => key.startsWith('osmu.multipartUpload.')).length
  ))).toBe(0)
  expect(multipartUploadRequests).toHaveLength(1)
  expect(multipartRefreshRequests).toHaveLength(1)
  expect(multipartPartsRequests).toHaveLength(1)
  expect(multipartCompleteRequests).toHaveLength(1)
  expect(multipartAbortRequests).toHaveLength(0)
  expect(multipartPartUploadRequests.length).toBeGreaterThan(0)
})

test('developer can pause and resume real MinIO multipart object upload from pending session', async ({ page }) => {
  test.skip(!realMultipartFixtureEnabled, 'Requires Docker local demo real multipart fixture env.')
  test.skip(!realMultipartBucketName, 'Requires OSMU_BROWSER_REAL_MULTIPART_BUCKET.')
  test.setTimeout(120_000)

  const partProbe = await installRealMinioPartDelay(page)
  const multipartKey = `browser-real-multipart-${Date.now()}.bin`
  await clearStoredBrowserSession(page)

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Storage' }).click()
  const bucketRow = page.getByTestId(`bucket-row-${realMultipartBucketName}`)
  await expect(bucketRow).toBeVisible()
  await bucketRow.click()
  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-panel')).toContainText(realMultipartBucketName)

  await page.getByTestId('object-key-input').fill(multipartKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=real-multipart')
  await page.getByTestId('object-file-input').setInputFiles({
    name: multipartKey,
    mimeType: 'application/octet-stream',
    buffer: Buffer.alloc(realMultipartFileBytes, 7),
  })

  const createResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${realMultipartBucketName}/objects/multipart-upload`)
  ))
  await page.getByTestId('object-upload-button').click()
  await createResponse
  await expect(page.getByTestId('object-upload-pause-button')).toBeEnabled()
  await page.getByTestId('object-upload-pause-button').click()

  await expect(page.getByTestId('status-alert')).toContainText('Multipart upload paused')
  await expect(page.getByTestId('object-upload-progress')).toContainText('Multipart upload paused')
  const pausedRow = page.getByTestId('object-multipart-resume-row').filter({ hasText: multipartKey })
  await expect(pausedRow).toBeVisible()
  await expect(pausedRow.getByTestId('object-multipart-resume-button')).toBeEnabled()
  await expect.poll(() => page.evaluate(() => (
    Object.keys(window.sessionStorage).filter((key) => key.startsWith('osmu.multipartUpload.')).length
  ))).toBe(1)

  const refreshResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${realMultipartBucketName}/objects/multipart-upload/refresh`)
  ))
  const partsResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${realMultipartBucketName}/objects/multipart-upload/parts`)
  ))
  const completeResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${realMultipartBucketName}/objects/multipart-upload/complete`)
  ))
  await pausedRow.getByTestId('object-multipart-resume-button').click()
  await refreshResponse
  await partsResponse
  await completeResponse

  await expect(page.getByTestId('status-alert')).toContainText(multipartKey)
  await expect(page.getByTestId('object-table')).toContainText(multipartKey)
  await expect.poll(() => page.evaluate(() => (
    Object.keys(window.sessionStorage).filter((key) => key.startsWith('osmu.multipartUpload.')).length
  ))).toBe(0)
  expect(partProbe.putCount).toBeGreaterThan(0)
})

test('developer can create and complete presigned object upload handoff', async ({ page }) => {
  const presignedUploadRequests = []
  const presignedUploadCompletes = []
  const presignedKey = 'browser-presigned.txt'
  await installDeveloperApiMocks(page, {
    presignedUploadRequests,
    presignedUploadCompletes,
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await page.getByTestId('object-key-input').fill(presignedKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=presigned')
  await expect(page.getByTestId('object-presigned-upload-complete-button')).toBeDisabled()

  const createResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects/presigned-upload`)
  ))
  await page.getByTestId('object-presigned-upload-url-button').click()
  await createResponse

  await expect(page.getByTestId('status-alert')).toContainText('Presigned upload URL')
  await expect(page.getByTestId('object-presigned-url')).toContainText('browser-presigned-1')
  await expect(page.getByTestId('object-presigned-upload-complete-button')).toBeEnabled()

  const completeResponse = page.waitForResponse((response) => (
    response.status() === 200
      && new URL(response.url()).pathname.endsWith(`/api/buckets/${developerBucketName}/objects/presigned-upload/complete`)
  ))
  await page.getByTestId('object-presigned-upload-complete-button').click()
  await completeResponse

  await expect(page.getByTestId('status-alert')).toContainText('Presigned upload 완료')
  await expect(page.getByTestId('object-presigned-url')).toHaveCount(0)
  await expect(page.getByTestId('object-table')).toContainText(presignedKey)
  await expect(page.getByTestId('object-table')).toContainText('stage=presigned')
  expect(presignedUploadRequests).toHaveLength(1)
  expect(presignedUploadRequests[0]).toMatchObject({
    key: presignedKey,
    tags: 'project=osmu,stage=presigned',
    contentType: 'application/octet-stream',
    uploadId: 'browser-presigned-1',
  })
  expect(presignedUploadCompletes).toEqual([{
    uploadId: 'browser-presigned-1',
    key: presignedKey,
  }])
})

test('developer object metadata detail shows drift fields from fixture', async ({ page }) => {
  const driftKey = 'metadata-drift.txt'
  await installDeveloperApiMocks(page, {
    objectPages: [{
      items: [{
        key: driftKey,
        sizeBytes: 64,
        contentType: 'text/plain',
        tags: { project: 'osmu' },
      }],
      prefixes: [],
      nextCursor: '',
    }],
    objectMetadataByKey: {
      [driftKey]: {
        key: driftKey,
        sizeBytes: 64,
        storageSizeBytes: 128,
        contentType: 'text/plain',
        storageContentType: 'application/octet-stream',
        etag: 'index-etag',
        storageEtag: 'storage-etag',
        checksums: { SHA256: 'index-sha256' },
        storageChecksums: { SHA256: 'storage-sha256' },
        lastModifiedAt: '2026-06-20T00:00:00Z',
        storageLastModifiedAt: '2026-06-21T00:00:00Z',
        tags: { project: 'osmu' },
        storageTags: { project: 'archive' },
        syncStatus: 'STALE',
      },
    },
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-table')).toContainText(driftKey)
  await page.getByTestId('object-detail-button').first().click()

  const detailPanel = page.getByTestId('object-detail-panel')
  await expect(detailPanel).toContainText(driftKey)
  await expect(page.getByTestId('object-metadata-sync-status')).toHaveClass(/mock/)
  await expect(detailPanel).toContainText('Index size')
  await expect(detailPanel).toContainText('64')
  await expect(detailPanel).toContainText('Storage size')
  await expect(detailPanel).toContainText('128')
  await expect(detailPanel).toContainText('index-etag')
  await expect(detailPanel).toContainText('storage-etag')
  await expect(detailPanel).toContainText('project=archive')
  await expect(detailPanel.getByTestId('object-metadata-row-state').filter({ hasText: 'Drift' })).toHaveCount(12)
})

test('developer can inspect and delete pending multipart resume sessions', async ({ page }) => {
  await installDeveloperApiMocks(page)
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await page.getByRole('link', { name: 'Objects' }).click()
  await page.getByTestId('object-key-input').fill('resume.bin')
  await page.getByTestId('object-tags-input').fill('project=osmu')
  await page.getByTestId('object-file-input').setInputFiles({
    name: 'resume.bin',
    mimeType: 'application/octet-stream',
    buffer: Buffer.from('resume-fixture'),
  })

  const resumePartSizeBytes = process.env.OSMU_BROWSER_MULTIPART_FIXTURE === 'true' ? 32 : 64 * 1024 * 1024
  const seededKeys = await page.evaluate(({ bucketName, partSizeBytes }) => {
    const input = document.querySelector('[data-testid="object-file-input"]')
    const file = input.files[0]
    const hashString = (value) => {
      let hash = 0
      for (let index = 0; index < value.length; index += 1) {
        hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0
      }
      return Math.abs(hash).toString(36)
    }
    const storageKeyFor = ({ key, tags, fileName, fileSize, fileLastModified, contentType }) => {
      const identity = JSON.stringify({
        bucketName,
        key,
        tags,
        fileName,
        fileSize,
        fileLastModified,
        contentType,
        partSizeBytes,
      })
      return `osmu.multipartUpload.${hashString(identity)}`
    }
    const now = Date.now()
    const matchingStorageKey = storageKeyFor({
      key: 'resume.bin',
      tags: 'project=osmu',
      fileName: file.name,
      fileSize: file.size,
      fileLastModified: file.lastModified,
      contentType: file.type || 'application/octet-stream',
    })
    const expiredStorageKey = 'osmu.multipartUpload.expired-browser-e2e'
    window.sessionStorage.setItem(matchingStorageKey, JSON.stringify({
      uploadId: 'browser-resume-upload',
      bucketName,
      key: 'resume.bin',
      tags: 'project=osmu',
      fileName: file.name,
      fileSize: file.size,
      fileLastModified: file.lastModified,
      contentType: file.type || 'application/octet-stream',
      partSizeBytes,
      completedParts: [{ partNumber: 1, etag: 'etag-1', sizeBytes: file.size }],
      partCount: 3,
      expiresAt: new Date(now + 60 * 60 * 1000).toISOString(),
      updatedAt: new Date(now).toISOString(),
    }))
    window.sessionStorage.setItem(expiredStorageKey, JSON.stringify({
      uploadId: 'browser-expired-upload',
      bucketName,
      key: 'expired.bin',
      tags: '',
      fileName: 'expired.bin',
      fileSize: 4096,
      fileLastModified: 0,
      contentType: 'application/octet-stream',
      partSizeBytes,
      completedParts: [],
      partCount: 2,
      expiresAt: new Date(now - 60 * 60 * 1000).toISOString(),
      updatedAt: new Date(now - 30 * 60 * 1000).toISOString(),
    }))
    return { matchingStorageKey, expiredStorageKey }
  }, { bucketName: developerBucketName, partSizeBytes: resumePartSizeBytes })

  await page.getByTestId('refresh-button').click()
  await expect(page.getByTestId('object-multipart-resume-panel')).toBeVisible()
  await expect(page.getByTestId('object-multipart-resume-row')).toHaveCount(2)

  const matchingRow = page.getByTestId('object-multipart-resume-row').filter({ hasText: 'resume.bin' })
  await expect(matchingRow).toContainText('1 of 3 parts')
  await expect(matchingRow.getByTestId('object-multipart-resume-button')).toBeEnabled()

  const expiredRow = page.getByTestId('object-multipart-resume-row').filter({ hasText: 'expired.bin' })
  await expect(expiredRow).toContainText('Expired')
  await expect(expiredRow.getByTestId('object-multipart-resume-button')).toBeDisabled()
  await expiredRow.getByTestId('object-multipart-resume-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Multipart resume')
  await page.getByTestId('confirm-submit-button').click()

  await expect(page.getByTestId('status-alert')).toContainText('Multipart resume')
  await expect(page.getByTestId('object-multipart-resume-row').filter({ hasText: 'expired.bin' })).toHaveCount(0)
  await expect(page.getByTestId('object-multipart-resume-row').filter({ hasText: 'resume.bin' })).toHaveCount(1)
  await expect.poll(() => page.evaluate((keys) => ({
    matchingPresent: Boolean(window.sessionStorage.getItem(keys.matchingStorageKey)),
    expiredPresent: Boolean(window.sessionStorage.getItem(keys.expiredStorageKey)),
  }), seededKeys)).toEqual({
    matchingPresent: true,
    expiredPresent: false,
  })
})

test('developer refresh failure clears session and redirects from portal click', async ({ page }) => {
  const authRefreshRequests = []
  const unauthorizedPaths = []
  await installDeveloperApiMocks(page, {
    authRefreshFails: true,
    authRefreshRequests,
    unauthorizedPaths,
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('logout-button')).toBeVisible()
  await expect(page.getByTestId('developer-s3-endpoint')).toContainText('/api/s3')
  unauthorizedPaths.push('/buckets')
  await page.getByTestId('refresh-button').click()

  await expect(page).toHaveURL(/\/login\?/)
  await expect(page).toHaveURL(/reason=session-expired/)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('logout-button')).toHaveCount(0)
  expect(authRefreshRequests).toHaveLength(1)
  await expect.poll(() => page.evaluate(() => ({
    local: window.localStorage.getItem('osmu.auth.tokens'),
    session: window.sessionStorage.getItem('osmu.auth.tokens'),
  }))).toEqual({ local: null, session: null })
})

test('developer logout clears stored tokens and returns to login', async ({ page }) => {
  await installDeveloperApiMocks(page)
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('developer-page')).toBeVisible()
  await expect.poll(() => page.evaluate(() => window.sessionStorage.getItem('osmu.auth.tokens'))).toContain('developer-e2e-access')

  await page.getByTestId('logout-button').click()

  await expect(page).toHaveURL(/\/login$/)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('logout-button')).toHaveCount(0)
  await expect.poll(() => page.evaluate(() => ({
    local: window.localStorage.getItem('osmu.auth.tokens'),
    session: window.sessionStorage.getItem('osmu.auth.tokens'),
  }))).toEqual({ local: null, session: null })
})

test('org admin can open scoped admin page without global operation panels', async ({ page }) => {
  await installDeveloperApiMocks(page, {
    user: {
      id: 2102,
      loginId: 'org-admin-browser',
      name: 'Org Admin Browser',
      role: 'ORG_ADMIN',
      organizationId: 3001,
    },
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill('org-admin-browser')
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/admin$/)
  await expect(page.locator('#admin-access-keys')).toBeVisible()
  await expect(page.getByTestId('admin-role-empty-state')).toBeVisible()
  await expect(page.getByTestId('admin-role-restricted-panel-list')).toContainText('Share policy / analytics')
  await expect(page.getByTestId('admin-role-restricted-panel-list')).toContainText('Quota, lifecycle, retention')
  await expect(page.getByTestId('admin-role-restricted-panel-list')).toContainText('Storage expansion and runner controls')
  await expect(page.getByRole('link', { name: 'Admin' })).toBeVisible()
  await expect(page.getByTestId('admin-approval-workflow-panel')).toHaveCount(0)
  await expect(page.getByTestId('admin-security-audit-policy-panel')).toHaveCount(0)
  await expect(page.getByTestId('object-share-policy-panel')).toHaveCount(0)
  await expect(page.getByTestId('object-share-analytics-panel')).toHaveCount(0)
  await expect(page.getByTestId('quota-policy-panel')).toHaveCount(0)
  await expect(page.locator('.lifecycle-rules')).toHaveCount(0)
  await expect(page.getByTestId('storage-expansion-panel')).toHaveCount(0)
  await expect(page.getByTestId('admin-storage-profile-panel')).toHaveCount(0)
})

test('user is redirected away from admin page', async ({ page }) => {
  await installDeveloperApiMocks(page)

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(/\/developer$/)
  await expect.poll(() => page.evaluate(() => window.sessionStorage.getItem('osmu.auth.tokens'))).toContain('developer-e2e-access')

  await page.goto(`${frontendBaseUrl}/admin`)
  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('developer-page')).toBeVisible()
  await expect(page.getByRole('link', { name: 'Admin' })).toHaveCount(0)
  await expect(page.locator('#admin-access-keys')).toHaveCount(0)
})

test('admin action failures show remediation guidance', async ({ page }) => {
  await installDeveloperApiMocks(page, {
    user: {
      id: 2101,
      loginId: 'admin-remediation-browser',
      name: 'Admin Remediation Browser',
      role: 'ADMIN',
    },
    adminActionFailures: [
      {
        status: 401,
        code: 'AUTHENTICATION_REQUIRED',
        requestId: 'remediation-401',
        message: 'admin session expired',
      },
      {
        status: 403,
        code: 'AUTHORIZATION_FAILED',
        requestId: 'remediation-403',
        message: 'admin scope denied',
      },
      {
        status: 400,
        code: 'VALIDATION_ERROR',
        requestId: 'remediation-400',
        message: 'invalid admin request',
      },
      {
        status: 404,
        code: 'NOT_FOUND',
        requestId: 'remediation-404',
        message: 'target missing',
      },
      {
        status: 409,
        code: 'STATE_CONFLICT',
        requestId: 'remediation-409',
        message: 'state conflict',
      },
    ],
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill('admin-remediation-browser')
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(/\/admin$/)
  await expect(page.getByTestId('storage-expansion-panel')).toBeVisible()
  await expect(page.getByTestId('storage-expansion-list')).toContainText('증설 요청 없음')
  await expect(page.getByTestId('storage-expansion-create-button')).toBeEnabled()

  const submitStorageExpansionRequest = async () => {
    await page.getByTestId('storage-expansion-form').evaluate((form) => form.requestSubmit())
  }

  const expectRemediation = async ({ code, status, requestId, hasPrimary = true }) => {
    await expect.poll(() => page.evaluate(() => ({
      error: document.querySelector('[data-testid="error-alert"]')?.textContent || '',
      panel: document.querySelector('[data-testid="admin-action-remediation-panel"]')?.textContent || '',
      code: document.querySelector('[data-testid="admin-action-remediation-code"]')?.textContent || '',
      hasDetail: Boolean(document.querySelector('[data-testid="admin-action-remediation-detail"]')),
      stepCount: document.querySelectorAll('[data-testid="admin-action-remediation-steps"] li').length,
      primaryCount: document.querySelectorAll('[data-testid="admin-action-remediation-primary"]').length,
    })), { timeout: 5000, intervals: [50, 100, 250] }).toEqual(expect.objectContaining({
      error: expect.stringContaining(`Request ID ${requestId}`),
      panel: expect.any(String),
      code: `${code} / HTTP ${status}`,
      hasDetail: true,
      stepCount: 3,
      primaryCount: hasPrimary ? 1 : 0,
    }))
  }

  await submitStorageExpansionRequest()
  await expectRemediation({ code: 'AUTHENTICATION_REQUIRED', status: 401, requestId: 'remediation-401' })

  await submitStorageExpansionRequest()
  await expectRemediation({ code: 'AUTHORIZATION_FAILED', status: 403, requestId: 'remediation-403' })

  await submitStorageExpansionRequest()
  await expectRemediation({ code: 'VALIDATION_ERROR', status: 400, requestId: 'remediation-400', hasPrimary: false })

  await submitStorageExpansionRequest()
  await expectRemediation({ code: 'NOT_FOUND', status: 404, requestId: 'remediation-404' })

  await submitStorageExpansionRequest()
  await expectRemediation({ code: 'STATE_CONFLICT', status: 409, requestId: 'remediation-409' })
})

test('developer can filter access keys and inspect operational hints', async ({ page }) => {
  await installDeveloperApiMocks(page, {
    accessKeys: buildOperationalAccessKeys(),
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page.getByTestId('access-key-cleanup-summary')).toContainText('3 selected / 3 cleanup candidates')
  await expect(page.getByTestId('access-key-list')).toContainText('Disable expired')
  await expect(page.getByTestId('access-key-list')).toContainText('Rotate soon')
  await expect(page.getByTestId('access-key-list')).toContainText('Review unused')
  await expect(page.getByTestId('access-key-list')).toContainText('Review stale')
  await expect(page.getByTestId('access-key-list')).toContainText('Recent active usage detected')

  await page.getByTestId('access-key-filter-expired').click()
  await expect(page.getByTestId('access-key-list')).toContainText('expired-browser-key')
  await expect(page.getByTestId('access-key-list')).not.toContainText('healthy-browser-key')

  await page.getByTestId('access-key-filter-expiring').click()
  await expect(page.getByTestId('access-key-list')).toContainText('expiring-browser-key')
  await expect(page.getByTestId('access-key-list')).not.toContainText('expired-browser-key')

  await page.getByTestId('access-key-filter-unused').click()
  await expect(page.getByTestId('access-key-list')).toContainText('unused-browser-key')
  await expect(page.getByTestId('access-key-list')).toContainText('stale-browser-key')
  await expect(page.getByTestId('access-key-list')).not.toContainText('healthy-browser-key')

  await page.getByTestId('access-key-filter-inactive').click()
  await expect(page.getByTestId('access-key-list')).toContainText('inactive-browser-key')
  await expect(page.getByTestId('access-key-list')).not.toContainText('unused-browser-key')
})

test('developer can export and confirm access key bulk cleanup', async ({ page }) => {
  await installDeveloperApiMocks(page, {
    accessKeys: buildOperationalAccessKeys(),
  })
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page.getByTestId('access-key-cleanup-summary')).toContainText('3 selected / 3 cleanup candidates')
  await expect(page.getByTestId('access-key-cleanup-candidate')).toHaveCount(3)
  await expect(page.getByTestId('access-key-cleanup-preview')).toContainText('expired-browser-key')
  await expect(page.getByTestId('access-key-cleanup-preview')).toContainText('unused-browser-key')
  await expect(page.getByTestId('access-key-cleanup-preview')).toContainText('stale-browser-key')
  await expect(page.getByTestId('access-key-cleanup-preview')).not.toContainText('expiring-browser-key')

  await page
    .getByTestId('access-key-cleanup-candidate')
    .filter({ hasText: 'stale-browser-key' })
    .getByTestId('access-key-cleanup-candidate-checkbox')
    .uncheck()
  await expect(page.getByTestId('access-key-cleanup-summary')).toContainText('2 selected / 3 cleanup candidates')

  const downloadPromise = page.waitForEvent('download')
  await page.getByTestId('access-key-cleanup-export-button').click()
  const download = await downloadPromise
  expect(download.suggestedFilename()).toMatch(/^osmu-access-key-cleanup-\d{4}-\d{2}-\d{2}\.json$/)
  const downloadPath = await download.path()
  expect(downloadPath).toBeTruthy()
  const payload = JSON.parse(await readFile(downloadPath, 'utf8'))
  expect(payload.schemaVersion).toBe('osmu.access-key-cleanup-preview.v1')
  expect(payload.candidateCount).toBe(3)
  expect(payload.selectedCount).toBe(2)
  expect(payload.excludedCount).toBe(1)
  expect(payload.selectedCandidateIds).toEqual([11, 13])
  expect(payload.excludedCandidateIds).toEqual([14])
  expect(JSON.stringify(payload)).not.toContain('developer-e2e-super-secret')

  await page.getByTestId('access-key-cleanup-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Access Key Bulk Cleanup')
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Access Key')
  await expect(page.getByTestId('access-key-cleanup-summary')).toContainText('0 selected / 1 cleanup candidates')
  await expect(page.getByTestId('access-key-cleanup-button')).toBeDisabled()

  await page.getByTestId('access-key-filter-inactive').click()
  await expect(page.getByTestId('access-key-list')).toContainText('expired-browser-key')
  await expect(page.getByTestId('access-key-list')).toContainText('unused-browser-key')
  await expect(page.getByTestId('access-key-list')).toContainText('inactive-browser-key')
  await expect(page.getByTestId('access-key-list')).not.toContainText('stale-browser-key')
})

test('admin dashboard shows operations readiness convergence handoff', async ({ page }) => {
  test.skip(!expectOperationsConvergence, 'operations convergence fixture is not enabled for this E2E target')

  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page.getByTestId('logout-button')).toBeVisible()

  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page).toHaveURL(/\/dashboard$/)
  await expect(page.getByTestId('readiness-convergence-item-summary')).toContainText('action-required')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('dispatch-ready-subset-browser')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('2 of 8 stages ready')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('sync not-ready')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('source action-required')
  await expect(page.getByTestId('readiness-convergence-commands')).toContainText('Open browser dispatch for ready subset')
  await expect(page.getByTestId('readiness-convergence-commands')).toContainText('invoke-operations-evidence-plan.ps1')
  await expect(page.getByTestId('readiness-convergence-command-copy-button')).toBeVisible()
  await expect(page.getByTestId('readiness-convergence-command-list-copy-button').first()).toBeVisible()
  await expect(page.getByTestId('readiness-convergence-dispatch-link')).toHaveAttribute('href', /container-security-ci\.yml/)
})

test('admin can complete lightweight storage portal click path', async ({ page }) => {
  const suffix = Date.now().toString(36)
  const bucketName = `e2e-${suffix}`
  const deleteBucketName = `e2e-delete-${suffix}`
  const objectKey = `e2e/hello-${suffix}.txt`

  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })
  await page.goto(`${frontendBaseUrl}/login?mode=admin`)

  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('login-mode-admin')).toBeChecked()
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page.getByTestId('logout-button')).toBeVisible()
  await expect(page).toHaveURL(/\/admin$/)
  await expect(page.locator('#admin-access-keys')).toBeVisible()
  await expectAdminBucketContextReady(page)
  await expect(page.getByTestId('admin-security-audit-policy-panel')).toBeVisible()
  await expect(page.getByTestId('admin-security-policy-metrics')).toBeVisible()
  await expect(page.getByTestId('admin-security-policy-list')).toContainText('Access key hygiene')
  await expect(page.getByTestId('admin-security-policy-list')).toContainText('Share link protection')
  await expect(page.getByTestId('admin-security-policy-list')).toContainText('Audit trail')
  await expect(page.getByTestId('admin-security-policy-row')).toHaveCount(6)
  await page.getByTestId('admin-security-audit-open-audit-link').click()
  await expect(page).toHaveURL(/\/audit$/)
  await expect(page.getByTestId('audit-panel')).toBeVisible()
  await expect(page.getByTestId('audit-filter-form')).toBeVisible()
  await page.getByRole('link', { name: 'Admin' }).click()
  await expect(page).toHaveURL(/\/admin$/)
  await expect(page.getByTestId('admin-security-audit-policy-panel')).toBeVisible()

  await page.getByRole('link', { name: 'Storage' }).click()
  await expect(page.getByTestId('bucket-panel')).toBeVisible()

  await page.getByTestId('bucket-name-input').fill(deleteBucketName)
  await page.getByTestId('bucket-quota-input').fill('1')
  await page.getByTestId('bucket-owner-type-select').selectOption('USER')
  await page.getByTestId('bucket-create-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('버킷 생성 완료')

  const deleteBucketRow = page.getByTestId(`bucket-row-${deleteBucketName}`)
  await expect(deleteBucketRow).toBeVisible()
  await deleteBucketRow.getByTestId('bucket-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText(deleteBucketName)
  await page.getByTestId('confirm-cancel-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(deleteBucketRow).toBeVisible()
  await expect(page.getByTestId('status-alert')).not.toContainText('버킷 삭제 완료')
  await deleteBucketRow.getByTestId('bucket-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText(deleteBucketName)
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(page.getByTestId('status-alert')).toContainText('버킷 삭제 완료')
  await expect(deleteBucketRow).toHaveCount(0)

  await page.getByTestId('bucket-name-input').fill(bucketName)
  await page.getByTestId('bucket-quota-input').fill('1')
  await page.getByTestId('bucket-owner-type-select').selectOption('USER')
  await page.getByTestId('bucket-create-button').click()

  const bucketRow = page.getByTestId(`bucket-row-${bucketName}`)
  await expect(bucketRow).toBeVisible()
  await expect(bucketRow.getByTestId('bucket-row-name')).toHaveText(bucketName)
  await expect(bucketRow.getByTestId('bucket-row-usage')).toContainText(/0 B \/ 1(?:\.0)? GB/)
  await expect(bucketRow.getByTestId('bucket-row-object-count')).toHaveText('0')
  await bucketRow.click()
  await expect(page.getByTestId('storage-profile-panel')).toBeVisible()
  await expect(page.getByTestId('storage-profile-select')).toContainText('Performance')
  await page.getByTestId('storage-profile-select').selectOption('PERFORMANCE')
  await page.getByTestId('storage-profile-reason-input').fill('browser storage profile request')
  await page.getByTestId('storage-profile-request-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage profile requested')
  await expect(page.getByTestId('storage-profile-request-row').first()).toContainText(bucketName)
  await expect(page.getByTestId('storage-profile-request-row').first()).toContainText(/Performance|PERFORMANCE/)
  await expect(page.getByTestId('storage-profile-request-status').first()).toContainText('PENDING')
  await page.getByRole('link', { name: 'Admin' }).click()
  await expect(page.getByTestId('admin-storage-profile-panel')).toBeVisible()
  await expect(page.getByTestId('admin-approval-workflow-panel')).toBeVisible()
  await expect(page.getByTestId('admin-approval-workflow-metrics')).toContainText('Profiles')
  const approvalWorkflowProfileItem = page.getByTestId('admin-approval-workflow-list').locator('li').filter({ hasText: bucketName }).first()
  await expect(approvalWorkflowProfileItem).toContainText('Storage profile')
  await expect(approvalWorkflowProfileItem).toContainText('PENDING')
  await expect(approvalWorkflowProfileItem.getByTestId('admin-approval-profile-approve-button')).toBeVisible()
  await expect(approvalWorkflowProfileItem.getByTestId('admin-approval-profile-reject-button')).toBeVisible()
  const adminProfileRequestRow = page.getByTestId('admin-storage-profile-request-row').filter({ hasText: bucketName }).first()
  await expect(adminProfileRequestRow).toContainText('PENDING')
  await expect(adminProfileRequestRow.getByTestId('admin-storage-profile-approve-button')).toBeVisible()
  await page.getByTestId('storage-profile-admin-note-input').fill('browser profile approval')
  await approvalWorkflowProfileItem.getByTestId('admin-approval-profile-approve-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage profile request APPROVED')
  await expect(approvalWorkflowProfileItem).toContainText('APPROVED')
  await expect(approvalWorkflowProfileItem.getByTestId('admin-approval-profile-apply-button')).toBeVisible()
  await expect(adminProfileRequestRow.getByTestId('admin-storage-profile-request-status')).toContainText('APPROVED')
  await expect(adminProfileRequestRow.getByTestId('admin-storage-profile-apply-button')).toBeVisible()
  await approvalWorkflowProfileItem.getByTestId('admin-approval-profile-apply-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage profile applied')
  await expect(adminProfileRequestRow.getByTestId('admin-storage-profile-request-status')).toContainText('APPLIED')

  const expansionReason = `browser expansion workflow ${suffix}`
  await page.getByTestId('storage-expansion-capacity-input').fill('2')
  await page.getByTestId('storage-expansion-server-count-input').fill('4')
  await page.getByTestId('storage-expansion-volumes-input').fill('1')
  await page.getByTestId('storage-expansion-reason-input').fill(expansionReason)
  await page.getByTestId('storage-expansion-create-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage expansion request created')
  const expansionRow = page.getByTestId('storage-expansion-list').locator('li').filter({ hasText: expansionReason }).first()
  await expect(expansionRow).toContainText('PLANNED')
  const expansionPoolName = (await expansionRow.locator('b').first().innerText()).split(' / ')[0]
  const approvalWorkflowExpansionItem = page.getByTestId('admin-approval-workflow-list').locator('li').filter({ hasText: expansionPoolName }).first()
  await expect(approvalWorkflowExpansionItem).toContainText('Storage expansion')
  await expect(approvalWorkflowExpansionItem).toContainText('PLANNED')
  await approvalWorkflowExpansionItem.getByTestId('admin-approval-expansion-approve-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage expansion status updated')
  await expect(approvalWorkflowExpansionItem).toContainText('APPROVED')
  await expect(approvalWorkflowExpansionItem.getByTestId('admin-approval-expansion-plan-button')).toBeVisible()
  await expect(approvalWorkflowExpansionItem.getByTestId('admin-approval-expansion-reject-button')).toBeVisible()
  await approvalWorkflowExpansionItem.getByTestId('admin-approval-expansion-plan-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage expansion dry-run ready')
  await expect(page.getByTestId('storage-expansion-execution-plan-panel')).toContainText(expansionPoolName)
  await page.getByTestId('storage-expansion-apply-evidence-input').fill('browser expansion workflow evidence')
  await approvalWorkflowExpansionItem.getByTestId('admin-approval-expansion-apply-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('Storage expansion status updated')
  await expect(expansionRow).toContainText('APPLIED')

  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-panel')).toContainText(bucketName)

  await page.getByRole('link', { name: 'Admin' }).click()
  await expect(page.getByTestId('bucket-lifecycle-panel')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-load-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-save-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-delete-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toBeVisible()
  const lifecycleXml = [
    '<LifecycleConfiguration>',
    '  <Rule>',
    '    <ID>Browser lifecycle</ID>',
    '    <Status>Enabled</Status>',
    '    <Filter><Prefix>e2e/raw/</Prefix></Filter>',
    '    <Expiration><Days>7</Days></Expiration>',
    '  </Rule>',
    '</LifecycleConfiguration>',
  ].join('\n')
  await page.getByTestId('bucket-lifecycle-textarea').fill(lifecycleXml)
  await page.getByTestId('bucket-lifecycle-save-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket lifecycle')
  await expect(page.getByTestId('bucket-lifecycle-rule-count')).toContainText('1 rules')
  await expect(page.getByTestId('bucket-lifecycle-saved-count')).toContainText('saved 1 rules')
  await page.getByTestId('bucket-lifecycle-textarea').fill('')
  await page.getByTestId('bucket-lifecycle-load-button').click()
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue(/Browser lifecycle/)
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue(/e2e\/raw\//)
  await page.getByTestId('bucket-lifecycle-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Bucket lifecycle')
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket lifecycle')
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue('')
  await expect(page.getByTestId('bucket-lifecycle-rule-count')).toContainText('0 rules')
  await expect(page.getByTestId('bucket-tags-panel')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-load-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-save-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-delete-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-input')).toBeVisible()
  await page.getByTestId('bucket-tags-input').fill('project=osmu,stage=e2e')
  await page.getByTestId('bucket-tags-save-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket tags 저장 완료')
  await expect(page.getByTestId('bucket-tags-count')).toContainText('2 tags')
  await page.getByTestId('bucket-tags-input').fill('')
  await page.getByTestId('bucket-tags-load-button').click()
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue(/project=osmu/)
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue(/stage=e2e/)
  await page.getByTestId('bucket-tags-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Bucket tags')
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket tags 삭제 완료')
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue('')

  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-prefix-breadcrumb')).toBeVisible()
  await expect(page.getByTestId('object-prefix-breadcrumb-button').first()).toBeVisible()
  await page.getByTestId('object-key-input').fill(objectKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=e2e')
  await page.getByTestId('object-file-input').setInputFiles({
    name: 'hello.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('hello from browser e2e'),
  })
  await expect(page.getByTestId('object-upload-button')).toBeEnabled()
  await page.getByTestId('object-upload-button').click()

  await page.getByTestId('object-list-limit-select').selectOption('50')
  await expect(page.getByTestId('object-list-limit-select')).toHaveValue('50')
  await expect(page.getByTestId('object-prefix-row').first()).toContainText('e2e')
  await page.getByTestId('object-prefix-open-button').first().click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('e2e/')
  await expect(page.getByTestId('object-prefix-breadcrumb-button').filter({ hasText: 'e2e' })).toBeVisible()
  await page.getByTestId('object-prefix-breadcrumb-button').filter({ hasText: '/' }).click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('')
  await page.getByTestId('object-prefix-open-button').first().click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('e2e/')

  await page.getByTestId('object-search-input').fill('hello')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-key-match').first()).toContainText(/hello/i)
  await expect(page.getByTestId('object-tag-edit-button').first()).toBeVisible()

  await page.getByTestId('object-tag-filter-input').fill('project=osmu')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-table')).toContainText('project=osmu')

  await page.getByTestId('object-tag-edit-button').first().click()
  await expect(page.getByTestId('object-tag-key-input')).toHaveValue(objectKey)
  await expect(page.getByTestId('object-tag-value-input')).toHaveValue(/project=osmu/)
  await page.getByTestId('object-tag-value-input').fill('project=archive,stage=curated')
  await page.getByTestId('object-tag-save-button').click()
  await page.getByTestId('object-tag-filter-input').fill('project=archive')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-table')).toContainText('project=archive')
  await expect(page.getByTestId('object-table')).toContainText('stage=curated')

  await page.getByTestId('object-detail-button').first().click()
  await expect(page.getByTestId('object-detail-panel')).toContainText(objectKey)
  await expect(page.getByTestId('object-detail-panel')).toContainText('project=archive')
  await expect(page.getByTestId('object-detail-panel')).toContainText('stage=curated')
  await expect(page.getByTestId('object-metadata-row-state').first()).toContainText(/Synced|Drift|Missing/)

  await page.getByTestId('object-tag-edit-button').first().click()
  await page.getByTestId('object-tag-value-input').fill('bad key=value')
  await page.getByTestId('object-tag-save-button').click()
  await expect(page.getByTestId('error-alert')).toContainText('Tag keys can contain')
  await expect(page.getByTestId('object-table')).toContainText('stage=curated')

  await page.getByRole('link', { name: 'Audit' }).click()
  await page.getByTestId('audit-result-select').selectOption('SUCCESS')
  await page.getByTestId('audit-limit-input').fill('5')
  await page.getByTestId('audit-search-button').click()
  await expect(page.getByTestId('audit-list')).toContainText(/BUCKET|OBJECT|LOGIN/)
  await expect(page.getByTestId('audit-entry').first()).toContainText('SUCCESS')
  await expect(page.getByTestId('audit-entry')).toHaveCount(5)
  const auditNextButton = page.getByTestId('audit-next-button')
  await expect(auditNextButton).toBeEnabled()
  await auditNextButton.click()
  await expect(page.getByTestId('audit-entry').nth(5)).toContainText('SUCCESS')
  const auditDownloadPromise = page.waitForEvent('download')
  await page.getByTestId('audit-export-button').click()
  const auditDownload = await auditDownloadPromise
  expect(auditDownload.suggestedFilename()).toBe('osmu-audit.csv')
  await page.getByTestId('audit-reset-button').click()
  await expect(page.getByTestId('audit-result-select')).toHaveValue('')
  await expect(page.getByTestId('audit-limit-input')).toHaveValue('50')
})
