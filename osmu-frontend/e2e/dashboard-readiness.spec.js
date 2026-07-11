import { expect, test } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://127.0.0.1:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const artifactDirectory = path.resolve('..', '.osmu-run', 'dashboard-readiness')

test('dashboard keeps readiness concise until detailed diagnosis is requested', async ({ page }) => {
  await mkdir(artifactDirectory, { recursive: true })
  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(/\/admin$/)

  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page).toHaveURL(/\/dashboard$/)

  const overview = page.getByTestId('dashboard-readiness-overview')
  const details = page.getByTestId('dashboard-readiness-details')
  const toggle = page.getByTestId('dashboard-readiness-details-toggle')

  await expect(overview).toBeVisible()
  await expect(details).toHaveCount(0)
  await expect(toggle).toHaveAttribute('aria-expanded', 'false')
  await expect(overview).toContainText('Operations')
  await expect(overview).toContainText('Blockers')
  await expect(overview).toContainText('Warnings')
  await page.screenshot({ path: path.join(artifactDirectory, 'readiness-summary.png') })

  await toggle.click()
  await expect(details).toBeVisible()
  await expect(toggle).toHaveAttribute('aria-expanded', 'true')

  const desktopOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)

  expect(desktopOverflow).toBeFalsy()

  await page.setViewportSize({ width: 390, height: 844 })
  await expect(overview).toBeVisible()
  const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)
  expect(mobileOverflow).toBeFalsy()
  await page.screenshot({ path: path.join(artifactDirectory, 'readiness-mobile.png') })
})
