import assert from 'node:assert/strict'
import test from 'node:test'
import {
  formatKeyScope,
  mergePermissions,
  removeAccessKeyScope,
  upsertAccessKeyScope,
} from './accessKeys.js'

test('mergePermissions keeps canonical permission order and removes duplicates', () => {
  assert.deepEqual(mergePermissions(['WRITE', 'READ'], ['ADMIN', 'READ']), ['READ', 'WRITE', 'ADMIN'])
})

test('upsertAccessKeyScope appends and merges multi bucket scopes', () => {
  const first = upsertAccessKeyScope([], 'bucket-a', ['WRITE', 'READ'])
  const second = upsertAccessKeyScope(first, 'bucket-b', ['READ'])
  const third = upsertAccessKeyScope(second, 'bucket-a', ['DELETE', 'READ'])

  assert.deepEqual(third, [
    { bucketName: 'bucket-a', permissions: ['READ', 'WRITE', 'DELETE'] },
    { bucketName: 'bucket-b', permissions: ['READ'] },
  ])
})

test('removeAccessKeyScope removes selected bucket scope', () => {
  assert.deepEqual(removeAccessKeyScope([
    { bucketName: 'bucket-a', permissions: ['READ'] },
    { bucketName: 'bucket-b', permissions: ['WRITE'] },
  ], 'bucket-a'), [
    { bucketName: 'bucket-b', permissions: ['WRITE'] },
  ])
})

test('formatKeyScope displays bucket scopes and legacy key scopes', () => {
  assert.equal(formatKeyScope({
    bucketScopes: [
      { bucketName: 'bucket-a', permissions: ['READ', 'WRITE'] },
      { bucketName: 'bucket-b', permissions: ['READ'] },
    ],
  }), 'bucket-a: READ+WRITE, bucket-b: READ')
  assert.equal(formatKeyScope({
    allowedBuckets: ['bucket-a', 'bucket-b'],
    permissions: ['READ', 'WRITE'],
  }), 'bucket-a, bucket-b / READ, WRITE')
})
