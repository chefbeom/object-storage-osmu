import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildObjectMetadataDetailRows,
  buildObjectPrefixBreadcrumbs,
  formatChecksumMap,
  formatPrefixName,
  metadataStatusClass,
  metadataStatusLabel,
  parentObjectPrefix,
  splitObjectKeyBySearch,
} from './objectExplorer.js'

test('buildObjectPrefixBreadcrumbs returns root and cumulative prefixes', () => {
  assert.deepEqual(buildObjectPrefixBreadcrumbs('docs/2026/reports/'), [
    { label: '/', prefix: '' },
    { label: 'docs', prefix: 'docs/' },
    { label: '2026', prefix: 'docs/2026/' },
    { label: 'reports', prefix: 'docs/2026/reports/' },
  ])
})

test('parentObjectPrefix moves one prefix level up', () => {
  assert.equal(parentObjectPrefix('docs/2026/'), 'docs/')
  assert.equal(parentObjectPrefix('docs/2026'), 'docs/')
  assert.equal(parentObjectPrefix('docs/'), '')
  assert.equal(parentObjectPrefix(''), '')
})

test('formatPrefixName returns visible folder name', () => {
  assert.equal(formatPrefixName('docs/2026/'), '2026')
  assert.equal(formatPrefixName('media/'), 'media')
  assert.equal(formatPrefixName('/'), '/')
})

test('splitObjectKeyBySearch highlights matches without changing original text', () => {
  const parts = splitObjectKeyBySearch('reports/Report-Final.txt', 'report')

  assert.deepEqual(parts, [
    { text: 'report', match: true },
    { text: 's/', match: false },
    { text: 'Report', match: true },
    { text: '-Final.txt', match: false },
  ])
  assert.equal(parts.map((part) => part.text).join(''), 'reports/Report-Final.txt')
})

test('splitObjectKeyBySearch returns plain key when search is blank or missing', () => {
  assert.deepEqual(splitObjectKeyBySearch('docs/readme.txt', ''), [
    { text: 'docs/readme.txt', match: false },
  ])
  assert.deepEqual(splitObjectKeyBySearch('docs/readme.txt', 'zip'), [
    { text: 'docs/readme.txt', match: false },
  ])
})

test('metadataStatus helpers map drift status to badge copy and class', () => {
  assert.equal(metadataStatusLabel('SYNCED'), 'Synced')
  assert.equal(metadataStatusClass('SYNCED'), 'up')
  assert.equal(metadataStatusLabel('STALE'), 'Stale')
  assert.equal(metadataStatusClass('STALE'), 'mock')
  assert.equal(metadataStatusLabel('MISSING_IN_STORAGE'), 'Missing in storage')
  assert.equal(metadataStatusClass('MISSING_IN_STORAGE'), 'down')
  assert.equal(metadataStatusLabel('UNKNOWN'), 'UNKNOWN')
  assert.equal(metadataStatusClass('UNKNOWN'), 'down')
})

test('formatChecksumMap formats missing and populated checksum maps', () => {
  assert.equal(formatChecksumMap(null), '-')
  assert.equal(formatChecksumMap({ sha256: 'abc', md5: 'def' }), 'sha256: abc, md5: def')
})

test('buildObjectMetadataDetailRows marks synced, drift, and missing storage fields', () => {
  const rows = buildObjectMetadataDetailRows({
    sizeBytes: 1024,
    storageSizeBytes: 2048,
    contentType: 'video/mp4',
    storageContentType: 'video/mp4',
    etag: 'index-etag',
    storageEtag: null,
    checksums: { sha256: 'index' },
    storageChecksums: { sha256: 'storage' },
    lastModifiedAt: '2026-06-13T10:00:00Z',
    storageLastModifiedAt: '2026-06-13T10:00:00Z',
    tags: { project: 'osmu', stage: 'raw' },
    storageTags: { stage: 'raw', project: 'osmu' },
  }, {
    bytes: (value) => `${value} B`,
    optionalBytes: (value) => `${value} B`,
    dateTime: (value) => `date:${value}`,
    tags: (value) => Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, itemValue]) => `${key}=${itemValue}`)
      .join(', '),
  })

  assert.deepEqual(rows.map((row) => row.key), [
    'size-index',
    'size-storage',
    'type-index',
    'type-storage',
    'etag-index',
    'etag-storage',
    'checksum-index',
    'checksum-storage',
    'modified-index',
    'modified-storage',
    'tags-index',
    'tags-storage',
  ])
  assert.equal(rows.find((row) => row.key === 'size-storage').state, 'drift')
  assert.equal(rows.find((row) => row.key === 'type-storage').state, 'synced')
  assert.equal(rows.find((row) => row.key === 'etag-storage').state, 'missing')
  assert.equal(rows.find((row) => row.key === 'checksum-storage').state, 'drift')
  assert.equal(rows.find((row) => row.key === 'tags-storage').state, 'synced')
  assert.equal(rows.find((row) => row.key === 'size-storage').value, '2048 B')
  assert.equal(rows.find((row) => row.key === 'etag-storage').value, '-')
})
