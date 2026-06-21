import assert from 'node:assert/strict'
import test from 'node:test'
import {
  clearAuthTokens,
  deleteBucketLifecycleS3Xml,
  deleteBucketTags,
  deleteBucketTagsS3Xml,
  getBucketLifecycleS3Xml,
  getBucketTags,
  getBucketTagsS3Xml,
  getBucketVersioning,
  putBucketLifecycleS3Xml,
  putBucketTags,
  putBucketTagsS3Xml,
  putBucketVersioning,
} from './api.js'

test('bucket lifecycle REST wrappers preserve XML payload and methods', async () => {
  const lifecycleXml = '<LifecycleConfiguration><Rule><ID>raw</ID></Rule></LifecycleConfiguration>'
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { xml: lifecycleXml, ruleCount: 1 } }),
    () => jsonResponse({ data: { xml: lifecycleXml, ruleCount: 1 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await getBucketLifecycleS3Xml('media bucket')
    await putBucketLifecycleS3Xml('media bucket', lifecycleXml)
    await deleteBucketLifecycleS3Xml('media bucket')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/lifecycle')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/lifecycle')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), { xml: lifecycleXml })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/lifecycle')
    assert.equal(fetchMock.calls[2].options.method, 'DELETE')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('bucket tag REST wrappers preserve tag map and methods', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { tags: { project: 'osmu' }, tagCount: 1 } }),
    () => jsonResponse({ data: { tags: { project: 'osmu', stage: 'raw' }, tagCount: 2 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await getBucketTags('media bucket')
    await putBucketTags('media bucket', { project: 'osmu', stage: 'raw' })
    await deleteBucketTags('media bucket')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/tags')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/tags')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      tags: { project: 'osmu', stage: 'raw' },
    })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/tags')
    assert.equal(fetchMock.calls[2].options.method, 'DELETE')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('bucket versioning REST wrappers preserve status and methods', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { bucketName: 'media bucket', status: 'SUSPENDED', storageBacked: true } }),
    () => jsonResponse({ data: { bucketName: 'media bucket', status: 'ENABLED', storageBacked: true } }),
  ])

  try {
    await getBucketVersioning('media bucket')
    await putBucketVersioning('media bucket', 'ENABLED')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/versioning')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/versioning')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), { status: 'ENABLED' })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('bucket tagging S3 XML wrappers use text requests and XML headers', async () => {
  const taggingXml = '<Tagging><TagSet><Tag><Key>project</Key><Value>osmu</Value></Tag></TagSet></Tagging>'
  const fetchMock = mockFetch([
    () => new Response(taggingXml, {
      status: 200,
      headers: { 'Content-Type': 'application/xml' },
    }),
    () => new Response('', { status: 200 }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    assert.equal(await getBucketTagsS3Xml('media bucket'), taggingXml)
    await putBucketTagsS3Xml('media bucket', taggingXml)
    await deleteBucketTagsS3Xml('media bucket')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/s3/media%20bucket?tagging')
    assert.equal(fetchMock.calls[0].options.headers.get('Accept'), 'application/xml')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/s3/media%20bucket?tagging')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.equal(fetchMock.calls[1].options.headers.get('Content-Type'), 'application/xml')
    assert.equal(fetchMock.calls[1].options.body, taggingXml)

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/s3/media%20bucket?tagging')
    assert.equal(fetchMock.calls[2].options.method, 'DELETE')
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
