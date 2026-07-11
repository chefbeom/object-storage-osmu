import assert from 'node:assert/strict'
import test from 'node:test'

import { normalizeDashboardReadiness } from './dashboardReadiness.js'

test('normalizeDashboardReadiness supplies safe defaults', () => {
  const readiness = normalizeDashboardReadiness(null)

  assert.equal(readiness.status, 'UNKNOWN')
  assert.equal(readiness.runtimeProfile, '-')
  assert.deepEqual(readiness.items, [])
  assert.equal(readiness.operationsReadinessSummary.passedCount, 0)
  assert.deepEqual(readiness.operationsReadinessSummary.pendingCategoryCounts, [])
  assert.equal(readiness.operationsDispatchPreflight.gitRefSafety.aheadCount, 0)
  assert.equal(readiness.operationsReadinessConvergence.finalizerFailedCountValid, null)
  assert.equal(readiness.kubernetesOperationsReportSync.failedCount, 0)
})

test('normalizeDashboardReadiness coerces nested operations evidence fields', () => {
  const readiness = normalizeDashboardReadiness({
    status: 'REVIEW',
    blockerCount: '2',
    items: [{ code: 'OPERATIONS_READINESS_CHECK' }],
    operationsReadinessSummary: {
      result: 'pending',
      passedCount: '83',
      pendingCount: '19',
      pendingCategoryCounts: [{ category: 'ha-dr', count: '2' }],
    },
    operationsEvidencePlan: {
      actionSummary: { totalActions: '19' },
    },
    operationsDispatchPreflight: {
      gitRefSafety: {
        aheadCount: '5',
        workingTreeDirty: true,
      },
    },
    operationsReadinessConvergence: {
      finalizerFailedCountValid: false,
      kubernetesReportSyncFailedCountValid: true,
    },
    kubernetesOperationsReportSync: {
      publishDataFlowQueryRetentionBudgetToConfigMap: true,
      failedCount: '0',
    },
  })

  assert.equal(readiness.status, 'REVIEW')
  assert.equal(readiness.blockerCount, 2)
  assert.equal(readiness.operationsReadinessSummary.passedCount, 83)
  assert.deepEqual(
    readiness.operationsReadinessSummary.pendingCategoryCounts,
    [{ category: 'ha-dr', count: 2 }],
  )
  assert.equal(readiness.operationsEvidencePlan.actionSummary.totalActions, 19)
  assert.equal(readiness.operationsDispatchPreflight.gitRefSafety.aheadCount, 5)
  assert.equal(readiness.operationsDispatchPreflight.gitRefSafety.workingTreeDirty, true)
  assert.equal(readiness.operationsReadinessConvergence.finalizerFailedCountValid, false)
  assert.equal(readiness.operationsReadinessConvergence.kubernetesReportSyncFailedCountValid, true)
  assert.equal(readiness.kubernetesOperationsReportSync.publishDataFlowQueryRetentionBudgetToConfigMap, true)
  assert.equal(readiness.kubernetesOperationsReportSync.failedCount, 0)
})
