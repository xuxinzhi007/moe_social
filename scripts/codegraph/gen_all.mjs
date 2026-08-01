#!/usr/bin/env node
/**
 * Regenerate developer CodeGraph JSON into moe-admin/public/dev/codegraph/.
 *
 * Usage (repo root):
 *   node scripts/codegraph/gen_all.mjs
 *   npm run codegraph:gen   (from moe-admin/)
 */
import { ensureDir, nowIso, OUT_DIR, writeJson } from './lib.mjs'
import { generatePet } from './gen_pet.mjs'
import { generateAdmin } from './gen_admin.mjs'
import { generateBackend } from './gen_backend.mjs'
import { generateFlutter } from './gen_flutter.mjs'

function main() {
  ensureDir(OUT_DIR)
  const outputs = {
    pet: generatePet(),
    admin: generateAdmin(),
    backend: generateBackend(),
    flutter: generateFlutter(),
  }

  const index = {
    schemaVersion: 1,
    generatedAt: nowIso(),
    domains: [
      {
        id: 'pet',
        label: 'Pet 内容包',
        file: 'pet.json',
        description: 'admin 预览包 / Flutter 运行时包 → manifest → assets → consumers',
      },
      {
        id: 'admin',
        label: 'Admin 路由',
        file: 'admin.json',
        description: 'workspace → nav → App route → page → feature',
      },
      {
        id: 'backend',
        label: 'Backend API',
        file: 'backend.json',
        description: 'OpenAPI / proto → service → biz',
      },
      {
        id: 'flutter',
        label: 'Flutter',
        file: 'flutter.json',
        description: 'routes → pages → domain services',
      },
    ],
    outputs,
  }
  writeJson('index.json', index)

  console.log('CodeGraph generated →', OUT_DIR)
  for (const [k, v] of Object.entries(outputs)) {
    console.log(`  ${k}: ${v}`)
  }
}

main()
