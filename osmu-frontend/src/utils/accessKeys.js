export const ACCESS_KEY_PERMISSION_ORDER = ['READ', 'WRITE', 'DELETE', 'ADMIN']

export function mergePermissions(current, next) {
  const values = new Set([...(current ?? []), ...(next ?? [])])
  return ACCESS_KEY_PERMISSION_ORDER.filter((permission) => values.has(permission))
}

export function upsertAccessKeyScope(scopes, bucketName, permissions) {
  if (!bucketName || !permissions?.length) {
    return [...scopes]
  }
  const nextPermissions = mergePermissions([], permissions)
  const existing = scopes.find((scope) => scope.bucketName === bucketName)
  if (!existing) {
    return [...scopes, { bucketName, permissions: nextPermissions }]
  }
  return scopes.map((scope) => (
    scope.bucketName === bucketName
      ? { ...scope, permissions: mergePermissions(scope.permissions, nextPermissions) }
      : scope
  ))
}

export function removeAccessKeyScope(scopes, bucketName) {
  return scopes.filter((scope) => scope.bucketName !== bucketName)
}

export function formatKeyScope(key) {
  if (key.bucketScopes?.length) {
    return key.bucketScopes
      .map((scope) => `${scope.bucketName}: ${scope.permissions?.join('+')}`)
      .join(', ')
  }
  return `${key.allowedBuckets?.join(', ')} / ${key.permissions?.join(', ')}`
}
