export function buildObjectPrefixBreadcrumbs(prefix) {
  const crumbs = [{ label: '/', prefix: '' }]
  const parts = prefix.split('/').filter(Boolean)
  let currentPrefix = ''
  for (const part of parts) {
    currentPrefix += `${part}/`
    crumbs.push({ label: part, prefix: currentPrefix })
  }
  return crumbs
}

export function parentObjectPrefix(prefix) {
  const currentPrefix = prefix.replace(/\/$/, '')
  const slashIndex = currentPrefix.lastIndexOf('/')
  return slashIndex >= 0 ? currentPrefix.slice(0, slashIndex + 1) : ''
}

export function formatPrefixName(prefix) {
  const trimmed = prefix.replace(/\/$/, '')
  return trimmed.slice(trimmed.lastIndexOf('/') + 1) || prefix
}

export function splitObjectKeyBySearch(key, searchValue) {
  const search = searchValue.trim()
  if (!search) {
    return [{ text: key, match: false }]
  }

  const keyLower = key.toLowerCase()
  const searchLower = search.toLowerCase()
  const parts = []
  let cursor = 0
  let matchIndex = keyLower.indexOf(searchLower)
  while (matchIndex >= 0) {
    if (matchIndex > cursor) {
      parts.push({ text: key.slice(cursor, matchIndex), match: false })
    }
    const matchEnd = matchIndex + search.length
    parts.push({ text: key.slice(matchIndex, matchEnd), match: true })
    cursor = matchEnd
    matchIndex = keyLower.indexOf(searchLower, cursor)
  }
  if (cursor < key.length) {
    parts.push({ text: key.slice(cursor), match: false })
  }
  return parts.length > 0 ? parts : [{ text: key, match: false }]
}

export function metadataStatusLabel(status) {
  if (status === 'SYNCED') {
    return 'Synced'
  }
  if (status === 'STALE') {
    return 'Stale'
  }
  if (status === 'MISSING_IN_STORAGE') {
    return 'Missing in storage'
  }
  return status || '-'
}

export function metadataStatusClass(status) {
  if (status === 'SYNCED') {
    return 'up'
  }
  if (status === 'STALE') {
    return 'mock'
  }
  return 'down'
}

export function formatChecksumMap(checksums) {
  if (!checksums || Object.keys(checksums).length === 0) {
    return '-'
  }
  return Object.entries(checksums)
    .map(([name, value]) => `${name}: ${value}`)
    .join(', ')
}

export function buildObjectMetadataDetailRows(metadata, formatters = {}) {
  const value = metadata || {}
  const bytes = formatters.bytes || formatPlainValue
  const optionalBytes = formatters.optionalBytes || ((input) => formatOptionalValue(input, bytes))
  const text = formatters.text || formatPlainValue
  const dateTime = formatters.dateTime || formatPlainValue
  const tags = formatters.tags || formatObjectMap
  const checksums = formatters.checksums || formatChecksumMap

  return [
    buildMetadataDetailPair('size', 'Index size', 'Storage size', value.sizeBytes, value.storageSizeBytes, bytes, optionalBytes),
    buildMetadataDetailPair('type', 'Index type', 'Storage type', value.contentType, value.storageContentType, text, text),
    buildMetadataDetailPair('etag', 'Index ETag', 'Storage ETag', value.etag, value.storageEtag, text, text),
    buildMetadataDetailPair('checksum', 'Index checksum', 'Storage checksum', value.checksums, value.storageChecksums, checksums, checksums),
    buildMetadataDetailPair('modified', 'Index modified', 'Storage modified', value.lastModifiedAt, value.storageLastModifiedAt, dateTime, dateTime),
    buildMetadataDetailPair('tags', 'Index tags', 'Storage tags', value.tags, value.storageTags, tags, tags),
  ].flat()
}

function buildMetadataDetailPair(key, indexLabel, storageLabel, indexValue, storageValue, formatIndex, formatStorage) {
  const state = metadataFieldState(indexValue, storageValue)
  return [
    {
      key: `${key}-index`,
      label: indexLabel,
      value: formatOptionalValue(indexValue, formatIndex),
      state,
    },
    {
      key: `${key}-storage`,
      label: storageLabel,
      value: formatOptionalValue(storageValue, formatStorage),
      state,
    },
  ]
}

function metadataFieldState(indexValue, storageValue) {
  if (isMissingMetadataValue(storageValue)) {
    return 'missing'
  }
  return comparableMetadataValue(indexValue) === comparableMetadataValue(storageValue) ? 'synced' : 'drift'
}

function comparableMetadataValue(value) {
  if (isMissingMetadataValue(value)) {
    return ''
  }
  if (typeof value === 'object') {
    return JSON.stringify(Object.entries(value).sort(([left], [right]) => left.localeCompare(right)))
  }
  return String(value)
}

function isMissingMetadataValue(value) {
  return value === null || value === undefined || value === ''
}

function formatOptionalValue(value, formatter) {
  if (isMissingMetadataValue(value)) {
    return '-'
  }
  return formatter(value)
}

function formatPlainValue(value) {
  return String(value)
}

function formatObjectMap(value) {
  if (!value || Object.keys(value).length === 0) {
    return '-'
  }
  return Object.entries(value)
    .map(([key, itemValue]) => `${key}=${itemValue}`)
    .join(', ')
}
