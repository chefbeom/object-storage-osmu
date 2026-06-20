import assert from 'node:assert/strict'
import test from 'node:test'
import {
  approveBillingPricingPolicyProposal,
  approveBillingPricingPolicyProposalPriceList,
  approveChargebackInvoiceDraft,
  clearAuthTokens,
  completeOidcCallback,
  cleanupObjectShareLinks,
  createBillingPricingPolicyProposal,
  createChargebackInvoiceDrafts,
  applyDashboardLayoutPreset,
  createObjectShareLink,
  createDashboardLayoutPreset,
  createPresignedUploadUrl,
  deleteDashboardLayout,
  deleteDashboardLayoutDefault,
  deleteDashboardLayoutPreset,
  deleteObjectShareLink,
  downloadChargebackInvoiceDraftCsv,
  downloadChargebackPreviewCsv,
  downloadAuditLogsCsv,
  downloadDataFlowDailyRollupCsv,
  downloadMaterializedDataFlowDailyRollupCsv,
  downloadDataFlowMonitoringCsv,
  finalizeChargebackInvoiceDraft,
  exportDashboardLayoutPreset,
  exportDashboardLayoutPresetBundle,
  getAuditLogs,
  getBackupRestoreDrillEvidence,
  getBillingPricingPolicy,
  getBillingPricingPolicyProposals,
  getBuckets,
  getChargebackAlertNotificationPreview,
  getChargebackAlertNotificationOutbox,
  getChargebackAdapterRetryWorkerStatus,
  getChargebackAlerts,
  getChargebackFinalInvoices,
  getChargebackInvoiceDrafts,
  getChargebackPaymentProviderHandoffPreview,
  getChargebackPaymentProviderHandoffs,
  getChargebackPreview,
  getDashboardLayout,
  getDashboardLayoutDefaults,
  getDashboardLayoutPresets,
  getDashboardReadiness,
  getDashboardSummary,
  getDashboardWidgetCatalog,
  getDataFlowDailyRollup,
  getDataFlowRetentionStatus,
  getMaterializedDataFlowDailyRollup,
  getDataFlowMonitoring,
  getEnterpriseAuthPlan,
  getObjectMetadata,
  getObjectShareAnalytics,
  getObjectSharePolicy,
  getObjectShareLinks,
  getObjects,
  getOidcAuthorizationRequest,
  getS3ClientConfig,
  getTeams,
  getUsers,
  importDashboardLayoutPreset,
  importDashboardLayoutPresetBundle,
  loginWithLdap,
  materializeDataFlowDailyRollup,
  previewEnterpriseAuthClaims,
  provisionEnterpriseAuthUser,
  queueChargebackAlertNotifications,
  queueChargebackPaymentProviderHandoff,
  recordChargebackAlertNotificationAdapterResult,
  recordChargebackInvoicePayment,
  recordChargebackPaymentProviderHandoffAdapterResult,
  requestChargebackInvoicePayment,
  runChargebackAdapterRetryWorker,
  runDataFlowRetention,
  saveDashboardLayout,
  saveDashboardLayoutDefault,
  saveBillingPricingPolicy,
  saveObjectSharePolicy,
  sendChargebackAlertNotificationAdapter,
  sendChargebackPaymentProviderHandoffAdapter,
  updateDashboardLayoutPreset,
  updateObjectTags,
} from './api.js'

test('getDashboardSummary reads admin dashboard aggregate endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        usage: { totalQuotaBytes: 1024, usedBytes: 256 },
        system: { backend: 'UP', storage: 'UP', database: 'UP' },
        recentAuditLogs: { items: [], nextCursor: null },
      },
    }),
  ])

  try {
    const result = await getDashboardSummary()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/dashboard/summary')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.usage.usedBytes, 256)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getEnterpriseAuthPlan reads admin security plan endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        status: 'LOCAL_ONLY',
        currentLoginMode: 'LOCAL_PASSWORD',
        plannedExternalModes: ['OIDC', 'LDAP'],
      },
    }),
  ])

  try {
    const result = await getEnterpriseAuthPlan()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/security/enterprise-auth-plan')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.currentLoginMode, 'LOCAL_PASSWORD')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('previewEnterpriseAuthClaims posts sample claims for admin review', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        status: 'MATCHED_EXISTING_USER',
        email: 'admin@example.com',
        primaryRole: 'ADMIN',
        auditLogId: 12,
      },
    }),
  ])

  try {
    const result = await previewEnterpriseAuthClaims({
      sub: 'oidc-admin-1',
      email: 'admin@example.com',
      osmu_roles: ['osmu-admins'],
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/security/enterprise-auth/claim-preview')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), {
      claims: {
        sub: 'oidc-admin-1',
        email: 'admin@example.com',
        osmu_roles: ['osmu-admins'],
      },
    })
    assert.equal(result.data.primaryRole, 'ADMIN')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('provisionEnterpriseAuthUser posts admin-approved OIDC JIT payload', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        status: 'PROVISIONED',
        user: { loginId: 'jit.user', email: 'jit.user@example.com', role: 'USER' },
        approvedRole: 'USER',
        auditLogId: 21,
      },
    }),
  ])

  try {
    const payload = {
      claims: {
        sub: 'oidc-user-1',
        email: 'jit.user@example.com',
        osmu_roles: ['external-users'],
      },
      approvedRole: 'USER',
      approvePrivilegedRole: false,
      reason: 'pilot onboarding',
    }
    const result = await provisionEnterpriseAuthUser(payload)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/security/enterprise-auth/jit-provision')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), payload)
    assert.equal(result.data.user.loginId, 'jit.user')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('loginWithLdap posts LDAP credentials to public login adapter', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        accessToken: 'jwt',
        refreshToken: 'refresh',
        user: { loginId: 'admin', role: 'ADMIN' },
      },
    }),
  ])

  try {
    const result = await loginWithLdap('admin', 'ldap password')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/auth/ldap/login')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), {
      loginId: 'admin',
      password: 'ldap password',
    })
    assert.equal(result.data.user.role, 'ADMIN')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getOidcAuthorizationRequest reads public OIDC start endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        authorizationUrl: 'https://idp.example.com/auth?response_type=code',
        state: 'state-1',
        nonce: 'nonce-1',
        codeChallenge: 'challenge-1',
        codeChallengeMethod: 'S256',
        redirectUri: 'http://localhost:5173/auth/oidc/callback',
        scopes: ['openid', 'profile', 'email'],
      },
    }),
  ])

  try {
    const result = await getOidcAuthorizationRequest()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/auth/oidc/authorize')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.codeChallengeMethod, 'S256')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('completeOidcCallback reads public OIDC callback endpoint with code and state', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        accessToken: 'jwt',
        refreshToken: 'refresh',
        user: { loginId: 'admin', role: 'ADMIN' },
      },
    }),
  ])

  try {
    const result = await completeOidcCallback('auth code', 'state 1')

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/auth/oidc/callback')
    assert.equal(url.searchParams.get('code'), 'auth code')
    assert.equal(url.searchParams.get('state'), 'state 1')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.user.role, 'ADMIN')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getDashboardReadiness reads focused readiness endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        status: 'REVIEW',
        generatedAt: '2026-06-15T01:00:00Z',
        severitySummaries: [{ severity: 'WARNING', totalCount: 1 }],
        categorySummaries: [{ category: 'STORAGE', totalCount: 1, blockerCount: 0, warningCount: 1 }],
        items: [{ category: 'STORAGE', code: 'NO_BUCKET', targetPanel: 'storage-buckets' }],
      },
    }),
  ])

  try {
    const result = await getDashboardReadiness()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/dashboard/readiness')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.generatedAt, '2026-06-15T01:00:00Z')
    assert.equal(result.data.severitySummaries[0].severity, 'WARNING')
    assert.equal(result.data.categorySummaries[0].category, 'STORAGE')
    assert.equal(result.data.items[0].category, 'STORAGE')
    assert.equal(result.data.items[0].targetPanel, 'storage-buckets')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getDataFlowMonitoring reads admin data flow endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        traffic: { uploadedBytes: 1024, downloadedBytes: 256, copiedBytes: 128, internalBytes: 128 },
        operations: { uploadCount: 1, downloadCount: 1, copyCount: 1, failureCount: 0 },
        topBuckets: [],
        trendPoints: [{ bucketStartAt: '2026-06-18T00:00:00Z', source: 'rest', operation: 'upload', totalCount: 1 }],
        recentEvents: [],
      },
    }),
  ])

  try {
    const result = await getDataFlowMonitoring({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/admin/monitoring/data-flow')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.traffic.uploadedBytes, 1024)
    assert.equal(result.data.traffic.copiedBytes, 128)
    assert.equal(result.data.trendPoints[0].operation, 'upload')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getDataFlowDailyRollup reads admin daily data flow rollup endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DATA_FLOW_DAILY_ROLLUP',
        granularity: 'UTC_DAY',
        dayWindow: 30,
        pointLimit: 25,
        points: [{ day: '2026-06-18', bucketName: 'media', source: 'rest', operation: 'upload', totalBytes: 1024 }],
      },
    }),
  ])

  try {
    const result = await getDataFlowDailyRollup({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      days: 30,
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/admin/monitoring/data-flow/daily-rollup')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('days'), '30')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.mode, 'DATA_FLOW_DAILY_ROLLUP')
    assert.equal(result.data.points[0].totalBytes, 1024)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('materializeDataFlowDailyRollup posts admin daily rollup refresh request', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION',
        granularity: 'UTC_DAY',
        storedPointCount: 1,
        points: [{ day: '2026-06-18', bucketName: 'media', source: 'rest', operation: 'upload', totalBytes: 1024 }],
      },
    }),
  ])

  try {
    const result = await materializeDataFlowDailyRollup({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      days: 30,
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/admin/monitoring/data-flow/daily-rollup/materialize')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('days'), '30')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.equal(result.data.mode, 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION')
    assert.equal(result.data.storedPointCount, 1)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getMaterializedDataFlowDailyRollup reads stored admin daily rollup endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZED',
        granularity: 'UTC_DAY',
        pointCount: 1,
        points: [{ day: '2026-06-18', bucketName: 'media', source: 'rest', operation: 'upload', totalBytes: 1024 }],
      },
    }),
  ])

  try {
    const result = await getMaterializedDataFlowDailyRollup({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      days: 30,
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/admin/monitoring/data-flow/daily-rollup/materialized')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('days'), '30')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.mode, 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZED')
    assert.equal(result.data.pointCount, 1)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getDataFlowRetentionStatus reads admin data flow retention status endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DATA_FLOW_RETENTION',
        eventRetention: { enabled: true, jobAvailable: true, retentionDays: 90, batchSize: 1000 },
        dailyRollupRetention: { enabled: true, jobAvailable: true, retentionDays: 1095, batchSize: 1000 },
      },
    }),
  ])

  try {
    const result = await getDataFlowRetentionStatus()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/monitoring/data-flow/retention/status')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.mode, 'DATA_FLOW_RETENTION')
    assert.equal(result.data.dailyRollupRetention.retentionDays, 1095)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('runDataFlowRetention posts selected retention targets', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DATA_FLOW_RETENTION',
        deletedEventCount: 0,
        deletedDailyRollupCount: 1,
      },
    }),
  ])

  try {
    const result = await runDataFlowRetention({
      includeEvents: false,
      includeDailyRollups: true,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.origin + url.pathname, 'http://localhost:8080/api/admin/monitoring/data-flow/retention/run')
    assert.equal(url.searchParams.get('includeEvents'), 'false')
    assert.equal(url.searchParams.get('includeDailyRollups'), 'true')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.equal(result.data.deletedDailyRollupCount, 1)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadDataFlowMonitoringCsv uses export endpoint and returns CSV blob', async () => {
  const fetchMock = mockFetch([
    () => new Response('createdAt,eventType\n2026-06-18T00:00:00Z,UPLOAD\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadDataFlowMonitoringCsv({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/monitoring/data-flow/export.csv')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(await blob.text(), 'createdAt,eventType\n2026-06-18T00:00:00Z,UPLOAD\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadDataFlowDailyRollupCsv uses rollup export endpoint and returns CSV blob', async () => {
  const fetchMock = mockFetch([
    () => new Response('day,bucketName,totalBytes\n2026-06-18,media,1024\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadDataFlowDailyRollupCsv({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      days: 30,
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/monitoring/data-flow/daily-rollup/export.csv')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('days'), '30')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(await blob.text(), 'day,bucketName,totalBytes\n2026-06-18,media,1024\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadMaterializedDataFlowDailyRollupCsv uses stored rollup export endpoint and returns CSV blob', async () => {
  const fetchMock = mockFetch([
    () => new Response('day,bucketName,totalBytes\n2026-06-18,media,1024\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadMaterializedDataFlowDailyRollupCsv({
      bucketName: 'media',
      actorId: 'admin',
      source: 'rest',
      operation: 'upload',
      status: 'SUCCESS',
      from: '2026-06-18T00:00:00.000Z',
      to: '2026-06-19T00:00:00.000Z',
      days: 30,
      limit: 25,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/monitoring/data-flow/daily-rollup/materialized/export.csv')
    assert.equal(url.searchParams.get('bucketName'), 'media')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('source'), 'rest')
    assert.equal(url.searchParams.get('operation'), 'upload')
    assert.equal(url.searchParams.get('status'), 'SUCCESS')
    assert.equal(url.searchParams.get('from'), '2026-06-18T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-19T00:00:00.000Z')
    assert.equal(url.searchParams.get('days'), '30')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(await blob.text(), 'day,bucketName,totalBytes\n2026-06-18,media,1024\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getChargebackPreview reads admin billing preview endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        currency: 'KRW',
        rates: { storageGbMonthRate: 1, ingressGbRate: 2 },
        organizations: [{ organizationName: 'Media', estimatedTotalCost: 25 }],
      },
    }),
  ])

  try {
    const result = await getChargebackPreview({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      eventScanLimit: 2500,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/billing/chargeback-preview')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(url.searchParams.get('currency'), 'krw')
    assert.equal(url.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(url.searchParams.get('ingressGbRate'), '0.10')
    assert.equal(url.searchParams.get('egressGbRate'), '0.20')
    assert.equal(url.searchParams.get('internalGbRate'), '0.05')
    assert.equal(url.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(url.searchParams.get('eventScanLimit'), '2500')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.currency, 'KRW')
    assert.equal(result.data.organizations[0].estimatedTotalCost, 25)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadChargebackPreviewCsv exports current admin billing preview query', async () => {
  const fetchMock = mockFetch([
    () => new Response('rowType,currency\nTOTAL,KRW\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadChargebackPreviewCsv({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      eventScanLimit: 2500,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/billing/chargeback-preview/export.csv')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(url.searchParams.get('currency'), 'krw')
    assert.equal(url.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(url.searchParams.get('ingressGbRate'), '0.10')
    assert.equal(url.searchParams.get('egressGbRate'), '0.20')
    assert.equal(url.searchParams.get('internalGbRate'), '0.05')
    assert.equal(url.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(url.searchParams.get('eventScanLimit'), '2500')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(await blob.text(), 'rowType,currency\nTOTAL,KRW\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadChargebackInvoiceDraftCsv exports current admin billing invoice draft query', async () => {
  const fetchMock = mockFetch([
    () => new Response('rowType,invoiceStatus\nDRAFT_INVOICE,DRAFT\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadChargebackInvoiceDraftCsv({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      eventScanLimit: 2500,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/billing/chargeback-invoice-draft/export.csv')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(url.searchParams.get('currency'), 'krw')
    assert.equal(url.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(url.searchParams.get('ingressGbRate'), '0.10')
    assert.equal(url.searchParams.get('egressGbRate'), '0.20')
    assert.equal(url.searchParams.get('internalGbRate'), '0.05')
    assert.equal(url.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(url.searchParams.get('eventScanLimit'), '2500')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(await blob.text(), 'rowType,invoiceStatus\nDRAFT_INVOICE,DRAFT\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getChargebackAlerts reads current admin billing threshold alerts query', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        currency: 'KRW',
        warningAmount: 20,
        criticalAmount: 25,
        alertCount: 1,
        organizations: [{ organizationName: 'Media', severity: 'CRITICAL' }],
      },
    }),
  ])

  try {
    const result = await getChargebackAlerts({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      eventScanLimit: 2500,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/billing/chargeback-alerts')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(url.searchParams.get('currency'), 'krw')
    assert.equal(url.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(url.searchParams.get('ingressGbRate'), '0.10')
    assert.equal(url.searchParams.get('egressGbRate'), '0.20')
    assert.equal(url.searchParams.get('internalGbRate'), '0.05')
    assert.equal(url.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(url.searchParams.get('eventScanLimit'), '2500')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.alertCount, 1)
    assert.equal(result.data.organizations[0].severity, 'CRITICAL')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getChargebackAlertNotificationPreview reads scoped billing alert notification payload query', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'PREVIEW',
        channel: 'SLACK',
        target: 'ops-webhook',
        externalDeliveryEnabled: false,
        notificationCount: 1,
        notifications: [{ organizationName: 'Media', severity: 'CRITICAL' }],
      },
    }),
  ])

  try {
    const result = await getChargebackAlertNotificationPreview({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      eventScanLimit: 2500,
      notificationChannel: 'slack',
      notificationTarget: 'ops-webhook',
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/billing/chargeback-alert-notifications/preview')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(url.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(url.searchParams.get('currency'), 'krw')
    assert.equal(url.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(url.searchParams.get('ingressGbRate'), '0.10')
    assert.equal(url.searchParams.get('egressGbRate'), '0.20')
    assert.equal(url.searchParams.get('internalGbRate'), '0.05')
    assert.equal(url.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(url.searchParams.get('eventScanLimit'), '2500')
    assert.equal(url.searchParams.get('notificationChannel'), 'slack')
    assert.equal(url.searchParams.get('notificationTarget'), 'ops-webhook')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.mode, 'PREVIEW')
    assert.equal(result.data.notificationCount, 1)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('chargeback alert notification outbox wrappers queue and read delivery records', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'OUTBOX',
        status: 'PENDING_DELIVERY_ADAPTER',
        queuedCount: 1,
        deliveries: [{ organizationName: 'Media', status: 'PENDING_DELIVERY_ADAPTER' }],
      },
    }),
    () => jsonResponse({
      data: {
        deliveryCount: 1,
        deliveries: [{ organizationName: 'Media', status: 'PENDING_DELIVERY_ADAPTER' }],
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RESULT',
        status: 'DELIVERY_ADAPTER_RETRY_SCHEDULED',
        externalDeliveryEnabled: false,
        delivery: { id: 3, attemptCount: 1, status: 'DELIVERY_ADAPTER_RETRY_SCHEDULED' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RESULT',
        status: 'DELIVERY_ADAPTER_SUCCEEDED',
        externalDeliveryEnabled: true,
        delivery: { id: 3, attemptCount: 2, status: 'DELIVERY_ADAPTER_SUCCEEDED' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RETRY_WORKER',
        dryRun: true,
        externalAdaptersEnabled: false,
        notificationCandidateCount: 1,
        paymentCandidateCount: 0,
        updatedCount: 0,
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RETRY_WORKER',
        dryRun: false,
        externalAdaptersEnabled: false,
        updatedCount: 1,
      },
    }),
  ])

  try {
    const queued = await queueChargebackAlertNotifications({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      storageGbMonthRate: '1.25',
      notificationChannel: 'slack',
      notificationTarget: 'ops-webhook',
      reason: 'review send',
    })
    const outbox = await getChargebackAlertNotificationOutbox({ limit: 25 })
    const adapterResult = await recordChargebackAlertNotificationAdapterResult(3, {
      result: 'RETRY',
      retryDelayMinutes: 60,
      lastError: 'adapter endpoint not ready',
    })
    const adapterSend = await sendChargebackAlertNotificationAdapter(3, { retryDelayMinutes: 120 })
    const workerStatus = await getChargebackAdapterRetryWorkerStatus({ limit: 25 })
    const workerRun = await runChargebackAdapterRetryWorker({ dryRun: false, limit: 25 })

    const queueUrl = new URL(fetchMock.calls[0].url)
    assert.equal(queueUrl.pathname, '/api/admin/billing/chargeback-alert-notifications/outbox')
    assert.equal(queueUrl.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(queueUrl.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(queueUrl.searchParams.get('currency'), 'krw')
    assert.equal(queueUrl.searchParams.get('storageGbMonthRate'), '1.25')
    assert.equal(queueUrl.searchParams.get('notificationChannel'), 'slack')
    assert.equal(queueUrl.searchParams.get('notificationTarget'), 'ops-webhook')
    assert.equal(queueUrl.searchParams.get('reason'), 'review send')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.equal(queued.data.status, 'PENDING_DELIVERY_ADAPTER')

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/admin/billing/chargeback-alert-notifications/outbox')
    assert.equal(listUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[1].options.method, undefined)
    assert.equal(outbox.data.deliveryCount, 1)

    const adapterUrl = new URL(fetchMock.calls[2].url)
    assert.equal(adapterUrl.pathname, '/api/admin/billing/chargeback-alert-notifications/outbox/3/adapter-result')
    assert.equal(adapterUrl.searchParams.get('result'), 'RETRY')
    assert.equal(adapterUrl.searchParams.get('retryDelayMinutes'), '60')
    assert.equal(adapterUrl.searchParams.get('lastError'), 'adapter endpoint not ready')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.equal(adapterResult.data.status, 'DELIVERY_ADAPTER_RETRY_SCHEDULED')

    const adapterSendUrl = new URL(fetchMock.calls[3].url)
    assert.equal(adapterSendUrl.pathname, '/api/admin/billing/chargeback-alert-notifications/outbox/3/adapter-send')
    assert.equal(adapterSendUrl.searchParams.get('retryDelayMinutes'), '120')
    assert.equal(fetchMock.calls[3].options.method, 'POST')
    assert.equal(adapterSend.data.status, 'DELIVERY_ADAPTER_SUCCEEDED')

    const workerStatusUrl = new URL(fetchMock.calls[4].url)
    assert.equal(workerStatusUrl.pathname, '/api/admin/billing/chargeback-adapter-retry-worker/status')
    assert.equal(workerStatusUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[4].options.method, undefined)
    assert.equal(workerStatus.data.mode, 'ADAPTER_RETRY_WORKER')

    const workerRunUrl = new URL(fetchMock.calls[5].url)
    assert.equal(workerRunUrl.pathname, '/api/admin/billing/chargeback-adapter-retry-worker/run')
    assert.equal(workerRunUrl.searchParams.get('dryRun'), 'false')
    assert.equal(workerRunUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[5].options.method, 'POST')
    assert.equal(workerRun.data.updatedCount, 1)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('chargeback invoice draft wrappers create list and approve internal review records', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'DRAFT_REVIEW',
        status: 'DRAFT_REVIEW',
        persistedCount: 1,
        invoices: [{ id: 7, organizationName: 'Media', status: 'DRAFT_REVIEW' }],
      },
    }),
    () => jsonResponse({
      data: {
        invoiceCount: 1,
        invoices: [{ id: 7, organizationName: 'Media', status: 'DRAFT_REVIEW' }],
      },
    }),
    () => jsonResponse({
      data: {
        status: 'APPROVED_INTERNAL',
        invoice: { id: 7, organizationName: 'Media', status: 'APPROVED_INTERNAL' },
      },
    }),
  ])

  try {
    const created = await createChargebackInvoiceDrafts({
      from: '2026-06-01T00:00:00.000Z',
      to: '2026-06-30T23:59:59.000Z',
      currency: 'krw',
      operationThousandRate: '0.01',
      reason: 'monthly review',
    })
    const listed = await getChargebackInvoiceDrafts({ status: 'DRAFT_REVIEW', limit: 25 })
    const approved = await approveChargebackInvoiceDraft(7, { approvalNote: 'approved' })

    const createUrl = new URL(fetchMock.calls[0].url)
    assert.equal(createUrl.pathname, '/api/admin/billing/chargeback-invoice-drafts')
    assert.equal(createUrl.searchParams.get('from'), '2026-06-01T00:00:00.000Z')
    assert.equal(createUrl.searchParams.get('to'), '2026-06-30T23:59:59.000Z')
    assert.equal(createUrl.searchParams.get('currency'), 'krw')
    assert.equal(createUrl.searchParams.get('operationThousandRate'), '0.01')
    assert.equal(createUrl.searchParams.get('reason'), 'monthly review')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.equal(created.data.status, 'DRAFT_REVIEW')

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/admin/billing/chargeback-invoice-drafts')
    assert.equal(listUrl.searchParams.get('status'), 'DRAFT_REVIEW')
    assert.equal(listUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[1].options.method, undefined)
    assert.equal(listed.data.invoiceCount, 1)

    const approveUrl = new URL(fetchMock.calls[2].url)
    assert.equal(approveUrl.pathname, '/api/admin/billing/chargeback-invoice-drafts/7/approve')
    assert.equal(approveUrl.searchParams.get('approvalNote'), 'approved')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.equal(approved.data.status, 'APPROVED_INTERNAL')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('chargeback final invoice wrappers finalize update payment status and queue provider handoff', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        mode: 'FINAL_INVOICE',
        status: 'FINALIZED',
        paymentStatus: 'NOT_REQUESTED',
        invoice: { id: 9, sourceDraftId: 7, invoiceNumber: 'OSMU-FINAL-20260620-1' },
      },
    }),
    () => jsonResponse({
      data: {
        invoiceCount: 1,
        invoices: [{ id: 9, status: 'FINALIZED', paymentStatus: 'NOT_REQUESTED' }],
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'PAYMENT_REQUEST',
        status: 'PAYMENT_REQUESTED',
        paymentStatus: 'REQUESTED',
        invoice: { id: 9, paymentRequestedBy: 'admin' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'PREVIEW',
        provider: 'MANUAL_AP',
        targetAccount: 'finance-ap',
        externalPaymentEnabled: false,
        invoice: { id: 9, invoiceNumber: 'OSMU-FINAL-20260620-1' },
        payload: { eventType: 'chargeback.payment_provider.handoff' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'OUTBOX',
        status: 'PENDING_PAYMENT_PROVIDER_ADAPTER',
        externalPaymentEnabled: false,
        handoff: { id: 3, finalInvoiceId: 9, provider: 'MANUAL_AP' },
      },
    }),
    () => jsonResponse({
      data: {
        handoffCount: 1,
        handoffs: [{ id: 3, status: 'PENDING_PAYMENT_PROVIDER_ADAPTER', provider: 'MANUAL_AP' }],
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RESULT',
        status: 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL',
        externalPaymentEnabled: false,
        handoff: { id: 3, attemptCount: 1, status: 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'ADAPTER_RESULT',
        status: 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED',
        externalPaymentEnabled: true,
        handoff: { id: 3, attemptCount: 2, status: 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED' },
      },
    }),
    () => jsonResponse({
      data: {
        mode: 'PAYMENT_RECORD',
        status: 'PAID',
        paymentStatus: 'PAID',
        invoice: { id: 9, paymentReference: 'PAY-2026-0001' },
      },
    }),
  ])

  try {
    const finalized = await finalizeChargebackInvoiceDraft(7, { finalizationNote: 'finalize' })
    const listed = await getChargebackFinalInvoices({ status: 'FINALIZED', limit: 25 })
    const requested = await requestChargebackInvoicePayment(9, { paymentRequestNote: 'send request' })
    const handoffPreview = await getChargebackPaymentProviderHandoffPreview(9, {
      paymentProvider: 'manual_ap',
      paymentTargetAccount: 'finance-ap',
    })
    const queuedHandoff = await queueChargebackPaymentProviderHandoff(9, {
      paymentProvider: 'manual_ap',
      paymentTargetAccount: 'finance-ap',
      reason: 'handoff',
    })
    const handoffs = await getChargebackPaymentProviderHandoffs({
      status: 'PENDING_PAYMENT_PROVIDER_ADAPTER',
      limit: 25,
    })
    const handoffAdapterResult = await recordChargebackPaymentProviderHandoffAdapterResult(3, {
      result: 'BLOCKED_CREDENTIAL',
      lastError: 'adapter configuration pending',
    })
    const handoffAdapterSend = await sendChargebackPaymentProviderHandoffAdapter(3, { retryDelayMinutes: 90 })
    const paid = await recordChargebackInvoicePayment(9, {
      paymentReference: 'PAY-2026-0001',
      paymentNote: 'paid',
    })

    const finalizeUrl = new URL(fetchMock.calls[0].url)
    assert.equal(finalizeUrl.pathname, '/api/admin/billing/chargeback-invoice-drafts/7/finalize')
    assert.equal(finalizeUrl.searchParams.get('finalizationNote'), 'finalize')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.equal(finalized.data.status, 'FINALIZED')

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/admin/billing/chargeback-invoices')
    assert.equal(listUrl.searchParams.get('status'), 'FINALIZED')
    assert.equal(listUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[1].options.method, undefined)
    assert.equal(listed.data.invoiceCount, 1)

    const requestUrl = new URL(fetchMock.calls[2].url)
    assert.equal(requestUrl.pathname, '/api/admin/billing/chargeback-invoices/9/payment-request')
    assert.equal(requestUrl.searchParams.get('paymentRequestNote'), 'send request')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.equal(requested.data.paymentStatus, 'REQUESTED')

    const handoffPreviewUrl = new URL(fetchMock.calls[3].url)
    assert.equal(handoffPreviewUrl.pathname, '/api/admin/billing/chargeback-invoices/9/payment-provider-handoff/preview')
    assert.equal(handoffPreviewUrl.searchParams.get('paymentProvider'), 'manual_ap')
    assert.equal(handoffPreviewUrl.searchParams.get('paymentTargetAccount'), 'finance-ap')
    assert.equal(fetchMock.calls[3].options.method, undefined)
    assert.equal(handoffPreview.data.externalPaymentEnabled, false)

    const queueHandoffUrl = new URL(fetchMock.calls[4].url)
    assert.equal(queueHandoffUrl.pathname, '/api/admin/billing/chargeback-invoices/9/payment-provider-handoff')
    assert.equal(queueHandoffUrl.searchParams.get('paymentProvider'), 'manual_ap')
    assert.equal(queueHandoffUrl.searchParams.get('paymentTargetAccount'), 'finance-ap')
    assert.equal(queueHandoffUrl.searchParams.get('reason'), 'handoff')
    assert.equal(fetchMock.calls[4].options.method, 'POST')
    assert.equal(queuedHandoff.data.status, 'PENDING_PAYMENT_PROVIDER_ADAPTER')

    const handoffListUrl = new URL(fetchMock.calls[5].url)
    assert.equal(handoffListUrl.pathname, '/api/admin/billing/chargeback-payment-provider-handoffs')
    assert.equal(handoffListUrl.searchParams.get('status'), 'PENDING_PAYMENT_PROVIDER_ADAPTER')
    assert.equal(handoffListUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[5].options.method, undefined)
    assert.equal(handoffs.data.handoffCount, 1)

    const handoffAdapterUrl = new URL(fetchMock.calls[6].url)
    assert.equal(handoffAdapterUrl.pathname, '/api/admin/billing/chargeback-payment-provider-handoffs/3/adapter-result')
    assert.equal(handoffAdapterUrl.searchParams.get('result'), 'BLOCKED_CREDENTIAL')
    assert.equal(handoffAdapterUrl.searchParams.get('lastError'), 'adapter configuration pending')
    assert.equal(fetchMock.calls[6].options.method, 'POST')
    assert.equal(handoffAdapterResult.data.status, 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL')

    const handoffAdapterSendUrl = new URL(fetchMock.calls[7].url)
    assert.equal(handoffAdapterSendUrl.pathname, '/api/admin/billing/chargeback-payment-provider-handoffs/3/adapter-send')
    assert.equal(handoffAdapterSendUrl.searchParams.get('retryDelayMinutes'), '90')
    assert.equal(fetchMock.calls[7].options.method, 'POST')
    assert.equal(handoffAdapterSend.data.status, 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED')

    const recordUrl = new URL(fetchMock.calls[8].url)
    assert.equal(recordUrl.pathname, '/api/admin/billing/chargeback-invoices/9/payment-record')
    assert.equal(recordUrl.searchParams.get('paymentReference'), 'PAY-2026-0001')
    assert.equal(recordUrl.searchParams.get('paymentNote'), 'paid')
    assert.equal(fetchMock.calls[8].options.method, 'POST')
    assert.equal(paid.data.paymentStatus, 'PAID')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('billing pricing policy wrappers read and save admin billing policy endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        currency: 'USD',
        storageGbMonthRate: 0.02,
        warningAmount: 20,
        criticalAmount: 25,
        eventScanLimit: 10000,
      },
    }),
    () => jsonResponse({
      data: {
        currency: 'KRW',
        storageGbMonthRate: 1.25,
        warningAmount: 2000,
        criticalAmount: 3000,
        eventScanLimit: 2500,
      },
    }),
  ])

  try {
    const current = await getBillingPricingPolicy()
    const saved = await saveBillingPricingPolicy({
      currency: 'KRW',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      warningAmount: '2000',
      criticalAmount: '3000',
      eventScanLimit: 2500,
      reason: 'unit test',
    })

    assert.equal(new URL(fetchMock.calls[0].url).pathname, '/api/admin/billing/pricing-policy')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(new URL(fetchMock.calls[1].url).pathname, '/api/admin/billing/pricing-policy')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      currency: 'KRW',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      egressGbRate: '0.20',
      internalGbRate: '0.05',
      operationThousandRate: '0.01',
      warningAmount: '2000',
      criticalAmount: '3000',
      eventScanLimit: 2500,
      reason: 'unit test',
    })
    assert.equal(current.data.currency, 'USD')
    assert.equal(saved.data.currency, 'KRW')
    assert.equal(saved.data.criticalAmount, 3000)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('billing pricing policy proposal wrappers create list and approve internal policy records', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        status: 'PENDING_APPROVAL',
        approvedPriceList: false,
        proposal: { id: 11, status: 'PENDING_APPROVAL', currency: 'KRW' },
      },
    }),
    () => jsonResponse({
      data: {
        proposalCount: 1,
        proposals: [{ id: 11, status: 'PENDING_APPROVAL', currency: 'KRW' }],
      },
    }),
    () => jsonResponse({
      data: {
        status: 'APPROVED_APPLIED',
        approvedPriceList: false,
        proposal: { id: 11, status: 'APPROVED_APPLIED', currency: 'KRW' },
        appliedPolicy: { currency: 'KRW', storageGbMonthRate: 1.25 },
      },
    }),
    () => jsonResponse({
      data: {
        status: 'PRICE_LIST_APPROVED',
        approvedPriceList: true,
        proposal: {
          id: 11,
          status: 'PRICE_LIST_APPROVED',
          approvedPriceList: true,
          commercialApprovalReference: 'LEGAL-2026-0001',
        },
        appliedPolicy: { currency: 'KRW', storageGbMonthRate: 1.25 },
      },
    }),
  ])

  try {
    const created = await createBillingPricingPolicyProposal({
      currency: 'KRW',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      operationThousandRate: '0.01',
      warningAmount: '2000',
      criticalAmount: '3000',
      eventScanLimit: 2500,
      reason: 'proposal unit test',
    })
    const listed = await getBillingPricingPolicyProposals({ status: 'PENDING_APPROVAL', limit: 25 })
    const approved = await approveBillingPricingPolicyProposal(11, { approvalNote: 'approved' })
    const priceListApproved = await approveBillingPricingPolicyProposalPriceList(11, {
      approvalReference: 'LEGAL-2026-0001',
      approvalNote: 'commercial approved',
      effectiveFrom: '2026-06-20T00:00:00Z',
    })

    assert.equal(new URL(fetchMock.calls[0].url).pathname, '/api/admin/billing/pricing-policy-proposals')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), {
      currency: 'KRW',
      storageGbMonthRate: '1.25',
      ingressGbRate: '0.10',
      operationThousandRate: '0.01',
      warningAmount: '2000',
      criticalAmount: '3000',
      eventScanLimit: 2500,
      reason: 'proposal unit test',
    })
    assert.equal(created.data.status, 'PENDING_APPROVAL')
    assert.equal(created.data.approvedPriceList, false)

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/admin/billing/pricing-policy-proposals')
    assert.equal(listUrl.searchParams.get('status'), 'PENDING_APPROVAL')
    assert.equal(listUrl.searchParams.get('limit'), '25')
    assert.equal(fetchMock.calls[1].options.method, undefined)
    assert.equal(listed.data.proposalCount, 1)

    const approveUrl = new URL(fetchMock.calls[2].url)
    assert.equal(approveUrl.pathname, '/api/admin/billing/pricing-policy-proposals/11/approve')
    assert.equal(approveUrl.searchParams.get('approvalNote'), 'approved')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.equal(approved.data.status, 'APPROVED_APPLIED')
    assert.equal(approved.data.approvedPriceList, false)
    assert.equal(approved.data.appliedPolicy.currency, 'KRW')

    const priceListApproveUrl = new URL(fetchMock.calls[3].url)
    assert.equal(priceListApproveUrl.pathname, '/api/admin/billing/pricing-policy-proposals/11/commercial-approval')
    assert.equal(priceListApproveUrl.searchParams.get('approvalReference'), 'LEGAL-2026-0001')
    assert.equal(priceListApproveUrl.searchParams.get('approvalNote'), 'commercial approved')
    assert.equal(priceListApproveUrl.searchParams.get('effectiveFrom'), '2026-06-20T00:00:00Z')
    assert.equal(fetchMock.calls[3].options.method, 'POST')
    assert.equal(priceListApproved.data.status, 'PRICE_LIST_APPROVED')
    assert.equal(priceListApproved.data.approvedPriceList, true)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getBackupRestoreDrillEvidence reads filtered restore drill evidence history', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      items: [
        {
          auditLogId: 7,
          environment: 'kubernetes-drill',
          result: 'SUCCESS',
          recordedAt: '2026-06-15T01:00:00Z',
        },
      ],
      nextCursor: null,
    }),
  ])

  try {
    const result = await getBackupRestoreDrillEvidence({ result: 'SUCCESS', limit: 5 })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/backup/restore-drill-evidence?result=SUCCESS&limit=5')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.items[0].environment, 'kubernetes-drill')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('dashboard layout wrappers read save and reset current user layout', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { scope: 'main', source: 'DEFAULT', schemaVersion: 'osmu.dashboard-layout.v1', widgets: [], sections: [{ id: 'overview', collapsed: false }] } }),
    () => jsonResponse({ data: [{ id: 'compact', name: 'Compact', schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'capacity', enabled: true, size: 'normal' }], sections: [{ id: 'overview', collapsed: false }] }] }),
    () => jsonResponse({ data: [{ targetType: 'ROLE', targetId: 'USER', presetId: 'compact', presetName: 'Compact' }] }),
    () => jsonResponse({ data: { targetType: 'ROLE', targetId: 'ADMIN', presetId: 'operations', presetName: 'Operations' } }),
    () => jsonResponse({ data: { id: 'custom-ops', name: 'Ops', custom: true, schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'capacity', enabled: true, size: 'wide' }], sections: [{ id: 'operations', collapsed: true }] } }),
    () => jsonResponse({ data: { id: 'custom-ops', name: 'Ops Updated', custom: true, schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'quota', enabled: true, size: 'compact' }], sections: [{ id: 'governance', collapsed: true }] } }),
    () => jsonResponse({ data: { formatVersion: 'osmu.dashboard-preset.v1', preset: { id: 'custom-ops', name: 'Ops Updated', schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'quota', enabled: true, size: 'compact' }], sections: [{ id: 'governance', collapsed: true }] } } }),
    () => jsonResponse({ data: { id: 'custom-imported', name: 'Ops Imported', custom: true, schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'readiness', enabled: true, size: 'wide' }], sections: [{ id: 'operations', collapsed: true }] } }),
    () => jsonResponse({ data: { formatVersion: 'osmu.dashboard-preset-bundle.v1', presets: [{ id: 'custom-ops', name: 'Ops Updated', custom: true, schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'quota', enabled: true, size: 'compact' }], sections: [{ id: 'governance', collapsed: true }] }] } }),
    () => jsonResponse({ data: { importedCount: 1, presets: [{ id: 'custom-bundle-imported', name: 'Ops Bundle Imported', custom: true, schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'health', enabled: true, size: 'normal' }], sections: [{ id: 'overview', collapsed: false }] }] } }),
    () => jsonResponse({ data: { scope: 'main', source: 'SAVED', schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'capacity', enabled: true, size: 'wide' }], sections: [{ id: 'operations', collapsed: true }] } }),
    () => jsonResponse({ data: { scope: 'main', source: 'SAVED', schemaVersion: 'osmu.dashboard-layout.v1', widgets: [{ id: 'health', enabled: true, size: 'compact' }], sections: [{ id: 'overview', collapsed: false }] } }),
    () => new Response(null, { status: 204 }),
    () => new Response(null, { status: 204 }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    const initial = await getDashboardLayout()
    const presets = await getDashboardLayoutPresets()
    const defaults = await getDashboardLayoutDefaults()
    const savedDefault = await saveDashboardLayoutDefault({ targetType: 'ROLE', targetId: 'ADMIN', presetId: 'operations' })
    const createdPreset = await createDashboardLayoutPreset({ schemaVersion: 'osmu.dashboard-layout.v1', name: 'Ops', description: 'custom', widgets: [{ id: 'capacity', enabled: true, size: 'wide' }], sections: [{ id: 'operations', collapsed: true }] })
    const updatedPreset = await updateDashboardLayoutPreset('custom-ops', { schemaVersion: 'osmu.dashboard-layout.v1', name: 'Ops Updated', description: 'custom', widgets: [{ id: 'quota', enabled: true, size: 'compact' }], sections: [{ id: 'governance', collapsed: true }] })
    const exportedPreset = await exportDashboardLayoutPreset('custom-ops')
    const importedPreset = await importDashboardLayoutPreset({ preset: { name: 'Ops Imported', widgets: [{ id: 'readiness', enabled: true, size: 'wide' }], sections: [{ id: 'operations', collapsed: true }] } })
    const exportedPresetBundle = await exportDashboardLayoutPresetBundle()
    const importedPresetBundle = await importDashboardLayoutPresetBundle({ formatVersion: 'osmu.dashboard-preset-bundle.v1', presets: [{ name: 'Ops Bundle Imported', widgets: [{ id: 'health', enabled: true, size: 'normal' }] }] })
    const saved = await saveDashboardLayout(
      [{ id: 'capacity', enabled: true, size: 'wide', section: 'overview', options: { tone: 'focus' } }],
      'main',
      [{ id: 'operations', collapsed: true }],
    )
    const applied = await applyDashboardLayoutPreset('compact')
    const deletedPreset = await deleteDashboardLayoutPreset('custom-ops')
    const reset = await deleteDashboardLayout()
    const deletedDefault = await deleteDashboardLayoutDefault('ROLE', 'ADMIN')

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/dashboard/layout?scope=main')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(initial.data.source, 'DEFAULT')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/dashboard/layout/presets')
    assert.equal(presets.data[0].id, 'compact')
    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/dashboard/layout/defaults')
    assert.equal(fetchMock.calls[2].options.method, undefined)
    assert.equal(defaults.data[0].targetId, 'USER')
    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/dashboard/layout/defaults')
    assert.equal(fetchMock.calls[3].options.method, 'PUT')
    assert.equal(JSON.parse(fetchMock.calls[3].options.body).presetId, 'operations')
    assert.equal(savedDefault.data.targetId, 'ADMIN')
    assert.equal(fetchMock.calls[4].url, 'http://localhost:8080/api/dashboard/layout/presets')
    assert.equal(fetchMock.calls[4].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[4].options.body).name, 'Ops')
    assert.equal(JSON.parse(fetchMock.calls[4].options.body).schemaVersion, 'osmu.dashboard-layout.v1')
    assert.equal(JSON.parse(fetchMock.calls[4].options.body).sections[0].id, 'operations')
    assert.equal(createdPreset.data.custom, true)
    assert.equal(fetchMock.calls[5].url, 'http://localhost:8080/api/dashboard/layout/presets/custom-ops')
    assert.equal(fetchMock.calls[5].options.method, 'PATCH')
    assert.equal(JSON.parse(fetchMock.calls[5].options.body).name, 'Ops Updated')
    assert.equal(JSON.parse(fetchMock.calls[5].options.body).schemaVersion, 'osmu.dashboard-layout.v1')
    assert.equal(JSON.parse(fetchMock.calls[5].options.body).sections[0].collapsed, true)
    assert.equal(updatedPreset.data.widgets[0].id, 'quota')
    assert.equal(fetchMock.calls[6].url, 'http://localhost:8080/api/dashboard/layout/presets/custom-ops/export')
    assert.equal(fetchMock.calls[6].options.method, undefined)
    assert.equal(exportedPreset.data.formatVersion, 'osmu.dashboard-preset.v1')
    assert.equal(fetchMock.calls[7].url, 'http://localhost:8080/api/dashboard/layout/presets/import')
    assert.equal(fetchMock.calls[7].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[7].options.body).preset.name, 'Ops Imported')
    assert.equal(JSON.parse(fetchMock.calls[7].options.body).preset.sections[0].id, 'operations')
    assert.equal(importedPreset.data.id, 'custom-imported')
    assert.equal(fetchMock.calls[8].url, 'http://localhost:8080/api/dashboard/layout/preset-bundle/export')
    assert.equal(fetchMock.calls[8].options.method, undefined)
    assert.equal(exportedPresetBundle.data.formatVersion, 'osmu.dashboard-preset-bundle.v1')
    assert.equal(fetchMock.calls[9].url, 'http://localhost:8080/api/dashboard/layout/preset-bundle/import')
    assert.equal(fetchMock.calls[9].options.method, 'POST')
    assert.equal(JSON.parse(fetchMock.calls[9].options.body).formatVersion, 'osmu.dashboard-preset-bundle.v1')
    assert.equal(JSON.parse(fetchMock.calls[9].options.body).presets[0].name, 'Ops Bundle Imported')
    assert.equal(importedPresetBundle.data.importedCount, 1)
    assert.equal(fetchMock.calls[10].url, 'http://localhost:8080/api/dashboard/layout?scope=main')
    assert.equal(fetchMock.calls[10].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[10].options.body), {
      widgets: [{ id: 'capacity', enabled: true, size: 'wide', section: 'overview', options: { tone: 'focus' } }],
      sections: [{ id: 'operations', collapsed: true }],
      schemaVersion: 'osmu.dashboard-layout.v1',
    })
    assert.equal(saved.data.widgets[0].id, 'capacity')
    assert.equal(saved.data.widgets[0].size, 'wide')
    assert.equal(fetchMock.calls[11].url, 'http://localhost:8080/api/dashboard/layout/presets/compact?scope=main')
    assert.equal(fetchMock.calls[11].options.method, 'PUT')
    assert.equal(applied.data.widgets[0].id, 'health')
    assert.equal(fetchMock.calls[12].url, 'http://localhost:8080/api/dashboard/layout/presets/custom-ops')
    assert.equal(fetchMock.calls[12].options.method, 'DELETE')
    assert.equal(deletedPreset, null)
    assert.equal(fetchMock.calls[13].options.method, 'DELETE')
    assert.equal(reset, null)
    assert.equal(fetchMock.calls[14].url, 'http://localhost:8080/api/dashboard/layout/defaults/ROLE/ADMIN')
    assert.equal(fetchMock.calls[14].options.method, 'DELETE')
    assert.equal(deletedDefault, null)
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getDashboardWidgetCatalog reads dashboard palette metadata endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: [
        { id: 'access-keys', title: 'Access Key 운영', category: 'SECURITY', adminOnly: false },
      ],
    }),
  ])

  try {
    const result = await getDashboardWidgetCatalog()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/dashboard/layout/widgets')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data[0].id, 'access-keys')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getS3ClientConfig reads developer S3 client settings endpoint', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        endpoint: 'https://storage.example.com/api/s3',
        region: 'ap-northeast-2',
        signatureVersion: 'AWS4-HMAC-SHA256',
        service: 's3',
      },
    }),
  ])

  try {
    const result = await getS3ClientConfig()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/developer/s3-client-config')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.data.endpoint, 'https://storage.example.com/api/s3')
    assert.equal(result.data.region, 'ap-northeast-2')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getAuditLogs sends all audit filters as query parameters', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: null }),
  ])

  try {
    await getAuditLogs({
      eventType: 'OBJECT_UPLOAD',
      actorId: 'admin',
      requestId: 'req 1',
      targetType: 'OBJECT',
      targetId: 'bucket/hello.txt',
      result: 'SUCCESS',
      cursor: 'cursor-1',
      from: '2026-06-01T00:00:00Z',
      to: '2026-06-02T00:00:00Z',
      limit: 50,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/audit-logs')
    assert.equal(url.searchParams.get('eventType'), 'OBJECT_UPLOAD')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('requestId'), 'req 1')
    assert.equal(url.searchParams.get('targetType'), 'OBJECT')
    assert.equal(url.searchParams.get('targetId'), 'bucket/hello.txt')
    assert.equal(url.searchParams.get('result'), 'SUCCESS')
    assert.equal(url.searchParams.get('cursor'), 'cursor-1')
    assert.equal(url.searchParams.get('from'), '2026-06-01T00:00:00Z')
    assert.equal(url.searchParams.get('to'), '2026-06-02T00:00:00Z')
    assert.equal(url.searchParams.get('limit'), '50')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getUsers sends admin user filters as query parameters', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: '12' }),
  ])

  try {
    await getUsers({
      keyword: 'alpha user',
      status: 'ACTIVE',
      limit: 25,
      cursor: '42',
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/users')
    assert.equal(url.searchParams.get('keyword'), 'alpha user')
    assert.equal(url.searchParams.get('status'), 'ACTIVE')
    assert.equal(url.searchParams.get('limit'), '25')
    assert.equal(url.searchParams.get('cursor'), '42')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getTeams sends admin team filters as query parameters', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: null }),
  ])

  try {
    await getTeams({ organizationId: 7 })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/teams')
    assert.equal(url.searchParams.get('organizationId'), '7')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share policy wrappers read and save global policy', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { requirePassword: false, requireIpAllowlist: false, maxExpiresSeconds: 604800 } }),
    () => jsonResponse({ data: { requirePassword: true, requireIpAllowlist: true, maxExpiresSeconds: 3600, maxDownloadsLimit: 5 } }),
  ])

  try {
    await getObjectSharePolicy()
    await saveObjectSharePolicy({
      requirePassword: true,
      requireIpAllowlist: true,
      maxExpiresSeconds: 3600,
      maxDownloadsLimit: 5,
      reason: 'secure pilot',
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/admin/object-share-policy')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/admin/object-share-policy')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      requirePassword: true,
      requireIpAllowlist: true,
      maxExpiresSeconds: 3600,
      maxDownloadsLimit: 5,
      reason: 'secure pilot',
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getBuckets uses bucket list endpoint for dashboard table', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({
      items: [
        { name: 'media', usedBytes: 1024, quotaBytes: 4096, objectCount: 2 },
      ],
    }),
  ])

  try {
    const result = await getBuckets()

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets')
    assert.equal(fetchMock.calls[0].options.method, undefined)
    assert.equal(result.items[0].name, 'media')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('downloadAuditLogsCsv uses export endpoint and returns CSV blob', async () => {
  const fetchMock = mockFetch([
    () => new Response('id,eventType\n1,LOGIN\n', {
      status: 200,
      headers: { 'Content-Type': 'text/csv' },
    }),
  ])

  try {
    const blob = await downloadAuditLogsCsv({
      eventType: 'LOGIN',
      actorId: 'admin',
      result: 'SUCCESS',
      limit: 100,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/audit-logs/export.csv')
    assert.equal(url.searchParams.get('eventType'), 'LOGIN')
    assert.equal(url.searchParams.get('actorId'), 'admin')
    assert.equal(url.searchParams.get('result'), 'SUCCESS')
    assert.equal(url.searchParams.get('limit'), '100')
    assert.equal(await blob.text(), 'id,eventType\n1,LOGIN\n')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('getObjects builds browse, search, tag, cursor, and page size query', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ items: [], nextCursor: 'next' }),
  ])

  try {
    await getObjects('media bucket', {
      prefix: ' docs/2026/ ',
      delimiter: '/',
      search: ' report ',
      tag: ' project=osmu ',
      cursor: 'cursor 2',
      limit: 250,
      deleted: true,
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/buckets/media%20bucket/objects')
    assert.equal(url.searchParams.get('prefix'), 'docs/2026/')
    assert.equal(url.searchParams.get('delimiter'), '/')
    assert.equal(url.searchParams.get('search'), 'report')
    assert.equal(url.searchParams.get('tag'), 'project=osmu')
    assert.equal(url.searchParams.get('cursor'), 'cursor 2')
    assert.equal(url.searchParams.get('limit'), '250')
    assert.equal(url.searchParams.get('deleted'), 'true')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object metadata, tag update, and presigned upload wrappers preserve keys and tags', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { key: 'docs/hello world.txt' } }),
    () => jsonResponse({ data: { key: 'docs/hello world.txt', tags: { project: 'osmu' } } }),
    () => jsonResponse({ data: { uploadUrl: 'https://storage/upload' } }),
  ])

  try {
    await getObjectMetadata('media bucket', 'docs/hello world.txt')
    await updateObjectTags('media bucket', {
      key: 'docs/hello world.txt',
      tags: { project: 'osmu', stage: 'raw' },
    })
    await createPresignedUploadUrl('media bucket', {
      key: 'videos/input.mp4',
      contentType: 'video/mp4',
      sizeBytes: 1024,
      tags: 'project=osmu,stage=raw',
    })

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/metadata/docs/hello%20world.txt')

    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/tags')
    assert.equal(fetchMock.calls[1].options.method, 'PUT')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), {
      key: 'docs/hello world.txt',
      tags: { project: 'osmu', stage: 'raw' },
    })

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/presigned-upload')
    assert.equal(fetchMock.calls[2].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[2].options.body), {
      key: 'videos/input.mp4',
      contentType: 'video/mp4',
      sizeBytes: 1024,
      tags: 'project=osmu,stage=raw',
    })
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share link wrappers create, list, cleanup, and revoke share links', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { id: 3, url: 'http://localhost:8080/api/public/share-links/token' } }),
    () => jsonResponse({ items: [{ id: 3, key: 'docs/hello world.txt' }] }),
    () => jsonResponse({ data: { bucketName: 'media bucket', expiredCount: 0 } }),
    () => new Response(null, { status: 204 }),
  ])

  try {
    await createObjectShareLink('media bucket', 'docs/hello world.txt', {
      expiresInSeconds: 3600,
      note: 'department reuse',
      maxDownloads: 12,
      password: 'SharePass!23',
      allowedIpCidrs: '203.0.113.0/24',
    })
    await getObjectShareLinks('media bucket', 'docs/hello world.txt', 25)
    await cleanupObjectShareLinks('media bucket')
    await deleteObjectShareLink('media bucket', 3)

    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links')
    assert.equal(fetchMock.calls[0].options.method, 'POST')
    assert.deepEqual(JSON.parse(fetchMock.calls[0].options.body), {
      key: 'docs/hello world.txt',
      expiresInSeconds: 3600,
      note: 'department reuse',
      maxDownloads: 12,
      password: 'SharePass!23',
      allowedIpCidrs: '203.0.113.0/24',
    })

    const listUrl = new URL(fetchMock.calls[1].url)
    assert.equal(listUrl.pathname, '/api/buckets/media%20bucket/objects/share-links')
    assert.equal(listUrl.searchParams.get('key'), 'docs/hello world.txt')
    assert.equal(listUrl.searchParams.get('limit'), '25')

    assert.equal(fetchMock.calls[2].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links/cleanup')
    assert.equal(fetchMock.calls[2].options.method, 'POST')

    assert.equal(fetchMock.calls[3].url, 'http://localhost:8080/api/buckets/media%20bucket/objects/share-links/3')
    assert.equal(fetchMock.calls[3].options.method, 'DELETE')
  } finally {
    cleanupFetch(fetchMock)
  }
})

test('object share analytics wrapper reads bounded admin summary', async () => {
  const fetchMock = mockFetch([
    () => jsonResponse({ data: { totalLinks: 1, activeLinks: 1, recentLinks: [] } }),
  ])

  try {
    await getObjectShareAnalytics(12, {
      bucketName: 'media bucket',
      status: 'ACTIVE',
    })

    const url = new URL(fetchMock.calls[0].url)
    assert.equal(url.pathname, '/api/admin/object-share-analytics')
    assert.equal(url.searchParams.get('limit'), '12')
    assert.equal(url.searchParams.get('bucketName'), 'media bucket')
    assert.equal(url.searchParams.get('status'), 'ACTIVE')
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

function cleanupFetch(fetchMock) {
  clearAuthTokens()
  fetchMock.restore()
}
