export function summarizeBuckets(buckets) {
  const items = Array.isArray(buckets) ? buckets : []
  const totalQuotaBytes = items.reduce((sum, bucket) => sum + Number(bucket.quotaBytes || 0), 0)
  const usedBytes = items.reduce((sum, bucket) => sum + Number(bucket.usedBytes || 0), 0)

  return {
    bucketCount: items.length,
    objectCount: items.reduce((sum, bucket) => sum + Number(bucket.objectCount || 0), 0),
    totalQuotaBytes,
    usedBytes,
    remainingBytes: Math.max(0, totalQuotaBytes - usedBytes),
  }
}

export function buildBucketListRows(buckets, formatBytes = String) {
  const items = Array.isArray(buckets) ? buckets : []
  return items.map((bucket) => ({
    name: bucket.name,
    usedBytes: Number(bucket.usedBytes || 0),
    quotaBytes: Number(bucket.quotaBytes || 0),
    usageLabel: `${formatBytes(bucket.usedBytes || 0)} / ${formatBytes(bucket.quotaBytes || 0)}`,
    objectCount: Number(bucket.objectCount || 0),
    ownerType: bucket.ownerType,
    ownerId: bucket.ownerId,
    raw: bucket,
  }))
}
