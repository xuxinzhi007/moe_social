import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath } from 'node:url'

const workspaceRoot = fileURLToPath(new URL('../..', import.meta.url))
const sharedPublic = fileURLToPath(new URL('../../moe-admin/public', import.meta.url))

export default defineConfig({
  plugins: [react()],
  base: '/',
  publicDir: sharedPublic,
  server: {
    host: '127.0.0.1',
    port: 5174,
    strictPort: true,
    fs: {
      allow: [workspaceRoot],
    },
  },
  preview: {
    port: 4174,
    strictPort: true,
  },
})
