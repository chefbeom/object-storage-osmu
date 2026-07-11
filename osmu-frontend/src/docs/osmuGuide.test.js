import assert from 'node:assert/strict'
import test from 'node:test'
import {
  aiContextTemplate,
  documentationRoles,
  documentationSections,
  roleCapabilities,
} from './osmuGuide.js'

test('OSMU guide covers every product role and critical operating workflow', () => {
  const roleIds = documentationRoles.map((role) => role.id)
  assert.deepEqual(roleIds, ['ALL', 'USER', 'ADMIN', 'ORG_ADMIN', 'AUDITOR', 'AI'])

  for (const role of ['USER', 'ADMIN', 'ORG_ADMIN', 'AUDITOR', 'AI']) {
    assert.ok(
      documentationSections.some((section) => section.roles.includes(role)),
      `Missing guide content for ${role}`,
    )
  }

  for (const sectionId of [
    'start-here',
    'user-buckets',
    'developer-s3',
    'admin-layout',
    'auditor',
    'troubleshooting',
    'ai-contract',
    'production-readiness',
  ]) {
    const section = documentationSections.find((candidate) => candidate.id === sectionId)
    assert.ok(section, `Missing guide section ${sectionId}`)
    assert.ok(section.steps.length >= 4, `Guide section ${sectionId} needs actionable steps`)
  }

  assert.equal(roleCapabilities.length >= 6, true)
  assert.match(aiContextTemplate, /Storage Layout/)
  assert.match(aiContextTemplate, /UNVERIFIED\/PLANNED/)
  assert.match(aiContextTemplate, /role-based E2E/)
})
