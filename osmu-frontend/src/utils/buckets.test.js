import assert from 'node:assert/strict'
import test from 'node:test'
import {
  buildBucketListRows,
  summarizeBuckets,
} from './buckets.js'

test('summarizeBuckets calculates dashboard counts and capacity totals', () => {
  assert.deepEqual(summarizeBuckets([
    { name: 'media', usedBytes: 1024, quotaBytes: 4096, objectCount: 3 },
    { name: 'archive', usedBytes: 8192, quotaBytes: 4096, objectCount: 7 },
  ]), {
    bucketCount: 2,
    objectCount: 10,
    totalQuotaBytes: 8192,
    usedBytes: 9216,
    remainingBytes: 0,
  })
})

test('buildBucketListRows prepares visible bucket list values', () => {
  const rows = buildBucketListRows([
    {
      name: 'media',
      usedBytes: 1536,
      quotaBytes: 4096,
      objectCount: 12,
      ownerType: 'ORG',
      ownerId: 3,
    },
  ], (value) => `${value} B`)

  assert.deepEqual(rows, [{
    name: 'media',
    usedBytes: 1536,
    quotaBytes: 4096,
    usageLabel: '1536 B / 4096 B',
    objectCount: 12,
    ownerType: 'ORG',
    ownerId: 3,
    raw: {
      name: 'media',
      usedBytes: 1536,
      quotaBytes: 4096,
      objectCount: 12,
      ownerType: 'ORG',
      ownerId: 3,
    },
  }])
})
