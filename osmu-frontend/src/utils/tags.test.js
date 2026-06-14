import assert from 'node:assert/strict'
import test from 'node:test'
import {
  parseTagInput,
  tagPairsToMap,
  tagsToInput,
  validateBucketTagInput,
  validateObjectTagInput,
  validateObjectTagMap,
} from './tags.js'

test('parseTagInput parses comma separated key value pairs', () => {
  assert.deepEqual(parseTagInput('project=osmu, stage=raw').tags, [
    { key: 'project', value: 'osmu' },
    { key: 'stage', value: 'raw' },
  ])
})

test('tagPairsToMap converts parsed tags to JSON map', () => {
  const parsed = parseTagInput('project=osmu,stage=raw')

  assert.deepEqual(tagPairsToMap(parsed.tags), {
    project: 'osmu',
    stage: 'raw',
  })
})

test('tagsToInput formats object or pair tags', () => {
  assert.equal(tagsToInput({ project: 'osmu', stage: 'raw' }), 'project=osmu, stage=raw')
  assert.equal(tagsToInput([{ key: 'owner', value: 'platform' }]), 'owner=platform')
})

test('validateObjectTagInput enforces object tag limit', () => {
  const tags = Array.from({ length: 11 }, (_, index) => `k${index}=v`).join(',')

  assert.match(validateObjectTagInput(tags), /at most 10 pairs/)
})

test('validateBucketTagInput allows more than object tag limit but rejects duplicates', () => {
  const tags = Array.from({ length: 11 }, (_, index) => `k${index}=v`).join(',')

  assert.equal(validateBucketTagInput(tags).error, '')
  assert.match(validateBucketTagInput('project=osmu,project=copy').error, /Duplicate bucket tag key/)
})

test('parseTagInput rejects malformed and unsafe tags', () => {
  assert.match(parseTagInput('project').error, /key=value/)
  assert.match(parseTagInput('bad key=value').error, /can contain/)
  assert.match(parseTagInput('project=line\u0000break').error, /control characters/)
})

test('validateObjectTagMap rejects unsafe API tag maps', () => {
  assert.equal(validateObjectTagMap({ project: 'osmu', stage: 'raw' }), '')
  assert.match(validateObjectTagMap({ 'bad key': 'value' }), /can contain/)
  assert.match(validateObjectTagMap({ project: 'x'.repeat(257) }), /at most 256/)
  assert.match(validateObjectTagMap({ project: 123 }), /must be strings/)
})
