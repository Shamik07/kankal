import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    exclude: ['**/node_modules/**', '**/dist/**', 'e2e/**'],
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
