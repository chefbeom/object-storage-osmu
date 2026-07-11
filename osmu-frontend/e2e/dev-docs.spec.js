import { expect, test } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'

const frontendBaseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://127.0.0.1:5173'
const adminLoginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const adminPassword = process.env.OSMU_ADMIN_PASSWORD || 'password'
const artifactDirectory = path.resolve('..', '.osmu-run', 'dev-docs')

test('Dev-Docs keeps navigation intact and shows one focused document', async ({ page }) => {
  await mkdir(artifactDirectory, { recursive: true })
  await login(page)

  await page.getByTestId('dev-docs-nav-link').click()
  await expect(page).toHaveURL(/\/dev-docs$/)
  await expect(page.getByTestId('dev-docs-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: '사람과 AI를 위한 운영 안내서' })).toBeVisible()
  await expect(page.getByTestId('dev-docs-role-matrix')).toContainText('ADMIN')

  const imagesLoaded = await page.locator('.visual-examples img').evaluateAll((images) => (
    images.every((image) => image.complete && image.naturalWidth > 0 && image.naturalHeight > 0)
  ))
  expect(imagesLoaded).toBeTruthy()

  await page.getByTestId('dev-docs-nav-user-buckets').click()
  await expect(page.getByTestId('dev-docs-section-user-buckets')).toBeVisible()
  await expect(page.locator('.guide-document')).toHaveCount(1)
  await expect(page.getByTestId('dev-docs-section-user-objects')).toHaveCount(0)

  const roleFilter = page.getByTestId('dev-docs-role-filter')
  await roleFilter.selectOption('AUDITOR')
  await expect(page.getByTestId('dev-docs-nav-auditor')).toBeVisible()
  await expect(page.getByTestId('dev-docs-nav-user-buckets')).toHaveCount(0)
  await page.getByTestId('dev-docs-nav-auditor').click()
  await expect(page.getByTestId('dev-docs-section-auditor')).toBeVisible()

  const search = page.getByTestId('dev-docs-search')
  await search.fill('Request ID')
  await expect(page.getByTestId('dev-docs-nav-troubleshooting')).toBeVisible()
  await page.getByTestId('dev-docs-nav-troubleshooting').click()
  await expect(page.getByTestId('dev-docs-section-troubleshooting')).toBeVisible()
  await search.fill('검색결과없음테스트')
  await expect(page.getByText('검색 결과가 없습니다')).toBeVisible()
  await search.fill('')
  await roleFilter.selectOption('ALL')
  await page.getByTestId('dev-docs-nav-overview').click()

  const desktopOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)
  expect(desktopOverflow).toBeFalsy()

  await page.locator('.docs-workspace').evaluate((element) => { element.scrollTop = element.scrollHeight })
  const sidebarBox = await page.locator('.sidebar').boundingBox()
  expect(sidebarBox?.y).toBe(0)
  expect(sidebarBox?.height).toBe(page.viewportSize()?.height)
  await page.screenshot({ path: path.join(artifactDirectory, 'dev-docs-redesign-desktop.png') })

  await page.setViewportSize({ width: 390, height: 844 })
  await page.getByTestId('dev-docs-nav-user-objects').click()
  await expect(page.getByTestId('dev-docs-section-user-objects')).toBeVisible()
  const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)
  expect(mobileOverflow).toBeFalsy()
  await page.screenshot({ path: path.join(artifactDirectory, 'dev-docs-redesign-mobile.png'), fullPage: true })
})

async function login(page) {
  await page.goto(`${frontendBaseUrl}/login?mode=admin`)
  await page.getByTestId('login-id-input').fill(adminLoginId)
  await page.getByTestId('login-password-input').fill(adminPassword)
  await page.getByTestId('login-submit-button').click()
  await expect(page).toHaveURL(/\/admin$/)
}
