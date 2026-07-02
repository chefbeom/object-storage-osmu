import { createServer } from 'node:http'
import { randomUUID } from 'node:crypto'

const DEFAULT_HOST = '127.0.0.1'
const DEFAULT_PORT = 8080
const BYTES_PER_GIB = 1024 ** 3
const BROWSER_READY_SUBSET_NOTE = 'Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch.'
const SECURITY_FINALIZER_DEPENDENCY_NOTE = 'Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml.'
const BROWSER_READY_SUBSET_CONVERGENCE_NOTE = `${BROWSER_READY_SUBSET_NOTE} ${SECURITY_FINALIZER_DEPENDENCY_NOTE}`
const SECURITY_FINALIZER_RUN_ID_HINTS = [
  {
    workflow: 'image-publish-sign-ci.yml',
    group: 'image-signing-source',
    actionOrders: [],
    runIdParameter: 'ImageSigningRunId',
    recommendedRunId: '',
    artifactName: 'osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68',
    requiredForReadiness: false,
    readyForArtifactDownload: false,
    runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml',
    runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\image-publish-sign-ci.yml.json',
    queryCommand: 'gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
    gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
    sourceSelected: false,
    supplementalForSecurityFinalizer: true,
  },
  {
    workflow: 'container-security-ci.yml',
    group: 'container-security-source',
    actionOrders: [6],
    runIdParameter: 'ContainerSecurityRunId',
    recommendedRunId: '',
    artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
    requiredForReadiness: false,
    readyForArtifactDownload: false,
    runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
    runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json',
    queryCommand: 'gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
    gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
    sourceSelected: true,
    supplementalForSecurityFinalizer: false,
  },
]

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
    dataFlowDailyRollups: [],
    dataFlowMonthlyRollups: [],
    dataFlowRetentionMetrics: {
      eventsDeleted: 0,
      dailyRollupsDeleted: 0,
      monthlyRollupsDeleted: 0,
      eventFailures: 0,
      dailyRollupFailures: 0,
      monthlyRollupFailures: 0,
    },
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
    storageExpansionRequests: [],
    storageExpansionExecutions: [],
    storageExpansionRequestSequence: 1,
    storageExpansionExecutionSequence: 1,
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
    lifecycleXml: '',
    lifecycleRuleCount: 0,
    tags: {},
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
  if (request.method === 'GET' && path === '/admin/storage/backend-status') {
    sendJson(response, 200, apiData(storageBackendStatus()))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow') {
    sendJson(response, 200, apiData(dataFlowSummary(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/daily-rollup') {
    sendJson(response, 200, apiData(dataFlowDailyRollup(dataFlowFilters(url))))
    return
  }
  if (request.method === 'POST' && path === '/admin/monitoring/data-flow/daily-rollup/materialize') {
    sendJson(response, 200, apiData(materializeDataFlowDailyRollup(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/daily-rollup/materialized') {
    sendJson(response, 200, apiData(materializedDataFlowDailyRollup(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/daily-rollup/materialized/export.csv') {
    sendCsv(response, 'osmu-data-flow-daily-rollup-materialized.csv', materializedDataFlowDailyRollupCsv(dataFlowFilters(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/daily-rollup/export.csv') {
    sendCsv(response, 'osmu-data-flow-daily-rollup.csv', dataFlowDailyRollupCsv(dataFlowFilters(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/monthly-rollup') {
    const filters = dataFlowFilters(url)
    sendJson(response, 200, apiData(filters.materialized ? materializedDataFlowMonthlyRollup(filters) : dataFlowMonthlyRollup(filters)))
    return
  }
  if (request.method === 'POST' && path === '/admin/monitoring/data-flow/monthly-rollup/materialize') {
    sendJson(response, 200, apiData(materializeDataFlowMonthlyRollup(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/monthly-rollup/materialized') {
    sendJson(response, 200, apiData(storedDataFlowMonthlyRollup(dataFlowFilters(url))))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/monthly-rollup/materialized/export.csv') {
    sendCsv(response, 'osmu-data-flow-monthly-rollup-materialized.csv', storedDataFlowMonthlyRollupCsv(dataFlowFilters(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/monthly-rollup/export.csv') {
    sendCsv(response, 'osmu-data-flow-monthly-rollup.csv', dataFlowMonthlyRollupCsv(dataFlowFilters(url)))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/storage-status') {
    sendJson(response, 200, apiData(dataFlowStorageStatus()))
    return
  }
  if (request.method === 'GET' && path === '/admin/monitoring/data-flow/retention/status') {
    sendJson(response, 200, apiData(dataFlowRetentionStatus()))
    return
  }
  if (request.method === 'POST' && path === '/admin/monitoring/data-flow/retention/run') {
    const run = dataFlowRetentionRun(url)
    if (run.error) {
      sendJson(response, 400, { error: run.error })
      return
    }
    sendJson(response, 200, apiData(run))
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
  if (suffix === '/lifecycle') {
    const bucket = findBucket(bucketName)
    if (!bucket) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Bucket not found.' } })
      return
    }
    if (request.method === 'GET') {
      sendJson(response, 200, apiData({ xml: bucket.lifecycleXml || '', ruleCount: bucket.lifecycleRuleCount || 0 }))
      return
    }
    if (request.method === 'PUT') {
      const xml = String(jsonBody.xml || '')
      const ruleCount = countLifecycleRules(xml)
      bucket.lifecycleXml = xml
      bucket.lifecycleRuleCount = ruleCount
      state.auditLogs.unshift(auditLog('BUCKET_LIFECYCLE_PUT', 'BUCKET', bucketName))
      sendJson(response, 200, apiData({ xml, ruleCount, savedCount: ruleCount, importedCount: ruleCount }))
      return
    }
    if (request.method === 'DELETE') {
      bucket.lifecycleXml = ''
      bucket.lifecycleRuleCount = 0
      state.auditLogs.unshift(auditLog('BUCKET_LIFECYCLE_DELETE', 'BUCKET', bucketName))
      sendJson(response, 200, apiData({ xml: '', ruleCount: 0, savedCount: 0 }))
      return
    }
  }
  if (suffix === '/tags') {
    const bucket = findBucket(bucketName)
    if (!bucket) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Bucket not found.' } })
      return
    }
    if (request.method === 'GET') {
      sendJson(response, 200, apiData({ tags: bucket.tags || {}, tagCount: Object.keys(bucket.tags || {}).length }))
      return
    }
    if (request.method === 'PUT') {
      bucket.tags = { ...(jsonBody.tags || {}) }
      state.auditLogs.unshift(auditLog('BUCKET_TAGS_PUT', 'BUCKET', bucketName))
      sendJson(response, 200, apiData({ tags: bucket.tags, tagCount: Object.keys(bucket.tags).length }))
      return
    }
    if (request.method === 'DELETE') {
      bucket.tags = {}
      state.auditLogs.unshift(auditLog('BUCKET_TAGS_DELETE', 'BUCKET', bucketName))
      sendJson(response, 200, apiData({ tags: {}, tagCount: 0 }))
      return
    }
  }
  if (request.method === 'PUT' && suffix === '/objects/tags') {
    const objectKey = String(jsonBody.key || '')
    const object = objectsFor(bucketName).find((item) => item.key === objectKey)
    if (!object) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Object not found.' } })
      return
    }
    object.tags = typeof jsonBody.tags === 'string' ? parseTags(jsonBody.tags) : { ...(jsonBody.tags || {}) }
    object.updatedAt = new Date().toISOString()
    state.auditLogs.unshift(auditLog('OBJECT_TAGS_PUT', 'OBJECT', `${bucketName}/${objectKey}`))
    sendJson(response, 200, apiData({ key: object.key, tags: object.tags, tagCount: Object.keys(object.tags).length }))
    return
  }  if (request.method === 'GET' && suffix === '/objects') {
    const prefix = url.searchParams.get('prefix') || ''
    const delimiter = url.searchParams.get('delimiter') || ''
    const search = url.searchParams.get('search') || ''
    const tagFilter = parseTags(url.searchParams.get('tag') || '')
    const listed = listObjectsForMock(bucketName, { prefix, delimiter, search, tagFilter })
    recordDataFlow('LIST', 'list', 'METADATA', bucketName, '', currentUser(request).loginId, 'SUCCESS', 0, 'Object list read', 'REST')
    sendJson(response, 200, { items: listed.items, prefixes: listed.prefixes, nextCursor: '' })
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
  const objectMetadataMatch = /^\/objects\/metadata\/(.+)$/.exec(suffix)
  if (objectMetadataMatch && request.method === 'GET') {
    const objectKey = decodeURIComponent(objectMetadataMatch[1])
    const object = objectsFor(bucketName).find((item) => item.key === objectKey)
    if (!object) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Object not found.' } })
      return
    }
    const etag = object.etag || `mock-${Math.max(1, Number(object.sizeBytes || 0)).toString(16)}`
    const checksums = object.checksums && Object.keys(object.checksums).length > 0 ? object.checksums : { SHA256: `mock-sha256-${Math.max(1, Number(object.sizeBytes || 0)).toString(16)}` }
    sendJson(response, 200, apiData({
      key: object.key,
      syncStatus: object.status || 'SYNCED',
      sizeBytes: object.sizeBytes,
      storageSizeBytes: object.sizeBytes,
      contentType: object.contentType,
      storageContentType: object.contentType,
      etag,
      storageEtag: etag,
      checksums,
      storageChecksums: checksums,
      lastModifiedAt: object.updatedAt || object.createdAt,
      storageLastModifiedAt: object.updatedAt || object.createdAt,
      tags: object.tags || {},
      storageTags: object.tags || {},
    }))
    return
  }  if (request.method === 'GET' && isObjectDataPath(suffix)) {
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
  if (request.method === 'GET' && path === '/admin/billing/chargeback-daily-rollup') {
    sendJson(response, 200, apiData(chargebackDailyRollup(url)))
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
  if (request.method === 'GET' && path === '/admin/billing/chargeback-adapter-retry-worker/status') {
    sendJson(response, 200, apiData(chargebackAdapterRetryWorker(url, true)))
    return
  }
  if (request.method === 'POST' && path === '/admin/billing/chargeback-adapter-retry-worker/run') {
    sendJson(response, 200, apiData(chargebackAdapterRetryWorker(url, String(url.searchParams.get('dryRun') ?? 'true') !== 'false')))
    return
  }
  const chargebackNotificationAdapterSendMatch = path.match(/^\/admin\/billing\/chargeback-alert-notifications\/outbox\/(\d+)\/adapter-send$/)
  if (request.method === 'POST' && chargebackNotificationAdapterSendMatch) {
    sendJson(response, 200, apiData(sendChargebackNotificationAdapter(Number(chargebackNotificationAdapterSendMatch[1]))))
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
  if (request.method === 'GET' && path === '/admin/billing/payment-provider-adapter-readiness') {
    sendJson(response, 200, apiData(chargebackPaymentProviderAdapterReadiness()))
    return
  }
  const chargebackPaymentProviderAdapterResultMatch = path.match(/^\/admin\/billing\/chargeback-payment-provider-handoffs\/(\d+)\/adapter-result$/)
  if (request.method === 'POST' && chargebackPaymentProviderAdapterResultMatch) {
    sendJson(response, 200, apiData(recordChargebackPaymentProviderAdapterResult(Number(chargebackPaymentProviderAdapterResultMatch[1]), url)))
    return
  }
  const chargebackPaymentProviderAdapterSendMatch = path.match(/^\/admin\/billing\/chargeback-payment-provider-handoffs\/(\d+)\/adapter-send$/)
  if (request.method === 'POST' && chargebackPaymentProviderAdapterSendMatch) {
    sendJson(response, 200, apiData(sendChargebackPaymentProviderAdapter(Number(chargebackPaymentProviderAdapterSendMatch[1]))))
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
  if (request.method === 'GET' && path === '/admin/billing/chargeback-daily-rollup/export.csv') {
    sendCsv(response, 'osmu-chargeback-daily-rollup.csv', chargebackDailyRollupCsv(url))
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
  const pricingPolicyProposalCommercialApproveMatch = path.match(/^\/admin\/billing\/pricing-policy-proposals\/(\d+)\/commercial-approval$/)
  if (request.method === 'POST' && pricingPolicyProposalCommercialApproveMatch) {
    sendJson(response, 200, apiData(approveBillingPricingPolicyProposalPriceList(Number(pricingPolicyProposalCommercialApproveMatch[1]), url)))
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
  if (request.method === 'GET' && path === '/admin/audit-logs/export.csv') {
    sendCsv(response, 'osmu-audit.csv', auditLogsCsv(url))
    return
  }
  if (request.method === 'GET' && path === '/admin/audit-logs') {
    sendJson(response, 200, pagedAuditLogs(url))
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
    sendJson(response, 200, apiItems(state.storageExpansionRequests))
    return
  }
  if (request.method === 'POST' && path === '/admin/storage-expansion/requests') {
    const requestRecord = storageExpansionRequestRecord(jsonBody, currentUser(request).loginId)
    state.storageExpansionRequests.unshift(requestRecord)
    state.auditLogs.unshift(auditLog('STORAGE_EXPANSION_REQUEST_CREATE', 'STORAGE_EXPANSION_REQUEST', requestRecord.poolName))
    sendJson(response, 200, apiData(requestRecord))
    return
  }
  const storageExpansionManifestMatch = /^\/admin\/storage-expansion\/requests\/(\d+)\/manifest$/.exec(path)
  if (storageExpansionManifestMatch && request.method === 'GET') {
    const requestRecord = findStorageExpansionRequest(Number(storageExpansionManifestMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage expansion request not found.' } })
      return
    }
    sendJson(response, 200, apiData(storageExpansionManifest(requestRecord)))
    return
  }
  const storageExpansionManifestArtifactMatch = /^\/admin\/storage-expansion\/requests\/(\d+)\/manifest\/([^/]+)$/.exec(path)
  if (storageExpansionManifestArtifactMatch && request.method === 'GET') {
    const requestRecord = findStorageExpansionRequest(Number(storageExpansionManifestArtifactMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage expansion request not found.' } })
      return
    }
    const artifact = decodeURIComponent(storageExpansionManifestArtifactMatch[2])
    const manifest = storageExpansionManifest(requestRecord)
    const payload = artifact === 'tenant' ? manifest.tenantPatchYaml : artifact === 'helm' ? manifest.helmValuesPatchYaml : `${manifest.tenantPatchYaml}\n---\n${manifest.helmValuesPatchYaml}`
    setCorsHeaders(response)
    response.writeHead(200, {
      'Content-Type': 'application/x-yaml; charset=utf-8',
      'Content-Disposition': `attachment; filename="osmu-storage-expansion-${requestRecord.poolName}-${artifact}.yaml"`,
    })
    response.end(payload)
    return
  }
  const storageExpansionExecutionPlanMatch = /^\/admin\/storage-expansion\/requests\/(\d+)\/execution-plan$/.exec(path)
  if (storageExpansionExecutionPlanMatch && request.method === 'POST') {
    const requestRecord = findStorageExpansionRequest(Number(storageExpansionExecutionPlanMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage expansion request not found.' } })
      return
    }
    if (requestRecord.status !== 'APPROVED') {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Storage expansion request must be APPROVED before dry-run planning.' } })
      return
    }
    sendJson(response, 200, apiData(storageExpansionExecutionPlan(requestRecord)))
    return
  }
  const storageExpansionStatusMatch = /^\/admin\/storage-expansion\/requests\/(\d+)\/status$/.exec(path)
  if (storageExpansionStatusMatch && request.method === 'PATCH') {
    const requestRecord = findStorageExpansionRequest(Number(storageExpansionStatusMatch[1]))
    if (!requestRecord) {
      sendJson(response, 404, { error: { code: 'NOT_FOUND', message: 'Storage expansion request not found.' } })
      return
    }
    const status = String(jsonBody.status || '').trim().toUpperCase()
    if (!['APPROVED', 'REJECTED', 'APPLIED'].includes(status)) {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Invalid storage expansion status.' } })
      return
    }
    if (status === 'APPROVED' && requestRecord.status !== 'PLANNED') {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Only PLANNED storage expansion requests can be approved.' } })
      return
    }
    if (status === 'APPLIED' && requestRecord.status !== 'APPROVED') {
      sendJson(response, 400, { error: { code: 'VALIDATION_ERROR', message: 'Only APPROVED storage expansion requests can be applied.' } })
      return
    }
    updateStorageExpansionStatusRecord(requestRecord, status, jsonBody.appliedEvidence || '')
    state.auditLogs.unshift(auditLog('STORAGE_EXPANSION_REQUEST_STATUS', 'STORAGE_EXPANSION_REQUEST', requestRecord.poolName))
    sendJson(response, 200, apiData(requestRecord))
    return
  }
  const storageExpansionExecutionsMatch = /^\/admin\/storage-expansion\/requests\/(\d+)\/executions$/.exec(path)
  if (storageExpansionExecutionsMatch && request.method === 'GET') {
    const requestId = Number(storageExpansionExecutionsMatch[1])
    sendJson(response, 200, apiItems(state.storageExpansionExecutions.filter((execution) => execution.requestId === requestId)))
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
    days: url.searchParams.has('days') ? Number(url.searchParams.get('days')) : undefined,
    months: url.searchParams.has('months') ? Number(url.searchParams.get('months')) : undefined,
    limit: url.searchParams.has('limit') ? Number(url.searchParams.get('limit')) : undefined,
    materialized: url.searchParams.get('materialized') === 'true',
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

function dataFlowDailyRollup(filters = {}) {
  const days = Math.min(366, Math.max(1, Math.floor(Number(filters.days || 30))))
  const limit = Math.min(1000, Math.max(1, Math.floor(Number(filters.limit || 200))))
  const boundedFilters = { ...filters }
  if (!boundedFilters.from) {
    const from = new Date()
    from.setUTCHours(0, 0, 0, 0)
    from.setUTCDate(from.getUTCDate() - (days - 1))
    boundedFilters.from = from.toISOString()
  }
  const buckets = new Map()
  for (const event of filterDataFlowEvents(state.dataFlowEvents || [], boundedFilters)) {
    const parsed = Date.parse(event.createdAt)
    if (Number.isNaN(parsed)) continue
    const day = new Date(parsed).toISOString().slice(0, 10)
    const bucketName = event.bucketName || 'unknown'
    const source = String(event.source || 'unknown').toLowerCase()
    const operation = String(event.operation || 'unknown').toLowerCase()
    const key = `${day}|${bucketName}|${source}|${operation}`
    if (!buckets.has(key)) {
      buckets.set(key, {
        day,
        bucketName,
        source,
        operation,
        successCount: 0,
        failureCount: 0,
        cancelCount: 0,
        totalCount: 0,
        uploadedBytes: 0,
        downloadedBytes: 0,
        copiedBytes: 0,
        totalBytes: 0,
      })
    }
    const point = buckets.get(key)
    point.totalCount += 1
    if (event.status === 'SUCCESS') {
      point.successCount += 1
      if (event.eventType === 'UPLOAD') point.uploadedBytes += Math.max(0, Number(event.sizeBytes || 0))
      if (event.eventType === 'DOWNLOAD') point.downloadedBytes += Math.max(0, Number(event.sizeBytes || 0))
      if (event.eventType === 'COPY') point.copiedBytes += Math.max(0, Number(event.sizeBytes || 0))
    }
    if (event.eventType === 'FAILURE' || event.status === 'FAILED') point.failureCount += 1
    if (event.eventType === 'CANCEL' || event.status === 'CANCELLED') point.cancelCount += 1
    point.totalBytes = point.uploadedBytes + point.downloadedBytes + point.copiedBytes
  }
  const points = [...buckets.values()]
    .sort((left, right) => (
      right.day.localeCompare(left.day)
      || right.totalCount - left.totalCount
      || left.bucketName.localeCompare(right.bucketName)
      || left.source.localeCompare(right.source)
      || left.operation.localeCompare(right.operation)
    ))
    .slice(0, limit)
  return {
    mode: 'DATA_FLOW_DAILY_ROLLUP',
    granularity: 'UTC_DAY',
    dayWindow: days,
    pointLimit: limit,
    pointCount: points.length,
    points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only data-flow analytics rollup. Query filters are identical to the detailed data-flow monitoring endpoint.',
    storagePolicy: 'Aggregates mock runtime data-flow events; MariaDB mode aggregates persisted data_flow_events.',
    note: 'This is an OSMU operations and chargeback planning rollup, not AWS billing parity.',
  }
}

function materializeDataFlowDailyRollup(filters = {}) {
  const rollup = dataFlowDailyRollup(filters)
  const actorId = materializedDimension(filters.actorId)
  const status = materializedDimension(filters.status)
  const refreshedAt = new Date().toISOString()
  for (const point of rollup.points) {
    state.dataFlowDailyRollups = state.dataFlowDailyRollups.filter((record) => !(
      record.day === point.day
      && record.bucketName === point.bucketName
      && record.actorId === actorId
      && record.source === point.source
      && record.operation === point.operation
      && record.status === status
    ))
    state.dataFlowDailyRollups.push({ ...point, actorId, status, refreshedAt })
  }
  return {
    mode: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION',
    granularity: rollup.granularity,
    dayWindow: rollup.dayWindow,
    pointLimit: rollup.pointLimit,
    pointCount: rollup.pointCount,
    storedPointCount: state.dataFlowDailyRollups.length,
    points: rollup.points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only data-flow rollup materialization. Query filters are identical to the daily rollup endpoint.',
    storagePolicy: 'Refreshes mock materialized daily rollup rows; MariaDB mode persists data_flow_daily_rollups.',
    note: 'Materialization stores aggregate rows only; object keys, raw event messages, and AWS billing parity fields are not stored.',
  }
}

function materializedDataFlowDailyRollup(filters = {}) {
  const days = Math.min(366, Math.max(1, Math.floor(Number(filters.days || 30))))
  const limit = Math.min(1000, Math.max(1, Math.floor(Number(filters.limit || 200))))
  const actorId = materializedDimension(filters.actorId)
  const status = materializedDimension(filters.status)
  const fromDay = dataFlowFilterDay(filters.from)
  const toDay = dataFlowFilterDay(filters.to)
  const points = state.dataFlowDailyRollups
    .filter((point) => {
      if (filters.bucketName && point.bucketName !== filters.bucketName) return false
      if (point.actorId !== actorId) return false
      if (filters.source && String(point.source || '').toLowerCase() !== String(filters.source).toLowerCase()) return false
      if (filters.operation && String(point.operation || '').toLowerCase() !== String(filters.operation).toLowerCase()) return false
      if (point.status !== status) return false
      if (fromDay && point.day < fromDay) return false
      if (toDay && point.day > toDay) return false
      return true
    })
    .sort((left, right) => (
      right.day.localeCompare(left.day)
      || right.totalCount - left.totalCount
      || left.bucketName.localeCompare(right.bucketName)
      || left.source.localeCompare(right.source)
      || left.operation.localeCompare(right.operation)
    ))
    .slice(0, limit)
    .map(({ actorId: ignoredActorId, status: ignoredStatus, refreshedAt: ignoredRefreshedAt, ...point }) => point)
  return {
    mode: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZED',
    granularity: 'UTC_DAY',
    dayWindow: days,
    pointLimit: limit,
    pointCount: points.length,
    points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only materialized data-flow analytics rollup. Query filters are identical to the daily rollup endpoint.',
    storagePolicy: 'Reads mock materialized daily rollup rows; MariaDB mode reads data_flow_daily_rollups.',
    note: 'This reads OSMU materialized operations analytics rows; it does not expose object keys, raw event messages, or AWS billing parity fields.',
  }
}

function dataFlowMonthlyRollup(filters = {}) {
  const months = Math.min(60, Math.max(1, Math.floor(Number(filters.months || 12))))
  const limit = Math.min(1000, Math.max(1, Math.floor(Number(filters.limit || 200))))
  const boundedFilters = { ...filters }
  if (!boundedFilters.from) {
    const from = new Date()
    from.setUTCDate(1)
    from.setUTCHours(0, 0, 0, 0)
    from.setUTCMonth(from.getUTCMonth() - (months - 1))
    boundedFilters.from = from.toISOString()
  }
  const buckets = new Map()
  for (const event of filterDataFlowEvents(state.dataFlowEvents || [], boundedFilters)) {
    const parsed = Date.parse(event.createdAt)
    if (Number.isNaN(parsed)) continue
    const month = new Date(parsed).toISOString().slice(0, 7)
    const bucketName = event.bucketName || 'unknown'
    const source = String(event.source || 'unknown').toLowerCase()
    const operation = String(event.operation || 'unknown').toLowerCase()
    const key = `${month}|${bucketName}|${source}|${operation}`
    if (!buckets.has(key)) {
      buckets.set(key, emptyMonthlyRollupPoint(month, bucketName, source, operation))
    }
    recordEventIntoMonthlyPoint(buckets.get(key), event)
  }
  const points = sortedMonthlyRollupPoints([...buckets.values()], limit)
  return {
    mode: 'DATA_FLOW_MONTHLY_ROLLUP',
    rollupSource: 'DATA_FLOW_EVENTS',
    granularity: 'UTC_MONTH',
    monthWindow: months,
    pointLimit: limit,
    pointCount: points.length,
    points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only long-term data-flow analytics rollup. Query filters are identical to the detailed data-flow monitoring endpoint.',
    storagePolicy: 'Aggregates mock runtime data-flow events into UTC months; MariaDB mode aggregates data_flow_events.',
    note: 'This is an OSMU operations analytics rollup, not AWS billing parity; object keys and raw event messages are not returned.',
  }
}

function materializedDataFlowMonthlyRollup(filters = {}) {
  const months = Math.min(60, Math.max(1, Math.floor(Number(filters.months || 12))))
  const limit = Math.min(1000, Math.max(1, Math.floor(Number(filters.limit || 200))))
  const boundedFilters = { ...filters }
  if (!boundedFilters.from) {
    const from = new Date()
    from.setUTCDate(1)
    from.setUTCHours(0, 0, 0, 0)
    from.setUTCMonth(from.getUTCMonth() - (months - 1))
    boundedFilters.from = from.toISOString()
  }
  const actorId = materializedDimension(boundedFilters.actorId)
  const status = materializedDimension(boundedFilters.status)
  const fromDay = dataFlowFilterDay(boundedFilters.from)
  const toDay = dataFlowFilterDay(boundedFilters.to)
  const buckets = new Map()
  for (const point of state.dataFlowDailyRollups) {
    if (boundedFilters.bucketName && point.bucketName !== boundedFilters.bucketName) continue
    if (point.actorId !== actorId) continue
    if (boundedFilters.source && String(point.source || '').toLowerCase() !== String(boundedFilters.source).toLowerCase()) continue
    if (boundedFilters.operation && String(point.operation || '').toLowerCase() !== String(boundedFilters.operation).toLowerCase()) continue
    if (point.status !== status) continue
    if (fromDay && point.day < fromDay) continue
    if (toDay && point.day > toDay) continue
    const month = String(point.day || '').slice(0, 7)
    if (!month) continue
    const key = `${month}|${point.bucketName}|${point.source}|${point.operation}`
    if (!buckets.has(key)) {
      buckets.set(key, emptyMonthlyRollupPoint(month, point.bucketName, point.source, point.operation))
    }
    recordDailyPointIntoMonthlyPoint(buckets.get(key), point)
  }
  const points = sortedMonthlyRollupPoints([...buckets.values()], limit)
  return {
    mode: 'DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZED',
    rollupSource: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZED',
    granularity: 'UTC_MONTH',
    monthWindow: months,
    pointLimit: limit,
    pointCount: points.length,
    points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only long-term data-flow analytics rollup. Query filters are identical to the detailed data-flow monitoring endpoint.',
    storagePolicy: 'Aggregates mock materialized daily rollup rows into UTC months; MariaDB mode reads data_flow_daily_rollups.',
    note: 'This is an OSMU operations analytics rollup, not AWS billing parity; object keys and raw event messages are not returned.',
  }
}

function materializeDataFlowMonthlyRollup(filters = {}) {
  const rollup = materializedDataFlowMonthlyRollup(filters)
  const actorId = materializedDimension(filters.actorId)
  const status = materializedDimension(filters.status)
  const refreshedAt = new Date().toISOString()
  for (const point of rollup.points) {
    state.dataFlowMonthlyRollups = state.dataFlowMonthlyRollups.filter((record) => !(
      record.month === point.month
      && record.bucketName === point.bucketName
      && record.actorId === actorId
      && record.source === point.source
      && record.operation === point.operation
      && record.status === status
    ))
    state.dataFlowMonthlyRollups.push({ ...point, actorId, status, refreshedAt })
  }
  return {
    mode: 'DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZATION',
    rollupSource: 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZED',
    granularity: 'UTC_MONTH',
    monthWindow: rollup.monthWindow,
    pointLimit: rollup.pointLimit,
    pointCount: rollup.pointCount,
    storedPointCount: rollup.points.length,
    points: rollup.points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only monthly data-flow rollup materialization. Query filters are identical to the monthly rollup endpoint.',
    storagePolicy: 'Compacts mock materialized daily rollup rows into data_flow_monthly_rollups.',
    note: 'Monthly materialization stores aggregate rows only; object keys, raw event messages, and AWS billing parity fields are not stored.',
  }
}

function storedDataFlowMonthlyRollup(filters = {}) {
  const months = Math.min(60, Math.max(1, Math.floor(Number(filters.months || 12))))
  const limit = Math.min(1000, Math.max(1, Math.floor(Number(filters.limit || 200))))
  const boundedFilters = { ...filters }
  if (!boundedFilters.from) {
    const from = new Date()
    from.setUTCDate(1)
    from.setUTCHours(0, 0, 0, 0)
    from.setUTCMonth(from.getUTCMonth() - (months - 1))
    boundedFilters.from = from.toISOString()
  }
  const actorId = materializedDimension(boundedFilters.actorId)
  const status = materializedDimension(boundedFilters.status)
  const fromMonth = dataFlowFilterMonth(boundedFilters.from)
  const toMonth = dataFlowFilterMonth(boundedFilters.to)
  const points = state.dataFlowMonthlyRollups
    .filter((point) => {
      if (boundedFilters.bucketName && point.bucketName !== boundedFilters.bucketName) return false
      if (point.actorId !== actorId) return false
      if (boundedFilters.source && String(point.source || '').toLowerCase() !== String(boundedFilters.source).toLowerCase()) return false
      if (boundedFilters.operation && String(point.operation || '').toLowerCase() !== String(boundedFilters.operation).toLowerCase()) return false
      if (point.status !== status) return false
      if (fromMonth && point.month < fromMonth) return false
      if (toMonth && point.month > toMonth) return false
      return true
    })
    .sort((left, right) => (
      right.month.localeCompare(left.month)
      || right.totalCount - left.totalCount
      || left.bucketName.localeCompare(right.bucketName)
      || left.source.localeCompare(right.source)
      || left.operation.localeCompare(right.operation)
    ))
    .slice(0, limit)
    .map(({ actorId: ignoredActorId, status: ignoredStatus, refreshedAt: ignoredRefreshedAt, ...point }) => point)
  return {
    mode: 'DATA_FLOW_MONTHLY_ROLLUP_STORED',
    rollupSource: 'DATA_FLOW_MONTHLY_ROLLUPS',
    granularity: 'UTC_MONTH',
    monthWindow: months,
    pointLimit: limit,
    pointCount: points.length,
    points,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'ADMIN-only stored monthly data-flow analytics rollup. Query filters are identical to the monthly rollup endpoint.',
    storagePolicy: 'Reads mock data_flow_monthly_rollups rows; MariaDB mode reads the dedicated monthly aggregate table.',
    note: 'This reads OSMU stored monthly operations analytics rows; it does not expose object keys, raw event messages, or AWS billing parity fields.',
  }
}

function dataFlowRetentionStatus(generatedAt = new Date().toISOString()) {
  return {
    mode: 'DATA_FLOW_RETENTION',
    eventRetention: dataFlowRetentionPolicyStatus(90, 1000, state.dataFlowRetentionMetrics.eventsDeleted, state.dataFlowRetentionMetrics.eventFailures),
    dailyRollupRetention: dataFlowRetentionPolicyStatus(1095, 1000, state.dataFlowRetentionMetrics.dailyRollupsDeleted, state.dataFlowRetentionMetrics.dailyRollupFailures),
    monthlyRollupRetention: dataFlowRetentionPolicyStatus(1825, 1000, state.dataFlowRetentionMetrics.monthlyRollupsDeleted, state.dataFlowRetentionMetrics.monthlyRollupFailures),
    generatedAt,
    note: 'OSMU data-flow retention status for detailed events, materialized daily rollups, and stored monthly rollups. This is operational analytics retention, not AWS billing parity.',
  }
}

function dataFlowStorageStatus() {
  return {
    mode: 'DATA_FLOW_STORAGE_STATUS',
    metadataMode: 'in-memory',
    repositoryHealthy: true,
    eventRowCount: state.dataFlowEvents.length,
    dailyRollupRowCount: state.dataFlowDailyRollups.length,
    monthlyRollupRowCount: state.dataFlowMonthlyRollups.length,
    summaryEventScanLimit: 10000,
    dailyRollupWindowLimitDays: 366,
    monthlyRollupWindowLimitMonths: 60,
    aggregateStoreReady: true,
    partitionedOrTimeSeriesStoreEnabled: false,
    readiness: 'DEMO_ONLY',
    generatedAt: new Date().toISOString(),
    note: 'Mock data-flow storage status for detailed events, materialized daily rollups, and stored monthly rollups. Partitioned or external time-series storage is not enabled in this mock build.',
  }
}

function dataFlowRetentionPolicyStatus(retentionDays, batchSize, deletedCount, failedRunCount) {
  return {
    enabled: true,
    jobAvailable: true,
    retentionDays,
    batchSize,
    deletedCount,
    failedRunCount,
  }
}

function dataFlowRetentionRun(url) {
  const includeEvents = queryBoolean(url, 'includeEvents', true)
  const includeDailyRollups = queryBoolean(url, 'includeDailyRollups', true)
  const includeMonthlyRollups = queryBoolean(url, 'includeMonthlyRollups', true)
  if (!includeEvents && !includeDailyRollups && !includeMonthlyRollups) {
    return {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'At least one data-flow retention target must be selected.',
      },
    }
  }
  const deletedEventCount = includeEvents ? deleteExpiredDataFlowEvents(90, 1000) : 0
  const deletedDailyRollupCount = includeDailyRollups ? deleteExpiredDailyRollups(1095, 1000) : 0
  const deletedMonthlyRollupCount = includeMonthlyRollups ? deleteExpiredMonthlyRollups(1825, 1000) : 0
  state.dataFlowRetentionMetrics.eventsDeleted += deletedEventCount
  state.dataFlowRetentionMetrics.dailyRollupsDeleted += deletedDailyRollupCount
  state.dataFlowRetentionMetrics.monthlyRollupsDeleted += deletedMonthlyRollupCount
  state.auditLogs.unshift(auditLog('DATA_FLOW_RETENTION_RUN', 'DATA_FLOW_RETENTION', 'all-targets'))
  const generatedAt = new Date().toISOString()
  return {
    mode: 'DATA_FLOW_RETENTION',
    deletedEventCount,
    deletedDailyRollupCount,
    deletedMonthlyRollupCount,
    status: dataFlowRetentionStatus(generatedAt),
    generatedAt,
    note: 'Manual ADMIN data-flow retention run. Detailed event retention is shorter; materialized daily and monthly rollup retention is longer for aggregate analytics.',
  }
}

function queryBoolean(url, name, defaultValue) {
  if (!url.searchParams.has(name)) return defaultValue
  return String(url.searchParams.get(name)).toLowerCase() === 'true'
}

function deleteExpiredDataFlowEvents(retentionDays, batchSize) {
  const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000
  const candidates = state.dataFlowEvents
    .filter((event) => {
      const createdAt = Date.parse(event.createdAt)
      return !Number.isNaN(createdAt) && createdAt < cutoff
    })
    .sort((left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt))
    .slice(0, batchSize)
  const candidateSet = new Set(candidates)
  state.dataFlowEvents = state.dataFlowEvents.filter((event) => !candidateSet.has(event))
  return candidates.length
}

function deleteExpiredDailyRollups(retentionDays, batchSize) {
  const cutoffDay = dataFlowRetentionCutoffDay(retentionDays)
  const candidates = state.dataFlowDailyRollups
    .filter((point) => String(point.day || '') < cutoffDay)
    .sort((left, right) => (
      String(left.day || '').localeCompare(String(right.day || ''))
      || String(left.bucketName || '').localeCompare(String(right.bucketName || ''))
      || String(left.actorId || '').localeCompare(String(right.actorId || ''))
      || String(left.source || '').localeCompare(String(right.source || ''))
      || String(left.operation || '').localeCompare(String(right.operation || ''))
      || String(left.status || '').localeCompare(String(right.status || ''))
    ))
    .slice(0, batchSize)
  const candidateSet = new Set(candidates)
  state.dataFlowDailyRollups = state.dataFlowDailyRollups.filter((point) => !candidateSet.has(point))
  return candidates.length
}

function deleteExpiredMonthlyRollups(retentionDays, batchSize) {
  const cutoffMonth = dataFlowRetentionCutoffMonth(retentionDays)
  const candidates = state.dataFlowMonthlyRollups
    .filter((point) => String(point.month || '') < cutoffMonth)
    .sort((left, right) => (
      String(left.month || '').localeCompare(String(right.month || ''))
      || String(left.bucketName || '').localeCompare(String(right.bucketName || ''))
      || String(left.actorId || '').localeCompare(String(right.actorId || ''))
      || String(left.source || '').localeCompare(String(right.source || ''))
      || String(left.operation || '').localeCompare(String(right.operation || ''))
      || String(left.status || '').localeCompare(String(right.status || ''))
    ))
    .slice(0, batchSize)
  const candidateSet = new Set(candidates)
  state.dataFlowMonthlyRollups = state.dataFlowMonthlyRollups.filter((point) => !candidateSet.has(point))
  return candidates.length
}

function dataFlowRetentionCutoffDay(retentionDays) {
  const cutoff = new Date()
  cutoff.setUTCDate(cutoff.getUTCDate() - retentionDays)
  return cutoff.toISOString().slice(0, 10)
}

function dataFlowRetentionCutoffMonth(retentionDays) {
  const cutoff = new Date()
  cutoff.setUTCDate(cutoff.getUTCDate() - retentionDays)
  cutoff.setUTCDate(1)
  return cutoff.toISOString().slice(0, 7)
}

function emptyMonthlyRollupPoint(month, bucketName, source, operation) {
  return {
    month,
    bucketName,
    source,
    operation,
    successCount: 0,
    failureCount: 0,
    cancelCount: 0,
    totalCount: 0,
    uploadedBytes: 0,
    downloadedBytes: 0,
    copiedBytes: 0,
    totalBytes: 0,
  }
}

function recordEventIntoMonthlyPoint(point, event) {
  point.totalCount += 1
  if (event.status === 'SUCCESS') {
    point.successCount += 1
    if (event.eventType === 'UPLOAD') point.uploadedBytes += Math.max(0, Number(event.sizeBytes || 0))
    if (event.eventType === 'DOWNLOAD') point.downloadedBytes += Math.max(0, Number(event.sizeBytes || 0))
    if (event.eventType === 'COPY') point.copiedBytes += Math.max(0, Number(event.sizeBytes || 0))
  }
  if (event.eventType === 'FAILURE' || event.status === 'FAILED') point.failureCount += 1
  if (event.eventType === 'CANCEL' || event.status === 'CANCELLED') point.cancelCount += 1
  point.totalBytes = point.uploadedBytes + point.downloadedBytes + point.copiedBytes
}

function recordDailyPointIntoMonthlyPoint(target, point) {
  target.successCount += Number(point.successCount || 0)
  target.failureCount += Number(point.failureCount || 0)
  target.cancelCount += Number(point.cancelCount || 0)
  target.totalCount += Number(point.totalCount || 0)
  target.uploadedBytes += Number(point.uploadedBytes || 0)
  target.downloadedBytes += Number(point.downloadedBytes || 0)
  target.copiedBytes += Number(point.copiedBytes || 0)
  target.totalBytes = target.uploadedBytes + target.downloadedBytes + target.copiedBytes
}

function sortedMonthlyRollupPoints(points, limit) {
  return points
    .sort((left, right) => (
      right.month.localeCompare(left.month)
      || right.totalCount - left.totalCount
      || left.bucketName.localeCompare(right.bucketName)
      || left.source.localeCompare(right.source)
      || left.operation.localeCompare(right.operation)
    ))
    .slice(0, limit)
}

function materializedDimension(value) {
  return value ? String(value) : ''
}

function dataFlowFilterDay(value) {
  if (!value) return ''
  const timestamp = Date.parse(value)
  return Number.isNaN(timestamp) ? '' : new Date(timestamp).toISOString().slice(0, 10)
}

function dataFlowFilterMonth(value) {
  if (!value) return ''
  const timestamp = Date.parse(value)
  return Number.isNaN(timestamp) ? '' : new Date(timestamp).toISOString().slice(0, 7)
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

function dataFlowDailyRollupCsv(filters = {}) {
  return dataFlowDailyRollupPointsCsv(dataFlowDailyRollup(filters).points)
}

function materializedDataFlowDailyRollupCsv(filters = {}) {
  return dataFlowDailyRollupPointsCsv(materializedDataFlowDailyRollup(filters).points)
}

function dataFlowMonthlyRollupCsv(filters = {}) {
  const rollup = filters.materialized ? materializedDataFlowMonthlyRollup(filters) : dataFlowMonthlyRollup(filters)
  return dataFlowMonthlyRollupPointsCsv(rollup.points)
}

function storedDataFlowMonthlyRollupCsv(filters = {}) {
  return dataFlowMonthlyRollupPointsCsv(storedDataFlowMonthlyRollup(filters).points)
}

function dataFlowMonthlyRollupPointsCsv(points = []) {
  const rows = [
    ['month', 'bucketName', 'source', 'operation', 'successCount', 'failureCount', 'cancelCount', 'totalCount', 'uploadedBytes', 'downloadedBytes', 'copiedBytes', 'totalBytes'],
    ...points.map((point) => [
      point.month,
      point.bucketName,
      point.source,
      point.operation,
      point.successCount,
      point.failureCount,
      point.cancelCount,
      point.totalCount,
      point.uploadedBytes,
      point.downloadedBytes,
      point.copiedBytes,
      point.totalBytes,
    ]),
  ]
  return rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n'
}

function dataFlowDailyRollupPointsCsv(points = []) {
  const rows = [
    ['day', 'bucketName', 'source', 'operation', 'successCount', 'failureCount', 'cancelCount', 'totalCount', 'uploadedBytes', 'downloadedBytes', 'copiedBytes', 'totalBytes'],
    ...points.map((point) => [
      point.day,
      point.bucketName,
      point.source,
      point.operation,
      point.successCount,
      point.failureCount,
      point.cancelCount,
      point.totalCount,
      point.uploadedBytes,
      point.downloadedBytes,
      point.copiedBytes,
      point.totalBytes,
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

function chargebackDailyRollup(url) {
  refreshBucketUsage()
  const rates = chargebackRates(url)
  const materialized = String(url.searchParams.get('materialized') || 'false').toLowerCase() === 'true'
  const rollup = materialized ? materializedDataFlowDailyRollup(dataFlowFilters(url)) : dataFlowDailyRollup(dataFlowFilters(url))
  const usage = organizationUsageRows()[0]
  const dailyBuckets = new Map()
  for (const point of rollup.points || []) {
    const key = `${point.day}|${usage.id}`
    if (!dailyBuckets.has(key)) {
      dailyBuckets.set(key, {
        day: point.day,
        organizationId: usage.id,
        organizationName: usage.name,
        bucketCount: usage.bucketCount,
        objectCount: usage.objectCount,
        usedBytes: usage.usedBytes,
        ingressBytes: 0,
        egressBytes: 0,
        internalBytes: 0,
        billableOperationCount: 0,
        failedOperationCount: 0,
        cancelledOperationCount: 0,
      })
    }
    const bucket = dailyBuckets.get(key)
    bucket.ingressBytes += Number(point.uploadedBytes || 0)
    bucket.egressBytes += Number(point.downloadedBytes || 0)
    bucket.internalBytes += Number(point.copiedBytes || 0)
    bucket.billableOperationCount += Number(point.successCount || 0)
    bucket.failedOperationCount += Number(point.failureCount || 0)
    bucket.cancelledOperationCount += Number(point.cancelCount || 0)
  }
  const points = [...dailyBuckets.values()]
    .map((point) => {
      const projectedStorageCost = costForBytes(rates.storageGbMonthRate, point.usedBytes)
      const ingressCost = costForBytes(rates.ingressGbRate, point.ingressBytes)
      const egressCost = costForBytes(rates.egressGbRate, point.egressBytes)
      const internalCost = costForBytes(rates.internalGbRate, point.internalBytes)
      const operationCost = costForOperations(rates.operationThousandRate, point.billableOperationCount)
      return {
        ...point,
        projectedStorageCost,
        ingressCost,
        egressCost,
        internalCost,
        operationCost,
        estimatedTotalCost: money(projectedStorageCost + ingressCost + egressCost + internalCost + operationCost),
      }
    })
    .sort((left, right) => (
      right.day.localeCompare(left.day)
      || right.estimatedTotalCost - left.estimatedTotalCost
      || left.organizationName.localeCompare(right.organizationName)
    ))
  return {
    mode: 'CHARGEBACK_DAILY_ROLLUP',
    rollupSource: materialized ? 'MATERIALIZED_DATA_FLOW_DAILY_ROLLUP' : 'DATA_FLOW_DAILY_ROLLUP',
    granularity: 'UTC_DAY',
    currency: String(url.searchParams.get('currency') || state.billingPricingPolicy.currency || 'USD').trim().toUpperCase().slice(0, 12) || 'USD',
    days: rollup.dayWindow,
    limit: rollup.pointLimit,
    inputPointCount: (rollup.points || []).length,
    pointCount: points.length,
    totalEstimatedCost: money(points.reduce((sum, point) => sum + point.estimatedTotalCost, 0)),
    points,
    generatedAt: new Date().toISOString(),
    note: 'ADMIN/ORG_ADMIN scoped chargeback trend from data-flow daily rollups; no raw object keys or provider responses are returned.',
    storageCostPolicy: 'Daily points apply the current organization bucket storage snapshot to each active rollup day. This is OSMU chargeback planning, not AWS billing parity.',
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

function sendChargebackNotificationAdapter(deliveryId) {
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
  delivery.status = 'DELIVERY_ADAPTER_SUCCEEDED'
  delivery.attemptCount = Number(delivery.attemptCount || 0) + 1
  delivery.nextAttemptAt = ''
  delivery.updatedAt = now
  delivery.lastError = ''
  state.auditLogs.unshift(auditLog('CHARGEBACK_ALERT_NOTIFICATION_ADAPTER_SEND', 'CHARGEBACK_ALERT_NOTIFICATION_DELIVERY', String(deliveryId)))
  return {
    mode: 'ADAPTER_RESULT',
    status: delivery.status,
    externalDeliveryEnabled: true,
    delivery,
    recordedAt: now,
    note: 'Notification delivery adapter delivered this outbox row.',
  }
}

function chargebackAdapterRetryWorker(url, dryRun = true) {
  const now = new Date().toISOString()
  const limit = clampNumber(Number(url.searchParams.get('limit') || 50), 1, 200)
  const notificationLimit = Math.max(1, Math.floor(limit / 2))
  const paymentLimit = Math.max(1, limit - notificationLimit)
  const notifications = dueNotificationAdapterRetries(now).slice(0, notificationLimit)
  const handoffs = duePaymentAdapterRetries(now).slice(0, paymentLimit)
  const items = [
    ...notifications.map((delivery) => adapterRetryWorkerItem(
      'NOTIFICATION',
      delivery,
      'DELIVERY_ADAPTER_BLOCKED_CREDENTIAL',
      dryRun,
      'Notification adapter retry worker blocked because delivery adapter credentials/configuration are not configured.'
    )),
    ...handoffs.map((handoff) => adapterRetryWorkerItem(
      'PAYMENT_PROVIDER',
      handoff,
      'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL',
      dryRun,
      'Payment provider adapter retry worker blocked because payment adapter credentials/configuration are not configured.'
    )),
  ]
  if (!dryRun) {
    for (const delivery of notifications) {
      delivery.status = 'DELIVERY_ADAPTER_BLOCKED_CREDENTIAL'
      delivery.attemptCount = Number(delivery.attemptCount || 0) + 1
      delivery.nextAttemptAt = ''
      delivery.updatedAt = now
      delivery.lastError = 'Notification adapter retry worker blocked because delivery adapter credentials/configuration are not configured.'
    }
    for (const handoff of handoffs) {
      handoff.status = 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL'
      handoff.attemptCount = Number(handoff.attemptCount || 0) + 1
      handoff.nextAttemptAt = ''
      handoff.updatedAt = now
      handoff.lastError = 'Payment provider adapter retry worker blocked because payment adapter credentials/configuration are not configured.'
    }
    if (items.length > 0) {
      state.auditLogs.unshift(auditLog('CHARGEBACK_ADAPTER_RETRY_WORKER_RUN', 'CHARGEBACK_ADAPTER_RETRY', 'due-outbox'))
    }
  }
  return {
    mode: 'ADAPTER_RETRY_WORKER',
    enabled: false,
    dryRun,
    externalAdaptersEnabled: false,
    scanLimit: limit,
    notificationCandidateCount: notifications.length,
    paymentCandidateCount: handoffs.length,
    updatedCount: dryRun ? 0 : items.length,
    items,
    generatedAt: now,
    note: dryRun
      ? 'Dry-run only; no external adapter calls or status updates were performed.'
      : 'Due adapter retry rows were blocked because external adapter credentials/configuration are not configured.',
  }
}

function dueNotificationAdapterRetries(now) {
  return state.chargebackNotificationDeliveries
    .filter((delivery) => ['PENDING_DELIVERY_ADAPTER', 'DELIVERY_ADAPTER_RETRY_SCHEDULED'].includes(delivery.status))
    .filter((delivery) => isDueAt(delivery.nextAttemptAt, now))
}

function duePaymentAdapterRetries(now) {
  return state.chargebackPaymentProviderHandoffs
    .filter((handoff) => ['PENDING_PAYMENT_PROVIDER_ADAPTER', 'PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED'].includes(handoff.status))
    .filter((handoff) => isDueAt(handoff.nextAttemptAt, now))
}

function adapterRetryWorkerItem(itemType, record, toStatus, dryRun, note) {
  return {
    itemType,
    id: record.id,
    fromStatus: record.status,
    toStatus,
    attemptCount: dryRun ? Number(record.attemptCount || 0) : Number(record.attemptCount || 0) + 1,
    nextAttemptAt: dryRun ? record.nextAttemptAt || '' : '',
    note: dryRun ? `Due ${itemType.toLowerCase()} adapter retry candidate.` : note,
  }
}

function isDueAt(value, now) {
  if (!value) {
    return true
  }
  return Date.parse(value) <= Date.parse(now)
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

function sendChargebackPaymentProviderAdapter(handoffId) {
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
  handoff.status = 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED'
  handoff.attemptCount = Number(handoff.attemptCount || 0) + 1
  handoff.nextAttemptAt = ''
  handoff.updatedAt = now
  handoff.lastError = ''
  state.auditLogs.unshift(auditLog('CHARGEBACK_PAYMENT_PROVIDER_ADAPTER_SEND', 'CHARGEBACK_PAYMENT_PROVIDER_HANDOFF', String(handoffId)))
  return {
    mode: 'ADAPTER_RESULT',
    status: handoff.status,
    externalPaymentEnabled: true,
    handoff,
    recordedAt: now,
    note: 'Payment provider adapter delivered this handoff row.',
  }
}

function chargebackPaymentProviderAdapterReadiness() {
  const profiles = ['GENERIC', 'CARD', 'BANK', 'TAX', 'ERP'].map((profile) => {
    const sampleProvider = profile === 'GENERIC' ? 'MANUAL_AP' : `${profile}_PROVIDER`
    const nativeApiSupported = profile !== 'GENERIC'
    return {
      providerProfile: profile,
      sampleProvider,
      adapterMode: nativeApiSupported ? 'NATIVE_API_UNCONFIGURED' : 'UNCONFIGURED',
      status: nativeApiSupported ? 'NATIVE_API_CONFIGURATION_REQUIRED' : 'ACTION_REQUIRED',
      webhookProfileConfigured: false,
      nativeApiSupported,
      nativeApiReady: false,
      requiredConfiguration: paymentProviderAdapterRequirement(profile),
      note: nativeApiSupported
        ? `${profile} handoff can use the native API bridge after endpoint URL and auth-header value are configured.`
        : `${profile} handoff needs a configured webhook profile before external send.`,
    }
  })
  return {
    mode: 'PAYMENT_PROVIDER_ADAPTER_READINESS',
    status: 'ACTION_REQUIRED',
    nativeApiSupported: true,
    nativeApiReady: false,
    profileCount: profiles.length,
    webhookReadyProfileCount: 0,
    nativeApiReadyProfileCount: 0,
    profiles,
    generatedAt: new Date().toISOString(),
    scopePolicy: 'Mock readiness checks configuration shape only and does not call provider APIs.',
    secretPolicy: 'Webhook/native endpoint URLs, secret/auth header values, signing secrets, provider credentials, raw provider responses, and customer payment data are never returned.',
    note: 'Configure generic/provider-specific webhook profiles or CARD/BANK/TAX/ERP native API bridge endpoint URL plus auth-header value before sending handoff rows.',
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
    providerProfile: paymentProviderProfile(provider),
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

function paymentProviderProfile(provider) {
  const normalized = String(provider || '').trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_')
  if (normalized.startsWith('CARD')) {
    return 'CARD'
  }
  if (normalized.startsWith('BANK')) {
    return 'BANK'
  }
  if (normalized.startsWith('TAX')) {
    return 'TAX'
  }
  if (normalized.startsWith('ERP')) {
    return 'ERP'
  }
  return 'GENERIC'
}

function paymentProviderAdapterRequirement(profile) {
  if (profile === 'CARD') {
    return 'Set osmu.billing.payment-provider.card.webhook-url, the generic payment-provider webhook, or osmu.billing.payment-provider.card.native-api-url plus osmu.billing.payment-provider.card.native-api-auth-header-value.'
  }
  if (profile === 'BANK') {
    return 'Set osmu.billing.payment-provider.bank.webhook-url, the generic payment-provider webhook, or osmu.billing.payment-provider.bank.native-api-url plus osmu.billing.payment-provider.bank.native-api-auth-header-value.'
  }
  if (profile === 'TAX') {
    return 'Set osmu.billing.payment-provider.tax.webhook-url, the generic payment-provider webhook, or osmu.billing.payment-provider.tax.native-api-url plus osmu.billing.payment-provider.tax.native-api-auth-header-value.'
  }
  if (profile === 'ERP') {
    return 'Set osmu.billing.payment-provider.erp.webhook-url, the generic payment-provider webhook, or osmu.billing.payment-provider.erp.native-api-url plus osmu.billing.payment-provider.erp.native-api-auth-header-value.'
  }
  return 'Set osmu.billing.payment-provider.webhook-url for generic/manual payment-provider handoff delivery.'
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
    commercialApprovedBy: '',
    commercialApprovalReference: '',
    commercialApprovalNote: '',
    createdAt: now,
    updatedAt: now,
    approvedAt: '',
    appliedAt: '',
    commercialApprovedAt: '',
    commercialEffectiveFrom: '',
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

function approveBillingPricingPolicyProposalPriceList(proposalId, url) {
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
  if (proposal.status !== 'APPROVED_APPLIED') {
    return {
      status: proposal.status,
      approvedPriceList: Boolean(proposal.approvedPriceList),
      proposal,
      appliedPolicy: state.billingPricingPolicy,
      generatedAt: new Date().toISOString(),
      note: 'Only internally approved pricing policy proposals can become approved price lists.',
    }
  }
  const now = new Date().toISOString()
  const approvalReference = String(url.searchParams.get('approvalReference') || '').trim().slice(0, 128)
  const effectiveFrom = String(url.searchParams.get('effectiveFrom') || now).trim()
  proposal.status = 'PRICE_LIST_APPROVED'
  proposal.approvedPriceList = true
  proposal.commercialApprovedBy = 'admin'
  proposal.commercialApprovalReference = approvalReference
  proposal.commercialApprovalNote = String(url.searchParams.get('approvalNote') || '').trim().slice(0, 512)
  proposal.commercialApprovedAt = now
  proposal.commercialEffectiveFrom = effectiveFrom
  proposal.updatedAt = now
  state.auditLogs.unshift(auditLog('BILLING_PRICING_POLICY_PRICE_LIST_APPROVE', 'BILLING_PRICING_POLICY_PROPOSAL', String(proposal.id)))
  return {
    status: 'PRICE_LIST_APPROVED',
    approvedPriceList: true,
    proposal,
    appliedPolicy: state.billingPricingPolicy,
    generatedAt: now,
    note: 'Pricing policy proposal was recorded as an approved external commercial price list reference.',
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

function chargebackDailyRollupCsv(url) {
  const rollup = chargebackDailyRollup(url)
  const points = rollup.points || []
  const rows = [
    ['rowType', 'currency', 'generatedAt', 'rollupSource', 'granularity', 'days', 'limit', 'inputPointCount', 'pointCount', 'day', 'organizationId', 'organizationName', 'bucketCount', 'objectCount', 'usedBytes', 'ingressBytes', 'egressBytes', 'internalBytes', 'billableOperationCount', 'failedOperationCount', 'cancelledOperationCount', 'projectedStorageCost', 'ingressCost', 'egressCost', 'internalCost', 'operationCost', 'estimatedTotalCost', 'note'],
    [
      'TOTAL',
      rollup.currency,
      rollup.generatedAt,
      rollup.rollupSource,
      rollup.granularity,
      rollup.days,
      rollup.limit,
      rollup.inputPointCount,
      rollup.pointCount,
      '',
      '',
      'TOTAL',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      rollup.totalEstimatedCost,
      'Aggregate daily chargeback trend only - not a final invoice or AWS billing parity report.',
    ],
    ...points.map((point) => [
      'DAILY_ORGANIZATION',
      rollup.currency,
      rollup.generatedAt,
      rollup.rollupSource,
      rollup.granularity,
      rollup.days,
      rollup.limit,
      rollup.inputPointCount,
      rollup.pointCount,
      point.day,
      point.organizationId,
      point.organizationName,
      point.bucketCount,
      point.objectCount,
      point.usedBytes,
      point.ingressBytes,
      point.egressBytes,
      point.internalBytes,
      point.billableOperationCount,
      point.failedOperationCount,
      point.cancelledOperationCount,
      point.projectedStorageCost,
      point.ingressCost,
      point.egressCost,
      point.internalCost,
      point.operationCost,
      point.estimatedTotalCost,
      rollup.storageCostPolicy,
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

function storageBackendStatus() {
  const usage = usageSummary()
  return {
    mode: 'mock-memory',
    metadataMode: 'mock-memory',
    storageHealthy: true,
    accessKeyProvisionerHealthy: true,
    bucketCount: usage.bucketCount,
    objectCount: usage.objectCount,
    usedBytes: usage.usedBytes,
    quotaBytes: usage.totalBytes,
    remainingBytes: Math.max(0, usage.totalBytes - usage.usedBytes),
    directMetricTotalBytes: 0,
    directMetricFreeBytes: 0,
    capacitySource: 'bucket_metadata_usage',
    directStorageMetricsEnabled: false,
    minioAdminMetricsEnabled: false,
    directStorageMetricsStatus: 'DISABLED',
    directStorageMetricsSource: 'disabled',
    directStorageMetricsDetail: 'Direct MinIO capacity metrics are disabled.',
    directStorageMetricNames: [],
    readiness: 'DEMO_ONLY',
    pendingGates: ['MinIO object storage mode is not enabled.'],
    generatedAt: new Date().toISOString(),
    note: 'Mock storage backend status uses bucket metadata usage and health probes until direct MinIO capacity metrics are ready.',
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
    warningCount: 10,
    blockers: [],
    warnings: [
      'Java backend tests pending',
      'Docker MariaDB/MinIO smoke pending',
      'Operations evidence plan action required',
      'Operations evidence invocation planned for action 6',
      'Operations dispatch preflight needs browser dispatch for action 6',
      'Operations workflow run id plan is waiting for container-security-ci.yml run id',
      'Operations artifact collection is waiting for container security evidence',
      'Operations evidence handoff action required',
      'Operations readiness convergence action required',
      'Data-flow storage plan target evidence pending',
    ],    severitySummaries: [
      { severity: 'WARNING', count: 10 },
    ],
    categorySummaries: [
      { category: 'RUNTIME', count: 1 },
      { category: 'STORAGE', count: 1 },
      { category: 'OPERATIONS', count: 8 },
    ],
    items: [
      { code: 'METADATA_ENGINE', category: 'RUNTIME', severity: 'WARNING', title: 'Mock metadata engine', message: 'Java/MariaDB gate is pending.', targetPage: 'dashboard', targetPanel: 'overview' },
      { code: 'OBJECT_STORAGE', category: 'STORAGE', severity: 'WARNING', title: 'Mock object store', message: 'Docker/MinIO gate is pending.', targetPage: 'storage', targetPanel: 'storage-buckets' },
      {
        code: 'OPERATIONS_EVIDENCE_PLAN',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Evidence plan',
        message: 'Operations evidence plan is action-required: passed=82 pending=20, actions=20, selected ready subset is action 6.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-evidence-plan.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-evidence-plan.ps1',
        remediationNote: 'Mock readiness mirrors the current local evidence chain and keeps the action 6 browser dispatch path visible.',
      },
      {
        code: 'OPERATIONS_EVIDENCE_PLAN_INVOCATION',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Evidence invocation',
        message: 'Operations evidence invocation is planned for selected action 6 with zero blocked actions.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-evidence-plan-invocation.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        remediationNote: 'Run plan-only first, review the generated workflow dispatch, then dispatch the GitHub workflow from the browser.',
      },
      {
        code: 'OPERATIONS_DISPATCH_PREFLIGHT',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Dispatch preflight',
        message: 'Dispatch preflight is action-required only because GitHub CLI is unavailable; action 6 is ready for browser dispatch.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-dispatch-preflight.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        remediationWorkflow: '.github/workflows/container-security-ci.yml',
        remediationWorkflowCommand: 'gh workflow run container-security-ci.yml --repo chefbeom/object-storage-osmu --ref main',
        remediationNote: 'Browser dispatch URL: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
      },
      {
        code: 'OPERATIONS_WORKFLOW_RUN_ID_PLAN',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Workflow run id plan',
        message: 'Workflow run id plan is query-required: container-security-ci.yml run id is missing for action 6.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-workflow-run-ids.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
        remediationNote: 'After container-security-ci.yml finishes, collect the run id before artifact collection.',
      },
      {
        code: 'OPERATIONS_ARTIFACT_COLLECTION_PLAN',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Artifact collection',
        message: 'Artifact collection has no readiness artifacts yet and is waiting for the container security source artifact.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-artifact-collection-plan.json',
        remediationCommand: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true',
        remediationNote: 'Security evidence finalizer remains blocked until image signing and container security run ids are available.',
      },
      {
        code: 'OPERATIONS_EVIDENCE_HANDOFF',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Evidence handoff',
        message: 'Operations evidence handoff is action-required: currentBottleneck=dispatch-ready-subset-browser, selected action=6.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-evidence-handoff.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        remediationNote: 'Open the container-security-ci.yml browser dispatch after reviewing the ready subset plan.',
      },      {
        code: 'OPERATIONS_READINESS_CONVERGENCE',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Convergence',
        message: 'Operations readiness convergence is action-required: bottleneck=dispatch-ready-subset-browser, stages=2/8, missingWorkflowRuns=1, handoffStale=false, kubernetesReportSyncStale=false.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-operations-readiness-convergence.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        remediationNote:
          'The ready subset is action 6. This mock report does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands.',
      },
      {
        code: 'DATA_FLOW_STORAGE_PLAN',
        category: 'OPERATIONS',
        severity: 'WARNING',
        title: 'Data-flow storage plan',
        message: 'Data-flow storage plan is plan-ready-execute-required: store=MARIADB_PARTITION, pending=2/3.',
        targetPage: 'dashboard',
        targetPanel: 'dashboard-readiness-panel',
        evidencePath: '.osmu-run/latest-data-flow-storage-plan.json',
        remediationCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-data-flow-storage-plan.ps1 -CandidateStore <store> -ExpectedPeakEventsPerDay <n> -ExpectedQueryWindowDays <days> -TargetP95QueryLatencyMs <p95-ms> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\\.osmu-run\\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence',
        remediationNote: 'OSMU operations analytics only. This mock plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages.',
      },
    ],
    operationsReadinessSummary: {
      result: 'pending',
      summary: 'passed=82 pending=20',
      reportPath: '.osmu-run/latest-operations-readiness.json',
      generatedAt: '2026-06-30T12:48:07.4142068+09:00',
      passedCount: 82,
      pendingCount: 20,
      totalCount: 102,
      checkCount: 102,
      pendingCategorySummary: 'chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1',
      pendingCategoryCounts: [
        { category: 'chargeback-closeout', count: 1 },
        { category: 'commercial-approval', count: 1 },
        { category: 'commercial-integration', count: 1 },
        { category: 'data-flow', count: 3 },
        { category: 'enterprise-auth', count: 2 },
        { category: 'ha-dr', count: 2 },
        { category: 'monitoring', count: 1 },
        { category: 'operations-handoff-package', count: 1 },
        { category: 'security-hardening', count: 6 },
        { category: 'storage-backend', count: 1 },
        { category: 'storage-expansion', count: 1 },
      ],
      pendingRemediationCount: 20,
      pendingRemediations: [
        {
          name: 'Container scan/SBOM evidence',
          category: 'security-hardening',
          evidencePath: '.osmu-run/latest-container-security-evidence.json',
          requiredEvidence: 'container scan/SBOM result=passed from GitHub-hosted workflow',
          detail: 'report not found',
          command: 'Dispatch .github/workflows/container-security-ci.yml on the target commit',
          workflow: '.github/workflows/container-security-ci.yml',
          workflowCommand: 'gh workflow run container-security-ci.yml',
          note: 'Mock source readiness keeps action 6 visible as the next browser-dispatchable evidence run.',
        },
      ],
      decisionRule: 'Operations readiness remains pending until all target evidence checks pass and the final handoff package is generated from non-secret target evidence.',
    },
    operationsEvidencePlan: {
      result: 'action-required',
      sourceSummary: 'passed=82 pending=20',
      sourceReport: '.osmu-run/latest-operations-readiness.json',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      sourcePendingRemediationCount: 20,
      sourcePendingRemediationEntryCount: 20,
      sourcePendingRemediationActionCount: 20,
      sourcePendingRemediationMissingActionCount: 0,
      sourcePendingRemediationCoverageReady: true,
      pendingCount: 20,
      actionCount: 20,
      unplannedCount: 0,
      pendingCategorySummary: 'chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1',
      pendingCategoryCounts: [
        { category: 'security-hardening', count: 6 },
        { category: 'data-flow', count: 3 },
        { category: 'enterprise-auth', count: 2 },
        { category: 'ha-dr', count: 2 },
      ],
      actionSummary: {
        totalActions: 20,
        kubernetesLiveActions: 3,
        securityCiActions: 6,
        operatorRemediationActions: 11,
        requiresOperatorApprovalCount: 17,
        requiresKubeconfigSecretCount: 3,
        actionsWithPlaceholdersCount: 16,
        unplannedCheckCount: 0,
      },
      actions: [
        {
          order: 6,
          name: 'Container scan/SBOM evidence',
          category: 'security-hardening',
          currentDetail: 'report not found',
          command: 'gh workflow run container-security-ci.yml',
          workflowCommand: 'gh workflow run container-security-ci.yml',
          recommendedCommand: 'gh workflow run container-security-ci.yml',
          workflow: '.github/workflows/container-security-ci.yml',
          dispatchUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          requiresOperatorApproval: true,
          requiresKubeconfigSecret: false,
          reason: 'Container security scan and SBOM evidence is the ready subset currently blocking convergence.',
        },
      ],
    },
    operationsEvidenceInvocation: {
      result: 'planned',
      sourceSummary: 'passed=82 pending=20',
      sourcePlan: '.osmu-run/latest-operations-evidence-plan.json',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      commandMode: 'Workflow',
      executionMode: 'plan-only',
      selectedActionCount: 1,
      selectedActionOrders: [6],
      plannedCount: 1,
      blockedCount: 0,
      executedCount: 0,
      failedCount: 0,
      actions: [
        {
          order: 6,
          name: 'Container scan/SBOM evidence',
          status: 'planned',
          command: 'gh workflow run container-security-ci.yml',
          workflow: '.github/workflows/container-security-ci.yml',
          dispatchUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          blockReasons: [],
        },
      ],
    },
    operationsInvocationUnblockPlan: {
      result: 'ready',
      sourceInvocationReport: '.osmu-run/latest-operations-evidence-plan-invocation.json',
      sourceResult: 'planned',
      sourceSummary: 'passed=82 pending=20',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      selectedActionCount: 1,
      plannedCount: 1,
      blockedCount: 0,
      failedCount: 0,
      needsKubeconfigSecretConfirmation: false,
      needsOperatorApprovalConfirmation: false,
      requiredPlaceholderCount: 0,
      ambiguousRepeatedPlaceholderCount: 0,
      confirmationGroupCount: 0,
      requiredInputGroupCount: 0,
      blockedActionOrders: [],
      plannedActionOrders: [6],
      confirmedPlanCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
      blockedOnlyPlanCommand: '',
      plannedOnlyCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
      decisionRule: 'Selected action 6 can proceed in plan-only/browser dispatch mode because no placeholder or confirmation blockers remain.',
      confirmationGroups: [],
      requiredInputGroups: [],
      actions: [],
    },
    operationsDispatchPreflight: {
      result: 'action-required',
      sourceUnblockPlan: '.osmu-run/latest-operations-invocation-unblock-plan.json',
      sourceResult: 'ready',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      selectedActionCount: 1,
      selectedActionOrders: [6],
      readyActionCount: 1,
      readyActionOrders: [6],
      blockedActionCount: 0,
      blockedActionOrders: [],
      needsKubeconfigSecretConfirmation: false,
      needsOperatorApprovalConfirmation: false,
      requiredInputCount: 0,
      missingInputCount: 0,
      ambiguousInputCount: 0,
      unsafeInputCount: 0,
      invalidInputCount: 0,
      failedCheckCount: 2,
      warningCheckCount: 0,
      requiredGitHubSecrets: [],
      githubCliPath: '',
      githubRepository: 'chefbeom/object-storage-osmu',
      githubRef: 'main',
      gitRefSafety: {
        checked: true,
        status: 'action-required',
        githubRef: 'main',
        currentBranch: 'main',
        commitSha: 'a0730b64636a22c38639b5f5c647f2e13792fc68',
        shortCommitSha: 'a0730b64',
        upstreamRef: 'origin/main',
        upstreamCommitSha: '572eb099aacdc3ed03929bf24c34e251e37885bd',
        aheadCount: 25,
        behindCount: 0,
        workingTreeDirty: true,
        githubRefMatchesCurrentBranch: true,
        githubRefLikelyContainsCommit: false,
        suggestedGitHubRef: 'codex/operations-readiness-a0730b64',
        note: 'Working tree has uncommitted changes; GitHub Actions will only run committed content from GitHubRef main, not local dirty files. Current branch main is also 25 commit(s) ahead of origin/main. Commit or intentionally exclude the changes, rerun preflight, then push a branch and dispatch that ref.',
      },
      workflowFiles: [
        {
          actionOrder: 6,
          workflow: 'container-security-ci.yml',
          path: '.github/workflows/container-security-ci.yml',
          exists: true,
          readyToDispatch: true,
          dispatchUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
        },
      ],
      checks: [
        {
          id: 'GITHUB_CLI_AVAILABLE',
          code: 'GITHUB_CLI_AVAILABLE',
          status: 'fail',
          severity: 'ERROR',
          message: 'GitHub CLI was not found on PATH.',
          detail: 'GitHub CLI was not found on PATH in the mock/demo environment.',
          remediation: 'Use the browser dispatch URL or install gh before using CLI dispatch.',
        },
        {
          id: 'GITHUB_REF_SYNC',
          code: 'GITHUB_REF_SYNC',
          status: 'fail',
          severity: 'ERROR',
          message: 'Working tree has uncommitted changes; GitHub Actions will only run committed content from GitHubRef main, not local dirty files. Current branch main is also 25 commit(s) ahead of origin/main. Commit or intentionally exclude the changes, rerun preflight, then push a branch and dispatch that ref.',
          detail: 'Commit or intentionally exclude local changes, then rerun preflight to get a push command for codex/operations-readiness-a0730b64.',
          remediation: 'Review git status, commit intended changes, then rerun dispatch preflight before push/dispatch.',
        },
      ],
      readyPlanCommand: '',
      executeCommand: '',
      apiExecuteCommand: '',
      readySubsetPlanCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
      readySubsetExecuteCommand: '',
      readySubsetApiExecuteCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute',
      requiredInputs: [],
      inputTemplates: [],
      decisionRule: 'Browser or GitHub REST API dispatch is available for ready action 6 after pushing a GitHub ref that contains commit a0730b64.',
    },
    operationsWorkflowRunIdPlan: {
      result: 'query-required',
      sourceInvocationReport: '.osmu-run/latest-operations-evidence-plan-invocation.json',
      invocationResult: 'planned',
      sourceSummary: 'passed=82 pending=20',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      selectedActionOrders: [6],
      branch: 'main',
      githubRepository: 'chefbeom/object-storage-osmu',
      queryMode: 'plan-only',
      runListJsonDirectory: '.\\.osmu-run\\workflow-run-lists',
      runListJsonDirectoryCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\.osmu-run\\workflow-run-lists',
      githubApiRunListCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
      githubApiBaseUrl: 'https://api.github.com',
      runListJsonFilePattern: '<workflow>.json',
      runListJsonHandoffNote: 'Save each workflow run-list JSON as .\\.osmu-run\\workflow-run-lists\\<workflow>.json. Each file may contain an array of runs or an object with a runs array.',
      browserWorkflowRunsUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml', 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml'],
      workflowRunIdInputs: [
        {
          workflow: 'container-security-ci.yml',
          group: 'container-security-source',
          actionOrders: [6],
          runIdParameter: 'ContainerSecurityRunId',
          recommendedRunId: '',
          artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
          requiredForReadiness: false,
          readyForArtifactDownload: false,
          runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json',
          queryCommand: 'gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
          gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
          sourceSelected: true,
          supplementalForSecurityFinalizer: false,
        },
      ],
      recommendedCommands: [
        {
          order: 1,
          name: 'Collect run ids from saved run-list JSON',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\.osmu-run\\workflow-run-lists',
          reason: 'Use after browser dispatch when GitHub CLI is unavailable locally.',
          note: 'Save each workflow run-list JSON as .\\.osmu-run\\workflow-run-lists\\<workflow>.json. Each file may contain an array of runs or an object with a runs array.',
          dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml', 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml'],
        },
        {
          order: 2,
          name: 'Collect workflow run ids with GitHub REST API',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
          reason: 'Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable.',
          note: 'Queries workflow_dispatch runs through the GitHub REST API, using GH_TOKEN or GITHUB_TOKEN if present, and never writes token values to the report.',
          dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml', 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml'],
        },
        {
          order: 3,
          name: 'Collect workflow run ids with GitHub CLI',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -Execute',
          reason: 'Use after workflow dispatch when gh is installed and authenticated.',
          note: 'Regenerates this plan by querying workflow_dispatch runs directly.',
          dispatchUrls: [],
        },
        {
          order: 4,
          name: 'Write artifact collection plan with browser run ids',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningRunId <ImageSigningRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          reason: 'Use when a browser workflow run page shows the run id but gh/run-list JSON is unavailable.',
          note: `Replace each <RunIdParameter> placeholder with either the numeric GitHub Actions run id or the full workflow run URL; artifact collection normalizes /actions/runs/<id> before regenerating the same selected-action scope. ${SECURITY_FINALIZER_DEPENDENCY_NOTE}`,
          dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml', 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml'],
        },
        {
          order: 5,
          name: 'Write artifact collection plan',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          reason: 'Use after recommended run ids are available.',
          note: 'Feeds run ids into the artifact collection/import chain.',
          dispatchUrls: [],
        },
        {
          order: 6,
          name: 'Run security evidence finalizer',
          command: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true',
          reason: 'Use after image signing and container security run ids are collected.',
          note: 'Promotes signed-image and container scan/SBOM evidence into the security finalizer artifact. Missing run id inputs: ImageSigningRunId, ContainerSecurityRunId.',
          dispatchUrls: [],
        },
      ],
      limit: 20,
      workflowCount: 1,
      readyWorkflowCount: 0,
      missingWorkflowCount: 1,
      staleWorkflowCount: 0,
      imageSigningVersion: 'v0.1.0-rc.1',
      commitSha: 'a0730b64636a22c38639b5f5c647f2e13792fc68',
      artifactCollectionPlanCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
      manualArtifactCollectionPlanCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningRunId <ImageSigningRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
      securityEvidenceFinalizerReady: false,
      securityEvidenceFinalizerRunIdInputs: ['ImageSigningRunId', 'ContainerSecurityRunId'],
      securityEvidenceFinalizerRunIdInputHints: [
        {
          workflow: 'image-publish-sign-ci.yml',
          group: 'image-signing-source',
          actionOrders: [],
          runIdParameter: 'ImageSigningRunId',
          recommendedRunId: '',
          artifactName: 'osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68',
          requiredForReadiness: false,
          readyForArtifactDownload: false,
          runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml',
          runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\image-publish-sign-ci.yml.json',
          queryCommand: 'gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
          gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
          sourceSelected: false,
          supplementalForSecurityFinalizer: true,
        },
        {
          workflow: 'container-security-ci.yml',
          group: 'container-security-source',
          actionOrders: [6],
          runIdParameter: 'ContainerSecurityRunId',
          recommendedRunId: '',
          artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
          requiredForReadiness: false,
          readyForArtifactDownload: false,
          runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json',
          queryCommand: 'gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
          gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
          sourceSelected: true,
          supplementalForSecurityFinalizer: false,
        },
      ],
      securityEvidenceFinalizerMissingRunIdInputs: ['ImageSigningRunId', 'ContainerSecurityRunId'],
      securityEvidenceFinalizerDependencyNote: SECURITY_FINALIZER_DEPENDENCY_NOTE,
      securityEvidenceFinalizerCommand: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true',
      decisionRule: 'Query workflow runs after browser dispatch completes, then feed run ids into artifact collection.',
      workflows: [
        {
          actionOrder: 6,
          workflow: 'container-security-ci.yml',
          workflowFile: '.github/workflows/container-security-ci.yml',
          runId: '',
          runStatus: '',
          runConclusion: '',
          queryCommand: 'gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle',
          gitHubApiQueryUrl: 'https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20',
          runListJsonFile: 'container-security-ci.yml.json',
          runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json',
          runListJsonExists: false,
          runListJsonNote: 'Save a run-list JSON array or object with a runs array here when collecting run ids without GitHub CLI on this machine.',
          runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          missing: true,
          stale: false,
        },
      ],
    },
    operationsArtifactCollectionPlan: {
      result: 'security-source-action-required',
      sourceInvocationReport: '.osmu-run/latest-operations-evidence-plan-invocation.json',
      invocationResult: 'planned',
      sourceSummary: 'passed=82 pending=20',
      sourcePassedCount: 82,
      sourcePendingCount: 20,
      sourceTotalCount: 102,
      sourceCheckCount: 102,
      selectedActionOrders: [6],
      invocationSummary: 'selected=1 planned=1 blocked=0 executed=0 failed=0',
      artifactCount: 1,
      requiredArtifactCount: 0,
      readyArtifactCount: 0,
      missingRequiredArtifactCount: 0,
      securitySourceArtifactCount: 1,
      readySecuritySourceArtifactCount: 0,
      missingSecuritySourceArtifactCount: 1,
      securityEvidenceFinalizerReady: false,
      securityEvidenceFinalizerInputs: [
        {
          name: 'ImageSigningRunId',
          runIdParameter: 'image_signing_run_id',
          workflow: 'image-publish-sign-ci.yml',
          artifactName: 'osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68',
          artifactNameParameter: 'image_signing_artifact_name',
          runId: '<image-signing-run-id>',
          ready: false,
          sourceArtifactSelected: false,
          sourceArtifactReady: false,
          requiredForSecurityFinalizer: true,
          note: 'Source artifact for security-evidence-finalizer-ci.yml.',
        },
        {
          name: 'ContainerSecurityRunId',
          runIdParameter: 'container_security_run_id',
          workflow: 'container-security-ci.yml',
          artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
          artifactNameParameter: 'container_security_artifact_name',
          runId: '<container-security-run-id>',
          ready: false,
          sourceArtifactSelected: true,
          sourceArtifactReady: false,
          requiredForSecurityFinalizer: true,
          note: 'Source artifact for security-evidence-finalizer-ci.yml.',
        },
      ],
      securityEvidenceFinalizerMissingRunIdInputs: ['ImageSigningRunId', 'ContainerSecurityRunId'],
      securityEvidenceFinalizerCommand: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true',
      operationsArtifactFinalizerCommand: '',
      dataFlowStoragePlanInputNote: '',
      dataFlowQueryRetentionBudgetInputNote: '',
      dataFlowStorageTransitionRunbookInputNote: '',
      minioBucketCorsInputNote: '',
      localImportCommand: '',
      decisionRule: 'Security evidence finalizer is not ready until image signing and container security workflow run ids are collected.',
      artifacts: [
        {
          actionOrder: 6,
          workflow: 'container-security-ci.yml',
          artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
          requiredForReadiness: false,
          ready: false,
          missing: true,
          downloadCommand: 'gh run download <container-security-run-id> -n osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
        },
      ],
    },
    operationsEvidenceHandoff: {
      result: 'action-required',
      generatedAt: '2026-06-30T12:48:10.6661472+09:00',
      nextStep: {
        code: 'dispatch-ready-subset-browser',
        title: 'Open browser dispatch for ready subset',
        command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        reason: 'The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6.',
        note: BROWSER_READY_SUBSET_NOTE,
        dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml'],
      },
      currentBottleneck: {
        code: 'dispatch-ready-subset-browser',
        title: 'Open browser dispatch for ready subset',
        command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        reason: 'The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6.',
        note: BROWSER_READY_SUBSET_NOTE,
        dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml'],
      },
      stageCount: 8,
      readyStageCount: 2,
      readinessSummary: 'passed=82 pending=20',
      readinessPassedCount: 82,
      readinessPendingCount: 20,
      readinessTotalCount: 102,
      readinessCheckCount: 102,
      dispatchPreflightResult: 'action-required',
      dispatchGithubRepository: 'chefbeom/object-storage-osmu',
      readyDispatchTemplateCount: 1,
      blockedDispatchTemplateCount: 0,
      readyDispatchActionOrders: [6],
      blockedDispatchActionOrders: [],
      invocationSelectedActionOrders: [6],
      dispatchPreflightSelectedActionOrders: [6],
      workflowRunIdPlanActionOrders: [6],
      artifactCollectionActionOrders: [6],
      dispatchPreflightScopeMismatch: false,
      workflowRunIdPlanStale: false,
      workflowRunIdPlanScopeMismatch: false,
      workflowRunIdPlanQueryMode: 'github-api',
      workflowRunIdPlanGithubApiTokenPresent: false,
      workflowRunIdPlanGithubApiUnauthenticated: true,
      workflowRunIdPlanQueryExecuted: true,
      workflowRunIdPlanQueryExecutedCount: 1,
      workflowRunIdPlanQueryWorkflowCount: 1,
      workflowRunIdPlanQuerySucceededCount: 1,
      workflowRunIdPlanQueryErrorCount: 0,
      workflowRunIdPlanCandidateCount: 0,
      inputFreeBlockedReviewReportExists: true,
      inputFreeBlockedReviewReportResult: 'blocked',
      inputFreeBlockedReviewReportGeneratedAt: '2026-06-30T12:48:09.0000000+09:00',
      inputFreeBlockedReviewReportSelectedActionCount: 1,
      inputFreeBlockedReviewReportPlannedCount: 0,
      inputFreeBlockedReviewReportBlockedCount: 1,
      inputFreeBlockedReviewReportFailedCount: 0,
      inputFreeBlockedReviewReportExecutedCount: 0,
      inputFreeBlockedReviewReportActionOrders: [6],
      inputFreeBlockedReviewReportStale: false,
      inputFreeBlockedReviewReportScopeMismatch: false,
      artifactCollectionStale: false,
      artifactCollectionScopeMismatch: false,
      staleReportCount: 0,
      readyDispatchWorkflows: [
        {
          actionOrder: 6,
          workflow: 'container-security-ci.yml',
          dispatchUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
        },
      ],
      blockedDispatchWorkflows: [],
      browserDispatchChecklistCount: 1,
      browserDispatchChecklist: [
        {
          actionOrder: 6,
          name: 'Container scan/SBOM evidence',
          category: 'security-hardening',
          actionType: 'security-ci',
          workflow: 'container-security-ci.yml',
          dispatchUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          runsUrl: 'https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml',
          runIdParameter: 'ContainerSecurityRunId',
          artifactName: 'osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68',
          runListJsonPath: '.\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json',
          runListJsonDirectoryCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\.osmu-run\\workflow-run-lists',
          manualArtifactCollectionCommand: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          securityFinalizerRunIdInputs: ['ImageSigningRunId', 'ContainerSecurityRunId'],
          securityFinalizerMissingRunIdInputs: ['ImageSigningRunId', 'ContainerSecurityRunId'],
          securityFinalizerDependencyNote: SECURITY_FINALIZER_DEPENDENCY_NOTE,
          workflowInputNames: [],
          operatorChecklist: [],
          steps: [
            'Open the workflow dispatch URL and select branch main.',
            'No workflow inputs are required for this dispatch template.',
            'Run the workflow and open the workflow run page from the runs URL.',
            'Copy the numeric run id or full workflow run URL into ContainerSecurityRunId.',
            'Regenerate artifact collection with the manual run-id command.',
            SECURITY_FINALIZER_DEPENDENCY_NOTE,
          ],
        },
      ],
      securityEvidenceFinalizerRunIdInputHintCount: 2,
      securityEvidenceFinalizerRunIdInputHints: SECURITY_FINALIZER_RUN_ID_HINTS,
      blockedActionCount: 0,
      missingWorkflowRunCount: 1,
      missingRequiredArtifactCount: 0,
      failedImportCount: 0,
      finalizerFailedCount: 0,
      finalizerGapCount: 0,
      postDispatchCommands: [
        {
          name: 'Collect workflow run ids from saved run-list JSON',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>',
          note: 'Use after browser dispatch when GitHub CLI is unavailable locally. Store gh run list JSON per workflow in the directory, then let the run-id plan derive artifact commands.',
        },
        {
          name: 'Collect workflow run ids with GitHub REST API',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
          note: 'Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values.',
        },
        {
          name: 'Collect workflow run ids with GitHub CLI',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -Execute',
          note: 'Use after browser dispatch when gh is installed and authenticated.',
        },
        {
          name: 'Regenerate artifact collection plan with browser run ids',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          note: 'Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running.',
        },
        {
          name: 'Regenerate artifact collection plan after run id collection',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          note: 'Use after one of the run-id collection commands has produced recommended run ids so artifact names, download commands, and finalizer commands stay in the same selected-action scope.',
        },
      ],
      stages: [
        { name: 'operations-readiness', result: 'pending', ready: false, command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-readiness.ps1', note: 'Production/B2B readiness gate summary.' },
        { name: 'evidence-plan', result: 'action-required', ready: true, command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-evidence-plan.ps1', note: 'Ordered remediation plan.' },
        { name: 'evidence-invocation', result: 'planned', ready: true, command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1', note: 'Guarded workflow/local command invocation report.' },
        { name: 'dispatch-preflight', result: 'action-required', ready: false, command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-dispatch-preflight.ps1 -CheckGitHubCli', note: 'GitHub CLI is unavailable; use browser dispatch for action 6.' },
        { name: 'workflow-run-ids', result: 'query-required', ready: false, command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1', note: 'GitHub workflow run id handoff. Prefer the GitHub REST API command when gh is unavailable; it uses GH_TOKEN or GITHUB_TOKEN only if present and never writes token values. Browser workflow runs URL(s): container-security-ci.yml: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml.' },
        { name: 'artifact-collection', result: 'security-source-action-required', ready: false, command: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true', note: 'Artifact finalizer waits for security source run ids.' },
      ],
    },
    dataFlowStoragePlan: {
      result: 'plan-ready-execute-required',
      recordedAt: '2026-06-21T09:15:00Z',
      environmentName: 'frontend-mock',
      targetCluster: 'mock-analytics',
      operatorName: 'mock-admin',
      evidenceRef: 'mock-data-flow-sizing',
      candidateStore: 'MARIADB_PARTITION',
      expectedPeakEventsPerDay: 250000,
      expectedQueryWindowDays: 180,
      targetP95QueryLatencyMs: 500,
      eventRetentionDays: 90,
      dailyRollupRetentionDays: 730,
      monthlyRollupRetentionMonths: 36,
      checkCount: 3,
      passedCount: 1,
      pendingCount: 2,
      checks: [
        {
          id: 'aggregate_no_object_keys',
          title: 'Aggregate stores exclude object keys and raw event messages',
          status: 'passed',
          detail: 'Monthly/materialized aggregate scope stays bucket/source/operation/status/time only.',
          nextAction: '',
        },
        {
          id: 'explain_or_store_evidence',
          title: 'Query plan or target-store evidence exists',
          status: 'pending',
          detail: 'MariaDB partition path needs EXPLAIN evidence.',
          nextAction: 'Attach EXPLAIN evidence before enabling partitioned/time-series storage.',
        },
        {
          id: 'mariadb_query_plan_evidence',
          title: 'MariaDB query plan evidence passed',
          status: 'pending',
          detail: 'No MariaDB query plan evidence JSON supplied.',
          nextAction: 'Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan.',
        },
      ],
      queryPlanEvidence: {
        provided: false,
        path: '',
        parsed: false,
        formatVersion: '',
        expectedFormatVersion: 'osmu.mariadb-query-plan-evidence.v1',
        validFormatVersion: false,
        result: '',
        mode: '',
        checkCount: 0,
        passedCount: 0,
        failedCount: 0,
        failedChecks: [],
        detail: 'No MariaDB query plan evidence JSON supplied.',
      },
      scopePolicy: 'OSMU operations analytics only. This mock plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages.',
    },
    storageBackendTelemetryEvidence: {
      result: 'passed',
      generatedAt: '2026-06-21T08:03:05Z',
      environmentName: 'frontend-mock',
      targetCluster: 'mock-minio',
      operatorName: 'mock-admin',
      sourceMode: 'admin-info-json-path',
      minioAlias: 'osmu-minio',
      evidenceRef: 'mock-mc-admin-info',
      adminInfoJsonSha256: 'mocksha256',
      rawAdminInfoStored: false,
      poolCount: 1,
      serverCount: 2,
      onlineServerCount: 2,
      offlineServerCount: 0,
      driveCount: 4,
      totalBytes: 4398046511104,
      usedBytes: 927712935936,
      freeBytes: 3470333575168,
      capacityKnown: true,
      failureCount: 0,
      plannedCount: 0,
      decisionRule: 'Storage backend telemetry evidence passes when target MinIO pool/node summaries are present.',
      scopePolicy: 'This mock storage telemetry summary excludes raw admin output and credentials.',
    },
    operationsReadinessConvergence: {
      result: 'action-required',
      generatedAt: '2026-06-30T12:48:11.1058503+09:00',
      handoffReportPath: '.osmu-run/latest-operations-evidence-handoff.json',
      readinessReportPath: '.osmu-run/latest-operations-readiness.json',
      operationsReadinessFinalizeReportPath: '.osmu-run/latest-operations-readiness-finalize.json',
      handoffExists: true,
      handoffResult: 'action-required',
      readinessExists: true,
      readinessResult: 'pending',
      readinessSummary: 'passed=82 pending=20',
      readinessPassedCount: 82,
      readinessPendingCount: 20,
      readinessTotalCount: 102,
      readinessCheckCount: 102,
      finalizerExists: false,
      finalizerResult: '',
      finalizerReadinessResult: '',
      finalizerFailedCount: 0,
      finalizerGapCount: 0,
      stageCount: 8,
      readyStageCount: 2,
      blockedActionCount: 0,
      handoffWorkflowRunIdPlanQueryMode: 'github-api',
      handoffWorkflowRunIdPlanGithubApiTokenPresent: false,
      handoffWorkflowRunIdPlanGithubApiUnauthenticated: true,
      handoffWorkflowRunIdPlanQueryExecuted: true,
      handoffWorkflowRunIdPlanQueryExecutedCount: 1,
      handoffWorkflowRunIdPlanQueryWorkflowCount: 1,
      handoffWorkflowRunIdPlanQuerySucceededCount: 1,
      handoffWorkflowRunIdPlanQueryErrorCount: 0,
      handoffWorkflowRunIdPlanCandidateCount: 0,
      handoffInputFreeBlockedReviewReportExists: true,
      handoffInputFreeBlockedReviewReportResult: 'blocked',
      handoffInputFreeBlockedReviewReportGeneratedAt: '2026-06-30T12:48:09.0000000+09:00',
      handoffInputFreeBlockedReviewReportSelectedActionCount: 1,
      handoffInputFreeBlockedReviewReportPlannedCount: 0,
      handoffInputFreeBlockedReviewReportBlockedCount: 1,
      handoffInputFreeBlockedReviewReportFailedCount: 0,
      handoffInputFreeBlockedReviewReportExecutedCount: 0,
      handoffInputFreeBlockedReviewReportActionOrders: [6],
      handoffInputFreeBlockedReviewReportStale: false,
      handoffInputFreeBlockedReviewReportScopeMismatch: false,
      missingWorkflowRunCount: 1,
      missingRequiredArtifactCount: 0,
      failedImportCount: 0,
      currentBottleneck: {
        code: 'dispatch-ready-subset-browser',
        title: 'Open browser dispatch for ready subset',
        reason: 'The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6.',
        command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
        note: BROWSER_READY_SUBSET_CONVERGENCE_NOTE,
        dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml'],
      },
      handoffBrowserDispatchDependencyNotes: [SECURITY_FINALIZER_DEPENDENCY_NOTE],
      handoffSecurityEvidenceFinalizerRunIdInputHintCount: 2,
      handoffSecurityEvidenceFinalizerRunIdInputHints: SECURITY_FINALIZER_RUN_ID_HINTS,

      handoffPostDispatchCommands: [
        {
          name: 'Collect workflow run ids from saved run-list JSON',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>',
          note: 'Use after browser dispatch when GitHub CLI is unavailable locally. Store gh run list JSON per workflow in the directory, then let the run-id plan derive artifact commands.',
        },
        {
          name: 'Collect workflow run ids with GitHub REST API',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
          note: 'Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values.',
        },
        {
          name: 'Collect workflow run ids with GitHub CLI',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -Execute',
          note: 'Use after browser dispatch when gh is installed and authenticated.',
        },
        {
          name: 'Regenerate artifact collection plan with browser run ids',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          note: 'Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running.',
        },
        {
          name: 'Regenerate artifact collection plan after run id collection',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68',
          note: 'Use after one of the run-id collection commands has produced recommended run ids so artifact names, download commands, and finalizer commands stay in the same selected-action scope.',
        },
      ],
      recommendedCommands: [
        {
          order: 1,
          name: 'Open browser dispatch for ready subset',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6',
          reason: 'The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6.',
          note: BROWSER_READY_SUBSET_CONVERGENCE_NOTE,
          dispatchUrls: ['https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml'],
        },
        {
          order: 2,
          name: 'Review workflow-run-ids',
          command: 'powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1',
          reason: 'GitHub workflow run id handoff. Prefer the GitHub REST API command when gh is unavailable; browser workflow runs URL(s): container-security-ci.yml: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml.',
          note: '',
        },
        {
          order: 3,
          name: 'Review artifact-collection',
          command: 'gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true',
          reason: 'Run the security evidence finalizer once source run ids and artifacts exist.',
          note: '',
        },
      ],
      handoffStale: false,
      handoffTimestamp: '2026-06-30T12:48:10.6661472+09:00',
      handoffTimestampSource: 'generatedAt',
      readinessTimestamp: '2026-06-30T12:48:07.4142068+09:00',
      readinessTimestampSource: 'generatedAt',
      kubernetesOperationsReportSyncReportPath: '.osmu-run/latest-kubernetes-operations-report-sync.json',
      kubernetesReportSyncExists: true,
      kubernetesReportSyncResult: 'planned',
      kubernetesReportSyncStale: false,
      kubernetesReportSyncTimestamp: '2026-06-16T09:33:30.1080022+09:00',
      kubernetesReportSyncTimestampSource: 'generatedAt',
      kubernetesReportSyncFreshnessReason: 'Kubernetes operations report sync evidence is older than the latest handoff/readiness/finalizer input.',
      kubernetesReportSyncFailedCount: 0,
      kubernetesReportSyncFailedCountValid: true,
      kubernetesReportSyncFailedCountRaw: '0',
      kubernetesReportSyncConfigMapName: 'osmu-operations-reports',
      kubernetesReportSyncConfigMapKey: 'latest-operations-readiness-convergence.json',
      kubernetesReportSyncSourceReportResult: 'action-required',
      kubernetesReportSyncWorkflowCommand: 'gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=osmu -f report_path=.osmu-run/latest-operations-readiness-convergence.json -f run_live=true -f apply=false -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json> -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>',
      kubernetesReportSyncWorkflowNote: 'Latest plan-mode sync evidence is fresh against the convergence report; production readiness still requires applied target Kubernetes operations report sync evidence. Include optional data_flow_storage_plan_json_base64, data_flow_query_retention_budget_json_base64, and data_flow_storage_transition_runbook_json_base64 only for passed sanitized target data-flow evidence.',
      kubernetesReportSyncReady: false,
      decisionRule: 'Operations readiness convergence is ready only when handoff, readiness finalizer, workflow artifacts, and Kubernetes report sync are all current and ready.',
      safetyPolicy: 'This mock report does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only mirrors the current local evidence chain.',
    },    generatedAt: new Date().toISOString(),
  }
}

function storageExpansionSummary() {
  const requests = state.storageExpansionRequests
  const executions = state.storageExpansionExecutions
  const openRequests = requests.filter((request) => ['PLANNED', 'APPROVED'].includes(request.status))
  return {
    requestCount: requests.length,
    openRequestCount: openRequests.length,
    plannedRequestCount: requests.filter((request) => request.status === 'PLANNED').length,
    approvedRequestCount: requests.filter((request) => request.status === 'APPROVED').length,
    appliedRequestCount: requests.filter((request) => request.status === 'APPLIED').length,
    rejectedRequestCount: requests.filter((request) => request.status === 'REJECTED').length,
    totalRequestedCapacityBytes: requests.reduce((sum, request) => sum + Number(request.requestedCapacityBytes || 0), 0),
    openRequestedCapacityBytes: openRequests.reduce((sum, request) => sum + Number(request.requestedCapacityBytes || 0), 0),
    totalEstimatedUsableCapacityBytes: requests.reduce((sum, request) => sum + Number(request.estimatedUsableCapacityBytes || 0), 0),
    openEstimatedUsableCapacityBytes: openRequests.reduce((sum, request) => sum + Number(request.estimatedUsableCapacityBytes || 0), 0),
    executionCount: executions.length,
    successExecutionCount: executions.filter((execution) => execution.result === 'SUCCESS').length,
    failedExecutionCount: executions.filter((execution) => execution.result === 'FAILED').length,
    skippedExecutionCount: executions.filter((execution) => execution.result === 'SKIPPED').length,
    timedOutExecutionCount: executions.filter((execution) => execution.result === 'TIMED_OUT').length,
    recentExecutions: executions.slice(0, 5),
  }
}

function findStorageExpansionRequest(id) {
  return state.storageExpansionRequests.find((request) => request.id === id)
}

function storageExpansionRequestRecord(payload = {}, requestedBy = 'admin') {
  const id = state.storageExpansionRequestSequence++
  const now = new Date().toISOString()
  const serverCount = Math.max(4, Number(payload.serverCount || 4))
  const volumesPerServer = Math.max(1, Number(payload.volumesPerServer || 1))
  const requestedCapacityBytes = Math.max(BYTES_PER_GIB, Number(payload.requestedCapacityBytes || BYTES_PER_GIB))
  const volumeSizeBytes = Math.max(BYTES_PER_GIB, Math.ceil(requestedCapacityBytes / (serverCount * volumesPerServer)))
  const estimatedRawCapacityBytes = serverCount * volumesPerServer * volumeSizeBytes
  const estimatedUsableCapacityBytes = Math.floor(estimatedRawCapacityBytes * 0.75)
  return {
    id,
    poolName: `pool-${id}`,
    status: 'PLANNED',
    requestedCapacityBytes,
    estimatedRawCapacityBytes,
    estimatedUsableCapacityBytes,
    serverCount,
    volumesPerServer,
    volumeSizeBytes,
    reason: payload.reason || '',
    requestedBy,
    requestedAt: now,
    createdAt: now,
    updatedAt: now,
    approvedBy: '',
    approvedAt: '',
    appliedBy: '',
    appliedAt: '',
    appliedEvidence: '',
  }
}

function storageExpansionManifest(requestRecord) {
  return {
    requestId: requestRecord.id,
    poolName: requestRecord.poolName,
    status: requestRecord.status,
    artifactSha256: `mock-${requestRecord.poolName}-manifest-sha256`,
    tenantPatchYaml: `apiVersion: minio.min.io/v2\nkind: Tenant\nmetadata:\n  name: osmu-minio\nspec:\n  pools:\n  - name: ${requestRecord.poolName}\n    servers: ${requestRecord.serverCount}\n    volumesPerServer: ${requestRecord.volumesPerServer}\n`,
    helmValuesPatchYaml: `tenant:\n  pools:\n    - name: ${requestRecord.poolName}\n      servers: ${requestRecord.serverCount}\n      volumesPerServer: ${requestRecord.volumesPerServer}\n`,
    warnings: [],
  }
}

function storageExpansionExecutionPlan(requestRecord) {
  return {
    requestId: requestRecord.id,
    poolName: requestRecord.poolName,
    status: requestRecord.status,
    artifactSha256: `mock-${requestRecord.poolName}-dry-run-sha256`,
    evidenceTemplate: `mock dry-run evidence for ${requestRecord.poolName}`,
    preflightChecks: ['mock manifest generated', 'mock dry-run commands prepared'],
    suggestedCommands: [
      `kubectl -n osmu diff -f osmu-storage-expansion-${requestRecord.poolName}-bundle.yaml`,
      `helm upgrade osmu-minio ./infra/helm/osmu -f osmu-storage-expansion-${requestRecord.poolName}-bundle.yaml --dry-run`,
    ],
  }
}

function updateStorageExpansionStatusRecord(requestRecord, status, appliedEvidence = '') {
  const now = new Date().toISOString()
  requestRecord.status = status
  requestRecord.updatedAt = now
  if (status === 'APPROVED') {
    requestRecord.approvedBy = 'admin'
    requestRecord.approvedAt = now
  }
  if (status === 'APPLIED') {
    requestRecord.appliedBy = 'admin'
    requestRecord.appliedAt = now
    requestRecord.appliedEvidence = appliedEvidence || `mock apply evidence for ${requestRecord.poolName}`
  }
  if (status === 'REJECTED') {
    requestRecord.rejectedBy = 'admin'
    requestRecord.rejectedAt = now
  }
  return requestRecord
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

function countLifecycleRules(xml = '') {
  return (String(xml).match(/<Rule(?:\s|>)/g) || []).length
}

function objectsFor(bucketName) {
  if (!state.objects.has(bucketName)) {
    state.objects.set(bucketName, [])
  }
  return state.objects.get(bucketName)
}

function listObjectsForMock(bucketName, { prefix = '', delimiter = '', search = '', tagFilter = {} } = {}) {
  const prefixes = new Set()
  const items = []
  for (const item of objectsFor(bucketName)) {
    if (prefix && !item.key.startsWith(prefix)) {
      continue
    }
    const remainder = prefix ? item.key.slice(prefix.length) : item.key
    if (delimiter && remainder.includes(delimiter)) {
      const nextPrefix = `${prefix}${remainder.slice(0, remainder.indexOf(delimiter) + 1)}`
      prefixes.add(nextPrefix)
      continue
    }
    if (search && !item.key.includes(search)) {
      continue
    }
    if (!objectMatchesTagFilter(item, tagFilter)) {
      continue
    }
    items.push(item)
  }
  return { items, prefixes: Array.from(prefixes).sort() }
}

function objectMatchesTagFilter(item, tagFilter = {}) {
  return Object.entries(tagFilter).every(([key, value]) => String(item.tags?.[key] || '') === String(value))
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

function filteredAuditLogs(url) {
  const filters = {
    eventType: url.searchParams.get('eventType') || '',
    actorId: url.searchParams.get('actorId') || '',
    requestId: url.searchParams.get('requestId') || '',
    targetType: url.searchParams.get('targetType') || '',
    targetId: url.searchParams.get('targetId') || '',
    result: url.searchParams.get('result') || '',
  }
  return state.auditLogs.filter((entry) => Object.entries(filters).every(([key, value]) => {
    if (!value) return true
    return String(entry[key] || '').toUpperCase().includes(String(value).toUpperCase())
  }))
}

function pagedAuditLogs(url) {
  const items = filteredAuditLogs(url)
  const limit = Math.max(1, Math.min(500, Number(url.searchParams.get('limit') || 50)))
  const cursor = Math.max(0, Number(url.searchParams.get('cursor') || 0))
  const page = items.slice(cursor, cursor + limit)
  const nextCursor = cursor + limit < items.length ? String(cursor + limit) : ''
  return { items: page, nextCursor }
}

function auditLogsCsv(url) {
  const rows = filteredAuditLogs(url)
  const header = '"eventType","actorId","targetType","targetId","result","requestId","createdAt"'
  const lines = rows.map((entry) => [
    entry.eventType,
    entry.actorId,
    entry.targetType,
    entry.targetId,
    entry.result,
    entry.requestId,
    entry.createdAt,
  ].map((value) => `"${String(value || '').replaceAll('"', '""')}"`).join(','))
  return [header, ...lines].join('\n')
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
    if (readiness.data.operationsReadinessSummary?.pendingCount !== 20 || readiness.data.operationsReadinessSummary?.totalCount !== 102) {
      throw new Error('readiness source summary self-test failed')
    }
    if (readiness.data.operationsReadinessSummary?.pendingRemediationCount !== 20 || !readiness.data.operationsReadinessSummary?.pendingRemediations?.[0]?.workflowCommand?.includes('container-security-ci.yml')) {
      throw new Error('readiness source remediation summary self-test failed')
    }
    if (readiness.data.operationsEvidenceInvocation?.selectedActionOrders?.[0] !== 6) {
      throw new Error('readiness invocation selected-action self-test failed')
    }
    if (readiness.data.operationsEvidencePlan?.actions?.[0]?.currentDetail !== 'report not found') {
      throw new Error('readiness evidence plan current-detail self-test failed')
    }
    if (!readiness.data.operationsEvidencePlan?.actions?.[0]?.recommendedCommand?.includes('container-security-ci.yml')) {
      throw new Error('readiness evidence plan recommended-command self-test failed')
    }
    if (readiness.data.operationsEvidencePlan?.sourcePendingRemediationCoverageReady !== true || readiness.data.operationsEvidencePlan?.sourcePendingRemediationActionCount !== 20) {
      throw new Error('readiness evidence plan remediation coverage self-test failed')
    }
    if (readiness.data.operationsDispatchPreflight?.readyActionOrders?.[0] !== 6) {
      throw new Error('readiness dispatch preflight selected-action self-test failed')
    }
    if (readiness.data.operationsDispatchPreflight?.githubRef !== 'main' || !readiness.data.operationsDispatchPreflight?.readySubsetApiExecuteCommand?.includes('-UseGitHubApi')) {
      throw new Error('readiness dispatch preflight GitHub API dispatch self-test failed')
    }
    if (readiness.data.operationsDispatchPreflight?.gitRefSafety?.status !== 'action-required' || readiness.data.operationsDispatchPreflight?.gitRefSafety?.workingTreeDirty !== true || readiness.data.operationsDispatchPreflight?.gitRefSafety?.suggestedPushCommand) {
      throw new Error('readiness dispatch preflight Git ref safety self-test failed')
    }
    if (!readiness.data.operationsWorkflowRunIdPlan?.runListJsonDirectoryCommand?.includes('-RunListJsonDirectory') || !readiness.data.operationsWorkflowRunIdPlan?.workflows?.[0]?.runListJsonPath?.endsWith('container-security-ci.yml.json')) {
      throw new Error('readiness workflow run-id saved JSON handoff self-test failed')
    }
    if (!readiness.data.operationsWorkflowRunIdPlan?.browserWorkflowRunsUrls?.[0]?.includes('container-security-ci.yml') || !readiness.data.operationsWorkflowRunIdPlan?.browserWorkflowRunsUrls?.some((url) => url.includes('image-publish-sign-ci.yml')) || readiness.data.operationsWorkflowRunIdPlan?.workflowRunIdInputs?.[0]?.runIdParameter !== 'ContainerSecurityRunId' || !readiness.data.operationsWorkflowRunIdPlan?.workflowRunIdInputs?.[0]?.queryCommand?.includes('gh run list') || !readiness.data.operationsWorkflowRunIdPlan?.recommendedCommands?.[0]?.command?.includes('-RunListJsonDirectory') || !readiness.data.operationsWorkflowRunIdPlan?.githubApiRunListCommand?.includes('-UseGitHubApi') || !readiness.data.operationsWorkflowRunIdPlan?.recommendedCommands?.[1]?.command?.includes('-UseGitHubApi')) {
      throw new Error('readiness workflow run-id top-level handoff self-test failed')
    }
    const workflowRunIdHints = readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerRunIdInputHints || []
    const imageSigningRunIdHint = workflowRunIdHints.find((hint) => hint.runIdParameter === 'ImageSigningRunId')
    const containerSecurityRunIdHint = workflowRunIdHints.find((hint) => hint.runIdParameter === 'ContainerSecurityRunId')
    if (readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerReady !== false || !readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerRunIdInputs?.includes('ImageSigningRunId') || !readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerRunIdInputs?.includes('ContainerSecurityRunId') || workflowRunIdHints.length !== 2 || imageSigningRunIdHint?.workflow !== 'image-publish-sign-ci.yml' || imageSigningRunIdHint?.sourceSelected !== false || imageSigningRunIdHint?.supplementalForSecurityFinalizer !== true || containerSecurityRunIdHint?.sourceSelected !== true || containerSecurityRunIdHint?.supplementalForSecurityFinalizer !== false || !readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerMissingRunIdInputs?.includes('ImageSigningRunId') || !readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerMissingRunIdInputs?.includes('ContainerSecurityRunId') || !readiness.data.operationsWorkflowRunIdPlan?.securityEvidenceFinalizerDependencyNote?.includes('ImageSigningRunId') || !readiness.data.operationsWorkflowRunIdPlan?.recommendedCommands?.[3]?.command?.includes('-ImageSigningRunId <ImageSigningRunId>') || !readiness.data.operationsWorkflowRunIdPlan?.recommendedCommands?.[3]?.note?.includes('ImageSigningRunId') || !readiness.data.operationsWorkflowRunIdPlan?.recommendedCommands?.[5]?.note?.includes('Missing run id inputs')) {
      throw new Error('readiness workflow run-id security finalizer self-test failed')
    }
    if (readiness.data.operationsEvidenceHandoff?.currentBottleneck?.code !== 'dispatch-ready-subset-browser') {
      throw new Error('readiness handoff bottleneck self-test failed')
    }
    if (readiness.data.operationsEvidenceHandoff?.browserDispatchChecklistCount !== 1 || readiness.data.operationsEvidenceHandoff?.browserDispatchChecklist?.[0]?.runIdParameter !== 'ContainerSecurityRunId' || !readiness.data.operationsEvidenceHandoff?.browserDispatchChecklist?.[0]?.dispatchUrl?.includes('container-security-ci.yml') || !readiness.data.operationsEvidenceHandoff?.browserDispatchChecklist?.[0]?.securityFinalizerDependencyNote?.includes('ImageSigningRunId') || !readiness.data.operationsEvidenceHandoff?.browserDispatchChecklist?.[0]?.securityFinalizerMissingRunIdInputs?.includes('ContainerSecurityRunId')) {
      throw new Error('readiness handoff browser dispatch checklist self-test failed')
    }
    const handoffRunIdHints = readiness.data.operationsEvidenceHandoff?.securityEvidenceFinalizerRunIdInputHints || []
    const handoffImageSigningRunIdHint = handoffRunIdHints.find((hint) => hint.runIdParameter === 'ImageSigningRunId')
    const handoffContainerSecurityRunIdHint = handoffRunIdHints.find((hint) => hint.runIdParameter === 'ContainerSecurityRunId')
    if (readiness.data.operationsEvidenceHandoff?.securityEvidenceFinalizerRunIdInputHintCount !== 2 || handoffRunIdHints.length !== 2 || handoffImageSigningRunIdHint?.workflow !== 'image-publish-sign-ci.yml' || handoffImageSigningRunIdHint?.supplementalForSecurityFinalizer !== true || handoffContainerSecurityRunIdHint?.sourceSelected !== true) {
      throw new Error('readiness handoff security finalizer run-id hint self-test failed')
    }
    if (readiness.data.operationsEvidenceHandoff?.postDispatchCommands?.length !== 5 || !readiness.data.operationsEvidenceHandoff.postDispatchCommands[0].command.includes('-RunListJsonDirectory') || !readiness.data.operationsEvidenceHandoff.postDispatchCommands[1].command.includes('-UseGitHubApi') || !readiness.data.operationsEvidenceHandoff.postDispatchCommands[3].command.includes('-ContainerSecurityRunId <ContainerSecurityRunId>') || !readiness.data.operationsEvidenceHandoff.postDispatchCommands[4].command.includes('write-operations-artifact-collection-plan.ps1')) {
      throw new Error('readiness handoff post-dispatch command self-test failed')
    }
    const securityFinalizerInputs = readiness.data.operationsArtifactCollectionPlan?.securityEvidenceFinalizerInputs || []
    const imageSigningInput = securityFinalizerInputs.find((input) => input.name === 'ImageSigningRunId')
    const containerSecurityInput = securityFinalizerInputs.find((input) => input.name === 'ContainerSecurityRunId')
    if (readiness.data.operationsArtifactCollectionPlan?.result !== 'security-source-action-required' || !readiness.data.operationsArtifactCollectionPlan?.securityEvidenceFinalizerMissingRunIdInputs?.includes('ImageSigningRunId') || !readiness.data.operationsArtifactCollectionPlan?.securityEvidenceFinalizerMissingRunIdInputs?.includes('ContainerSecurityRunId') || securityFinalizerInputs.length !== 2 || imageSigningInput?.runIdParameter !== 'image_signing_run_id' || imageSigningInput?.sourceArtifactSelected !== false || containerSecurityInput?.runIdParameter !== 'container_security_run_id' || containerSecurityInput?.sourceArtifactSelected !== true || containerSecurityInput?.ready !== false) {
      throw new Error('readiness artifact collection security finalizer input self-test failed')
    }
    if (!readiness.data.operationsReadinessConvergence?.recommendedCommands?.[1]?.command?.includes('-UseGitHubApi')) {
      throw new Error('readiness convergence workflow run-id GitHub API command self-test failed')
    }
    if (readiness.data.operationsReadinessConvergence?.currentBottleneck?.code !== 'dispatch-ready-subset-browser' || !readiness.data.operationsReadinessConvergence?.currentBottleneck?.note?.includes('ImageSigningRunId') || !readiness.data.operationsReadinessConvergence?.handoffBrowserDispatchDependencyNotes?.[0]?.includes('security-evidence-finalizer-ci.yml')) {
      throw new Error('readiness convergence self-test failed')
    }
    const convergenceRunIdHints = readiness.data.operationsReadinessConvergence?.handoffSecurityEvidenceFinalizerRunIdInputHints || []
    const convergenceImageSigningRunIdHint = convergenceRunIdHints.find((hint) => hint.runIdParameter === 'ImageSigningRunId')
    const convergenceContainerSecurityRunIdHint = convergenceRunIdHints.find((hint) => hint.runIdParameter === 'ContainerSecurityRunId')
    if (readiness.data.operationsReadinessConvergence?.handoffSecurityEvidenceFinalizerRunIdInputHintCount !== 2 || convergenceRunIdHints.length !== 2 || convergenceImageSigningRunIdHint?.supplementalForSecurityFinalizer !== true || convergenceContainerSecurityRunIdHint?.sourceSelected !== true) {
      throw new Error('readiness convergence security finalizer run-id hint self-test failed')
    }
    if (!readiness.data.operationsReadinessConvergence?.currentBottleneck?.dispatchUrls?.[0]?.includes('container-security-ci.yml')) {
      throw new Error('readiness convergence bottleneck dispatch URL self-test failed')
    }
    if (readiness.data.operationsReadinessConvergence?.handoffPostDispatchCommands?.length !== 5 || !readiness.data.operationsReadinessConvergence.handoffPostDispatchCommands[0].command.includes('-RunListJsonDirectory') || !readiness.data.operationsReadinessConvergence.handoffPostDispatchCommands[1].command.includes('-UseGitHubApi') || !readiness.data.operationsReadinessConvergence.handoffPostDispatchCommands[3].command.includes('-ContainerSecurityRunId <ContainerSecurityRunId>') || !readiness.data.operationsReadinessConvergence.handoffPostDispatchCommands[4].command.includes('write-operations-artifact-collection-plan.ps1')) {
      throw new Error('readiness convergence post-dispatch command self-test failed')
    }
    if (!readiness.data.items.some((item) => item.code === 'OPERATIONS_READINESS_CONVERGENCE')) {
      throw new Error('readiness convergence item self-test failed')
    }
    if (!readiness.data.items.some((item) => item.code === 'OPERATIONS_EVIDENCE_HANDOFF')) {
      throw new Error('readiness handoff item self-test failed')
    }
    if (readiness.data.warningCount !== readiness.data.warnings.length) {
      throw new Error('readiness warning count self-test failed')
    }
    if (readiness.data.dataFlowStoragePlan?.result !== 'plan-ready-execute-required') {
      throw new Error('readiness data-flow storage plan self-test failed')
    }
    if (!readiness.data.items.some((item) => item.code === 'DATA_FLOW_STORAGE_PLAN')) {
      throw new Error('readiness data-flow storage plan item self-test failed')
    }
    const storageBackendStatus = await (await fetch(`${base}/admin/storage/backend-status`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (storageBackendStatus.data?.capacitySource !== 'bucket_metadata_usage' || storageBackendStatus.data?.directStorageMetricsStatus !== 'DISABLED') {
      throw new Error('storage backend status self-test failed')
    }
    const createdStorageExpansion = await (await fetch(`${base}/admin/storage-expansion/requests`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ requestedCapacityBytes: 2 * BYTES_PER_GIB, serverCount: 4, volumesPerServer: 1, reason: 'self-test expansion' }),
    })).json()
    if (createdStorageExpansion.data?.status !== 'PLANNED' || !createdStorageExpansion.data?.poolName) {
      throw new Error('storage expansion create self-test failed')
    }
    const listedStorageExpansion = await (await fetch(`${base}/admin/storage-expansion/requests`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!listedStorageExpansion.items?.some((item) => item.id === createdStorageExpansion.data.id && item.reason === 'self-test expansion')) {
      throw new Error('storage expansion list self-test failed')
    }
    const approvedStorageExpansion = await (await fetch(`${base}/admin/storage-expansion/requests/${createdStorageExpansion.data.id}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ status: 'APPROVED' }),
    })).json()
    if (approvedStorageExpansion.data?.status !== 'APPROVED') {
      throw new Error('storage expansion approval self-test failed')
    }
    const storageExpansionPlan = await (await fetch(`${base}/admin/storage-expansion/requests/${createdStorageExpansion.data.id}/execution-plan`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!storageExpansionPlan.data?.suggestedCommands?.[0]?.includes('kubectl') || !storageExpansionPlan.data?.evidenceTemplate?.includes(createdStorageExpansion.data.poolName)) {
      throw new Error('storage expansion execution plan self-test failed')
    }
    const appliedStorageExpansion = await (await fetch(`${base}/admin/storage-expansion/requests/${createdStorageExpansion.data.id}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.data.accessToken}` },
      body: JSON.stringify({ status: 'APPLIED', appliedEvidence: 'self-test apply evidence' }),
    })).json()
    if (appliedStorageExpansion.data?.status !== 'APPLIED' || appliedStorageExpansion.data?.appliedEvidence !== 'self-test apply evidence') {
      throw new Error('storage expansion apply self-test failed')
    }
    const storageExpansionSummaryResult = await (await fetch(`${base}/admin/storage-expansion/summary`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (storageExpansionSummaryResult.data?.requestCount !== 1 || storageExpansionSummaryResult.data?.appliedRequestCount !== 1 || storageExpansionSummaryResult.data?.openRequestCount !== 0) {
      throw new Error('storage expansion summary self-test failed')
    }    const dataFlowMonthlyRollup = await (await fetch(`${base}/admin/monitoring/data-flow/monthly-rollup?months=12&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!dataFlowMonthlyRollup.data || dataFlowMonthlyRollup.data.granularity !== 'UTC_MONTH' || !Array.isArray(dataFlowMonthlyRollup.data.points)) {
      throw new Error('data flow monthly rollup self-test failed')
    }
    const dataFlowMonthlyRollupCsv = await (await fetch(`${base}/admin/monitoring/data-flow/monthly-rollup/export.csv?months=12&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).text()
    if (!dataFlowMonthlyRollupCsv.includes('"month","bucketName","source","operation"')) {
      throw new Error('data flow monthly rollup CSV self-test failed')
    }
    const dataFlowDailyMaterialize = await (await fetch(`${base}/admin/monitoring/data-flow/daily-rollup/materialize?days=30&limit=200`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (dataFlowDailyMaterialize.data?.mode !== 'DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION') {
      throw new Error('data flow daily materialization self-test failed')
    }
    const dataFlowMonthlyMaterialize = await (await fetch(`${base}/admin/monitoring/data-flow/monthly-rollup/materialize?months=12&limit=200`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (dataFlowMonthlyMaterialize.data?.mode !== 'DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZATION') {
      throw new Error('data flow monthly materialization self-test failed')
    }
    const dataFlowStoredMonthlyRollup = await (await fetch(`${base}/admin/monitoring/data-flow/monthly-rollup/materialized?months=12&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (dataFlowStoredMonthlyRollup.data?.mode !== 'DATA_FLOW_MONTHLY_ROLLUP_STORED' || !Array.isArray(dataFlowStoredMonthlyRollup.data.points)) {
      throw new Error('stored data flow monthly rollup self-test failed')
    }
    const dataFlowStoredMonthlyRollupCsv = await (await fetch(`${base}/admin/monitoring/data-flow/monthly-rollup/materialized/export.csv?months=12&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).text()
    if (!dataFlowStoredMonthlyRollupCsv.includes('"month","bucketName","source","operation"')) {
      throw new Error('stored data flow monthly rollup CSV self-test failed')
    }
    const dataFlowRetentionStatus = await (await fetch(`${base}/admin/monitoring/data-flow/retention/status`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (dataFlowRetentionStatus.data?.monthlyRollupRetention?.retentionDays !== 1825) {
      throw new Error('data flow retention status self-test failed')
    }
    const dataFlowStorageStatus = await (await fetch(`${base}/admin/monitoring/data-flow/storage-status`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (dataFlowStorageStatus.data?.mode !== 'DATA_FLOW_STORAGE_STATUS' || dataFlowStorageStatus.data?.partitionedOrTimeSeriesStoreEnabled !== false) {
      throw new Error('data flow storage status self-test failed')
    }
    const dataFlowRetentionRun = await (await fetch(`${base}/admin/monitoring/data-flow/retention/run?includeEvents=true&includeDailyRollups=true&includeMonthlyRollups=true`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (typeof dataFlowRetentionRun.data?.deletedMonthlyRollupCount !== 'number') {
      throw new Error('data flow retention run self-test failed')
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
    const priceListPricingPolicyProposal = await (await fetch(`${base}/admin/billing/pricing-policy-proposals/${listedPricingPolicyProposals.data.proposals[0].id}/commercial-approval?approvalReference=LEGAL-2026-0001&approvalNote=self-test&effectiveFrom=2026-06-20T00:00:00Z`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!priceListPricingPolicyProposal.data || priceListPricingPolicyProposal.data.status !== 'PRICE_LIST_APPROVED' || priceListPricingPolicyProposal.data.approvedPriceList !== true || priceListPricingPolicyProposal.data.proposal?.commercialApprovalReference !== 'LEGAL-2026-0001') {
      throw new Error('billing pricing policy proposal price-list approval self-test failed')
    }
    const listedPriceListPricingPolicyProposals = await (await fetch(`${base}/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED&limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!listedPriceListPricingPolicyProposals.data || listedPriceListPricingPolicyProposals.data.proposalCount < 1 || listedPriceListPricingPolicyProposals.data.proposals?.[0]?.approvedPriceList !== true) {
      throw new Error('billing pricing policy proposal price-list list self-test failed')
    }
    const chargeback = await (await fetch(`${base}/admin/billing/chargeback-preview?storageGbMonthRate=0.02&egressGbRate=0.01&operationThousandRate=0.004`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargeback.data || chargeback.data.currency !== 'KRW' || chargeback.data.eventScanLimit !== 2500 || chargeback.data.organizationCount < 1 || !chargeback.data.organizations?.length) {
      throw new Error('chargeback preview self-test failed')
    }
    const chargebackDailyRollup = await (await fetch(`${base}/admin/billing/chargeback-daily-rollup?storageGbMonthRate=0.02&egressGbRate=0.01&operationThousandRate=0.004&days=30&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!chargebackDailyRollup.data || chargebackDailyRollup.data.mode !== 'CHARGEBACK_DAILY_ROLLUP' || chargebackDailyRollup.data.rollupSource !== 'DATA_FLOW_DAILY_ROLLUP' || chargebackDailyRollup.data.pointCount < 1 || !chargebackDailyRollup.data.points?.length) {
      throw new Error('chargeback daily rollup self-test failed')
    }
    const chargebackDailyRollupCsv = await (await fetch(`${base}/admin/billing/chargeback-daily-rollup/export.csv?storageGbMonthRate=0.02&egressGbRate=0.01&operationThousandRate=0.004&days=30&limit=200`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).text()
    if (!chargebackDailyRollupCsv.includes('DAILY_ORGANIZATION') || !chargebackDailyRollupCsv.includes('Mock Organization')) {
      throw new Error('chargeback daily rollup CSV self-test failed')
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
    const notificationAdapterSend = await (await fetch(`${base}/admin/billing/chargeback-alert-notifications/outbox/${chargebackNotificationOutbox.data.deliveries[0].id}/adapter-send?retryDelayMinutes=30`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!notificationAdapterSend.data || notificationAdapterSend.data.status !== 'DELIVERY_ADAPTER_SUCCEEDED' || notificationAdapterSend.data.delivery?.attemptCount !== 2 || notificationAdapterSend.data.externalDeliveryEnabled !== true) {
      throw new Error('chargeback alert notification adapter send self-test failed')
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
    const retryWorkerStatus = await (await fetch(`${base}/admin/billing/chargeback-adapter-retry-worker/status?limit=5`, {
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!retryWorkerStatus.data || retryWorkerStatus.data.mode !== 'ADAPTER_RETRY_WORKER' || retryWorkerStatus.data.dryRun !== true || retryWorkerStatus.data.paymentCandidateCount < 1) {
      throw new Error('chargeback adapter retry worker status self-test failed')
    }
    const retryWorkerRun = await (await fetch(`${base}/admin/billing/chargeback-adapter-retry-worker/run?dryRun=false&limit=5`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!retryWorkerRun.data || retryWorkerRun.data.mode !== 'ADAPTER_RETRY_WORKER' || retryWorkerRun.data.dryRun !== false || retryWorkerRun.data.updatedCount < 1 || retryWorkerRun.data.items?.[0]?.toStatus !== 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL') {
      throw new Error('chargeback adapter retry worker run self-test failed')
    }
    const handoffAdapterResult = await (await fetch(`${base}/admin/billing/chargeback-payment-provider-handoffs/${handoffList.data.handoffs[0].id}/adapter-result?result=BLOCKED_CREDENTIAL`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!handoffAdapterResult.data || handoffAdapterResult.data.status !== 'PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL' || handoffAdapterResult.data.handoff?.attemptCount < 2) {
      throw new Error('chargeback payment provider adapter result self-test failed')
    }
    const handoffAdapterSend = await (await fetch(`${base}/admin/billing/chargeback-payment-provider-handoffs/${handoffList.data.handoffs[0].id}/adapter-send?retryDelayMinutes=30`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login.data.accessToken}` },
    })).json()
    if (!handoffAdapterSend.data || handoffAdapterSend.data.status !== 'PAYMENT_PROVIDER_ADAPTER_SUCCEEDED' || handoffAdapterSend.data.handoff?.attemptCount < 3 || handoffAdapterSend.data.externalPaymentEnabled !== true) {
      throw new Error('chargeback payment provider adapter send self-test failed')
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
