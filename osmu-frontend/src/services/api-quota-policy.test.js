import assert from 'node:assert/strict'
import test from 'node:test'
import {
  applyStorageExpansionExecutionRecord,
  clearAuthTokens,
  createStorageExpansionExecutionRecord,
  createStorageExpansionExecutionPlan,
  createStorageExpansionGitOpsPlan,
  createStorageExpansionRequest,
  deleteQuotaPolicy,
  downloadStorageExpansionGitOpsArtifactBundle,
  downloadStorageExpansionManifestArtifact,
  getQuotaPolicies,
  getQuotaPolicyHistory,
  getStorageExpansionExecutionLogRetentionStatus,
  getStorageExpansionExecutions,
  getStorageExpansionRequestManifest,
  getStorageExpansionRequests,
  getStorageExpansionRunnerPreflight,
  getStorageExpansionSummary,
  recordStorageExpansionDryRunExecution,
  recordStorageExpansionGitOpsPrExecution,
  runStorageExpansionApplyExecution,
  runStorageExpansionDryRunExecution,
  runStorageExpansionExecutionLogRetention,
  runStorageExpansionGitOpsPrExecution,
  runStorageExpansionRollbackExecution,
  saveQuotaPolicy,
  updateStorageExpansionRequestStatus,
} from './api.js'

test('quota policy wrappers use admin quota policy endpoints', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { targetType: 'USER', targetId: 7, quotaBytes: 1024 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await getQuotaPolicies()
    await getQuotaPolicyHistory(25)
    await saveQuotaPolicy('USER', 7, 1024, 'pilot quota')
    await deleteQuotaPolicy('USER', 7, 'pilot cleanup')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/quota-policies')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/quota-policies/history?limit=25')

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/admin/quota-policies/USER/7')
    assert.equal(fetchMock.calls[2].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), { quotaBytes: 1024, reason: 'pilot quota' })

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/admin/quota-policies/USER/7?reason=pilot%20cleanup')
    assert.equal(fetchMock.calls[3].options.method, 'DELETE')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('storage expansion wrappers use admin request endpoints', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 1, poolName: 'pool-1', status: 'PLANNED' } }),
    () => jsonResponse({ data: { requestId: 1, poolName: 'pool-1', referenceOnly: true } }),
    () => textResponse('kind: Tenant\nmetadata:\n  name: osmu-minio\n'),
    () => jsonResponse({ data: { requestId: 1, poolName: 'pool-1', ready: true, artifactSha256: 'abc' } }),
    () => jsonResponse({ data: { requestId: 1, poolName: 'pool-1', branchName: 'storage-expansion/pool-1' } }),
    () => jsonResponse({ data: { id: 1, requestId: 1, executionType: 'KUBECTL_DIFF', result: 'SUCCESS' } }),
    () => jsonResponse({ data: { id: 2, requestId: 1, executionType: 'KUBECTL_DIFF', result: 'SKIPPED', timedOut: false } }),
    () => jsonResponse({ data: { execution: { id: 3, requestId: 1, executionType: 'APPLY', result: 'SKIPPED', timedOut: false }, request: { id: 1, status: 'APPROVED' } } }),
    () => jsonResponse({ data: { id: 3, requestId: 1, executionType: 'GITOPS_PR', result: 'SKIPPED', timedOut: false } }),
    () => jsonResponse({ data: { id: 1, requestId: 1, executionType: 'GITOPS_PR', result: 'SUCCESS' } }),
    () => new Response('PK zip', { status: 200, headers: { 'Content-Type': 'application/zip' } }),
    () => jsonResponse({ items: [] }),
    () => jsonResponse({ data: { id: 1, requestId: 1, executionType: 'HELM_DIFF', result: 'SUCCESS' } }),
    () => jsonResponse({ data: { id: 1, poolName: 'pool-1', status: 'APPLIED' } }),
    () => jsonResponse({ data: { execution: { id: 4, requestId: 1, executionType: 'ROLLBACK', result: 'SKIPPED', timedOut: false }, request: { id: 1, status: 'APPLIED' } } }),
    () => jsonResponse({ data: { id: 1, poolName: 'pool-1', status: 'APPLIED' } }),
    () => jsonResponse({ data: { enabled: true, retentionDays: 90, batchSize: 100, pendingOutputCount: 0 } }),
    () => jsonResponse({ data: { redactedOutputCount: 0, status: { enabled: true } } }),
    () => jsonResponse({ data: { requestCount: 1, openRequestCount: 0, executionCount: 9, recentExecutions: [{ id: 4, executionType: 'ROLLBACK' }] } }),
    () => jsonResponse({ data: { status: 'DISABLED', ready: false, checks: [] } }),
  ])

  try {
    await getStorageExpansionRequests()
    await createStorageExpansionRequest({
      requestedCapacityBytes: 107374182400,
      serverCount: 4,
      volumesPerServer: 1,
      reason: 'media archive growth',
    })
    await getStorageExpansionRequestManifest(1)
    const tenantYaml = await downloadStorageExpansionManifestArtifact(1, 'tenant')
    await createStorageExpansionExecutionPlan(1)
    await createStorageExpansionGitOpsPlan(1)
    await recordStorageExpansionDryRunExecution(1, {
      executionType: 'KUBECTL_DIFF',
      result: 'SUCCESS',
      output: 'server-side diff clean',
      externalUrl: 'https://ci.example/osmu/storage-expansion/pool-1/dry-run',
      notes: 'checked',
    })
    await runStorageExpansionDryRunExecution(1, {
      executionType: 'KUBECTL_DIFF',
    })
    await runStorageExpansionApplyExecution(1, {
      applyType: 'KUBECTL_APPLY',
    })
    await runStorageExpansionGitOpsPrExecution(1)
    await recordStorageExpansionGitOpsPrExecution(1, {
      externalUrl: 'https://git.example/osmu/pull/42',
      mergeSha: 'abcdef1234567890',
      pipelineUrl: 'https://ci.example/osmu/storage-expansion/pool-1',
      notes: 'ready',
    })
    const gitOpsBundle = await downloadStorageExpansionGitOpsArtifactBundle(1)
    await getStorageExpansionExecutions(1)
    await createStorageExpansionExecutionRecord(1, {
      executionType: 'HELM_DIFF',
      result: 'SUCCESS',
      command: 'helm diff upgrade osmu-minio',
      output: 'No drift',
      externalUrl: 'https://git.example/osmu/pull/42',
      artifactSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      notes: 'reviewed',
    })
    await applyStorageExpansionExecutionRecord(1, 1)
    await runStorageExpansionRollbackExecution(1, {
      rollbackType: 'HELM_ROLLBACK',
      helmRevision: 1,
    })
    await updateStorageExpansionRequestStatus(1, 'APPLIED', 'helm upgrade osmu-minio --values pool-1.yaml')
    await getStorageExpansionExecutionLogRetentionStatus()
    await runStorageExpansionExecutionLogRetention()
    await getStorageExpansionSummary()
    await getStorageExpansionRunnerPreflight()
    assert.match(tenantYaml, /kind: Tenant/)
    assert.equal(gitOpsBundle.type, 'application/zip')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/storage-expansion/requests')
    assert.equal(fetchMock.calls[0].options.method, undefined)

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/storage-expansion/requests')
    assert.equal(fetchMock.calls[1].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[1].options.body).serverCount, 4)
    assert.equal(JSON.parse(fetchMock.calls[1].options.body).reason, 'media archive growth')

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/manifest')

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/manifest/tenant')

    assert.equal(fetchMock.calls[4].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/execution-plan')
    assert.equal(fetchMock.calls[4].options.method, 'POST')

    assert.equal(fetchMock.calls[5].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/gitops-plan')
    assert.equal(fetchMock.calls[5].options.method, 'POST')

    assert.equal(fetchMock.calls[6].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/dry-run-execution')
    assert.equal(fetchMock.calls[6].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[6].options.body).executionType, 'KUBECTL_DIFF')
    assert.equal(JSON.parse(fetchMock.calls[6].options.body).output, 'server-side diff clean')

    assert.equal(fetchMock.calls[7].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/dry-run-runner')
    assert.equal(fetchMock.calls[7].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[7].options.body).executionType, 'KUBECTL_DIFF')

    assert.equal(fetchMock.calls[8].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/apply-runner')
    assert.equal(fetchMock.calls[8].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[8].options.body).applyType, 'KUBECTL_APPLY')

    assert.equal(fetchMock.calls[9].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/gitops-pr-runner')
    assert.equal(fetchMock.calls[9].options.method, 'POST')

    assert.equal(fetchMock.calls[10].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/gitops-pr-execution')
    assert.equal(fetchMock.calls[10].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[10].options.body).externalUrl, 'https://git.example/osmu/pull/42')
    assert.equal(JSON.parse(fetchMock.calls[10].options.body).pipelineUrl, 'https://ci.example/osmu/storage-expansion/pool-1')

    assert.equal(fetchMock.calls[11].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/gitops-artifacts/bundle')
    assert.equal(fetchMock.calls[11].options.method, undefined)

    assert.equal(fetchMock.calls[12].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/executions')
    assert.equal(fetchMock.calls[12].options.method, undefined)

    assert.equal(fetchMock.calls[13].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/executions')
    assert.equal(fetchMock.calls[13].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[13].options.body).executionType, 'HELM_DIFF')
    assert.equal(JSON.parse(fetchMock.calls[13].options.body).artifactSha256, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')

    assert.equal(fetchMock.calls[14].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/executions/1/apply')
    assert.equal(fetchMock.calls[14].options.method, 'POST')

    assert.equal(fetchMock.calls[15].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/rollback-runner')
    assert.equal(fetchMock.calls[15].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[15].options.body).rollbackType, 'HELM_ROLLBACK')
    assert.equal(JSON.parse(fetchMock.calls[15].options.body).helmRevision, 1)

    assert.equal(fetchMock.calls[16].url, 'http://localhost:8080/api/admin/storage-expansion/requests/1/status')
    assert.equal(fetchMock.calls[16].options.method, 'PATCH')
    assert.deepEqual(JSON.parse(fetchMock.calls[16].options.body), {
      status: 'APPLIED',
      appliedEvidence: 'helm upgrade osmu-minio --values pool-1.yaml',
    })

    assert.equal(fetchMock.calls[17].url, 'http://localhost:8080/api/admin/storage-expansion/execution-log-retention/status')
    assert.equal(fetchMock.calls[17].options.method, undefined)

    assert.equal(fetchMock.calls[18].url, 'http://localhost:8080/api/admin/storage-expansion/execution-log-retention/run')
    assert.equal(fetchMock.calls[18].options.method, 'POST')

    assert.equal(fetchMock.calls[19].url, 'http://localhost:8080/api/admin/storage-expansion/summary')
    assert.equal(fetchMock.calls[19].options.method, undefined)

    assert.equal(fetchMock.calls[20].url, 'http://localhost:8080/api/admin/storage-expansion/runner-preflight')
    assert.equal(fetchMock.calls[20].options.method, undefined)
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

function textResponse(payload, status = 200) {
  return new Response(payload, {
    status,
    headers: { 'Content-Type': 'application/x-yaml' },
  })
}

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
