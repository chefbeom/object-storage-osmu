import { createServer } from 'node:http'
import { randomUUID } from 'node:crypto'

const DEFAULT_HOST = '127.0.0.1'
const DEFAULT_PORT = 8080
const BYTES_PER_GIB = 1024 ** 3

let state = createInitialState()

function createInitialState() {
  const initialState = {
    sessions: new Map(),
    buckets: [
      bucketRecord('osmu-demo-media', 10 * BYTES_PER_GIB),
      bucketRecord('osmu-demo-ai', 5 * BYTES_PER_GIB),
    ],
    objects: new Map(),
    accessKeys: [
      {
        id: 'mock-sdk-key',
        name: 'mock-sdk-key',
        accessKey: 'OSMUDEMOACCESS',
        status: 'ACTIVE',
        allowedBuckets: ['osmu-demo-media', 'osmu-demo-ai'],
        permissions: ['READ', 'WRITE'],
        bucketScopes: [
          { bucketName: 'osmu-demo-media', permissions: ['READ', 'WRITE'] },
          { bucketName: 'osmu-demo-ai', permissions: ['READ'] },
        ],
        createdAt: new Date().toISOString(),
        expiresAt: null,
        lastUsedAt: null,
      },
    ],
    auditLogs: [
      auditLog('LOGIN_SUCCESS', 'AUTH', 'admin', 'SUCCESS'),
      auditLog('DEMO_BOOTSTRAP', 'SYSTEM', 'mock-api', 'SUCCESS'),
    ],
    dataFlowEvents: [],
    teams: [
      {
        id: 1,
        organizationId: 1,
        name: 'Mock Data Team',
        description: 'Mock team-based bucket permission group',
        memberIds: [2],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    userSequence: 3,
    teamSequence: 2,
    storageProfileAssignments: new Map(),
    storageProfileRequests: [],
    storageProfileRequestSequence: 1,
    billingPricingPolicy: defaultBillingPricingPolicy(),
    billingPricingPolicyProposals: [],
    billingPricingPolicyProposalSequence: 1,
    chargebackNotificationDeliveries: [],
    chargebackNotificationDeliverySequence: 1,
    chargebackInvoiceDrafts: [],
    chargebackInvoiceDraftSequence: 1,
    chargebackFinalInvoices: [],
    chargebackFinalInvoiceSequence: 1,
    chargebackPaymentProviderHandoffs: [],
    chargebackPaymentProviderHandoffSequence: 1,
  }

  initialState.objects.set('osmu-demo-media', [
    objectRecord('videos/raw/sample-video-manifest.txt', 'sampleId=video-001', { project: 'osmu', workload: 'streaming' }),
    objectRecord('videos/encoded/sample-rendition.txt', 'rendition=1080p', { project: 'osmu', stage: 'encoded' }),
  ])
  initialState.objects.set('osmu-demo-ai', [
    objectRecord('datasets/images/sample-dataset.json', '{"name":"sample-images"}', { project: 'osmu', workload: 'ai' }),
  ])
  for (const [bucketName, objects] of initialState.objects.entries()) {
    for (const object of objects) {
      initialState.dataFlowEvents.unshift(dataFlowEvent(
        'UPLOAD',
        'upload',
        'INGRESS',
        bucketName,
        object.key,
        'mock-api',
        'SUCCESS',
        object.sizeBytes,
        'Seed object loaded',
        'MOCK'
      ))
    }
  }

  return initialState
}

function resetMockState() {
  state = createInitialState()
  refreshBucketUsage()
  return {
    reset: true,
    bucketCount: state.buckets.length,
    objectCount: Array.from(state.objects.values()).reduce((sum, items) => sum + items.length, 0),
    accessKeyCount: state.accessKeys.length,
  }
}

function bucketRecord(name, quotaBytes = BYTES_PER_GIB) {
  return {
    name,
    quotaBytes,
    usedBytes: 0,
    objectCount: 0,
    ownerType: 'USER',
    ownerId: 1,
    createdAt: new Date().toISOString(),
  }
}

function objectRecord(key, content = '', tags = {}) {
  return {
    key,
    sizeBytes: Buffer.byteLength(content),
    contentType: 'text/plain',
    tags,
    checksums: {},
    status: 'SYNCED',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
}

function auditLog(eventType, targetType, targetId, result = 'SUCCESS', actorId = 'admin') {
  return {
    id: randomUUID(),
    eventType,
    actorId,
    targetType,
    targetId,
    result,
    requestId: randomUUID(),
    createdAt: new Date().toISOString(),
  }
}

function dataFlowEvent(eventType, operation, direction, bucketName, objectKey, actorId, status, sizeBytes, message, source) {
  return {
    eventType,
    operation,
    direction,
    bucketName,
    objectKey,
    actorId,
    status,
    sizeBytes: Math.max(0, Number(sizeBytes || 0)),
    message,
    source,
    createdAt: new Date().toISOString(),
  }
}

function recordDataFlow(eventType, operation, direction, bucketName, objectKey, actorId, status, sizeBytes, message, source) {
  state.dataFlowEvents.unshift(dataFlowEvent(eventType, operation, direction, bucketName, objectKey, actorId, status, sizeBytes, message, source))
  state.dataFlowEvents = state.dataFlowEvents.slice(0, 50)
}

function createMockApiServer() {
  return createServer(async (request, response) => {
    try {
      await handleRequest(request, response)
    } catch (error) {
      sendJson(response, 500, {
        error: {
          code: 'MOCK_API_ERROR',
          message: error.message,
          requestId: randomUUID(),
        },
      })
    }
  })
}

async function handleRequest(request, response) {
  setCorsHeaders(response)
  if (request.method === 'OPTIONS') {
    response.writeHead(204)
    response.end()
    return
  }

  const url = new URL(request.url, `http://${request.headers.host || `${DEFAULT_HOST}:${DEFAULT_PORT}`}`)
  if (!url.pathname.startsWith('/api')) {
    sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Mock API only serves /api.' } })
    return
  }

  const path = url.pathname.slice('/api'.length) || '/'
  const bodyBuffer = await readBody(request)
  const jsonBody = parseJsonBody(bodyBuffer)

  if (request.method === 'POST' && path === '/mock/reset') {
    sendJson(response, 200, apiData(resetMockState()))
    return
  }
  if (request.method === 'GET' && path === '/health') {
    sendJson(response, 200, apiData(systemStatus()))
    return
  }
  if (request.method === 'GET' && path === '/storage/health') {
    sendJson(response, 200, apiData({ status: 'UP', engine: 'mock-memory' }))
    return
  }
  if (request.method === 'GET' && path === '/database/health') {
    sendJson(response, 200, apiData({ status: 'UP', engine: 'mock-memory' }))
    return
  }
  if (request.method === 'POST' && path === '/auth/login') {
    const loginId = jsonBody.loginId || 'admin'
    const user = userForLogin(loginId)
    state.auditLogs.unshift(auditLog('LOGIN_SUCCESS', 'AUTH', loginId, 'SUCCESS', user.loginId))
    sendJson(response, 200, apiData(authPayload(user)))
    return
  }
  if (request.method === 'POST' && path === '/auth/ldap/login') {
    const loginId = jsonBody.loginId || 'admin'
    const user = userForLogin(loginId)
    state.auditLogs.unshift(auditLog('LOGIN_LDAP', 'AUTH', loginId, 'SUCCESS', user.loginId))
    sendJson(response, 200, apiData(authPayload(user)))
    return
  }
  if (request.method === 'GET' && path === '/auth/oidc/authorize') {
    sendJson(response, 200, apiData(oidcAuthorizationRequest()))
    return
  }
  if (request.method === 'GET' && path === '/auth/oidc/callback') {
    const code = url.searchParams.get('code') || ''
    const callbackState = url.searchParams.get('state') || ''
    if (!code || !callbackState) {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'OIDC code and state are required.' } })
      return
    }
    sendJson(response, 200, apiData(authPayload(adminUser())))
    return
  }
  if (request.method === 'POST' && path === '/auth/refresh') {
    const session = sessionFromRefreshToken(jsonBody.refreshToken) || userForLogin('admin')
    sendJson(response, 200, apiData(authPayload(session)))
    return
  }
  if (request.method === 'POST' && path === '/auth/logout') {
    sendJson(response, 200, apiData({ loggedOut: true }))
    return
  }
  if (request.method === 'GET' && path === '/users/me') {
    sendJson(response, 200, apiData(currentUser(request)))
    return
  }
  if (request.method === 'GET' && path === '/developer/s3-client-config') {
    sendJson(response, 200, apiData({
      endpoint: 'http://localhost:8080/api/s3',
      region: 'us-east-1',
      signatureVersion: 'AWS4-HMAC-SHA256',
      service: 's3',
      pathStyleSupported: true,
      virtualHostedStyleEnabled: false,
      virtualHostedStyleDomainSuffixes: [],
    }))
    return
  }
  if (request.method === 'GET' && path === '/storage-profiles') {
    sendJson(response, 200, apiItems(storageProfiles()))
    return
  }
  if (request.method === 'GET' && path === '/storage-profile-requests') {
    const user = currentUser(request)
    const items = user.role === 'ADMIN'
      ? state.storageProfileRequests
      : state.storageProfileRequests.filter((item) => findBucket(item.bucketName)?.ownerId === user.id)
    sendJson(response, 200, apiItems(items))
    return
  }

  if (request.method === 'GET' && path === '/admin/dashboard/summary') {
    sendJson(response, 200, apiData(dashboardSummary()))
    return
  }
  if (request.method === 'GET' && path === '/admin/dashboard/readiness') {
    sendJson(response, 200, apiData(readinessSummary()))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow') {
    sendJson(response, 200, apiData(dataFlowSummary(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/export.csv') {
    sendCsv(response, 'osmu-data-flow.csv', dataFlowCsv(dataFlowFilters(url)))
    return
  }
  if (path.startsWith('/dashboard/layout')) {
    handleDashboardLayout(request, response, path)
    return
  }

  if (request.method === 'GET' && path === '/buckets') {
    refreshBucketUsage()
    sendJson(response, 200, apiItems(state.buckets))
    return
  }
  if (request.method === 'POST' && path === '/buckets') {
    const bucket = bucketRecord(jsonBody.name, Number(jsonBody.quotaBytes || BYTES_PER_GIB))
    state.buckets = state.buckets.filter((item) => item.name !== bucket.name)
    state.buckets.push(bucket)
    state.objects.set(bucket.name, [])
    state.auditLogs.unshift(auditLog('BUCKET_CREATE', 'BUCKET', bucket.name))
    sendJson(response, 200, apiData(bucket))
    return
  }

  const bucketMatch = /^\/buckets\/([^/]+)(.*)$/.exec(path)
  if (bucketMatch) {
    handleBucketRoute(request, response, decodeURIComponent(bucketMatch[1]), bucketMatch[2], bodyBuffer, jsonBody, url)
    return
  }

  handleAdminRoute(request, response, path, jsonBody, url)
}

function handleDashboardLayout(request, response, path) {
  if (request.method === 'GET' && path === '/dashboard/layout/widgets') {
    sendJson(response, 200, apiData(defaultWidgetCatalog()))
    return
  }
  if (request.method === 'GET' && path === '/dashboard/layout/presets') {
    sendJson(response, 200, apiData(defaultPresets()))
    return
  }
  if (request.method === 'GET' && path === '/dashboard/layout/defaults') {
    sendJson(response, 200, apiData([]))
    return
  }
  if (request.method === 'GET' && path === '/dashboard/layout') {
    sendJson(response, 200, apiData(defaultLayout()))
    return
  }
  if (request.method === 'PUT' && path === '/dashboard/layout') {
    sendJson(response, 200, apiData({ ...defaultLayout(), source: 'USER' }))
    return
  }
  sendJson(response, 200, apiData({ ok: true }))
}

function handleBucketRoute(request, response, bucketName, suffix, bodyBuffer, jsonBody, url) {
  if (request.method === 'DELETE' && suffix === '') {
    state.buckets = state.buckets.filter((bucket) => bucket.name !== bucketName)
    state.objects.delete(bucketName)
    state.storageProfileAssignments.delete(bucketName)
    state.auditLogs.unshift(auditLog('BUCKET_DELETE', 'BUCKET', bucketName))
    sendJson(response, 200, apiData({ deleted: true }))
    return
  }
  if (request.method === 'GET' && suffix === '/storage-profile') {
    sendJson(response, 200, apiData({
      bucketName,
      assignment: storageProfileAssignmentFor(bucketName),
      latestRequest: latestStorageProfileRequest(bucketName),
    }))
    return
  }
  if (request.method === 'POST' && suffix === '/storage-profile-requests') {
    const bucket = findBucket(bucketName)
    if (!bucket) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Bucket not found.' } })
      return
    }
    const requestRecord = createStorageProfileRequest(bucketName, jsonBody)
    state.storageProfileRequests.unshift(requestRecord)
    state.auditLogs.unshift(auditLog('STORAGE_PROFILE_REQUEST_CREATE', 'STORAGE_PROFILE_REQUEST', String(requestRecord.id), 'SUCCESS', requestRecord.requestedBy))
    sendJson(response, 200, apiData(requestRecord))
    return
  }
  if (request.method === 'POST' && suffix === '/sync') {
    refreshBucketUsage()
    sendJson(response, 200, apiData(findBucket(bucketName)))
    return
  }
  if (request.method === 'GET' && suffix === '/permissions') {
    sendJson(response, 200, apiItems([]))
    return
  }
  if (request.method === 'GET' && suffix === '/lifecycle') {
    sendJson(response, 200, apiData({ xml: '<LifecycleConfiguration />', ruleCount: 0 }))
    return
  }
  if (request.method === 'GET' && suffix === '/tags') {
    sendJson(response, 200, apiData({ tags: { project: 'osmu', runtime: 'mock' } }))
    return
  }
  if (request.method === 'GET' && suffix === '/objects') {
    const search = url.searchParams.get('search') || ''
    const items = objectsFor(bucketName).filter((item) => !search || item.key.includes(search))
    recordDataFlow('LIST', 'list', 'METADATA', bucketName, '', currentUser(request).loginId, 'SUCCESS', 0, 'Object list read', 'REST')
    sendJson(response, 200, { items, prefixes: [], nextCursor: '' })
    return
  }
  if (request.method === 'POST' && suffix === '/objects') {
    const upload = parseMultipartUpload(bodyBuffer, request.headers['content-type'] || '')
    const record = objectRecord(upload.key || upload.fileName || 'upload.bin', upload.content || '', parseTags(upload.tags))
    const objects = objectsFor(bucketName)
    state.objects.set(bucketName, [...objects.filter((item) => item.key !== record.key), record])
    refreshBucketUsage()
    state.auditLogs.unshift(auditLog('OBJECT_UPLOAD', 'OBJECT', `${bucketName}/${record.key}`))
    recordDataFlow('UPLOAD', 'upload', 'INGRESS', bucketName, record.key, currentUser(request).loginId, 'SUCCESS', record.sizeBytes, 'Object uploaded', 'REST')
    sendJson(response, 200, apiData(record))
    return
  }
  if (request.method === 'GET' && isObjectDataPath(suffix)) {
    const objectKey = decodeURIComponent(suffix.slice('/objects/'.length))
    const object = objectsFor(bucketName).find((item) => item.key === objectKey)
    if (!object) {
      recordDataFlow('FAILURE', 'download', 'CONTROL', bucketName, objectKey, currentUser(request).loginId, 'FAILED', 0, 'Object not found', 'REST')
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Object not found.' } })
      return
    }
    recordDataFlow('DOWNLOAD', 'download', 'EGRESS', bucketName, object.key, currentUser(request).loginId, 'SUCCESS', object.sizeBytes, 'Object downloaded', 'REST')
    response.writeHead(200, {
      'Content-Type': object.contentType || 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${object.key.split('/').pop() || 'download'}"`,
    })
    response.end(`mock object: ${object.key}`)
    return
  }
  if (request.method === 'DELETE' && isObjectDataPath(suffix)) {
    const objectKey = decodeURIComponent(suffix.slice('/objects/'.length))
    state.objects.set(bucketName, objectsFor(bucketName).filter((item) => item.key !== objectKey))
    refreshBucketUsage()
    state.auditLogs.unshift(auditLog('OBJECT_DELETE', 'OBJECT', `${bucketName}/${objectKey}`))
    recordDataFlow('DELETE', 'delete', 'METADATA', bucketName, objectKey, currentUser(request).loginId, 'SUCCESS', 0, 'Object deleted', 'REST')
    response.writeHead(204)
    response.end()
    return
  }
  sendJson(response, 200, apiData({ ok: true }))
}

function handleAdminRoute(request, response, path, jsonBody, url) {
  if (request.method === 'GET' && path === '/admin/usage') {
    sendJson(response, 200, apiData(usageSummary()))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-preview') {
    sendJson(response, 200, apiData(chargebackPreview(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-alerts') {
    sendJson(response, 200, apiData(chargebackAlerts(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-alert-notifications/preview') {
    sendJson(response, 200, apiData(chargebackAlertNotificationPreview(url)))
    return
  }
  if (request.method === 'POST' && path === '/admin/billing/chargeback-alert-notifications/outbox') {
    sendJson(response, 200, apiData(queueChargebackAlertNotifications(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-alert-notifications/outbox') {
    sendJson(response, 200, apiData(chargebackAlertNotificationOutbox(url)))
    return
  }
  const chargebackNotificationAdapterResultMatch = path.match(/^\/admin\/billing\/chargeback-alert-notifications\/outbox\/(\d+)\/adapter-result$/)
  if (request.method === 'POST' && chargebackNotificationAdapterResultMatch) {
    sendJson(response, 200, apiData(recordChargebackNotificationAdapterResult(Number(chargebackNotificationAdapterResultMatch[1]), url)))
    return
  }
  if (request.method === 'POST' && path === '/admin/billing/chargeback-invoice-drafts') {
    sendJson(response, 200, apiData(createChargebackInvoiceDrafts(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-invoice-drafts') {
    sendJson(response, 200, apiData(chargebackInvoiceDrafts(url)))
    return
  }
  const invoiceDraftApproveMatch = path.match(/^\/admin\/billing\/chargeback-invoice-drafts\/(\d+)\/approve$/)
  if (request.method === 'POST' && invoiceDraftApproveMatch) {
    sendJson(response, 200, apiData(approveChargebackInvoiceDraft(Number(invoiceDraftApproveMatch[1]), url)))
    return
  }
  const invoiceDraftFinalizeMatch = path.match(/^\/admin\/billing\/chargeback-invoice-drafts\/(\d+)\/finalize$/)
  if (request.method === 'POST' && invoiceDraftFinalizeMatch) {
    sendJson(response, 200, apiData(finalizeChargebackInvoiceDraft(Number(invoiceDraftFinalizeMatch[1]), url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-invoices') {
    sendJson(response, 200, apiData(chargebackFinalInvoices(url)))
    return
  }
  const finalInvoicePaymentRequestMatch = path.match(/^\/admin\/billing\/chargeback-invoices\/(\d+)\/payment-request$/)
  if (request.method === 'POST' && finalInvoicePaymentRequestMatch) {
    sendJson(response, 200, apiData(requestChargebackInvoicePayment(Number(finalInvoicePaymentRequestMatch[1]), url)))
    return
  }
  const finalInvoicePaymentHandoffPreviewMatch = path.match(/^\/admin\/billing\/chargeback-invoices\/(\d+)\/payment-provider-handoff\/preview$/)
  if (request.method === 'GET' && finalInvoicePaymentHandoffPreviewMatch) {
    sendJson(response, 200, apiData(chargebackPaymentProviderHandoffPreview(Number(finalInvoicePaymentHandoffPreviewMatch[1]), url)))
    return
  }
  const finalInvoicePaymentHandoffMatch = path.match(/^\/admin\/billing\/chargeback-invoices\/(\d+)\/payment-provider-handoff$/)
  if (request.method === 'POST' && finalInvoicePaymentHandoffMatch) {
    sendJson(response, 200, apiData(queueChargebackPaymentProviderHandoff(Number(finalInvoicePaymentHandoffMatch[1]), url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-payment-provider-handoffs') {
    sendJson(response, 200, apiData(chargebackPaymentProviderHandoffs(url)))
    return
  }
  const chargebackPaymentProviderAdapterResultMatch = path.match(/^\/admin\/billing\/chargeback-payment-provider-handoffs\/(\d+)\/adapter-result$/)
  if (request.method === 'POST' && chargebackPaymentProviderAdapterResultMatch) {
    sendJson(response, 200, apiData(recordChargebackPaymentProviderAdapterResult(Number(chargebackPaymentProviderAdapterResultMatch[1]), url)))
    return
  }
  const finalInvoicePaymentRecordMatch = path.match(/^\/admin\/billing\/chargeback-invoices\/(\d+)\/payment-record$/)
  if (request.method === 'POST' && finalInvoicePaymentRecordMatch) {
    sendJson(response, 200, apiData(recordChargebackInvoicePayment(Number(finalInvoicePaymentRecordMatch[1]), url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-preview/export.csv') {
    sendCsv(response, 'osmu-chargeback-preview.csv', chargebackPreviewCsv(url))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/chargeback-invoice-draft/export.csv') {
    sendCsv(response, 'osmu-chargeback-invoice-draft.csv', chargebackInvoiceDraftCsv(url))
    return
  }
  if (request.method === 'POST' && path === '/admin/billing/pricing-policy-proposals') {
    sendJson(response, 200, apiData(createBillingPricingPolicyProposal(jsonBody)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/pricing-policy-proposals') {
    sendJson(response, 200, apiData(billingPricingPolicyProposals(url)))
    return
  }
  const pricingPolicyProposalApproveMatch = path.match(/^\/admin\/billing\/pricing-policy-proposals\/(\d+)\/approve$/)
  if (request.method === 'POST' && pricingPolicyProposalApproveMatch) {
    sendJson(response, 200, apiData(approveBillingPricingPolicyProposal(Number(pricingPolicyProposalApproveMatch[1]), url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/billing/pricing-policy') {
    sendJson(response, 200, apiData(state.billingPricingPolicy))
    return
  }
  if (request.method === 'PUT' && path === '/admin/billing/pricing-policy') {
    state.billingPricingPolicy = saveBillingPricingPolicy(jsonBody)
    state.auditLogs.unshift(auditLog('BILLING_PRICING_POLICY_SAVE', 'BILLING_PRICING_POLICY', 'global'))
    sendJson(response, 200, apiData(state.billingPricingPolicy))
    return
  }
  if (request.method === 'GET' && path === '/admin/backup/status') {
    sendJson(response, 200, apiData(backupStatus()))
    return
  }
  if (request.method === 'GET' && path === '/admin/audit-logs') {
    sendJson(response, 200, { items: state.auditLogs, nextCursor: '' })
    return
  }
  if (request.method === 'GET' && path === '/access-keys') {
    sendJson(response, 200, apiItems(state.accessKeys))
    return
  }
  if (request.method === 'POST' && path === '/access-keys') {
    const key = {
      id: randomUUID(),
      name: jsonBody.name || 'mock-access-key',
      accessKey: `OSMU${randomUUID().slice(0, 8).toUpperCase()}`,
      secretKey: randomUUID().replaceAll('-', ''),
      status: 'ACTIVE',
      bucketScopes: jsonBody.bucketScopes || [],
      permissions: ['READ', 'WRITE'],
      createdAt: new Date().toISOString(),
      expiresAt: jsonBody.expiresAt || null,
      lastUsedAt: null,
    }
    state.accessKeys.unshift({ ...key, secretKey: undefined })
    sendJson(response, 200, apiData(key))
    return
  }
  if (request.method === 'GET' && path === '/admin/users') {
    sendJson(response, 200, filteredMockUsers(url.searchParams))
    return
  }
  if (request.method === 'GET' && path === '/admin/organizations') {
    sendJson(response, 200, apiItems([{ id: 1, name: 'Mock Organization', defaultQuotaBytes: 10 * BYTES_PER_GIB }]))
    return
  }
  if (request.method === 'GET' && path === '/admin/organizations/usage') {
    sendJson(response, 200, apiItems(organizationUsageRows()))
    return
  }
  if (request.method === 'GET' && path === '/admin/security/enterprise-auth-plan') {
    sendJson(response, 200, apiData(enterpriseAuthPlan()))
    return
  }
  if (request.method === 'POST' && path === '/admin/security/enterprise-auth/claim-preview') {
    const preview = enterpriseAuthClaimPreview(jsonBody.claims || {})
    state.auditLogs.unshift(auditLog('OIDC_CLAIM_PREVIEW', 'OIDC_CLAIM', preview.email || preview.subject || 'unknown', 'SUCCESS'))
    sendJson(response, 200, apiData(preview))
    return
  }
  if (request.method === 'POST' && path === '/admin/security/enterprise-auth/jit-provision') {
    const provision = enterpriseAuthJitProvision(jsonBody)
    state.auditLogs.unshift(auditLog('OIDC_JIT_PROVISION', 'USER', provision.user.loginId, 'SUCCESS'))
    sendJson(response, 200, apiData(provision))
    return
  }
  if (request.method === 'GET' && path === '/admin/teams') {
    const organizationId = Number(url.searchParams.get('organizationId') || 0)
    const teams = organizationId
      ? state.teams.filter((team) => team.organizationId === organizationId)
      : state.teams
    sendJson(response, 200, apiItems(teams))
    return
  }
  if (request.method === 'POST' && path === '/admin/teams') {
    const team = {
      id: state.teamSequence++,
      organizationId: Number(jsonBody.organizationId || 1),
      name: jsonBody.name || `Mock Team ${state.teamSequence}`,
      description: jsonBody.description || '',
      memberIds: Array.isArray(jsonBody.memberIds) ? jsonBody.memberIds.map(Number).filter(Boolean) : [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
    state.teams.unshift(team)
    state.auditLogs.unshift(auditLog('TEAM_CREATE', 'TEAM', team.name, 'SUCCESS'))
    sendJson(response, 200, apiData(team))
    return
  }
  const teamMembersMatch = /^\/admin\/teams\/(\d+)\/members$/.exec(path)
  if (teamMembersMatch && request.method === 'PUT') {
    const teamId = Number(teamMembersMatch[1])
    state.teams = state.teams.map((team) => team.id === teamId
      ? { ...team, memberIds: Array.isArray(jsonBody.memberIds) ? jsonBody.memberIds.map(Number).filter(Boolean) : [], updatedAt: new Date().toISOString() }
      : team)
    sendJson(response, 200, apiData(state.teams.find((team) => team.id === teamId)))
    return
  }
  const teamDeleteMatch = /^\/admin\/teams\/(\d+)$/.exec(path)
  if (teamDeleteMatch && request.method === 'DELETE') {
    const teamId = Number(teamDeleteMatch[1])
    state.teams = state.teams.filter((team) => team.id !== teamId)
    response.writeHead(204)
    response.end()
    return
  }
  if (request.method === 'GET' && path === '/admin/quota-policies') {
    sendJson(response, 200, apiItems([]))
    return
  }
  if (request.method === 'GET' && path === '/admin/quota-policies/history') {
    sendJson(response, 200, apiItems([]))
    return
  }
  if (request.method === 'GET' && path === '/admin/storage-expansion/requests') {
    sendJson(response, 200, apiItems([]))
    return
  }
  if (request.method === 'GET' && path === '/admin/storage-expansion/summary') {
    sendJson(response, 200, apiData(storageExpansionSummary()))
    return
  }
  if (request.method === 'GET' && path === '/admin/storage-expansion/runner-preflight') {
    sendJson(response, 200, apiData({ status: 'MOCK', ready: false, enabledRunnerCount: 0, failedCheckCount: 0, checks: [] }))
    return
  }
  if (request.method === 'GET' && path === '/admin/storage-profile-requests') {
    sendJson(response, 200, apiItems(state.storageProfileRequests))
    return
  }
  const profileStatusMatch = /^\/admin\/storage-profile-requests\/(\d+)\/status$/.exec(path)
  if (profileStatusMatch && request.method === 'PATCH') {
    const requestRecord = findStorageProfileRequest(Number(profileStatusMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage profile request not found.' } })
      return
    }
    const status = String(jsonBody.status || '').trim().toUpperCase()
    if (!['APPROVED', 'REJECTED'].includes(status) || requestRecord.status !== 'PENDING') {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Invalid storage profile status transition.' } })
      return
    }
    Object.assign(requestRecord, {
      status,
      approvedBy: 'admin',
      approvedAt: new Date().toISOString(),
      adminNote: jsonBody.adminNote || '',
      updatedAt: new Date().toISOString(),
    })
    state.auditLogs.unshift(auditLog('STORAGE_PROFILE_REQUEST_STATUS', 'STORAGE_PROFILE_REQUEST', String(requestRecord.id)))
    sendJson(response, 200, apiData(requestRecord))
    return
  }
  const profileApplyMatch = /^\/admin\/storage-profile-requests\/(\d+)\/apply$/.exec(path)
  if (profileApplyMatch && request.method === 'POST') {
    const requestRecord = findStorageProfileRequest(Number(profileApplyMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage profile request not found.' } })
      return
    }
    if (requestRecord.status !== 'APPROVED') {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Storage profile request must be APPROVED before apply.' } })
      return
    }
    const now = new Date().toISOString()
    state.storageProfileAssignments.set(requestRecord.bucketName, {
      bucketName: requestRecord.bucketName,
      profile: requestRecord.requestedProfile,
      appliedBy: 'admin',
      appliedAt: now,
      updatedAt: now,
      defaultProfile: false,
    })
    Object.assign(requestRecord, {
      status: 'APPLIED',
      appliedBy: 'admin',
      appliedAt: now,
      updatedAt: now,
    })
    state.auditLogs.unshift(auditLog('STORAGE_PROFILE_REQUEST_APPLY', 'STORAGE_PROFILE_REQUEST', String(requestRecord.id)))
    sendJson(response, 200, apiData(requestRecord))
    return
  }
  if (request.method === 'GET' && path === '/admin/object-lifecycle/rules') {
    sendJson(response, 200, apiData([]))
    return
  }
  if (request.method === 'GET' && path === '/admin/object-lifecycle/conflicts') {
    sendJson(response, 200, apiData({ ruleCount: 0, conflictCount: 0, conflicts: [] }))
    return
  }
  if (request.method === 'GET' && path === '/admin/object-share-policy') {
    sendJson(response, 200, apiData({ requirePassword: false, requireIpAllowlist: false, maxExpiryHours: 168, maxDownloads: 100 }))
    return
  }
  if (request.method === 'GET' && path === '/admin/object-share-analytics') {
    sendJson(response, 200, apiData(shareAnalytics()))
    return
  }
  if (request.method === 'GET' && path === '/admin/object-retention/status') {
    sendJson(response, 200, apiData({ enabled: true, retentionDays: 30, batchSize: 100, purgedObjectCount: 0, failedObjectCount: 0, failedRunCount: 0 }))
    return
  }
  sendJson(response, 200, apiData({ ok: true }))
}

function authPayload(user) {
  const accessToken = `mock-access-${user.loginId}-${Date.now()}-${randomUUID()}`
  const refreshToken = `mock-refresh-${user.loginId}-${Date.now()}-${randomUUID()}`
  state.sessions.set(accessToken, user)
  state.sessions.set(refreshToken, user)
  return {
    accessToken,
    refreshToken,
    user,
  }
}

function currentUser(request) {
  const token = bearerToken(request)
  if (token && state.sessions.has(token)) {
    return state.sessions.get(token)
  }
  return adminUser()
}

function sessionFromRefreshToken(refreshToken) {
  if (refreshToken && state.sessions.has(refreshToken)) {
    return state.sessions.get(refreshToken)
  }
  return null
}

function bearerToken(request) {
  const authorization = request?.headers?.authorization || ''
  const match = /^Bearer\s+(.+)$/i.exec(authorization)
  return match?.[1] || ''
}

function userForLogin(loginId = 'admin') {
  return loginId.toLowerCase().includes('dev') ? developerUser() : adminUser()
}

function adminUser() {
  return {
    id: 1,
    loginId: 'admin',
    email: 'admin@osmu.local',
    name: 'OSMU Admin',
    role: 'ADMIN',
    organizationId: 1,
    status: 'ACTIVE',
  }
}

function developerUser() {
  return {
    id: 2,
    loginId: 'developer',
    email: 'developer@osmu.local',
    name: 'OSMU Developer',
    role: 'USER',
    organizationId: 1,
    status: 'ACTIVE',
  }
}

function enterpriseAuthPlan() {
  return {
    status: 'LOCAL_ONLY',
    currentLoginMode: 'LOCAL_PASSWORD',
    activeLoginModes: ['LOCAL_PASSWORD'],
    plannedExternalModes: ['OIDC', 'LDAP'],
    externalProviderConfigured: false,
    oidc: { status: 'NOT_CONFIGURED', issuerUri: '', clientIdConfigured: false },
    ldap: { status: 'NOT_CONFIGURED', url: '', baseDn: '' },
    claimMapping: {
      subjectClaim: 'sub',
      emailClaim: 'email',
      nameClaim: 'name',
      roleClaim: 'osmu_roles',
      organizationClaim: 'osmu_org',
      teamClaim: 'osmu_teams',
      allowedDomains: [],
      jitProvisioningEnabled: false,
    },
    roleMappings: [
      { externalValue: 'osmu-admins', osmuRole: 'ADMIN', scopeRule: 'Global administration' },
      { externalValue: 'osmu-org-admins', osmuRole: 'ORG_ADMIN', scopeRule: 'Organization claim must match managed organization' },
      { externalValue: 'osmu-auditors', osmuRole: 'AUDITOR', scopeRule: 'Read-only audit and status routes' },
      { externalValue: '*', osmuRole: 'USER', scopeRule: 'Default role when no privileged mapping matches' },
    ],
    gates: [
      { key: 'provider-metadata', status: 'REVIEW', detail: 'Configure OIDC or LDAP provider before pilot login.' },
      { key: 'oidc-authorization-request', status: 'REVIEW', detail: 'Enable OIDC authorization-code start only after provider metadata and redirect URI are configured.' },
      { key: 'ldap-bind-search', status: 'REVIEW', detail: 'Enable LDAP bind/search only after directory smoke evidence is ready.' },
      { key: 'claim-mapping', status: 'SUCCESS', detail: 'Role, organization, and team claims are mapped.' },
      { key: 'login-cutover', status: 'REVIEW', detail: 'Local password login remains the only active login mode.' },
    ],
    nextImplementationSteps: [
      'Run OIDC callback smoke before replacing local-only login.',
      'Run LDAP bind/search smoke before replacing local-only login.',
    ],
    generatedAt: new Date().toISOString(),
  }
}

function oidcAuthorizationRequest() {
  const stateValue = randomUUID()
  const nonce = randomUUID()
  const codeChallenge = randomUUID().replaceAll('-', '')
  const redirectUri = 'http://localhost:5173/auth/oidc/callback'
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: 'osmu-web',
    redirect_uri: redirectUri,
    scope: 'openid profile email',
    state: stateValue,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  })
  return {
    authorizationUrl: `https://idp.example.com/realms/osmu/protocol/openid-connect/auth?${params.toString()}`,
    state: stateValue,
    nonce,
    codeChallenge,
    codeChallengeMethod: 'S256',
    redirectUri,
    scopes: ['openid', 'profile', 'email'],
    expiresAt: new Date(Date.now() + 300000).toISOString(),
  }
}

function enterpriseAuthClaimPreview(claims = {}) {
  const email = String(claims.email || '').trim().toLowerCase()
  const roleValues = Array.isArray(claims.osmu_roles) ? claims.osmu_roles : Array.isArray(claims.groups) ? claims.groups : []
  const mappedRoles = roleValues.includes('osmu-admins') ? ['ADMIN'] : roleValues.includes('osmu-org-admins') ? ['ORG_ADMIN'] : ['USER']
  const matchedAdmin = email === 'admin@example.com'
  return {
    status: matchedAdmin ? 'MATCHED_EXISTING_USER' : 'REQUIRES_ADMIN_APPROVAL',
    subject: String(claims.sub || ''),
    email,
    name: String(claims.name || ''),
    roleClaimValues: roleValues,
    mappedRoles,
    primaryRole: mappedRoles[0],
    organizationClaimValue: String(claims.osmu_org || claims.department || ''),
    teamClaimValues: Array.isArray(claims.osmu_teams) ? claims.osmu_teams : Array.isArray(claims.teams) ? claims.teams : [],
    allowedDomainMatched: !email || email.endsWith('@example.com'),
    existingUser: matchedAdmin ? { id: 1, loginId: 'admin', role: 'ADMIN', status: 'ACTIVE' } : null,
    jitProvisioningRequired: !matchedAdmin,
    adminApprovalRequired: !matchedAdmin,
    warnings: matchedAdmin ? [] : ['No ACTIVE local user matches this email; JIT provisioning would require admin approval.'],
    generatedAt: new Date().toISOString(),
    auditLogId: state.auditLogs.length + 1,
  }
}

function enterpriseAuthJitProvision(payload = {}) {
  const preview = enterpriseAuthClaimPreview(payload.claims || {})
  const loginId = preview.existingUser?.loginId || (preview.email.split('@')[0] || 'oidc-user').replace(/[^a-z0-9._-]/gi, '.').toLowerCase()
  const approvedRole = String(payload.approvedRole || preview.primaryRole || 'USER').toUpperCase()
  return {
    status: preview.existingUser ? 'ALREADY_PROVISIONED' : 'PROVISIONED',
    user: {
      id: preview.existingUser?.id || state.userSequence++,
      loginId,
      email: preview.email,
      name: preview.name || loginId,
      role: approvedRole,
      status: 'ACTIVE',
      organizationId: payload.organizationId || null,
    },
    preview,
    approvedRole,
    organizationId: payload.organizationId || null,
    privilegedRoleApproved: Boolean(payload.approvePrivilegedRole),
    auditLogId: state.auditLogs.length + 1,
  }
}

function filteredMockUsers(searchParams) {
  const keyword = (searchParams.get('keyword') || '').trim().toLowerCase()
  const status = (searchParams.get('status') || '').trim().toUpperCase()
  const requestedLimit = Number(searchParams.get('limit') || 200)
  const limit = Number.isFinite(requestedLimit) ? Math.min(200, Math.max(1, Math.floor(requestedLimit))) : 200
  const cursor = Number(searchParams.get('cursor') || 0)
  let users = [adminUser(), developerUser()]
    .filter((user) => !keyword
      || user.loginId.toLowerCase().includes(keyword)
      || user.email.toLowerCase().includes(keyword)
      || user.name.toLowerCase().includes(keyword))
    .filter((user) => !status || user.status === status)
    .filter((user) => !cursor || user.id < cursor)
    .sort((left, right) => right.id - left.id)

  const page = users.slice(0, limit)
  const nextCursor = users.length > limit ? String(page[page.length - 1].id) : null
  return apiItems(page, nextCursor)
}

function dashboardSummary() {
  return {
    usage: usageSummary(),
    system: systemStatus(),
    backup: backupStatus(),
    retention: { enabled: true, retentionDays: 30, batchSize: 100, purgedObjectCount: 0, failedObjectCount: 0, failedRunCount: 0 },
    shareAnalytics: shareAnalytics(),
    quota: {
      policyCount: 0,
      warningPolicyCount: 0,
      exhaustedPolicyCount: 0,
      totalQuotaBytes: state.buckets.reduce((sum, bucket) => sum + bucket.quotaBytes, 0),
      totalUsedBytes: state.buckets.reduce((sum, bucket) => sum + bucket.usedBytes, 0),
      totalRemainingBytes: state.buckets.reduce((sum, bucket) => sum + Math.max(0, bucket.quotaBytes - bucket.usedBytes), 0),
      topPolicies: [],
    },
    readiness: readinessSummary(),
    dataFlow: dataFlowSummary(),
    recentAuditLogs: state.auditLogs,
  }
}

function dataFlowFilters(url) {
  return {
    bucketName: url.searchParams.get('bucketName') || '',
    actorId: url.searchParams.get('actorId') || '',
    source: url.searchParams.get('source') || '',
    operation: url.searchParams.get('operation') || '',
    status: url.searchParams.get('status') || '',
    from: url.searchParams.get('from') || '',
    to: url.searchParams.get('to') || '',
    limit: Number(url.searchParams.get('limit') || 50),
  }
}

function dataFlowSummary(filters = {}) {
  const events = filterDataFlowEvents(state.dataFlowEvents || [], filters)
  const successUploads = events.filter((event) => event.eventType === 'UPLOAD' && event.status === 'SUCCESS')
  const successDownloads = events.filter((event) => event.eventType === 'DOWNLOAD' && event.status === 'SUCCESS')
  const successCopies = events.filter((event) => event.eventType === 'COPY' && event.status === 'SUCCESS')
  const uploadedBytes = successUploads.reduce((sum, event) => sum + Number(event.sizeBytes || 0), 0)
  const downloadedBytes = successDownloads.reduce((sum, event) => sum + Number(event.sizeBytes || 0), 0)
  const copiedBytes = successCopies.reduce((sum, event) => sum + Number(event.sizeBytes || 0), 0)
  const operationCount = (operation) => events.filter((event) => event.operation === operation && event.status === 'SUCCESS').length
  const bucketMetrics = new Map()
  for (const event of events) {
    if (!event.bucketName) continue
    if (!bucketMetrics.has(event.bucketName)) {
      bucketMetrics.set(event.bucketName, {
        bucketName: event.bucketName,
        uploadedBytes: 0,
        downloadedBytes: 0,
        copiedBytes: 0,
        totalBytes: 0,
        uploadCount: 0,
        downloadCount: 0,
        copyCount: 0,
        listCount: 0,
        deleteCount: 0,
        cancelCount: 0,
        failureCount: 0,
        lastEventAt: event.createdAt,
      })
    }
    const bucket = bucketMetrics.get(event.bucketName)
    if (event.eventType === 'UPLOAD' && event.status === 'SUCCESS') {
      bucket.uploadedBytes += Number(event.sizeBytes || 0)
      bucket.uploadCount += 1
    }
    if (event.eventType === 'DOWNLOAD' && event.status === 'SUCCESS') {
      bucket.downloadedBytes += Number(event.sizeBytes || 0)
      bucket.downloadCount += 1
    }
    if (event.eventType === 'COPY' && event.status === 'SUCCESS') {
      bucket.copiedBytes += Number(event.sizeBytes || 0)
      bucket.copyCount += 1
    }
    if (event.eventType === 'LIST' && event.status === 'SUCCESS') bucket.listCount += 1
    if (event.eventType === 'DELETE' && event.status === 'SUCCESS') bucket.deleteCount += 1
    if (event.eventType === 'CANCEL') bucket.cancelCount += 1
    if (event.eventType === 'FAILURE' || event.status === 'FAILED') bucket.failureCount += 1
    bucket.totalBytes = bucket.uploadedBytes + bucket.downloadedBytes + bucket.copiedBytes
    if (new Date(event.createdAt) > new Date(bucket.lastEventAt)) bucket.lastEventAt = event.createdAt
  }
  return {
    traffic: {
      uploadedBytes,
      downloadedBytes,
      copiedBytes,
      totalBytes: uploadedBytes + downloadedBytes + copiedBytes,
      ingressBytes: uploadedBytes,
      egressBytes: downloadedBytes,
      internalBytes: copiedBytes,
    },
    operations: {
      uploadCount: operationCount('upload'),
      downloadCount: operationCount('download'),
      copyCount: operationCount('copy'),
      listCount: operationCount('list'),
      deleteCount: operationCount('delete'),
      cancelCount: events.filter((event) => event.eventType === 'CANCEL').length,
      failureCount: events.filter((event) => event.eventType === 'FAILURE' || event.status === 'FAILED').length,
      totalCount: events.length,
    },
    topBuckets: [...bucketMetrics.values()].sort((left, right) => right.totalBytes - left.totalBytes).slice(0, 5),
    trendPoints: dataFlowTrend(events),
    recentEvents: events.slice(0, normalizeDataFlowLimit(filters.limit)),
    generatedAt: new Date().toISOString(),
  }
}

function dataFlowTrend(events) {
  const trendBuckets = new Map()
  for (const event of events) {
    const createdAt = Date.parse(event.createdAt)
    if (Number.isNaN(createdAt)) continue
    const bucketStartAt = new Date(Math.floor(createdAt / 3600000) * 3600000).toISOString()
    const source = String(event.source || 'unknown').toLowerCase()
    const operation = String(event.operation || 'unknown').toLowerCase()
    const key = `${bucketStartAt}|${source}|${operation}`
    if (!trendBuckets.has(key)) {
      trendBuckets.set(key, {
        bucketStartAt,
        source,
        operation,
        successCount: 0,
        failureCount: 0,
        cancelCount: 0,
        totalCount: 0,
        bytes: 0,
      })
    }
    const bucket = trendBuckets.get(key)
    bucket.totalCount += 1
    if (event.status === 'SUCCESS') {
      bucket.successCount += 1
      bucket.bytes += Math.max(0, Number(event.sizeBytes || 0))
    }
    if (event.eventType === 'CANCEL' || event.status === 'CANCELLED') bucket.cancelCount += 1
    if (event.eventType === 'FAILURE' || event.status === 'FAILED') bucket.failureCount += 1
  }
  return [...trendBuckets.values()]
    .sort((left, right) => (
      Date.parse(right.bucketStartAt) - Date.parse(left.bucketStartAt)
      || right.totalCount - left.totalCount
      || left.source.localeCompare(right.source)
      || left.operation.localeCompare(right.operation)
    ))
    .slice(0, 24)
}

function dataFlowCsv(filters = {}) {
  const rows = [
    ['createdAt', 'eventType', 'operation', 'direction', 'bucketName', 'objectKey', 'actorId', 'status', 'sizeBytes', 'source', 'message'],
    ...filterDataFlowEvents(state.dataFlowEvents || [], filters)
      .slice(0, normalizeDataFlowLimit(filters.limit))
      .map((event) => [
        event.createdAt,
        event.eventType,
        event.operation,
        event.direction,
        event.bucketName,
        event.objectKey,
        event.actorId,
        event.status,
        event.sizeBytes,
        event.source,
        event.message,
      ]),
  ]
  return rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n'
}

function csvCell(value) {
  return `"${String(value ?? '').replace(/"/g, '""').replace(/\r?\n/g, ' ')}"`
}

function filterDataFlowEvents(events, filters) {
  const from = parseDataFlowTime(filters.from)
  const to = parseDataFlowTime(filters.to)
  return events.filter((event) => {
    if (filters.bucketName && event.bucketName !== filters.bucketName) return false
    if (filters.actorId && event.actorId !== filters.actorId) return false
    if (filters.source && String(event.source || '').toLowerCase() !== String(filters.source).toLowerCase()) return false
    if (filters.operation && String(event.operation || '').toLowerCase() !== String(filters.operation).toLowerCase()) return false
    if (filters.status && String(event.status || '').toUpperCase() !== String(filters.status).toUpperCase()) return false
    const createdAt = Date.parse(event.createdAt)
    if (from !== null && createdAt < from) return false
    if (to !== null && createdAt > to) return false
    return true
  })
}

function parseDataFlowTime(value) {
  if (!value) return null
  const timestamp = Date.parse(value)
  return Number.isNaN(timestamp) ? null : timestamp
}

function normalizeDataFlowLimit(limit) {
  if (!Number.isFinite(limit) || limit <= 0) return 50
  return Math.min(500, Math.floor(limit))
}

function chargebackPreview(url) {
  refreshBucketUsage()
  const rates = chargebackRates(url)
  const limit = normalizeChargebackEventLimit(Number(url.searchParams.get('eventScanLimit') || state.billingPricingPolicy.eventScanLimit || 10000))
  const events = filterDataFlowEvents(state.dataFlowEvents || [], {
    from: url.searchParams.get('from') || '',
    to: url.searchParams.get('to') || '',
  }).slice(0, limit)
  const organizations = organizationUsageRows().map((organization) => chargebackOrganization(organization, events, rates))
  return {
    currency: String(url.searchParams.get('currency') || state.billingPricingPolicy.currency || 'USD').trim().toUpperCase().slice(0, 12) || 'USD',
    from: url.searchParams.get('from') || null,
    to: url.searchParams.get('to') || null,
    rates,
    eventScanLimit: limit,
    scannedEventCount: events.length,
    organizationCount: organizations.length,
    bucketCount: organizations.reduce((sum, organization) => sum + organization.bucketCount, 0),
    usedBytes: organizations.reduce((sum, organization) => sum + organization.usedBytes, 0),
    ingressBytes: organizations.reduce((sum, organization) => sum + organization.ingressBytes, 0),
    egressBytes: organizations.reduce((sum, organization) => sum + organization.egressBytes, 0),
    internalBytes: organizations.reduce((sum, organization) => sum + organization.internalBytes, 0),
    billableOperationCount: organizations.reduce((sum, organization) => sum + organization.billableOperationCount, 0),
    failedOperationCount: organizations.reduce((sum, organization) => sum + organization.failedOperationCount, 0),
    cancelledOperationCount: organizations.reduce((sum, organization) => sum + organization.cancelledOperationCount, 0),
    estimatedTotalCost: money(organizations.reduce((sum, organization) => sum + organization.estimatedTotalCost, 0)),
    organizations,
    generatedAt: new Date().toISOString(),
  }
}

function chargebackAlerts(url) {
  const preview = chargebackPreview(url)
  const warningAmount = money(state.billingPricingPolicy.warningAmount)
  const criticalAmount = money(state.billingPricingPolicy.criticalAmount)
  const organizations = (preview.organizations || [])
    .map((organization) => chargebackAlertOrganization(organization, warningAmount, criticalAmount))
    .filter(Boolean)
  return {
    currency: preview.currency,
    warningAmount,
    criticalAmount,
    alertCount: organizations.length,
    warningCount: organizations.filter((organization) => organization.severity === 'WARNING').length,
    criticalCount: organizations.filter((organization) => organization.severity === 'CRITICAL').length,
    organizations,
    generatedAt: new Date().toISOString(),
  }
}

function chargebackAlertOrganization(organization, warningAmount, criticalAmount) {
  const estimatedTotalCost = money(organization.estimatedTotalCost)
  const isCritical = criticalAmount > 0 && estimatedTotalCost >= criticalAmount
  const isWarning = warningAmount > 0 && estimatedTotalCost >= warningAmount
  if (!isCritical && !isWarning) return null
  return {
    organizationId: organization.organizationId,
    organizationName: organization.organizationName,
    severity: isCritical ? 'CRITICAL' : 'WARNING',
    estimatedTotalCost,
    warningAmount,
    criticalAmount,
  }
}

function chargebackAlertNotificationPreview(url) {
  const alerts = chargebackAlerts(url)
  const channel = normalizeNotificationChannel(url.searchParams.get('notificationChannel'))
  const target = normalizeNotificationTarget(url.searchParams.get('notificationTarget'))
  const notifications = (alerts.organizations || []).map((alert) => {
    const subject = `[OSMU] ${alert.severity} chargeback alert for ${alert.organizationName}`
    const message = `${alert.organizationName} projected chargeback cost is ${alerts.currency} ${money(alert.estimatedTotalCost)} (warning ${money(alert.warningAmount)}, critical ${money(alert.criticalAmount)}).`
    return {
      organizationId: alert.organizationId,
      organizationName: alert.organizationName,
      severity: alert.severity,
      estimatedTotalCost: money(alert.estimatedTotalCost),
      warningAmount: money(alert.warningAmount),
      criticalAmount: money(alert.criticalAmount),
      subject,
      message,
      payload: {
        eventType: 'chargeback.threshold',
        channel,
        target,
        organizationId: alert.organizationId,
        organizationName: alert.organizationName,
        severity: alert.severity,
        currency: alerts.currency,
        estimatedTotalCost: money(alert.estimatedTotalCost),
        warningAmount: money(alert.warningAmount),
        criticalAmount: money(alert.criticalAmount),
      },
    }
  })
  return {
    mode: 'PREVIEW',
    channel,
    target,
    externalDeliveryEnabled: false,
    currency: alerts.currency,
    notificationCount: notifications.length,
    notifications,
    generatedAt: new Date().toISOString(),
    note: 'Preview only - no external notification was sent.',
  }
}

function normalizeNotificationChannel(value) {
  return String(value || 'WEBHOOK').trim().toUpperCase().replace(/\s+/g, '_').slice(0, 32) || 'WEBHOOK'
}

function normalizeNotificationTarget(value) {
  const target = String(value || '').trim()
  return target ? target.slice(0, 512) : 'UNCONFIGURED'
}

function queueChargebackAlertNotifications(url) {
  const preview = chargebackAlertNotificationPreview(url)
  const now = new Date().toISOString()
  const reason = String(url.searchParams.get('reason') || 'Chargeback alert notification queued from admin billing panel.').trim().slice(0, 512)
  const deliveries = (preview.notifications || []).map((notification) => {
    const delivery = {
      id: state.chargebackNotificationDeliverySequence++,
      organizationId: notification.organizationId,
      organizationName: notification.organizationName,
      severity: notification.severity,
      estimatedTotalCost: notification.estimatedTotalCost,
      warningAmount: notification.warningAmount,
      criticalAmount: notification.criticalAmount,
      channel: preview.channel,
      target: preview.target,
      status: 'PENDING_DELIVERY_ADAPTER',
      attemptCount: 0,
      nextAttemptAt: now,
      subject: notification.subject,
      message: notification.message,
      payloadJson: JSON.stringify(notification.payload),
      requestedBy: 'admin',
      reason: reason || 'Chargeback alert notification queued from admin billing panel.',
      createdAt: now,
      updatedAt: now,
      lastError: '',
    }
    state.chargebackNotificationDeliveries.unshift(delivery)
    return delivery
  })
  return {
    mode: 'OUTBOX',
    status: 'PENDING_DELIVERY_ADAPTER',
    externalDeliveryEnabled: false,
    queuedCount: deliveries.length,
    deliveries,
    generatedAt: new Date().toISOString(),
    note: 'Recorded in delivery outbox; no external notification was sent because delivery adapters are not configured.',
  }
}

function chargebackAlertNotificationOutbox(url) {
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const deliveries = state.chargebackNotificationDeliveries.slice(0, limit)
  return {
    deliveryCount: deliveries.length,
    deliveries,
    generatedAt: new Date().toISOString(),
  }
}

function recordChargebackNotificationAdapterResult(deliveryId, url) {
  const delivery = state.chargebackNotificationDeliveries.find((item) => item.id === deliveryId)
  const now = new Date().toISOString()
  if (!delivery) {
    return {
      mode: 'ADAPTER_RESULT',
      status: 'NOT_FOUND',
      externalDeliveryEnabled: false,
      delivery: null,
      recordedAt: now,
      note: 'Chargeback notification delivery not found.',
    }
  }
  const result = adapterResult(url)
  delivery.status = notificationAdapterStatus(result)
  delivery.attemptCount = Number(delivery.attemptCount || 0) + 1
  delivery.nextAttemptAt = adapterNextAttemptAt(result, url, now)
  delivery.updatedAt = now
  delivery.lastError = adapterLastError(
    result,
    url,
    'Notification adapter waiting for credential/configuration reference.',
    'Notification adapter retry scheduled.'
  )
  state.auditLogs.unshift(auditLog('CHARGEBACK_ALERT_NOTIFICATION_ADAPTER_RESULT_RECORD', 'CHARGEBACK_ALERT_NOTIFICATION_DELIVERY', String(deliveryId)))
  return {
    mode: 'ADAPTER_RESULT',
    status: delivery.status,
    externalDeliveryEnabled: false,
    delivery,
    recordedAt: now,
    note: adapterResultNote(result, 'notification'),
  }
}

function createChargebackInvoiceDrafts(url) {
  const preview = chargebackPreview(url)
  const now = new Date().toISOString()
  const reason = String(url.searchParams.get('reason') || 'Chargeback invoice draft persisted from admin billing panel.').trim().slice(0, 512)
  const generatedDate = String(preview.generatedAt || now).slice(0, 10).replace(/-/g, '')
  const invoices = (preview.organizations || []).map((organization) => {
    const invoice = {
      id: state.chargebackInvoiceDraftSequence++,
      invoiceNumber: `OSMU-DRAFT-${generatedDate}-${organization.organizationId}`,
      status: 'DRAFT_REVIEW',
      finalInvoice: false,
      paymentRequest: false,
      organizationId: organization.organizationId,
      organizationName: organization.organizationName,
      currency: preview.currency,
      from: preview.from,
      to: preview.to,
      previewGeneratedAt: preview.generatedAt,
      eventScanLimit: preview.eventScanLimit,
      storageGbMonthRate: preview.rates?.storageGbMonthRate || 0,
      ingressGbRate: preview.rates?.ingressGbRate || 0,
      egressGbRate: preview.rates?.egressGbRate || 0,
      internalGbRate: preview.rates?.internalGbRate || 0,
      operationThousandRate: preview.rates?.operationThousandRate || 0,
      bucketCount: organization.bucketCount,
      objectCount: organization.objectCount,
      usedBytes: organization.usedBytes,
      storageCost: organization.projectedStorageCost,
      trafficCost: money(Number(organization.ingressCost || 0) + Number(organization.egressCost || 0) + Number(organization.internalCost || 0)),
      operationCost: organization.operationCost,
      estimatedTotalCost: organization.estimatedTotalCost,
      requestedBy: 'admin',
      approvedBy: '',
      reason: reason || 'Chargeback invoice draft persisted from admin billing panel.',
      approvalNote: '',
      createdAt: now,
      updatedAt: now,
      approvedAt: '',
      note: 'Internal review only - not a final legal invoice or payment request.',
    }
    state.chargebackInvoiceDrafts.unshift(invoice)
    return invoice
  })
  return {
    mode: 'DRAFT_REVIEW',
    status: 'DRAFT_REVIEW',
    finalInvoice: false,
    paymentRequest: false,
    persistedCount: invoices.length,
    invoices,
    generatedAt: new Date().toISOString(),
    note: 'Persisted for internal review only - not a final legal invoice or payment request.',
  }
}

function chargebackInvoiceDrafts(url) {
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const status = String(url.searchParams.get('status') || '').trim().toUpperCase()
  const invoices = (status
    ? state.chargebackInvoiceDrafts.filter((invoice) => invoice.status === status)
    : state.chargebackInvoiceDrafts).slice(0, limit)
  return {
    invoiceCount: invoices.length,
    invoices,
    generatedAt: new Date().toISOString(),
  }
}

function approveChargebackInvoiceDraft(invoiceId, url) {
  const invoice = state.chargebackInvoiceDrafts.find((item) => item.id === invoiceId)
  if (!invoice) {
    return {
      status: 'NOT_FOUND',
      finalInvoice: false,
      paymentRequest: false,
      invoice: null,
      generatedAt: new Date().toISOString(),
      note: 'Chargeback invoice draft not found.',
    }
  }
  const now = new Date().toISOString()
  invoice.status = 'APPROVED_INTERNAL'
  invoice.approvedBy = 'admin'
  invoice.approvalNote = String(url.searchParams.get('approvalNote') || 'Internal chargeback invoice draft approved.').trim().slice(0, 512)
  invoice.approvedAt = now
  invoice.updatedAt = now
  return {
    status: 'APPROVED_INTERNAL',
    finalInvoice: false,
    paymentRequest: false,
    invoice,
    generatedAt: now,
    note: 'Approved internally for chargeback review only - not a final legal invoice or payment request.',
  }
}

function finalizeChargebackInvoiceDraft(invoiceId, url) {
  const draft = state.chargebackInvoiceDrafts.find((item) => item.id === invoiceId)
  const now = new Date().toISOString()
  if (!draft || draft.status !== 'APPROVED_INTERNAL') {
    return {
      mode: 'FINAL_INVOICE',
      status: 'INVALID_DRAFT',
      paymentStatus: 'NOT_REQUESTED',
      finalInvoice: false,
      paymentRequest: false,
      invoice: null,
      generatedAt: now,
      note: 'Only APPROVED_INTERNAL invoice drafts can become final invoices.',
    }
  }
  const existing = state.chargebackFinalInvoices.find((invoice) => invoice.sourceDraftId === invoiceId)
  if (existing) {
    return {
      mode: 'FINAL_INVOICE',
      status: existing.status,
      paymentStatus: existing.paymentStatus,
      finalInvoice: true,
      paymentRequest: existing.paymentRequest,
      invoice: existing,
      generatedAt: now,
      note: 'Chargeback invoice draft already has a final invoice.',
    }
  }
  const finalInvoice = {
    ...draft,
    id: state.chargebackFinalInvoiceSequence++,
    sourceDraftId: draft.id,
    invoiceNumber: String(draft.invoiceNumber || '').startsWith('OSMU-DRAFT-')
      ? `OSMU-FINAL-${String(draft.invoiceNumber).slice('OSMU-DRAFT-'.length)}`
      : `OSMU-FINAL-${draft.invoiceNumber || draft.id}`,
    status: 'FINALIZED',
    paymentStatus: 'NOT_REQUESTED',
    finalInvoice: true,
    paymentRequest: false,
    finalizedBy: 'admin',
    paymentRequestedBy: '',
    paymentRecordedBy: '',
    finalizationNote: String(url.searchParams.get('finalizationNote') || 'Final chargeback invoice created from approved internal draft.').trim().slice(0, 512),
    paymentRequestNote: '',
    paymentReference: '',
    finalizedAt: now,
    paymentRequestedAt: '',
    paidAt: '',
    updatedAt: now,
    note: 'Final legal chargeback invoice created; payment request is not sent until explicitly requested.',
  }
  state.chargebackFinalInvoices.unshift(finalInvoice)
  return {
    mode: 'FINAL_INVOICE',
    status: 'FINALIZED',
    paymentStatus: 'NOT_REQUESTED',
    finalInvoice: true,
    paymentRequest: false,
    invoice: finalInvoice,
    generatedAt: now,
    note: 'Final invoice created from approved internal chargeback draft; no payment request has been sent.',
  }
}

function chargebackFinalInvoices(url) {
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const status = String(url.searchParams.get('status') || '').trim().toUpperCase()
  const invoices = (status
    ? state.chargebackFinalInvoices.filter((invoice) => invoice.status === status)
    : state.chargebackFinalInvoices).slice(0, limit)
  return {
    invoiceCount: invoices.length,
    invoices,
    generatedAt: new Date().toISOString(),
  }
}

function requestChargebackInvoicePayment(invoiceId, url) {
  const invoice = state.chargebackFinalInvoices.find((item) => item.id === invoiceId)
  const now = new Date().toISOString()
  if (!invoice || invoice.status !== 'FINALIZED') {
    return {
      mode: 'PAYMENT_REQUEST',
      status: 'INVALID_INVOICE',
      paymentStatus: invoice?.paymentStatus || 'NOT_REQUESTED',
      finalInvoice: Boolean(invoice),
      paymentRequest: false,
      invoice: invoice || null,
      generatedAt: now,
      note: 'Only FINALIZED invoices can request payment.',
    }
  }
  invoice.status = 'PAYMENT_REQUESTED'
  invoice.paymentStatus = 'REQUESTED'
  invoice.paymentRequest = true
  invoice.paymentRequestedBy = 'admin'
  invoice.paymentRequestNote = String(url.searchParams.get('paymentRequestNote') || 'Manual chargeback payment workflow update.').trim().slice(0, 512)
  invoice.paymentRequestedAt = now
  invoice.updatedAt = now
  invoice.note = 'Final invoice payment request recorded for billing operations.'
  return {
    mode: 'PAYMENT_REQUEST',
    status: 'PAYMENT_REQUESTED',
    paymentStatus: 'REQUESTED',
    finalInvoice: true,
    paymentRequest: true,
    invoice,
    generatedAt: now,
    note: 'Payment request recorded for the final chargeback invoice.',
  }
}

function recordChargebackInvoicePayment(invoiceId, url) {
  const invoice = state.chargebackFinalInvoices.find((item) => item.id === invoiceId)
  const now = new Date().toISOString()
  if (!invoice || invoice.status !== 'PAYMENT_REQUESTED') {
    return {
      mode: 'PAYMENT_RECORD',
      status: 'INVALID_INVOICE',
      paymentStatus: invoice?.paymentStatus || 'NOT_REQUESTED',
      finalInvoice: Boolean(invoice),
      paymentRequest: Boolean(invoice?.paymentRequest),
      invoice: invoice || null,
      generatedAt: now,
      note: 'Only PAYMENT_REQUESTED invoices can be marked paid.',
    }
  }
  invoice.status = 'PAID'
  invoice.paymentStatus = 'PAID'
  invoice.paymentRequest = true
  invoice.paymentRecordedBy = 'admin'
  invoice.paymentReference = String(url.searchParams.get('paymentReference') || `MANUAL-${now.slice(0, 10)}`).trim().slice(0, 512)
  invoice.paymentRequestNote = String(url.searchParams.get('paymentNote') || invoice.paymentRequestNote || 'Manual chargeback payment workflow update.').trim().slice(0, 512)
  invoice.paidAt = now
  invoice.updatedAt = now
  invoice.note = 'Final invoice payment recorded for billing operations.'
  return {
    mode: 'PAYMENT_RECORD',
    status: 'PAID',
    paymentStatus: 'PAID',
    finalInvoice: true,
    paymentRequest: true,
    invoice,
    generatedAt: now,
    note: 'Payment record attached to the final chargeback invoice.',
  }
}

function chargebackPaymentProviderHandoffPreview(invoiceId, url) {
  const invoice = state.chargebackFinalInvoices.find((item) => item.id === invoiceId)
  const now = new Date().toISOString()
  if (!invoice || invoice.status !== 'PAYMENT_REQUESTED') {
    return {
      mode: 'PREVIEW',
      provider: paymentProvider(url),
      targetAccount: paymentTargetAccount(url),
      externalPaymentEnabled: false,
      invoice: invoice || null,
      payload: {},
      generatedAt: now,
      note: 'Only PAYMENT_REQUESTED invoices can be queued for payment provider handoff.',
    }
  }
  const provider = paymentProvider(url)
  const targetAccount = paymentTargetAccount(url)
  return {
    mode: 'PREVIEW',
    provider,
    targetAccount,
    externalPaymentEnabled: false,
    invoice,
    payload: chargebackPaymentProviderPayload(invoice, provider, targetAccount),
    generatedAt: now,
    note: 'Preview only - no external payment provider was called.',
  }
}

function queueChargebackPaymentProviderHandoff(invoiceId, url) {
  const preview = chargebackPaymentProviderHandoffPreview(invoiceId, url)
  const now = new Date().toISOString()
  if (!preview.invoice || preview.invoice.status !== 'PAYMENT_REQUESTED') {
    return {
      mode: 'OUTBOX',
      status: 'INVALID_INVOICE',
      externalPaymentEnabled: false,
      handoff: null,
      generatedAt: now,
      note: preview.note,
    }
  }
  const handoff = {
    id: state.chargebackPaymentProviderHandoffSequence++,
    finalInvoiceId: preview.invoice.id,
    invoiceNumber: preview.invoice.invoiceNumber,
    organizationId: preview.invoice.organizationId,
    organizationName: preview.invoice.organizationName,
    currency: preview.invoice.currency,
    amount: Number(preview.invoice.estimatedTotalCost || 0),
    provider: preview.provider,
    targetAccount: preview.targetAccount,
    status: 'PENDING_PAYMENT_PROVIDER_ADAPTER',
    attemptCount: 0,
    nextAttemptAt: '',
    payloadJson: JSON.stringify(preview.payload),
    requestedBy: 'admin',
    reason: String(url.searchParams.get('reason') || 'Chargeback payment provider handoff queued from admin billing panel.').trim().slice(0, 512),
    createdAt: now,
    updatedAt: now,
    lastError: '',
  }
  state.chargebackPaymentProviderHandoffs.unshift(handoff)
  state.auditLogs.unshift(auditLog('CHARGEBACK_FINAL_INVOICE_PAYMENT_PROVIDER_HANDOFF_QUEUE', 'CHARGEBACK_FINAL_INVOICE', String(invoiceId)))
  return {
    mode: 'OUTBOX',
    status: 'PENDING_PAYMENT_PROVIDER_ADAPTER',
    externalPaymentEnabled: false,
    handoff,
    generatedAt: now,
    note: 'Recorded in payment provider handoff outbox; no external payment provider was called.',
  }
}

function chargebackPaymentProviderHandoffs(url) {
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const status = String(url.searchParams.get('status') || '').trim().toUpperCase()
  const handoffs = (status
    ? state.chargebackPaymentProviderHandoffs.filter((handoff) => handoff.status === status)
    : state.chargebackPaymentProviderHandoffs).slice(0, limit)
  return {
    handoffCount: handoffs.length,
    handoffs,
    generatedAt: new Date().toISOString(),
  }
}

function recordChargebackPaymentProviderAdapterResult(handoffId, url) {
  const handoff = state.chargebackPaymentProviderHandoffs.find((item) => item.id === handoffId)
  const now = new Date().toISOString()
  if (!handoff) {
    return {
      mode: 'ADAPTER_RESULT',
      status: 'NOT_FOUND',
      externalPaymentEnabled: false,
      handoff: null,
      recordedAt: now,
      note: 'Chargeback payment provider handoff not found.',
    }
  }
  const result = adapterResult(url)
  handoff.status = paymentProviderAdapterStatus(result)
  handoff.attemptCount = Number(handoff.attemptCount || 0) + 1
  handoff.nextAttemptAt = adapterNextAttemptAt(result, url, now)
  handoff.updatedAt = now
  handoff.lastError = adapterLastError(
    result,
    url,
    'Payment provider adapter waiting for credential/configuration reference.',
    'Payment provider adapter retry scheduled.'
  )
  state.auditLogs.unshift(auditLog('CHARGEBACK_PAYMENT_PROVIDER_ADAPTER_RESULT_RECORD', 'CHARGEBACK_PAYMENT_PROVIDER_HANDOFF', String(handoffId)))
  return {
    mode: 'ADAPTER_RESULT',
    status: handoff.status,
    externalPaymentEnabled: false,
    handoff,
    recordedAt: now,
    note: adapterResultNote(result, 'payment provider'),
  }
}

function chargebackPaymentProviderPayload(invoice, provider, targetAccount) {
  return {
    eventType: 'chargeback.payment_provider.handoff',
    finalInvoiceId: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    organizationId: invoice.organizationId,
    organizationName: invoice.organizationName,
    currency: invoice.currency,
    amount: Number(invoice.estimatedTotalCost || 0),
    paymentStatus: invoice.paymentStatus,
    provider,
    targetAccount,
    externalPaymentEnabled: false,
  }
}

function paymentProvider(url) {
  return String(url.searchParams.get('paymentProvider') || 'MANUAL_AP')
    .trim()
    .toUpperCase()
    .replaceAll(' ', '_')
    .slice(0, 64) || 'MANUAL_AP'
}

function paymentTargetAccount(url) {
  return String(url.searchParams.get('paymentTargetAccount') || 'UNCONFIGURED').trim().slice(0, 512) || 'UNCONFIGURED'
}

function adapterResult(url) {
  const result = String(url.searchParams.get('result') || 'BLOCKED_CREDENTIAL')
    .trim()
    .toUpperCase()
    .replaceAll('-', '_')
    .replaceAll(' ', '_')
  if (result === 'BLOCKED_SECRET' || result === 'SECRET_REQUIRED') {
    return 'BLOCKED_CREDENTIAL'
  }
  return ['SUCCESS', 'RETRY', 'BLOCKED_CREDENTIAL'].includes(result) ? result : 'BLOCKED_CREDENTIAL'
}

function notificationAdapterStatus(result) {
  if (result === 'SUCCESS') {
    return 'DELIVERY_ADAPTER_SUCCEEDED'
  }
  if (result === 'RETRY') {
    return 'DELIVERY_ADAPTER_RETRY_SCHEDULED'
  }
  return 'DELIVERY_ADAPTER_BLOCKED_CREDENTIAL'
}

function paymentProviderAdapterStatus(result) {
  if (result === 'SUCCESS') {
    return 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED'
  }
  if (result === 'RETRY') {
    return 'PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED'
  }
  return 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL'
}

function adapterNextAttemptAt(result, url, now) {
  if (result !== 'RETRY') {
    return ''
  }
  const retryDelayMinutes = clampNumber(Number(url.searchParams.get('retryDelayMinutes') || 60), 1, 1440)
  return new Date(Date.parse(now) + retryDelayMinutes * 60 * 1000).toISOString()
}

function adapterLastError(result, url, blockedFallback, retryFallback) {
  if (result === 'SUCCESS') {
    return ''
  }
  return String(url.searchParams.get('lastError') || (result === 'RETRY' ? retryFallback : blockedFallback))
    .trim()
    .slice(0, 512)
}

function adapterResultNote(result, adapterName) {
  if (result === 'SUCCESS') {
    return `Recorded ${adapterName} adapter success result; no external call was made by this API.`
  }
  if (result === 'RETRY') {
    return `Recorded retryable ${adapterName} adapter result and scheduled the next attempt.`
  }
  return `Recorded blocked ${adapterName} adapter result without storing credentials or raw provider responses.`
}

function createBillingPricingPolicyProposal(payload = {}) {
  const now = new Date().toISOString()
  const proposedPolicy = saveBillingPricingPolicy(payload)
  const proposal = {
    id: state.billingPricingPolicyProposalSequence++,
    status: 'PENDING_APPROVAL',
    approvedPriceList: false,
    currency: proposedPolicy.currency,
    storageGbMonthRate: proposedPolicy.storageGbMonthRate,
    ingressGbRate: proposedPolicy.ingressGbRate,
    egressGbRate: proposedPolicy.egressGbRate,
    internalGbRate: proposedPolicy.internalGbRate,
    operationThousandRate: proposedPolicy.operationThousandRate,
    warningAmount: proposedPolicy.warningAmount,
    criticalAmount: proposedPolicy.criticalAmount,
    eventScanLimit: proposedPolicy.eventScanLimit,
    requestedBy: 'admin',
    approvedBy: '',
    reason: String(payload.reason || 'Billing pricing policy proposal').trim().slice(0, 512),
    approvalNote: '',
    createdAt: now,
    updatedAt: now,
    approvedAt: '',
    appliedAt: '',
  }
  state.billingPricingPolicyProposals.unshift(proposal)
  state.auditLogs.unshift(auditLog('BILLING_PRICING_POLICY_PROPOSAL_CREATE', 'BILLING_PRICING_POLICY_PROPOSAL', String(proposal.id)))
  return {
    status: 'PENDING_APPROVAL',
    approvedPriceList: false,
    proposal,
    generatedAt: now,
    note: 'Pricing policy proposal is waiting for internal approval and is not an approved external price list.',
  }
}

function billingPricingPolicyProposals(url) {
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const status = String(url.searchParams.get('status') || '').trim().toUpperCase()
  const proposals = (status
    ? state.billingPricingPolicyProposals.filter((proposal) => proposal.status === status)
    : state.billingPricingPolicyProposals).slice(0, limit)
  return {
    proposalCount: proposals.length,
    proposals,
    generatedAt: new Date().toISOString(),
  }
}

function approveBillingPricingPolicyProposal(proposalId, url) {
  const proposal = state.billingPricingPolicyProposals.find((item) => item.id === proposalId)
  if (!proposal) {
    return {
      status: 'NOT_FOUND',
      approvedPriceList: false,
      proposal: null,
      appliedPolicy: state.billingPricingPolicy,
      generatedAt: new Date().toISOString(),
      note: 'Billing pricing policy proposal not found.',
    }
  }
  if (proposal.status !== 'PENDING_APPROVAL') {
    return {
      status: proposal.status,
      approvedPriceList: false,
      proposal,
      appliedPolicy: state.billingPricingPolicy,
      generatedAt: new Date().toISOString(),
      note: 'Only pending pricing policy proposals can be approved.',
    }
  }
  const now = new Date().toISOString()
  state.billingPricingPolicy = saveBillingPricingPolicy(proposal)
  proposal.status = 'APPROVED_APPLIED'
  proposal.approvedPriceList = false
  proposal.approvedBy = 'admin'
  proposal.approvalNote = String(url.searchParams.get('approvalNote') || 'Internal billing pricing policy proposal approved.').trim().slice(0, 512)
  proposal.approvedAt = now
  proposal.appliedAt = now
  proposal.updatedAt = now
  state.auditLogs.unshift(auditLog('BILLING_PRICING_POLICY_PROPOSAL_APPROVE', 'BILLING_PRICING_POLICY_PROPOSAL', String(proposal.id)))
  return {
    status: 'APPROVED_APPLIED',
    approvedPriceList: false,
    proposal,
    appliedPolicy: state.billingPricingPolicy,
    generatedAt: now,
    note: 'Pricing policy proposal was approved for internal chargeback calculation only; it is not a final legal price list.',
  }
}

function chargebackPreviewCsv(url) {
  const preview = chargebackPreview(url)
  const rates = preview.rates || {}
  const organizations = preview.organizations || []
  const totalRow = [
    'TOTAL',
    preview.currency,
    preview.from,
    preview.to,
    preview.generatedAt,
    preview.eventScanLimit,
    preview.scannedEventCount,
    preview.organizationCount,
    '',
    'TOTAL',
    preview.bucketCount,
    organizations.reduce((sum, organization) => sum + Number(organization.objectCount || 0), 0),
    preview.usedBytes,
    preview.ingressBytes,
    preview.egressBytes,
    preview.internalBytes,
    preview.billableOperationCount,
    preview.failedOperationCount,
    preview.cancelledOperationCount,
    rates.storageGbMonthRate,
    rates.ingressGbRate,
    rates.egressGbRate,
    rates.internalGbRate,
    rates.operationThousandRate,
    money(organizations.reduce((sum, organization) => sum + Number(organization.projectedStorageCost || 0), 0)),
    money(organizations.reduce((sum, organization) => sum + Number(organization.ingressCost || 0), 0)),
    money(organizations.reduce((sum, organization) => sum + Number(organization.egressCost || 0), 0)),
    money(organizations.reduce((sum, organization) => sum + Number(organization.internalCost || 0), 0)),
    money(organizations.reduce((sum, organization) => sum + Number(organization.operationCost || 0), 0)),
    preview.estimatedTotalCost,
  ]
  const rows = [
    ['rowType', 'currency', 'from', 'to', 'generatedAt', 'eventScanLimit', 'scannedEventCount', 'organizationCount', 'organizationId', 'organizationName', 'bucketCount', 'objectCount', 'usedBytes', 'ingressBytes', 'egressBytes', 'internalBytes', 'billableOperationCount', 'failedOperationCount', 'cancelledOperationCount', 'storageGbMonthRate', 'ingressGbRate', 'egressGbRate', 'internalGbRate', 'operationThousandRate', 'projectedStorageCost', 'ingressCost', 'egressCost', 'internalCost', 'operationCost', 'estimatedTotalCost'],
    totalRow,
    ...organizations.map((organization) => [
      'ORGANIZATION',
      preview.currency,
      preview.from,
      preview.to,
      preview.generatedAt,
      preview.eventScanLimit,
      preview.scannedEventCount,
      '',
      organization.organizationId,
      organization.organizationName,
      organization.bucketCount,
      organization.objectCount,
      organization.usedBytes,
      organization.ingressBytes,
      organization.egressBytes,
      organization.internalBytes,
      organization.billableOperationCount,
      organization.failedOperationCount,
      organization.cancelledOperationCount,
      rates.storageGbMonthRate,
      rates.ingressGbRate,
      rates.egressGbRate,
      rates.internalGbRate,
      rates.operationThousandRate,
      organization.projectedStorageCost,
      organization.ingressCost,
      organization.egressCost,
      organization.internalCost,
      organization.operationCost,
      organization.estimatedTotalCost,
    ]),
  ]
  return rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n'
}

function chargebackInvoiceDraftCsv(url) {
  const preview = chargebackPreview(url)
  const generatedDate = String(preview.generatedAt || new Date().toISOString()).slice(0, 10).replace(/-/g, '')
  const rows = [
    ['rowType', 'invoiceNumber', 'invoiceStatus', 'currency', 'from', 'to', 'generatedAt', 'organizationId', 'organizationName', 'bucketCount', 'objectCount', 'usedBytes', 'storageCost', 'trafficCost', 'operationCost', 'estimatedTotalCost', 'note'],
    ...(preview.organizations || []).map((organization) => [
      'DRAFT_INVOICE',
      `OSMU-DRAFT-${generatedDate}-${organization.organizationId}`,
      'DRAFT',
      preview.currency,
      preview.from,
      preview.to,
      preview.generatedAt,
      organization.organizationId,
      organization.organizationName,
      organization.bucketCount,
      organization.objectCount,
      organization.usedBytes,
      organization.projectedStorageCost,
      money(Number(organization.ingressCost || 0) + Number(organization.egressCost || 0) + Number(organization.internalCost || 0)),
      organization.operationCost,
      organization.estimatedTotalCost,
      'Preview only - not a final invoice or approved commercial price list.',
    ]),
  ]
  return rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n'
}

function chargebackRates(url) {
  return {
    storageGbMonthRate: parseChargebackRate(url.searchParams.get('storageGbMonthRate'), state.billingPricingPolicy.storageGbMonthRate),
    ingressGbRate: parseChargebackRate(url.searchParams.get('ingressGbRate'), state.billingPricingPolicy.ingressGbRate),
    egressGbRate: parseChargebackRate(url.searchParams.get('egressGbRate'), state.billingPricingPolicy.egressGbRate),
    internalGbRate: parseChargebackRate(url.searchParams.get('internalGbRate'), state.billingPricingPolicy.internalGbRate),
    operationThousandRate: parseChargebackRate(url.searchParams.get('operationThousandRate'), state.billingPricingPolicy.operationThousandRate),
  }
}

function chargebackOrganization(organization, events, rates) {
  const counters = chargebackCounters(events)
  const projectedStorageCost = costForBytes(rates.storageGbMonthRate, organization.usedBytes)
  const ingressCost = costForBytes(rates.ingressGbRate, counters.ingressBytes)
  const egressCost = costForBytes(rates.egressGbRate, counters.egressBytes)
  const internalCost = costForBytes(rates.internalGbRate, counters.internalBytes)
  const operationCost = costForOperations(rates.operationThousandRate, counters.billableOperationCount)
  return {
    organizationId: organization.id,
    organizationName: organization.name,
    bucketCount: organization.bucketCount,
    objectCount: organization.objectCount,
    usedBytes: organization.usedBytes,
    ingressBytes: counters.ingressBytes,
    egressBytes: counters.egressBytes,
    internalBytes: counters.internalBytes,
    billableOperationCount: counters.billableOperationCount,
    failedOperationCount: counters.failedOperationCount,
    cancelledOperationCount: counters.cancelledOperationCount,
    projectedStorageCost,
    ingressCost,
    egressCost,
    internalCost,
    operationCost,
    estimatedTotalCost: money(projectedStorageCost + ingressCost + egressCost + internalCost + operationCost),
  }
}

function chargebackCounters(events) {
  return events.reduce((counters, event) => {
    if (event.status === 'FAILED' || event.eventType === 'FAILURE') {
      counters.failedOperationCount += 1
      return counters
    }
    if (event.status === 'CANCELLED' || event.eventType === 'CANCEL') {
      counters.cancelledOperationCount += 1
      return counters
    }
    if (event.status !== 'SUCCESS') return counters
    counters.billableOperationCount += 1
    const bytes = Math.max(0, Number(event.sizeBytes || 0))
    if (event.direction === 'INGRESS') counters.ingressBytes += bytes
    if (event.direction === 'EGRESS') counters.egressBytes += bytes
    if (event.direction === 'INTERNAL') counters.internalBytes += bytes
    return counters
  }, {
    ingressBytes: 0,
    egressBytes: 0,
    internalBytes: 0,
    billableOperationCount: 0,
    failedOperationCount: 0,
    cancelledOperationCount: 0,
  })
}

function organizationUsageRows() {
  refreshBucketUsage()
  const usedBytes = state.buckets.reduce((sum, bucket) => sum + Number(bucket.usedBytes || 0), 0)
  return [{
    id: 1,
    name: 'Mock Organization',
    defaultQuotaBytes: 10 * BYTES_PER_GIB,
    bucketQuotaBytes: state.buckets.reduce((sum, bucket) => sum + Number(bucket.quotaBytes || 0), 0),
    bucketCount: state.buckets.length,
    objectCount: Array.from(state.objects.values()).reduce((sum, items) => sum + items.length, 0),
    usedBytes,
  }]
}

function defaultBillingPricingPolicy() {
  return {
    currency: 'USD',
    storageGbMonthRate: 0,
    ingressGbRate: 0,
    egressGbRate: 0,
    internalGbRate: 0,
    operationThousandRate: 0,
    warningAmount: 0,
    criticalAmount: 0,
    eventScanLimit: 10000,
    updatedAt: null,
  }
}

function saveBillingPricingPolicy(payload = {}) {
  const current = state.billingPricingPolicy || defaultBillingPricingPolicy()
  const warningAmount = parseChargebackRate(payload.warningAmount, current.warningAmount)
  const criticalAmount = parseChargebackRate(payload.criticalAmount, current.criticalAmount)
  if (criticalAmount > 0 && warningAmount > 0 && criticalAmount < warningAmount) {
    throw new Error('criticalAmount must be zero or greater than or equal to warningAmount.')
  }
  return {
    currency: String(payload.currency || current.currency || 'USD').trim().toUpperCase().slice(0, 12) || 'USD',
    storageGbMonthRate: parseChargebackRate(payload.storageGbMonthRate, current.storageGbMonthRate),
    ingressGbRate: parseChargebackRate(payload.ingressGbRate, current.ingressGbRate),
    egressGbRate: parseChargebackRate(payload.egressGbRate, current.egressGbRate),
    internalGbRate: parseChargebackRate(payload.internalGbRate, current.internalGbRate),
    operationThousandRate: parseChargebackRate(payload.operationThousandRate, current.operationThousandRate),
    warningAmount,
    criticalAmount,
    eventScanLimit: normalizeChargebackEventLimit(Number(payload.eventScanLimit || current.eventScanLimit || 10000)),
    updatedAt: new Date().toISOString(),
  }
}

function parseChargebackRate(value, fallback = 0) {
  const number = Number(value ?? fallback)
  return Number.isFinite(number) && number > 0 ? money(number) : 0
}

function normalizeChargebackEventLimit(limit) {
  if (!Number.isFinite(limit) || limit <= 0) return 10000
  return Math.min(50000, Math.floor(limit))
}

function costForBytes(rate, bytes) {
  return money((Number(rate || 0) * Math.max(0, Number(bytes || 0))) / BYTES_PER_GIB)
}

function costForOperations(rate, count) {
  return money((Number(rate || 0) * Math.max(0, Number(count || 0))) / 1000)
}

function money(value) {
  return Math.round(Number(value || 0) * 1000000) / 1000000
}

function clampNumber(value, min, max) {
  if (!Number.isFinite(value)) return min
  return Math.max(min, Math.min(max, value))
}

function usageSummary() {
  refreshBucketUsage()
  return {
    bucketCount: state.buckets.length,
    objectCount: Array.from(state.objects.values()).reduce((sum, items) => sum + items.length, 0),
    totalBytes: state.buckets.reduce((sum, bucket) => sum + bucket.quotaBytes, 0),
    usedBytes: state.buckets.reduce((sum, bucket) => sum + bucket.usedBytes, 0),
  }
}

function systemStatus() {
  return {
    status: 'UP',
    backend: 'UP',
    storage: 'MOCK',
    database: 'MOCK',
    accessKeyProvisioner: 'MOCK',
    metadataEngine: 'mock-memory',
    storageEngine: 'mock-memory',
  }
}

function backupStatus() {
  return {
    status: 'DRILL_PENDING',
    metadataStore: 'mock-memory',
    objectStore: 'mock-memory',
    databaseHealthy: true,
    storageHealthy: true,
    rpoTarget: '24h',
    rtoTarget: '4h',
    runbookAvailable: true,
    restoreDrillExecuted: false,
    lastRestoreDrillAt: '2026-06-15T10:30:00+09:00',
    latestRestoreDrillEvidence: {
      id: 1,
      environment: 'frontend-mock',
      operator: 'mock-admin',
      result: 'PARTIAL',
      recordedAt: '2026-06-15T10:30:00+09:00',
      statusImpact: 'REVIEW_REQUIRED',
      gaps: ['Run Kubernetes DR finalizer against a real cluster.'],
    },
    pendingGates: ['real MariaDB/MinIO backup drill required'],
  }
}

function readinessSummary() {
  return {
    status: 'REVIEW',
    runtimeProfile: 'Frontend mock API demo',
    blockerCount: 0,
    warningCount: 3,
    blockers: [],
    warnings: [
      'Java backend tests pending',
      'Docker MariaDB/MinIO smoke pending',
      'Operations readiness convergence action required',
    ],
    severitySummaries: [
      { severity: 'WARNING', count: 3 },
    ],
    categorySummaries: [
      { category: 'RUNTIME', count: 1 },
      { category: 'STORAGE', count: 1 },
      { category: 'OPERATIONS', count: 1 },
    ],
    items: [
      { code: 'METADATA_ENGINE', category: 'RUNTIME', severity: 'WARNING', title: 'Mock metadata engine', message: 'Java/MariaDB gate is pending.', targetPage: 'dashboard', targetPanel: 'overview' },
      { code: 'OBJECT_STORAGE', category: 'STORAGE', severity: 'WARNING', title: 'Mock object store', message: 'Docker/MinIO gate is pending.', targetPage: 'storage', targetPanel: 'storage-buckets' },
      {
        code: 'OPERATIONS_READINESS_CONVERGENCE',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Convergence',
        message: 'Operations readiness convergence is action-required: bottleneck=resolve-invocation-blockers, stages=1/7, finalizerGaps=1.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-readiness-convergence.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1',
        remediationNote: 'The invocation report still has blocked actions. This mock report does not execute kubectl, gh, workflow dispatch, or finalizer commands.',
      },
    ],
    operationsReadinessConvergence: {
      result: 'action-required',
      generatedAt: '2026-06-16T09:00:00+09:00',
      handoffReportPath: '.osmu-run/latest-operations-evidence-handoff.json',
      readinessReportPath: '.osmu-run/latest-operations-readiness.json',
      operationsReadinessFinalizeReportPath: '.osmu-run/latest-operations-readiness-finalize.json',
      handoffExists: true,
      handoffResult: 'blocked',
      readinessExists: true,
      readinessResult: 'pending',
      readinessSummary: 'passed=36 pending=6',
      finalizerExists: true,
      finalizerResult: 'pending',
      finalizerReadinessResult: 'pending',
      finalizerFailedCount: 0,
      finalizerGapCount: 1,
      stageCount: 7,
      readyStageCount: 1,
      blockedActionCount: 5,
      missingWorkflowRunCount: 6,
      missingRequiredArtifactCount: 4,
      failedImportCount: 0,
      currentBottleneck: {
        code: 'resolve-invocation-blockers',
        title: 'Resolve invocation blockers',
        reason: 'The invocation report still has blocked actions.',
        command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1',
      },
      recommendedCommands: [
        {
          order: 1,
          name: 'Resolve invocation blockers',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1',
          reason: 'The invocation report still has blocked actions.',
        },
      ],
      decisionRule: 'Operations readiness convergence is ready only when handoff, readiness, and finalizer reports are ready.',
      safetyPolicy: 'This convergence writer does not execute kubectl, gh, workflow dispatch, or finalizer commands; it only reads local reports and writes JSON/Markdown guidance.',
    },
    generatedAt: new Date().toISOString(),
  }
}

function storageExpansionSummary() {
  return {
    requestCount: 0,
    openRequestCount: 0,
    plannedRequestCount: 0,
    approvedRequestCount: 0,
    appliedRequestCount: 0,
    rejectedRequestCount: 0,
    totalRequestedCapacityBytes: 0,
    openRequestedCapacityBytes: 0,
    totalEstimatedUsableCapacityBytes: 0,
    openEstimatedUsableCapacityBytes: 0,
    executionCount: 0,
    successExecutionCount: 0,
    failedExecutionCount: 0,
    skippedExecutionCount: 0,
    timedOutExecutionCount: 0,
    recentExecutions: [],
  }
}

function storageProfiles() {
  return [
    {
      code: 'PERFORMANCE',
      name: 'Performance',
      alias: 'RAID0-like',
      strategy: 'Speed first, shard across performance pool',
      riskLevel: 'HIGH',
      minioStorageClassHint: 'PERFORMANCE',
      parityHint: 'Lowest allowed parity or dedicated low-parity pool',
      poolSelector: 'osmu.storage-profile=performance',
      description: 'Large sequential writes and temporary media processing.',
      useCase: 'Video ingest, render cache, temporary processing',
    },
    {
      code: 'STANDARD',
      name: 'Standard',
      alias: 'Erasure Coding',
      strategy: 'Balanced throughput and durability',
      riskLevel: 'MEDIUM',
      minioStorageClassHint: 'STANDARD',
      parityHint: 'Default erasure coding parity',
      poolSelector: 'osmu.storage-profile=standard',
      description: 'General object storage profile.',
      useCase: 'Team files, service assets, normal app data',
    },
    {
      code: 'DURABLE',
      name: 'Durable',
      alias: 'High Parity',
      strategy: 'Durability first, higher parity and stricter pool',
      riskLevel: 'LOW',
      minioStorageClassHint: 'DURABLE',
      parityHint: 'Higher parity or dedicated high-durability pool',
      poolSelector: 'osmu.storage-profile=durable',
      description: 'Important originals and backup objects.',
      useCase: 'Backups, source media, legal/archive data',
    },
  ]
}

function storageProfileByCode(code) {
  return storageProfiles().find((profile) => profile.code === String(code || '').toUpperCase()) || storageProfiles()[1]
}

function storageProfileAssignmentFor(bucketName) {
  return state.storageProfileAssignments.get(bucketName) || {
    bucketName,
    profile: storageProfileByCode('STANDARD'),
    appliedBy: 'system',
    appliedAt: null,
    updatedAt: null,
    defaultProfile: true,
  }
}

function latestStorageProfileRequest(bucketName) {
  return state.storageProfileRequests.find((request) => request.bucketName === bucketName) || null
}

function createStorageProfileRequest(bucketName, payload = {}) {
  const requestedProfile = storageProfileByCode(payload.requestedProfile)
  const currentProfile = storageProfileAssignmentFor(bucketName).profile
  const now = new Date().toISOString()
  return {
    id: state.storageProfileRequestSequence++,
    bucketName,
    currentProfile,
    requestedProfile,
    status: 'PENDING',
    reason: payload.reason || '',
    requestedBy: 'mock-user',
    approvedBy: null,
    approvedAt: null,
    appliedBy: null,
    appliedAt: null,
    adminNote: null,
    createdAt: now,
    updatedAt: now,
  }
}

function findStorageProfileRequest(id) {
  return state.storageProfileRequests.find((request) => request.id === id) || null
}

function shareAnalytics() {
  return {
    activeLinks: 0,
    expiredLinks: 0,
    revokedLinks: 0,
    limitReachedLinks: 0,
    passwordProtectedLinks: 0,
    ipRestrictedLinks: 0,
    totalDownloads: 0,
    recentLinks: [],
  }
}

function defaultWidgetCatalog() {
  return [
    'capacity', 'remaining', 'buckets', 'objects', 'health', 'runtime', 'readiness', 'backup', 'io',
    'requests', 'sharing', 'quota', 'access-keys', 'identity', 'lifecycle', 'selected', 'retention',
    'execution-retention', 'storage-expansion',
  ].map((id) => ({
    id,
    title: id,
    description: `Mock ${id} widget`,
    category: id === 'requests' ? 'AUDIT' : 'OPERATIONS',
    adminOnly: ['requests', 'sharing', 'quota', 'identity', 'lifecycle', 'retention', 'execution-retention', 'storage-expansion'].includes(id),
    configOptions: [{ key: 'tone', label: 'Tone', type: 'select', values: ['default', 'focus', 'muted'], defaultValue: 'default' }],
  }))
}

function defaultLayout() {
  return {
    schemaVersion: 'osmu.dashboard-layout.v1',
    source: 'DEFAULT',
    widgets: [
      { id: 'capacity', enabled: true, size: 'normal', section: 'overview' },
      { id: 'health', enabled: true, size: 'normal', section: 'overview' },
      { id: 'runtime', enabled: true, size: 'normal', section: 'overview' },
      { id: 'readiness', enabled: true, size: 'normal', section: 'overview' },
      { id: 'storage-expansion', enabled: true, size: 'normal', section: 'operations' },
      { id: 'selected', enabled: true, size: 'normal', section: 'overview' },
    ],
    sections: [
      { id: 'overview', collapsed: false },
      { id: 'operations', collapsed: false },
      { id: 'governance', collapsed: false },
    ],
  }
}

function defaultPresets() {
  return [
    { id: 'mock-ops', name: 'Mock Operations', description: 'Mock demo preset', custom: false, ...defaultLayout() },
  ]
}

function findBucket(bucketName) {
  return state.buckets.find((bucket) => bucket.name === bucketName) || null
}

function objectsFor(bucketName) {
  if (!state.objects.has(bucketName)) {
    state.objects.set(bucketName, [])
  }
  return state.objects.get(bucketName)
}

function isObjectDataPath(suffix) {
  if (!suffix.startsWith('/objects/')) {
    return false
  }
  return ![
    '/objects/metadata/',
    '/objects/versions/',
    '/objects/share-links',
    '/objects/presigned-',
    '/objects/multipart-upload',
    '/objects/tags',
  ].some((prefix) => suffix.startsWith(prefix))
}

function refreshBucketUsage() {
  for (const bucket of state.buckets) {
    const objects = objectsFor(bucket.name)
    bucket.objectCount = objects.length
    bucket.usedBytes = objects.reduce((sum, item) => sum + Number(item.sizeBytes || 0), 0)
  }
}

function parseMultipartUpload(buffer, contentType) {
  const boundaryMatch = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType)
  if (!boundaryMatch) {
    return {}
  }
  const text = buffer.toString('utf8')
  const bodyBoundary = /^--([^\r\n]+)/.exec(text)?.[1]
  const boundary = bodyBoundary || boundaryMatch[1] || boundaryMatch[2]
  const parts = multipartParts(text, boundary)
  return {
    key: parts.key?.body || '',
    tags: parts.tags?.body || '',
    fileName: parts.file?.fileName || '',
    content: parts.file?.body || '',
  }
}

function multipartParts(text, boundary) {
  const parts = {}
  for (const rawPart of text.split(`--${boundary}`)) {
    const trimmed = rawPart.replace(/^\r?\n/, '').replace(/\r?\n$/, '')
    if (!trimmed || trimmed === '--') {
      continue
    }
    const separator = trimmed.search(/\r?\n\r?\n/)
    if (separator < 0) {
      continue
    }
    const separatorMatch = /\r?\n\r?\n/.exec(trimmed)
    if (!separatorMatch) {
      continue
    }
    const headerText = trimmed.slice(0, separator)
    const bodyStart = separatorMatch.index + separatorMatch[0].length
    const body = trimmed.slice(bodyStart).replace(/\r?\n--$/, '')
    const name = /name="?([^";\r\n]+)"?/i.exec(headerText)?.[1]
    if (!name) {
      continue
    }
    parts[name] = {
      body: body.replace(/\r?\n$/, ''),
      fileName: /filename="?([^";\r\n]+)"?/i.exec(headerText)?.[1] || '',
    }
  }
  return parts
}

function parseTags(value = '') {
  return Object.fromEntries(value.split(',').map((pair) => pair.trim()).filter(Boolean).map((pair) => {
    const [key, ...rest] = pair.split('=')
    return [key.trim(), rest.join('=').trim()]
  }).filter(([key]) => key))
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = []
    request.on('data', (chunk) => chunks.push(chunk))
    request.on('end', () => resolve(Buffer.concat(chunks)))
    request.on('error', reject)
  })
}

function parseJsonBody(buffer) {
  if (!buffer.length) return {}
  try {
    return JSON.parse(buffer.toString('utf8'))
  } catch {
    return {}
  }
}

function sendJson(response, status, payload) {
  setCorsHeaders(response)
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' })
  response.end(JSON.stringify(payload))
}

function sendCsv(response, filename, payload) {
  setCorsHeaders(response)
  response.writeHead(200, {
    'Content-Type': 'text/csv; charset=utf-8',
    'Content-Disposition': `attachment; filename="${filename}"`,
  })
  response.end(payload)
}

function setCorsHeaders(response) {
  response.setHeader('Access-Control-Allow-Origin', '*')
  response.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Amz-Date, X-Amz-Content-Sha256')
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
  response.setHeader('Access-Control-Expose-Headers', 'ETag, X-Request-Id')
}

function apiData(data) {
  return { data }
}

function apiItems(items) {
  return { items }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

async function runSelfTest() {
  const server = createMockApiServer()
  await new Promise((resolve) => server.listen(0, DEFAULT_HOST, resolve))
  const port = server.address().port
  const base = `http://${DEFAULT_HOST}:${port}/api`
  try {
    const health = await (await fetch(`${base}/health`)).json()
    if (health.data.status !== 'UP') throw new Error('health self-test failed')
    const login = await (await fetch(`${base}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ loginId: 'admin', password: 'password' }),
    })).json()
    if (!login.data.accessToken || login.data.user.role !== 'ADMIN') throw new Error('admin login self-test failed')
    const developerLogin = await (await fetch(`${base}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ loginId: 'developer', password: 'password' }),
    })).json()
    if (!developerLogin.data.accessToken || developerLogin.data.user.role !== 'USER') throw new Error('developer login self-test failed')
    const developerProfile = await (await fetch(`${base}/users/me`, {
      headers: { Authorization: `Bearer ${developerLogin.data.accessToken}` },
    })).json()
    if (developerProfile.data.loginId !== 'developer') throw new Error('developer profile self-test failed')
    const readiness = await (await fetch(`${base}/admin/dashboard/readiness`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (readiness.data.operationsReadinessConvergence?.result !== 'action-required') {
      throw new Error('readiness convergence self-test failed')
    }
    if (!readiness.data.items.some((item) => item.code === 'OPERATIONS_READINESS_CONVERGENCE')) {
      throw new Error('readiness convergence item self-test failed')
    }
    const savedPricingPolicy = await (await fetch(`${base}/admin/billing/pricing-policy`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ currency: 'krw', storageGbMonthRate: 1, warningAmount: 0.000005, criticalAmount: 0.00001, eventScanLimit: 2500 }),
    })).json()
    if (savedPricingPolicy.data.currency !== 'KRW' || savedPricingPolicy.data.eventScanLimit !== 2500 || savedPricingPolicy.data.criticalAmount !== 0.00001) {
      throw new Error('billing pricing policy self-test failed')
    }
    const createdPricingPolicyProposal = await (await fetch(`${base}/admin/billing/pricing-policy-proposals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ currency: 'krw', storageGbMonthRate: 2, ingressGbRate: 0.02, operationThousandRate: 0.004, warningAmount: 0.000005, criticalAmount: 0.00001, eventScanLimit: 2500, reason: 'self-test' }),
    })).json()
    if (!createdPricingPolicyProposal.data || createdPricingPolicyProposal.data.status !== 'PENDING_APPROVAL' || createdPricingPolicyProposal.data.approvedPriceList !== false) {
      throw new Error('billing pricing policy proposal create self-test failed')
    }
    const listedPricingPolicyProposals = await (await fetch(`${base}/admin/billing/pricing-policy-proposals?status=PENDING_APPROVAL&limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!listedPricingPolicyProposals.data || listedPricingPolicyProposals.data.proposalCount < 1 || listedPricingPolicyProposals.data.proposals?.[0]?.status !== 'PENDING_APPROVAL') {
      throw new Error('billing pricing policy proposal list self-test failed')
    }
    const approvedPricingPolicyProposal = await (await fetch(`${base}/admin/billing/pricing-policy-proposals/${listedPricingPolicyProposals.data.proposals[0].id}/approve?approvalNote=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!approvedPricingPolicyProposal.data || approvedPricingPolicyProposal.data.status !== 'APPROVED_APPLIED' || approvedPricingPolicyProposal.data.approvedPriceList !== false || approvedPricingPolicyProposal.data.appliedPolicy?.storageGbMonthRate !== 2) {
      throw new Error('billing pricing policy proposal approval self-test failed')
    }
    const chargeback = await (await fetch(`${base}/admin/billing/chargeback-preview?storageGbMonthRate=0.02&egressGbRate=0.01&operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargeback.data || chargeback.data.currency !== 'KRW' || chargeback.data.eventScanLimit !== 2500 || chargeback.data.organizationCount < 1 || !chargeback.data.organizations?.length) {
      throw new Error('chargeback preview self-test failed')
    }
    const chargebackAlerts = await (await fetch(`${base}/admin/billing/chargeback-alerts?operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargebackAlerts.data || chargebackAlerts.data.currency !== 'KRW' || chargebackAlerts.data.criticalCount < 1 || chargebackAlerts.data.organizations?.[0]?.severity !== 'CRITICAL') {
      throw new Error('chargeback threshold alerts self-test failed')
    }
    const chargebackAlertNotifications = await (await fetch(`${base}/admin/billing/chargeback-alert-notifications/preview?notificationChannel=slack&notificationTarget=ops-webhook&operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargebackAlertNotifications.data || chargebackAlertNotifications.data.mode !== 'PREVIEW' || chargebackAlertNotifications.data.channel !== 'SLACK' || chargebackAlertNotifications.data.externalDeliveryEnabled !== false || chargebackAlertNotifications.data.notifications?.[0]?.payload?.eventType !== 'chargeback.threshold') {
      throw new Error('chargeback alert notification preview self-test failed')
    }
    const queuedChargebackNotifications = await (await fetch(`${base}/admin/billing/chargeback-alert-notifications/outbox?notificationChannel=slack&notificationTarget=ops-webhook&operationThousandRate=0.004&reason=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!queuedChargebackNotifications.data || queuedChargebackNotifications.data.mode !== 'OUTBOX' || queuedChargebackNotifications.data.status !== 'PENDING_DELIVERY_ADAPTER' || queuedChargebackNotifications.data.queuedCount < 1) {
      throw new Error('chargeback alert notification outbox queue self-test failed')
    }
    const chargebackNotificationOutbox = await (await fetch(`${base}/admin/billing/chargeback-alert-notifications/outbox?limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargebackNotificationOutbox.data || chargebackNotificationOutbox.data.deliveryCount < 1 || chargebackNotificationOutbox.data.deliveries?.[0]?.payloadJson?.includes('chargeback.threshold') !== true) {
      throw new Error('chargeback alert notification outbox list self-test failed')
    }
    const notificationAdapterResult = await (await fetch(`${base}/admin/billing/chargeback-alert-notifications/outbox/${chargebackNotificationOutbox.data.deliveries[0].id}/adapter-result?result=RETRY&retryDelayMinutes=30&lastError=adapter-not-ready`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!notificationAdapterResult.data || notificationAdapterResult.data.status !== 'DELIVERY_ADAPTER_RETRY_SCHEDULED' || notificationAdapterResult.data.delivery?.attemptCount !== 1 || !notificationAdapterResult.data.delivery?.nextAttemptAt) {
      throw new Error('chargeback alert notification adapter result self-test failed')
    }
    const chargebackCsv = await (await fetch(`${base}/admin/billing/chargeback-preview/export.csv?operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).text()
    if (!chargebackCsv.includes('"TOTAL","KRW"') || !chargebackCsv.includes('"ORGANIZATION","KRW"')) {
      throw new Error('chargeback CSV export self-test failed')
    }
    const chargebackInvoiceDraftExport = await (await fetch(`${base}/admin/billing/chargeback-invoice-draft/export.csv?operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).text()
    if (!chargebackInvoiceDraftExport.includes('"DRAFT_INVOICE"') || !chargebackInvoiceDraftExport.includes('"OSMU-DRAFT-') || !chargebackInvoiceDraftExport.includes('not a final invoice')) {
      throw new Error('chargeback invoice draft CSV export self-test failed')
    }
    const createdInvoiceDrafts = await (await fetch(`${base}/admin/billing/chargeback-invoice-drafts?operationThousandRate=0.004&reason=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!createdInvoiceDrafts.data || createdInvoiceDrafts.data.status !== 'DRAFT_REVIEW' || createdInvoiceDrafts.data.persistedCount < 1 || createdInvoiceDrafts.data.finalInvoice !== false) {
      throw new Error('chargeback invoice draft persistence self-test failed')
    }
    const listedInvoiceDrafts = await (await fetch(`${base}/admin/billing/chargeback-invoice-drafts?status=DRAFT_REVIEW&limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!listedInvoiceDrafts.data || listedInvoiceDrafts.data.invoiceCount < 1 || listedInvoiceDrafts.data.invoices?.[0]?.status !== 'DRAFT_REVIEW') {
      throw new Error('chargeback invoice draft list self-test failed')
    }
    const approvedInvoiceDraft = await (await fetch(`${base}/admin/billing/chargeback-invoice-drafts/${listedInvoiceDrafts.data.invoices[0].id}/approve?approvalNote=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!approvedInvoiceDraft.data || approvedInvoiceDraft.data.status !== 'APPROVED_INTERNAL' || approvedInvoiceDraft.data.paymentRequest !== false) {
      throw new Error('chargeback invoice draft approval self-test failed')
    }
    const finalizedInvoice = await (await fetch(`${base}/admin/billing/chargeback-invoice-drafts/${listedInvoiceDrafts.data.invoices[0].id}/finalize?finalizationNote=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!finalizedInvoice.data || finalizedInvoice.data.status !== 'FINALIZED' || finalizedInvoice.data.paymentStatus !== 'NOT_REQUESTED' || finalizedInvoice.data.finalInvoice !== true) {
      throw new Error('chargeback final invoice finalize self-test failed')
    }
    const listedFinalInvoices = await (await fetch(`${base}/admin/billing/chargeback-invoices?status=FINALIZED&limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!listedFinalInvoices.data || listedFinalInvoices.data.invoiceCount < 1 || listedFinalInvoices.data.invoices?.[0]?.status !== 'FINALIZED') {
      throw new Error('chargeback final invoice list self-test failed')
    }
    const requestedPayment = await (await fetch(`${base}/admin/billing/chargeback-invoices/${listedFinalInvoices.data.invoices[0].id}/payment-request?paymentRequestNote=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!requestedPayment.data || requestedPayment.data.status !== 'PAYMENT_REQUESTED' || requestedPayment.data.paymentStatus !== 'REQUESTED') {
      throw new Error('chargeback final invoice payment request self-test failed')
    }
    const handoffPreview = await (await fetch(`${base}/admin/billing/chargeback-invoices/${listedFinalInvoices.data.invoices[0].id}/payment-provider-handoff/preview?paymentProvider=manual_ap&paymentTargetAccount=finance-ap`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!handoffPreview.data || handoffPreview.data.mode !== 'PREVIEW' || handoffPreview.data.externalPaymentEnabled !== false || handoffPreview.data.payload?.eventType !== 'chargeback.payment_provider.handoff') {
      throw new Error('chargeback payment provider handoff preview self-test failed')
    }
    const queuedHandoff = await (await fetch(`${base}/admin/billing/chargeback-invoices/${listedFinalInvoices.data.invoices[0].id}/payment-provider-handoff?paymentProvider=manual_ap&paymentTargetAccount=finance-ap&reason=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!queuedHandoff.data || queuedHandoff.data.status !== 'PENDING_PAYMENT_PROVIDER_ADAPTER' || queuedHandoff.data.externalPaymentEnabled !== false) {
      throw new Error('chargeback payment provider handoff queue self-test failed')
    }
    const handoffList = await (await fetch(`${base}/admin/billing/chargeback-payment-provider-handoffs?limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!handoffList.data || handoffList.data.handoffCount < 1 || handoffList.data.handoffs?.[0]?.payloadJson?.includes('chargeback.payment_provider.handoff') !== true) {
      throw new Error('chargeback payment provider handoff list self-test failed')
    }
    const handoffAdapterResult = await (await fetch(`${base}/admin/billing/chargeback-payment-provider-handoffs/${handoffList.data.handoffs[0].id}/adapter-result?result=BLOCKED_CREDENTIAL`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!handoffAdapterResult.data || handoffAdapterResult.data.status !== 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL' || handoffAdapterResult.data.handoff?.attemptCount !== 1) {
      throw new Error('chargeback payment provider adapter result self-test failed')
    }
    const recordedPayment = await (await fetch(`${base}/admin/billing/chargeback-invoices/${listedFinalInvoices.data.invoices[0].id}/payment-record?paymentReference=PAY-SELF-TEST&paymentNote=self-test`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!recordedPayment.data || recordedPayment.data.status !== 'PAID' || recordedPayment.data.invoice?.paymentReference !== 'PAY-SELF-TEST') {
      throw new Error('chargeback final invoice payment record self-test failed')
    }
    const bucket = await (await fetch(`${base}/buckets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ name: 'self-test', quotaBytes: BYTES_PER_GIB }),
    })).json()
    if (bucket.data.name !== 'self-test') throw new Error('bucket self-test failed')
    const reset = await (await fetch(`${base}/mock/reset`, { method: 'POST' })).json()
    if (!reset.data.reset || reset.data.bucketCount !== 2 || reset.data.objectCount !== 3) throw new Error('mock reset self-test failed')
    const bucketsAfterReset = await (await fetch(`${base}/buckets`)).json()
    if (bucketsAfterReset.items.some((item) => item.name === 'self-test')) throw new Error('mock reset did not remove self-test bucket')
    console.log('OSMU frontend mock API self-test passed.')
  } finally {
    server.close()
  }
}

function parseArgs(argv) {
  const args = { host: DEFAULT_HOST, port: DEFAULT_PORT, selfTest: false }
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg === '--self-test') args.selfTest = true
    if (arg === '--host') args.host = argv[++index] || args.host
    if (arg === '--port') args.port = Number(argv[++index] || args.port)
  }
  return args
}

const args = parseArgs(process.argv.slice(2))
if (args.selfTest) {
  await runSelfTest()
} else {
  const server = createMockApiServer()
  server.listen(args.port, args.host, () => {
    console.log(`OSMU frontend mock API listening on http://${args.host}:${args.port}/api`)
    console.log('Mock admin login: admin / password')
    console.log('Mock developer login: developer / password')
  })
}
