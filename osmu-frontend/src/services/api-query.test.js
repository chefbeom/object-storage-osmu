import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  cleanupObjectShareLinks,
  createObjectShareLink,
  createPresignedUploadUrl,
  deleteObjectShareLink,
  downloadAuditLogsCsv,
  getAuditLogs,
  getBuckets,
  getObjectMetadata,
  getObjectShareAnalytics,
  getObjectSharePolicy,
  getObjectShareLinks,
  getObjects,
  saveObjectSharePolicy,
  updateObjectTags,
} from './api.js'

test('getAuditLogs sends all audit filters as query parameters', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: null }),
  ])

  try {
    await getAuditLogs({
      eventType: 'OBJECT_UPLOAD',
      actorId: 'admin',
      requestId: 'req 1',
      targetType: 'OBJECT',
      targetId: 'bucket/hello.txt',
      result: 'SUCCESS',
      cursor: 'cursor-1',
      from: '2026-06-01T00:00:00Z',
      to: '2026-06-02T00:00:00Z',
      limit: 50,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/audit-logs')
    assert.equal(url.searchParams.get('eventType'), 'OBJECT_UPLOAD')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('requestId'), 'req 1')
    assert.equal(url.searchParams.get('targetType'), 'OBJECT')
    assert.equal(url.searchParams.get('targetId'), 'bucket/hello.txt')
    assert.equal(url.searchParams.get('result'), 'SUCCESS')
    assert.equal(url.searchParams.get('cursor'), 'cursor-1')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00Z')
    assert.equal(url.searchParams.get('to'), '2026-06-02T00:00:00Z')
    assert.equal(url.searchParams.get('limit'), '50')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share policy wrappers read and save global policy', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { requirePassword: false, requireIpAllowlist: false, maxExpiresSeconds: 604800 } }),
    () => jsonResponse({ data: { requirePassword: true, requireIpAllowlist: true, maxExpiresSeconds: 3600, maxDownloadsLimit: 5 } }),
  ])

  try {
    await getObjectSharePolicy()
    await saveObjectSharePolicy({
      requirePassword: true,
      requireIpAllowlist: true,
      maxExpiresSeconds: 3600,
      maxDownloadsLimit: 5,
      reason: 'secure pilot',
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/object-share-policy')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/object-share-policy')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      requirePassword: true,
      requireIpAllowlist: true,
      maxExpiresSeconds: 3600,
      maxDownloadsLimit: 5,
      reason: 'secure pilot',
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getBuckets uses bucket list endpoint for dashboard table', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      items: [
        { name: 'media', usedBytes: 1024, quotaBytes: 4096, objectCount: 2 },
      ],
    }),
  ])

  try {
    const result = await getBuckets()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.items[0].name, 'media')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadAuditLogsCsv uses export endpoint and returns CSV blob', async () => {
  const fetchMock = mockFetch([
    () => new Response('id,eventType\n1,LOGIN\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadAuditLogsCsv({
      eventType: 'LOGIN',
      actorId: 'admin',
      result: 'SUCCESS',
      limit: 100,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/audit-logs/export.csv')
    assert.equal(url.searchParams.get('eventType'), 'LOGIN')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('result'), 'SUCCESS')
    assert.equal(url.searchParams.get('limit'), '100')
    assert.equal(await blob.text(), 'id,eventType\n1,LOGIN\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getObjects builds browse, search, tag, cursor, and page size query', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: 'next' }),
  ])

  try {
    await getObjects('media bucket', {
      prefix: ' docs/2026/ ',
      delimiter: '/',
      search: ' report ',
      tag: ' project=osmu ',
      cursor: 'cursor 2',
      limit: 250,
      deleted: true,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/buckets/media%20bucket/objects')
    assert.equal(url.searchParams.get('prefix'), 'docs/2026/')
    assert.equal(url.searchParams.get('delimiter'), '/')
    assert.equal(url.searchParams.get('search'), 'report')
    assert.equal(url.searchParams.get('tag'), 'project=osmu')
    assert.equal(url.searchParams.get('cursor'), 'cursor 2')
    assert.equal(url.searchParams.get('limit'), '250')
    assert.equal(url.searchParams.get('deleted'), 'true')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object metadata, tag update, and presigned upload wrappers preserve keys and tags', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { key: 'docs/hello world.txt' } }),
    () => jsonResponse({ data: { key: 'docs/hello world.txt', tags: { project: 'osmu' } } }),
    () => jsonResponse({ data: { uploadUrl: 'https://storage/upload' } }),
  ])

  try {
    await getObjectMetadata('media bucket', 'docs/hello world.txt')
    await updateObjectTags('media bucket', {
      key: 'docs/hello world.txt',
      tags: { project: 'osmu', stage: 'raw' },
    })
    await createPresignedUploadUrl('media bucket', {
      key: 'videos/input.mp4',
      contentType: 'video/mp4',
      sizeBytes: 1024,
      tags: 'project=osmu,stage=raw',
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/metadata/docs/hello%20world.txt')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/tags')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      key: 'docs/hello world.txt',
      tags: { project: 'osmu', stage: 'raw' },
    })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/presigned-upload')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), {
      key: 'videos/input.mp4',
      contentType: 'video/mp4',
      sizeBytes: 1024,
      tags: 'project=osmu,stage=raw',
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share link wrappers create, list, cleanup, and revoke share links', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { id: 3, url: 'http://localhost:8080/api/public/share-links/token' } }),
    () => jsonResponse({ items: [{ id: 3, key: 'docs/hello world.txt' }] }),
    () => jsonResponse({ data: { bucketName: 'media bucket', expiredCount: 0 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await createObjectShareLink('media bucket', 'docs/hello world.txt', {
      expiresInSeconds: 3600,
      note: 'department reuse',
      maxDownloads: 12,
      password: 'SharePass!23',
      allowedIpCidrs: '203.0.113.0/24',
    })
    await getObjectShareLinks('media bucket', 'docs/hello world.txt', 25)
    await cleanupObjectShareLinks('media bucket')
    await deleteObjectShareLink('media bucket', 3)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), {
      key: 'docs/hello world.txt',
      expiresInSeconds: 3600,
      note: 'department reuse',
      maxDownloads: 12,
      password: 'SharePass!23',
      allowedIpCidrs: '203.0.113.0/24',
    })

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/buckets/media%20bucket/objects/share-links')
    assert.equal(listUrl.searchParams.get('key'), 'docs/hello world.txt')
    assert.equal(listUrl.searchParams.get('limit'), '25')

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links/cleanup')
    assert.equal(fetchMock.calls[2].options.method, 'POST')

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links/3')
    assert.equal(fetchMock.calls[3].options.method, 'DELETE')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share analytics wrapper reads bounded admin summary', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { totalLinks: 1, activeLinks: 1, recentLinks: [] } }),
  ])

  try {
    await getObjectShareAnalytics(12, {
      bucketName: 'media bucket',
      status: 'ACTIVE',
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/object-share-analytics')
    assert.equal(url.searchParams.get('limit'), '12')
    assert.equal(url.searchParams.get('bucketName'), 'media bucket')
    assert.equal(url.searchParams.get('status'), 'ACTIVE')
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
