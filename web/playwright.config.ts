import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  workers: 3,
  forbidOnly: true,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results/e2e-report.json' }],
  ],
  use: {
    baseURL: 'http://127.0.0.1:4187',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'], channel: 'chrome' } },
    { name: 'mobile-chromium', use: { ...devices['Pixel 7'], channel: 'chrome' } },
    { name: 'narrow-chromium', use: { viewport: { width: 320, height: 700 }, channel: 'chrome' } },
  ],
  webServer: {
    command: 'bun run dev --host 127.0.0.1 --port 4187 --strictPort',
    url: 'http://127.0.0.1:4187/sign-in',
    reuseExistingServer: false,
    timeout: 30_000,
  },
})
