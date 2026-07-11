import { expect, test } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://127.0.0.1:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const artifactDirectory = path.resolve('..', '.osmu-run', 'quick-start')

test('Quick Start creates a bucket, issues a scoped key, and saves preferences', async ({ page }) => {
  await mkdir(artifactDirectory, { recursive: true })
  const suffix = Date.now().toString(36)
  const bucketName = `quick-${suffix}`

  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(/\/admin$/)

  await page.getByRole('link', { name: 'Quick Start' }).click()
  await expect(page).toHaveURL(/\/quick-start$/)
  await expect(page.getByTestId('quick-start-page')).toBeVisible()
  const guide = page.getByTestId('quick-start-guide')
  await expect(guide).toBeVisible()
  await page.getByTestId('quick-start-guide-files').click()
  await expect(guide).toContainText('Objects')
  await page.getByTestId('quick-start-guide-security').click()
  await expect(guide).toContainText('Secret Key')
  await page.getByTestId('quick-start-guide-first').click()


  await page.getByTestId('quick-start-bucket-name').fill(bucketName)
  await page.getByTestId('quick-start-create-bucket').click()
  await expect(page.getByTestId('quick-start-storage-step')).toContainText(bucketName)

  await page.getByTestId('quick-start-key-name').fill(`key-${suffix}`)
  await page.getByTestId('quick-start-create-key').click()
  await expect(page.getByTestId('quick-start-access-key')).not.toBeEmpty()
  await expect(page.getByTestId('quick-start-secret-key')).toBeVisible()
  await expect(page.getByTestId('quick-start-connect-step')).toContainText(bucketName)

  await page.getByTestId('quick-start-settings-button').click()
  await expect(page.getByTestId('quick-start-settings')).toBeVisible()
  await page.getByTestId('quick-start-save-settings').click()
  await expect(page.getByText('설정을 저장했습니다.')).toBeVisible()

  const desktopOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)
  expect(desktopOverflow).toBeFalsy()
  await page.screenshot({ path: path.join(artifactDirectory, 'quick-start-desktop.png') })

  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page.getByTestId('quick-start-settings')).toBeVisible()
  const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)
  expect(mobileOverflow).toBeFalsy()
  await page.screenshot({ path: path.join(artifactDirectory, 'quick-start-mobile.png'), fullPage: true })
})
