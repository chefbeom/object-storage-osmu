export const TAG_KEY_PATTERN = /^[A-Za-z0-9_.:/@+-]+$/
export const MAX_TAG_KEY_LENGTH = 128
export const MAX_TAG_VALUE_LENGTH = 256

export function parseTagInput(tags, { maxTagCount = 10, label = 'Tag' } = {}) {
  if (!tags?.trim()) {
    return { tags: [], error: '' }
  }
  const parsedTags = []
  for (const rawPair of tags.split(',')) {
    const pair = rawPair.trim()
    if (!pair) {
      continue
    }
    const separatorIndex = pair.indexOf('=')
    if (separatorIndex <= 0 || separatorIndex === pair.length - 1) {
      return { tags: [], error: `${label}s must use key=value format.` }
    }
    const key = pair.slice(0, separatorIndex).trim()
    const value = pair.slice(separatorIndex + 1).trim()
    if (!key || !value) {
      return { tags: [], error: `${label}s must use key=value format.` }
    }
    parsedTags.push({ key, value })
  }
  const error = validateParsedTags(parsedTags, { maxTagCount, label })
  return error ? { tags: [], error } : { tags: parsedTags, error: '' }
}

export function validateObjectTagInput(tags) {
  return parseTagInput(tags, { maxTagCount: 10, label: 'Tag' }).error
}

export function validateObjectTagMap(tags) {
  return validateTagMap(tags, { maxTagCount: 10, label: 'Tag' })
}

export function validateBucketTagInput(tags) {
  return parseTagInput(tags, { maxTagCount: 50, label: 'Bucket tag' })
}

export function validateBucketTagMap(tags) {
  return validateTagMap(tags, { maxTagCount: 50, label: 'Bucket tag' })
}

export function tagPairsToMap(tags) {
  return tags.reduce((result, tag) => {
    result[tag.key] = tag.value
    return result
  }, {})
}

export function tagsToInput(tags) {
  if (!tags) {
    return ''
  }
  const entries = Array.isArray(tags)
    ? tags.map(({ key, value }) => [key, value])
    : Object.entries(tags)
  return entries
    .map(([key, value]) => `${key}=${value}`)
    .join(', ')
}

function validateTagMap(tags, { maxTagCount, label }) {
  if (!tags) {
    return ''
  }
  if (typeof tags !== 'object' || Array.isArray(tags)) {
    return `${label}s must be an object map.`
  }
  if (Object.keys(tags).length === 0) {
    return ''
  }
  const pairs = []
  for (const [key, value] of Object.entries(tags)) {
    if (typeof value !== 'string') {
      return `${label} values must be strings.`
    }
    pairs.push({ key: key.trim(), value: value.trim() })
  }
  return validateParsedTags(pairs, { maxTagCount, label })
}

function validateParsedTags(tags, { maxTagCount, label }) {
  const parsedKeys = new Set()
  for (const { key, value } of tags) {
    if (!key || !value) {
      return `${label}s must use key=value format.`
    }
    if (key.length > MAX_TAG_KEY_LENGTH) {
      return `${label} keys can be at most 128 characters.`
    }
    if (!TAG_KEY_PATTERN.test(key)) {
      return `${label} keys can contain letters, digits, '.', '_', ':', '/', '@', '+', '-'.`
    }
    if (value.length > MAX_TAG_VALUE_LENGTH) {
      return `${label} values can be at most 256 characters.`
    }
    if (/[\u0000-\u001F\u007F]/.test(value)) {
      return `${label} values cannot contain control characters.`
    }
    if (parsedKeys.has(key)) {
      return `Duplicate ${label.toLowerCase()} key is not allowed.`
    }
    parsedKeys.add(key)
  }
  if (tags.length > maxTagCount) {
    return `${label}s can contain at most ${maxTagCount} pairs.`
  }
  return ''
}
