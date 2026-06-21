import { expect, test } from '@playwright/test'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://localhost:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const developerLoginId = process.env.OSMU_DEVELOPER_LOGIN_ID || 'developer'
const developerPassword = process.env.OSMU_DEVELOPER_PASSWORD || 'password'
const developerBucketName = 'developer-e2e-bucket'
const expectOperationsConvergence = process.env.OSMU_EXPECT_OPERATIONS_CONVERGENCE === 'true'

async function expectAdminBucketContextReady(page) {
  await expect(
    page.getByTestId('admin-bucket-empty-state')
      .or(page.getByTestId('bucket-lifecycle-panel'))
      .first(),
  ).toBeVisible()
}

async function installDeveloperApiMocks(page) {
  const developerUser = {
    id: 2001,
    loginId: developerLoginId,
    name: 'Developer User',
    role: 'USER',
  }
  const accessKeys = []

  await page.route('**/api/**', async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const path = url.pathname.replace(/^\/api/, '') || '/'
    const method = request.method()
    const json = (body, status = 200) => route.fulfill({
      status,
      contentType: 'application/json',
      body: JSON.stringify(body),
    })

    if (method === 'POST' && path === '/auth/login') {
      return json({
        data: {
          accessToken: 'developer-e2e-access',
          refreshToken: 'developer-e2e-refresh',
          user: developerUser,
        },
      })
    }

    if (method === 'POST' && path === '/auth/refresh') {
      return json({
        data: {
          accessToken: 'developer-e2e-access-refreshed',
          refreshToken: 'developer-e2e-refresh',
          user: developerUser,
        },
      })
    }

    if (method === 'GET' && path === '/users/me') {
      return json({ data: developerUser })
    }

    if (method === 'GET' && ['/health', '/storage/health', '/database/health'].includes(path)) {
      return json({ data: { status: 'UP', storage: 'MOCK', database: 'MOCK' } })
    }

    if (method === 'GET' && path === '/developer/s3-client-config') {
      return json({
        data: {
          endpoint: 'http://localhost:8080/api/s3',
          region: 'us-east-1',
          signatureVersion: 'AWS4-HMAC-SHA256',
          virtualHostedStyleEnabled: true,
          virtualHostedStyleDomainSuffixes: ['localhost'],
        },
      })
    }

    if (method === 'GET' && path === '/buckets') {
      return json({
        items: [{
          id: 3001,
          name: developerBucketName,
          ownerType: 'USER',
          ownerId: developerUser.id,
          quotaBytes: 1073741824,
          usedBytes: 0,
          objectCount: 0,
        }],
      })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/objects`) {
      return json({ items: [], prefixes: [], nextCursor: '' })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/permissions`) {
      return json({ items: [] })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/lifecycle`) {
      return json({ data: { xml: '', ruleCount: 0 } })
    }

    if (method === 'GET' && path === `/buckets/${developerBucketName}/tags`) {
      return json({ data: { tags: {}, tagCount: 0 } })
    }

    if (method === 'GET' && path === '/access-keys') {
      return json({ items: accessKeys.map(({ secretKey: _secretKey, ...key }) => key) })
    }

    if (method === 'POST' && path === '/access-keys') {
      const body = await request.postDataJSON()
      const created = {
        id: accessKeys.length + 1,
        name: body.name,
        accessKey: `OSMUDEVE2E${accessKeys.length + 1}`,
        secretKey: 'developer-e2e-secret',
        status: 'ACTIVE',
        bucketScopes: body.bucketScopes || [],
        expiresAt: body.expiresAt || null,
        lastUsedAt: null,
      }
      accessKeys.push(created)
      return json({ data: created })
    }

    const accessKeyDeleteMatch = path.match(/^\/access-keys\/(\d+)$/)
    if (method === 'DELETE' && accessKeyDeleteMatch) {
      const keyId = Number(accessKeyDeleteMatch[1])
      const key = accessKeys.find((item) => item.id === keyId)
      if (key) {
        key.status = 'INACTIVE'
      }
      return json({
        data: key
          ? {
            ...key,
            secretKey: undefined,
          }
          : null,
      })
    }

    if (method === 'GET' && path === '/dashboard/layout/widgets') {
      return json({ data: [] })
    }

    if (method === 'GET' && path === '/dashboard/layout') {
      return json({ data: { source: 'DEFAULT', widgets: [], sections: [] } })
    }

    if (method === 'GET' && path === '/dashboard/layout/presets') {
      return json({ data: [] })
    }

    return json({ data: null, items: [] })
  })
}

test('stale saved session returns to login redirect', async ({ page }) => {
  await page.addInitScript(() => {
    window.localStorage.setItem('osmu.auth.tokens', JSON.stringify({
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
    }))
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.route('**/api/**', async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith('/users/me')) {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'session expired',
          },
        }),
      })
      return
    }

    if (url.pathname.endsWith('/auth/refresh') || url.pathname.endsWith('/dashboard/layout/widgets')) {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'session expired',
          },
        }),
      })
      return
    }

    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        data: [],
        items: [],
      }),
    })
  })

  await page.goto(`${frontendBaseUrl}/dashboard`)

  await expect(page).toHaveURL(/\/login\?/)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page).toHaveURL(/redirect=(%2F|\/)dashboard/)
})

test('developer login lands on S3 API console with access key controls', async ({ page }) => {
  await installDeveloperApiMocks(page)
  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=developer`)

  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('login-mode-developer')).toBeChecked()
  await expect(page.getByTestId('login-submit-button')).toContainText('개발자 콘솔로 로그인')
  await page.getByTestId('login-id-input').fill(developerLoginId)
  await page.getByTestId('login-password-input').fill(developerPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page).toHaveURL(/\/developer$/)
  await expect(page.getByTestId('developer-page')).toBeVisible()
  await expect(page.getByRole('link', { name: 'Admin' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Developer' })).toBeVisible()
  await expect(page.getByTestId('developer-s3-endpoint-panel')).toContainText('API 접속 정보')
  await expect(page.getByTestId('developer-s3-endpoint')).toContainText('/api/s3')
  await expect(page.getByTestId('developer-s3-signature')).toContainText('AWS4-HMAC-SHA256')
  await expect(page.getByTestId('developer-client-snippets-panel')).toContainText('S3 클라이언트 예시')
  await expect(page.getByTestId('developer-client-aws-cli')).toContainText(`s3://${developerBucketName}`)

  await page.getByTestId('access-key-name-input').fill('developer-browser-key')
  await page.getByTestId('access-key-bucket-select').selectOption(developerBucketName)
  await page.getByTestId('access-key-scope-add-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-scope-remove-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toHaveCount(0)
  await expect(page.getByTestId('access-key-create-button')).toBeDisabled()
  await page.getByTestId('access-key-scope-add-button').click()
  await expect(page.getByTestId('access-key-scope-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-create-button').click()
  await expect(page.getByTestId('access-key-secret-box')).toContainText('developer-e2e-secret')
  await expect(page.getByTestId('status-alert')).toContainText('developer-browser-key Access Key 발급 완료')
  await expect(page.getByTestId('access-key-list')).toContainText('developer-browser-key')
  await expect(page.getByTestId('access-key-list')).toContainText(developerBucketName)
  await page.getByTestId('access-key-delete-button').first().click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Access Key')
  await page.getByTestId('confirm-cancel-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(page.getByTestId('access-key-list')).toContainText('ACTIVE')
  await page.getByTestId('access-key-delete-button').first().click()
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('비활성화 완료')
  await expect(page.getByTestId('access-key-list')).toContainText('INACTIVE')
})

test('admin dashboard shows operations readiness convergence handoff', async ({ page }) => {
  test.skip(!expectOperationsConvergence, 'operations convergence fixture is not enabled for this E2E target')

  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page.getByTestId('logout-button')).toBeVisible()

  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page).toHaveURL(/\/dashboard$/)
  await expect(page.getByTestId('readiness-convergence-item-summary')).toContainText('action-required')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('resolve-invocation-blockers')
  await expect(page.getByTestId('readiness-convergence-summary')).toContainText('1 of 7 stages ready')
  await expect(page.getByTestId('readiness-convergence-commands')).toContainText('Resolve invocation blockers')
  await expect(page.getByTestId('readiness-convergence-commands')).toContainText('write-operations-invocation-unblock-plan.ps1')
  await expect(page.getByTestId('readiness-convergence-command-copy-button')).toBeVisible()
  await expect(page.getByTestId('readiness-convergence-command-list-copy-button')).toBeVisible()
})

test('admin can complete lightweight storage portal click path', async ({ page }) => {
  const suffix = Date.now().toString(36)
  const bucketName = `e2e-${suffix}`
  const deleteBucketName = `e2e-delete-${suffix}`
  const objectKey = `e2e/hello-${suffix}.txt`

  await page.addInitScript(() => {
    window.localStorage.removeItem('osmu.dashboard.widgets.v1')
    window.localStorage.removeItem('osmu.auth.tokens')
    window.localStorage.removeItem('osmu.login.rememberedId')
    window.sessionStorage.removeItem('osmu.auth.tokens')
  })
  await page.goto(`${frontendBaseUrl}/login?mode=admin`)

  await expect(page.getByTestId('login-form')).toBeVisible()
  await expect(page.getByTestId('login-mode-admin')).toBeChecked()
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page.getByTestId('logout-button')).toBeVisible()
  await expect(page).toHaveURL(/\/admin$/)
  await expect(page.locator('#admin-access-keys')).toBeVisible()
  await expectAdminBucketContextReady(page)

  await page.getByRole('link', { name: 'Storage' }).click()
  await expect(page.getByTestId('bucket-panel')).toBeVisible()

  await page.getByTestId('bucket-name-input').fill(deleteBucketName)
  await page.getByTestId('bucket-quota-input').fill('1')
  await page.getByTestId('bucket-owner-type-select').selectOption('USER')
  await page.getByTestId('bucket-create-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('버킷 생성 완료')

  const deleteBucketRow = page.getByTestId(`bucket-row-${deleteBucketName}`)
  await expect(deleteBucketRow).toBeVisible()
  await deleteBucketRow.getByTestId('bucket-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText(deleteBucketName)
  await page.getByTestId('confirm-cancel-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(deleteBucketRow).toBeVisible()
  await expect(page.getByTestId('status-alert')).not.toContainText('버킷 삭제 완료')
  await deleteBucketRow.getByTestId('bucket-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText(deleteBucketName)
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('confirm-dialog')).toHaveCount(0)
  await expect(page.getByTestId('status-alert')).toContainText('버킷 삭제 완료')
  await expect(deleteBucketRow).toHaveCount(0)

  await page.getByTestId('bucket-name-input').fill(bucketName)
  await page.getByTestId('bucket-quota-input').fill('1')
  await page.getByTestId('bucket-owner-type-select').selectOption('USER')
  await page.getByTestId('bucket-create-button').click()

  const bucketRow = page.getByTestId(`bucket-row-${bucketName}`)
  await expect(bucketRow).toBeVisible()
  await bucketRow.click()

  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-panel')).toContainText(bucketName)

  await page.getByRole('link', { name: 'Admin' }).click()
  await expect(page.getByTestId('bucket-lifecycle-panel')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-load-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-save-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-delete-button')).toBeVisible()
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toBeVisible()
  const lifecycleXml = [
    '<LifecycleConfiguration>',
    '  <Rule>',
    '    <ID>Browser lifecycle</ID>',
    '    <Status>Enabled</Status>',
    '    <Filter><Prefix>e2e/raw/</Prefix></Filter>',
    '    <Expiration><Days>7</Days></Expiration>',
    '  </Rule>',
    '</LifecycleConfiguration>',
  ].join('\n')
  await page.getByTestId('bucket-lifecycle-textarea').fill(lifecycleXml)
  await page.getByTestId('bucket-lifecycle-save-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket lifecycle')
  await expect(page.getByTestId('bucket-lifecycle-rule-count')).toContainText('1 rules')
  await expect(page.getByTestId('bucket-lifecycle-saved-count')).toContainText('saved 1 rules')
  await page.getByTestId('bucket-lifecycle-textarea').fill('')
  await page.getByTestId('bucket-lifecycle-load-button').click()
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue(/Browser lifecycle/)
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue(/e2e\/raw\//)
  await page.getByTestId('bucket-lifecycle-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Bucket lifecycle')
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket lifecycle')
  await expect(page.getByTestId('bucket-lifecycle-textarea')).toHaveValue('')
  await expect(page.getByTestId('bucket-lifecycle-rule-count')).toContainText('0 rules')
  await expect(page.getByTestId('bucket-tags-panel')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-load-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-save-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-delete-button')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-input')).toBeVisible()
  await page.getByTestId('bucket-tags-input').fill('project=osmu,stage=e2e')
  await page.getByTestId('bucket-tags-save-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket tags 저장 완료')
  await expect(page.getByTestId('bucket-tags-count')).toContainText('2 tags')
  await page.getByTestId('bucket-tags-input').fill('')
  await page.getByTestId('bucket-tags-load-button').click()
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue(/project=osmu/)
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue(/stage=e2e/)
  await page.getByTestId('bucket-tags-delete-button').click()
  await expect(page.getByTestId('confirm-dialog')).toContainText('Bucket tags')
  await page.getByTestId('confirm-submit-button').click()
  await expect(page.getByTestId('status-alert')).toContainText('bucket tags 삭제 완료')
  await expect(page.getByTestId('bucket-tags-input')).toHaveValue('')

  await page.getByRole('link', { name: 'Objects' }).click()
  await expect(page.getByTestId('object-prefix-breadcrumb')).toBeVisible()
  await expect(page.getByTestId('object-prefix-breadcrumb-button').first()).toBeVisible()
  await page.getByTestId('object-key-input').fill(objectKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=e2e')
  await page.getByTestId('object-file-input').setInputFiles({
    name: 'hello.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('hello from browser e2e'),
  })
  await expect(page.getByTestId('object-upload-button')).toBeEnabled()
  await page.getByTestId('object-upload-button').click()

  await expect(page.getByTestId('object-prefix-row').first()).toContainText('e2e')
  await page.getByTestId('object-prefix-open-button').first().click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('e2e/')
  await expect(page.getByTestId('object-prefix-breadcrumb-button').filter({ hasText: 'e2e' })).toBeVisible()
  await page.getByTestId('object-prefix-breadcrumb-button').filter({ hasText: '/' }).click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('')
  await page.getByTestId('object-prefix-open-button').first().click()
  await expect(page.getByTestId('object-prefix-input')).toHaveValue('e2e/')

  await page.getByTestId('object-search-input').fill('hello')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-key-match').first()).toContainText(/hello/i)
  await expect(page.getByTestId('object-tag-edit-button').first()).toBeVisible()

  await page.getByTestId('object-tag-filter-input').fill('project=osmu')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-table')).toContainText('project=osmu')

  await page.getByTestId('object-tag-edit-button').first().click()
  await expect(page.getByTestId('object-tag-key-input')).toHaveValue(objectKey)
  await expect(page.getByTestId('object-tag-value-input')).toHaveValue(/project=osmu/)
  await page.getByTestId('object-tag-value-input').fill('project=archive,stage=curated')
  await page.getByTestId('object-tag-save-button').click()
  await page.getByTestId('object-tag-filter-input').fill('project=archive')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)
  await expect(page.getByTestId('object-table')).toContainText('project=archive')
  await expect(page.getByTestId('object-table')).toContainText('stage=curated')

  await page.getByTestId('object-detail-button').first().click()
  await expect(page.getByTestId('object-detail-panel')).toContainText(objectKey)
  await expect(page.getByTestId('object-detail-panel')).toContainText('project=archive')
  await expect(page.getByTestId('object-detail-panel')).toContainText('stage=curated')
  await expect(page.getByTestId('object-metadata-row-state').first()).toContainText(/Synced|Drift|Missing/)

  await page.getByTestId('object-tag-edit-button').first().click()
  await page.getByTestId('object-tag-value-input').fill('bad key=value')
  await page.getByTestId('object-tag-save-button').click()
  await expect(page.getByTestId('error-alert')).toContainText('Tag keys can contain')
  await expect(page.getByTestId('object-table')).toContainText('stage=curated')

  await page.getByRole('link', { name: 'Audit' }).click()
  await page.getByTestId('audit-result-select').selectOption('SUCCESS')
  await page.getByTestId('audit-limit-input').fill('5')
  await page.getByTestId('audit-search-button').click()
  await expect(page.getByTestId('audit-list')).toContainText(/BUCKET|OBJECT|LOGIN/)
  await expect(page.getByTestId('audit-entry').first()).toContainText('SUCCESS')
  await expect(page.getByTestId('audit-entry')).toHaveCount(5)
  const auditNextButton = page.getByTestId('audit-next-button')
  await expect(auditNextButton).toBeEnabled()
  await auditNextButton.click()
  await expect(page.getByTestId('audit-entry').nth(5)).toContainText('SUCCESS')
  const auditDownloadPromise = page.waitForEvent('download')
  await page.getByTestId('audit-export-button').click()
  const auditDownload = await auditDownloadPromise
  expect(auditDownload.suggestedFilename()).toBe('osmu-audit.csv')
  await page.getByTestId('audit-reset-button').click()
  await expect(page.getByTestId('audit-result-select')).toHaveValue('')
  await expect(page.getByTestId('audit-limit-input')).toHaveValue('50')
})
