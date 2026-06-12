import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './specs',
  timeout: 30000,
  expect: { timeout: 10000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.TEST_BASE_URL || 'http://127.0.0.1:9900',
    trace: 'off',
    screenshot: 'only-on-failure',
    video: 'off',
    headless: !!process.env.HEADLESS,
  },
  projects: [{
    name: 'chrome-local',
    use: {
      ...devices['Desktop Chrome'],
      channel: 'chrome',
      viewport: { width: 1440, height: 900 },
    },
  }],
});
