import { defineConfig } from '@playwright/test'

const browserChannel = process.env.OSMU_PLAYWRIGHT_CHANNEL || ''

export default defineConfig({
  use: {
    browserName: 'chromium',
    channel: browserChannel || undefined,
    headless: true,
  },
})
