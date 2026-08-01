import fs from 'node:fs'
import path from 'node:path'
import { GraphBuilder, REPO_ROOT, readText, writeJson, exists } from './lib.mjs'

function parseRoutes(src) {
  /** @type {{ path: string, gated?: string }[]} */
  const routes = []
  const lines = src.split(/\r?\n/)
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^\s*'(\/[^']+)'\s*:\s*/)
    if (!m) continue
    const block = lines.slice(i, i + 25).join('\n')
    const flag = block.match(/FeatureFlags\.([A-Za-z0-9_]+)/)?.[1]
    routes.push({ path: m[1], gated: flag })
  }
  return routes
}

function listServices() {
  const dir = path.join(REPO_ROOT, 'lib/services')
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((n) => n.endsWith('.dart') && !n.endsWith('.g.dart'))
    .map((n) => ({
      file: `lib/services/${n}`,
      name: n.replace(/\.dart$/, ''),
    }))
    .sort((a, b) => a.name.localeCompare(b.name))
}

function scanPageServiceImports() {
  /** @type {Map<string, Set<string>>} */
  const pageToServices = new Map()
  const pagesRoot = path.join(REPO_ROOT, 'lib/pages')
  if (!fs.existsSync(pagesRoot)) return pageToServices

  const stack = [pagesRoot]
  while (stack.length) {
    const dir = stack.pop()
    for (const name of fs.readdirSync(dir)) {
      const full = path.join(dir, name)
      const st = fs.statSync(full)
      if (st.isDirectory()) {
        stack.push(full)
        continue
      }
      if (!name.endsWith('.dart')) continue
      const text = fs.readFileSync(full, 'utf8')
      const rel = path.relative(REPO_ROOT, full).replace(/\\/g, '/')
      const imports = [
        ...text.matchAll(/import\s+['"](?:package:moe_social\/)?(?:\.\.\/)*services\/([^'"]+)['"]/g),
        ...text.matchAll(/import\s+['"](?:\.\.\/)+services\/([^'"]+)['"]/g),
      ]
      for (const im of imports) {
        const svc = im[1].replace(/\.dart$/, '')
        if (!pageToServices.has(rel)) pageToServices.set(rel, new Set())
        pageToServices.get(rel).add(svc)
      }
    }
  }
  return pageToServices
}

function guessPageForRoute(routePath) {
  // heuristic mapping for graph navigation
  const map = {
    '/pet/home': 'lib/pages/pet/pet_home_page.dart',
    '/life/world': 'lib/pages/life/life_world_page.dart',
    '/ai-chat': 'lib/pages/companion/companion_chat_page.dart',
    '/ai-memories': 'lib/pages/companion/companion_memories_page.dart',
    '/home': 'lib/pages/feed/home_page.dart',
    '/settings': 'lib/pages/settings/settings_page.dart',
  }
  if (map[routePath] && exists(map[routePath])) return map[routePath]
  return 'lib/app/app_routes.dart'
}

export function generateFlutter() {
  const g = new GraphBuilder('flutter')
  g.addNode({
    id: 'root:flutter',
    kind: 'root',
    label: 'Flutter App',
    summary: 'routes → pages → domain services',
    ref_id: 'lib/app/app_routes.dart',
    weight: 4,
  })

  g.addNode({
    id: 'layer:routes',
    kind: 'layer',
    label: 'routes',
    summary: 'buildAppRoutes()',
    ref_id: 'lib/app/app_routes.dart',
    weight: 3,
  })
  g.addNode({
    id: 'layer:services',
    kind: 'layer',
    label: 'services',
    summary: 'lib/services',
    ref_id: 'lib/services',
    weight: 3,
  })
  g.addEdge('root:flutter', 'layer:routes', 'contains')
  g.addEdge('root:flutter', 'layer:services', 'contains')

  if (exists('lib/constants/feature_flags.dart')) {
    g.addNode({
      id: 'flags:feature',
      kind: 'flags',
      label: 'FeatureFlags',
      summary: 'lib/constants/feature_flags.dart',
      ref_id: 'lib/constants/feature_flags.dart',
      weight: 2,
    })
    g.addEdge('root:flutter', 'flags:feature', 'contains')
  }

  const routes = parseRoutes(readText('lib/app/app_routes.dart'))
  for (const r of routes) {
    const id = `route:${r.path}`
    g.addNode({
      id,
      kind: 'route',
      label: r.path,
      summary: r.gated ? `FeatureFlags.${r.gated}` : 'always',
      ref_id: 'lib/app/app_routes.dart',
      meta: { gated: r.gated || null },
      weight: r.gated ? 2 : 1,
    })
    g.addEdge('layer:routes', id, 'registers')
    if (r.gated && g.nodes.has('flags:feature')) {
      g.addEdge('flags:feature', id, 'gates')
    }
    const pageRef = guessPageForRoute(r.path)
    const pageId = `page:${pageRef}`
    g.addNode({
      id: pageId,
      kind: 'page',
      label: path.basename(pageRef, '.dart'),
      summary: pageRef,
      ref_id: pageRef,
    })
    g.addEdge(id, pageId, 'opens')
  }

  const services = listServices()
  for (const s of services) {
    const id = `service:${s.name}`
    g.addNode({
      id,
      kind: 'service',
      label: s.name,
      summary: s.file,
      ref_id: s.file,
    })
    g.addEdge('layer:services', id, 'contains')
  }

  const pageImports = scanPageServiceImports()
  let linkCount = 0
  for (const [pageFile, svcs] of pageImports) {
    const pageId = `page:${pageFile}`
    g.addNode({
      id: pageId,
      kind: 'page',
      label: path.basename(pageFile, '.dart'),
      summary: pageFile,
      ref_id: pageFile,
    })
    for (const svc of svcs) {
      const sid = `service:${svc}`
      if (!g.nodes.has(sid)) continue
      g.addEdge(pageId, sid, 'uses_service')
      linkCount++
    }
  }

  return writeJson(
    'flutter.json',
    g.build({
      routes: routes.length,
      services: services.length,
      pageServiceLinks: linkCount,
    }),
  )
}
