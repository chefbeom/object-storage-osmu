import { expect, test } from '@playwright/test'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://localhost:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'

test('admin can complete lightweight storage portal click path', async ({ page }) => {
  const suffix = Date.now().toString(36)
  const bucketName = `e2e-${suffix}`
  const objectKey = `e2e/hello-${suffix}.txt`

  await page.goto(frontendBaseUrl)

  await expect(page.getByTestId('status-list')).toBeVisible()
  await expect(page.getByTestId('login-form')).toBeVisible()
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()

  await expect(page.getByTestId('logout-button')).toBeVisible()
  await expect(page.getByTestId('metrics-grid')).toBeVisible()
  await expect(page.getByTestId('backup-status-panel')).toContainText(/DRILL_PENDING|DEGRADED|READY/)
  await expect(page.getByTestId('bucket-panel')).toBeVisible()

  await page.getByTestId('bucket-name-input').fill(bucketName)
  await page.getByTestId('bucket-quota-input').fill('1')
  await page.getByTestId('bucket-owner-type-select').selectOption('USER')
  await page.getByTestId('bucket-create-button').click()

  const bucketRow = page.getByTestId(`bucket-row-${bucketName}`)
  await expect(bucketRow).toBeVisible()
  await bucketRow.click()

  await expect(page.getByTestId('object-panel')).toContainText(bucketName)
  await expect(page.getByTestId('bucket-lifecycle-panel')).toBeVisible()
  await expect(page.getByTestId('bucket-tags-panel')).toBeVisible()

  await page.getByTestId('object-key-input').fill(objectKey)
  await page.getByTestId('object-tags-input').fill('project=osmu,stage=e2e')
  await page.getByTestId('object-file-input').setInputFiles({
    name: 'hello.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('hello from browser e2e'),
  })
  await expect(page.getByTestId('object-upload-button')).toBeEnabled()
  await page.getByTestId('object-upload-button').click()

  await page.getByTestId('object-search-input').fill('hello')
  await page.getByTestId('object-search-button').click()
  await expect(page.getByTestId('object-table')).toContainText(objectKey)

  await page.getByTestId('audit-search-button').click()
  await expect(page.getByTestId('audit-list')).toContainText(/BUCKET|OBJECT|LOGIN/)
})
