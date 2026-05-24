import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base: '/ops/',
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': { target: 'http://127.0.0.1:19010', changeOrigin: true },
      '/debug': { target: 'http://127.0.0.1:19010', changeOrigin: true },
      '/tools': { target: 'http://127.0.0.1:19010', changeOrigin: true },
      '/devtools.html': { target: 'http://127.0.0.1:19010', changeOrigin: true },
      '/index.html': { target: 'http://127.0.0.1:19010', changeOrigin: true },
    },
  },
  preview: {
    port: 4173,
    strictPort: true,
  },
})
