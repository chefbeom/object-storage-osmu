import { expect, test } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://127.0.0.1:5173'
const apiBaseUrl = process.env.OSMU_API_BASE_URL || 'http://127.0.0.1:8080/api'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const artifactDirectory = path.resolve('..', '.osmu-run', 'storage-layout-scenarios')

test.setTimeout(120_000)

test('admin and user storage layout scenario', async ({ browser }) => {
  await mkdir(artifactDirectory, { recursive: true })
  const suffix = String(Date.now())
  const userLoginId = `layout-user-${suffix}`
  const userPassword = 'user-password'
  const bucketName = `layout-bucket-${suffix}`
  const browserFindings = {
    consoleErrors: [],
    failedResponses: [],
    developerLoginLabel: '',
    userAdminRoute: '',
    userAdminApiStatus: 0,
    userAdminModeRedirect: '',
    userAdminModeNoticeVisible: false,
    approvalBeforeSimulationAllowed: false,
    storageClassCheckText: '',
    layoutPlanHasBucketReference: false,
    profileAssignmentHasLayoutReference: false,
  }

  const adminContext = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
  const adminPage = await adminContext.newPage()
  collectBrowserErrors(adminPage, browserFindings)

  await login(adminPage, adminLoginId, adminPassword, 'admin', '/admin')
  await expect(adminPage.getByTestId('storage-layout-panel')).toBeVisible({ timeout: 30_000 })
  await expect(adminPage.getByTestId('storage-layout-catalog')).toContainText('JBOD')
  await expect(adminPage.getByTestId('storage-layout-catalog')).toContainText('RAID 6-like')
  await expect(adminPage.getByTestId('storage-layout-catalog')).toContainText('RAID 10-like')

  await adminPage.getByTestId('storage-layout-code-select').selectOption('RAID0')
  await adminPage.getByTestId('storage-layout-storage-class-input').fill('osmu-storage')
  await adminPage.getByTestId('storage-layout-server-count-input').fill('2')
  await adminPage.getByTestId('storage-layout-volumes-per-server-input').fill('1')
  await adminPage.getByTestId('storage-layout-volume-size-input').fill('256')
  await adminPage.getByTestId('storage-layout-reason-input').fill('scenario performance PVC pool')
  await adminPage.getByTestId('storage-layout-create-button').click()
  await expect(adminPage.getByTestId('status-alert')).toContainText('Storage layout plan created')

  const layoutPlanList = adminPage.getByTestId('storage-layout-plan-list')
  const layoutPlanRow = layoutPlanList.locator('li').filter({ hasText: 'RAID 0-like' }).first()
  await expect(layoutPlanRow).toContainText('PLANNED')
  await expect(layoutPlanRow.getByTestId('storage-layout-approve-button')).toBeDisabled()
  await layoutPlanRow.getByTestId('storage-layout-simulate-button').click()
  await expect(layoutPlanRow.getByTestId('storage-layout-approve-button')).toBeEnabled()
  await layoutPlanRow.getByTestId('storage-layout-approve-button').click()
  await expect(layoutPlanRow).toContainText('APPROVED')
  await expect(adminPage.getByTestId('storage-layout-simulation')).toBeVisible()
  await expect(adminPage.getByTestId('storage-layout-manifest-preview')).toContainText('clusterMutation: disabled')
  await expect(adminPage.getByTestId('storage-layout-simulation')).toContainText('CLUSTER_MUTATION')
  browserFindings.storageClassCheckText = await adminPage.getByTestId('storage-layout-simulation')
    .locator('li')
    .filter({ hasText: 'STORAGE_CLASS' })
    .innerText()
  await adminPage.getByTestId('storage-layout-panel').screenshot({
    path: path.join(artifactDirectory, 'admin-layout-panel.png'),
  })
  await adminPage.getByTestId('storage-layout-simulation').screenshot({
    path: path.join(artifactDirectory, 'admin-layout-simulation-panel.png'),
  })
  await adminPage.screenshot({ path: path.join(artifactDirectory, 'admin-layout-simulation.png'), fullPage: true })

  await adminPage.getByTestId('storage-layout-code-select').selectOption('RAID10')
  await adminPage.getByTestId('storage-layout-server-count-input').fill('3')
  await adminPage.getByTestId('storage-layout-volumes-per-server-input').fill('1')
  await adminPage.getByTestId('storage-layout-create-button').click()
  await expect(adminPage.getByTestId('error-alert')).toBeVisible()
  await expect(adminPage.getByTestId('error-alert')).toContainText('requires at least 4 PVCs')

  const userForm = adminPage.locator('form.user-form')
  await userForm.locator('input[placeholder="user1"]').fill(userLoginId)
  await userForm.locator('input[placeholder="user1@example.com"]').fill(`${userLoginId}@example.com`)
  await userForm.locator('input[placeholder="User One"]').fill('Storage Layout User')
  await userForm.locator('input[placeholder="password"]').fill(userPassword)
  await userForm.locator('select').last().selectOption('USER')
  await userForm.locator('button[type="submit"]').click()
  await expect(adminPage.locator('form.user-form + ul')).toContainText(userLoginId)

  const mismatchContext = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
  const mismatchPage = await mismatchContext.newPage()
  await login(mismatchPage, userLoginId, userPassword, 'admin', '/developer')
  browserFindings.userAdminModeRedirect = new URL(mismatchPage.url()).pathname
  browserFindings.userAdminModeNoticeVisible = await mismatchPage.getByTestId('status-alert').isVisible().catch(() => false)
  await mismatchContext.close()

  const userContext = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
  const userPage = await userContext.newPage()
  collectBrowserErrors(userPage, browserFindings)
  await userPage.goto(`${frontendBaseUrl}/login?mode=developer`)
  browserFindings.developerLoginLabel = await userPage.getByTestId('login-role-developer').innerText()
  await userPage.getByTestId('login-id-input').fill(userLoginId)
  await userPage.getByTestId('login-password-input').fill(userPassword)
  await userPage.getByTestId('login-submit-button').click()
  await expect(userPage).toHaveURL(/\/developer$/)

  await userPage.goto(`${frontendBaseUrl}/admin`)
  await expect(userPage).toHaveURL(/\/developer(?:\?.*)?$/)
  await expect(userPage.getByTestId('status-alert')).toContainText('does not have admin access')
  browserFindings.userAdminRoute = new URL(userPage.url()).pathname

  const userApiLogin = await userContext.request.post(`${apiBaseUrl}/auth/login`, {
    data: { loginId: userLoginId, password: userPassword },
  })
  expect(userApiLogin.ok()).toBeTruthy()
  const userApiSession = await userApiLogin.json()
  const userAdminApi = await userContext.request.get(`${apiBaseUrl}/admin/storage-layouts/capabilities`, {
    headers: { Authorization: `Bearer ${userApiSession.data.accessToken}` },
  })
  browserFindings.userAdminApiStatus = userAdminApi.status()
  expect(userAdminApi.status()).toBe(403)

  await userPage.goto(`${frontendBaseUrl}/storage`)
  await expect(userPage.getByTestId('bucket-panel')).toBeVisible()
  await userPage.getByTestId('bucket-name-input').fill(bucketName)
  await userPage.getByTestId('bucket-quota-input').fill('10')
  await userPage.getByTestId('bucket-create-button').click()
  const bucketRow = userPage.getByTestId(`bucket-row-${bucketName}`)
  await expect(bucketRow).toBeVisible()
  await bucketRow.click()
  await expect(userPage.getByTestId('storage-profile-panel')).toBeVisible()
  await userPage.getByTestId('storage-profile-select').selectOption('PERFORMANCE')
  await userPage.getByTestId('storage-profile-reason-input').fill('temporary ingest throughput')
  await userPage.getByTestId('storage-profile-request-button').click()
  await expect(userPage.getByTestId('storage-profile-request-table')).toContainText('Performance')
  await expect(userPage.getByTestId('storage-profile-request-status')).toContainText('PENDING')
  await userPage.getByTestId('storage-profile-panel').screenshot({
    path: path.join(artifactDirectory, 'user-profile-request-panel.png'),
  })
  await userPage.screenshot({ path: path.join(artifactDirectory, 'user-profile-request.png'), fullPage: true })

  await adminPage.goto(`${frontendBaseUrl}/admin`)
  const profileApprovalRow = adminPage.getByTestId('admin-storage-profile-request-row')
    .filter({ hasText: bucketName })
    .first()
  await expect(profileApprovalRow).toBeVisible({ timeout: 30_000 })
  await profileApprovalRow.getByTestId('admin-storage-profile-approve-button').click()
  await profileApprovalRow.getByTestId('admin-storage-profile-layout-select').selectOption({ index: 1 })
  await profileApprovalRow.getByTestId('admin-storage-profile-apply-button').click()
  await expect(profileApprovalRow).toHaveCount(0)

  await userPage.reload()
  const refreshedBucketRow = userPage.getByTestId(`bucket-row-${bucketName}`)
  await refreshedBucketRow.click()
  await expect(userPage.getByTestId('storage-profile-panel')).toContainText('Performance')
  await expect(userPage.getByTestId('storage-profile-panel')).toContainText('RAID0-like')
  await expect(userPage.getByTestId('storage-profile-request-status')).toContainText('APPLIED')
  await expect(userPage.getByTestId('storage-profile-request-status')).toHaveClass(/up/)
  await userPage.getByTestId('storage-profile-panel').screenshot({
    path: path.join(artifactDirectory, 'user-profile-applied-panel.png'),
  })
  await userPage.screenshot({ path: path.join(artifactDirectory, 'user-profile-applied.png'), fullPage: true })

  const adminApiLogin = await adminContext.request.post(apiBaseUrl + '/auth/login', {
    data: { loginId: adminLoginId, password: adminPassword },
  })
  const adminApiSession = await adminApiLogin.json()
  const layoutPlansResponse = await adminContext.request.get(apiBaseUrl + '/admin/storage-layouts/plans?status=ALL&limit=50', {
    headers: { Authorization: 'Bearer ' + adminApiSession.data.accessToken },
  })
  const layoutPlans = await layoutPlansResponse.json()
  const firstLayoutPlan = layoutPlans.items?.[0] || {}
  browserFindings.layoutPlanHasBucketReference = Object.keys(firstLayoutPlan)
    .some((key) => ['bucketName', 'bucketId', 'storageProfileRequestId'].includes(key))

  const currentProfileResponse = await userContext.request.get(
    apiBaseUrl + '/buckets/' + encodeURIComponent(bucketName) + '/storage-profile',
    { headers: { Authorization: 'Bearer ' + userApiSession.data.accessToken } },
  )
  const currentProfile = await currentProfileResponse.json()
  browserFindings.profileAssignmentHasLayoutReference = Object.keys(currentProfile.data?.assignment || {})
    .some((key) => ['storageLayoutPlanId', 'storagePoolName', 'storageLayoutCode'].includes(key))
  console.log(`STORAGE_LAYOUT_SCENARIO ${JSON.stringify(browserFindings)}`)
  await userContext.close()
  await adminContext.close()
})

async function login(page, loginId, password, mode, expectedPath) {
  await page.goto(`${frontendBaseUrl}/login?mode=${mode}`)
  await expect(page.getByTestId('login-form')).toBeVisible()
  await page.getByTestId('login-id-input').fill(loginId)
  await page.getByTestId('login-password-input').fill(password)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(new RegExp(`${expectedPath.replace('/', '\\/')}(?:\\?.*)?$`))
}

function collectBrowserErrors(page, findings) {
  page.on('console', (message) => {
    if (message.type() === 'error') {
      findings.consoleErrors.push(message.text())
    }
  })
  page.on('response', (response) => {
    if (response.status() >= 400) {
      findings.failedResponses.push({ status: response.status(), url: response.url() })
    }
  })
}
