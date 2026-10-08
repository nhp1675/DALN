import { defineConfig } from '@playwright/test';
export default defineConfig({
 testDir: './tests/ui', timeout: 60000, workers: 1,
 use: { baseURL: 'http://127.0.0.1:4173', browserName: 'chromium', trace: 'retain-on-failure' },
 webServer: { command: 'node tests/web-preview.js', url: 'http://127.0.0.1:4173', reuseExistingServer: false },
});
