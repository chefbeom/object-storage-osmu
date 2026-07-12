import { chromium } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'

const baseUrl = process.env.OSMU_FRONTEND_BASE_URL || 'http://localhost:5173'
const loginId = process.env.OSMU_ADMIN_LOGIN_ID || 'admin'
const password = process.env.OSMU_ADMIN_PASSWORD || 'password'
const outputDir = resolve(process.cwd(), '..', 'docs', 'assets')

await mkdir(outputDir, { recursive: true })

const browser = await chromium.launch({
  channel: process.env.OSMU_PLAYWRIGHT_CHANNEL || 'chrome',
  headless: true,
})
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1 })

try {
  await page.goto(`${baseUrl}/login?mode=admin`, { waitUntil: 'networkidle' })
  await page.getByTestId('login-id-input').fill(loginId)
  await page.getByTestId('login-password-input').fill(password)
  await page.getByTestId('login-submit-button').click()
  await page.getByTestId('logout-button').waitFor()

  const pages = [
    ['dashboard', '/dashboard'],
    ['admin', '/admin'],
    ['developer', '/developer'],
    ['quick-start', '/quick-start'],
  ]

  for (const [name, path] of pages) {
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'networkidle' })
    await page.waitForTimeout(600)
    await page.screenshot({ path: resolve(outputDir, `portfolio-${name}.png`), fullPage: false })
  }
} finally {
  await browser.close()
}
