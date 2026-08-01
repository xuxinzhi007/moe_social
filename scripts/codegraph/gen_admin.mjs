import fs from 'node:fs'
import path from 'node:path'
import { GraphBuilder, REPO_ROOT, readText, writeJson, exists } from './lib.mjs'

function parseNav(src) {
  /** @type {{ workspace: string, groupId: string|null, groupLabel: string|null, to: string, label: string, title?: string }[]} */
  const items = []
  let workspace = null
  /** @type {string|null} */
  let groupId = null
  /** @type {string|null} */
  let groupLabel = null
  let inGroupChildren = false

  const lines = src.split(/\r?\n/)
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    const ws = line.match(/^\s*(biz|ai|infra):\s*\[/)
    if (ws) {
      workspace = ws[1]
      groupId = null
      groupLabel = null
      inGroupChildren = false
      continue
    }

    if (!workspace) continue

    if (line.includes("kind: 'group'") || line.includes('kind: "group"')) {
      const block = lines.slice(i, i + 12).join('\n')
      groupId = block.match(/id:\s*['"]([^'"]+)['"]/)?.[1] ?? 'group'
      groupLabel = block.match(/label:\s*['"]([^'"]+)['"]/)?.[1] ?? groupId
      inGroupChildren = false
      continue
    }

    if (groupId && /children:\s*\[/.test(line)) {
      inGroupChildren = true
      continue
    }

    if (inGroupChildren && /^\s*\],?\s*$/.test(line)) {
      inGroupChildren = false
      groupId = null
      groupLabel = null
      continue
    }

    // workspace-level item (not inside children)
    if (
      !inGroupChildren &&
      (line.includes("kind: 'item'") || line.includes('kind: "item"'))
    ) {
      groupId = null
      groupLabel = null
    }

    const toM = line.match(/to:\s*['"](\/[^'"]+)['"]/)
    if (!toM) continue
    const block = lines.slice(Math.max(0, i - 3), i + 8).join('\n')
    if (block.includes("kind: 'group'") && !block.includes("kind: 'item'")) {
      continue
    }
    const labelM = block.match(/label:\s*['"]([^'"]+)['"]/)
    const titleM = block.match(/title:\s*['"]([^'"]+)['"]/)
    items.push({
      workspace,
      groupId: inGroupChildren ? groupId : null,
      groupLabel: inGroupChildren ? groupLabel : null,
      to: toM[1],
      label: labelM?.[1] || toM[1],
      title: titleM?.[1],
    })
  }
  return items
}

function parseAppRoutes(src) {
  /** @type {{ path: string, page: string }[]} */
  const routes = []
  const re =
    /<Route\s+path=["']([^"']+)["']\s+element=\{(?:<Navigate[\s\S]*?\/>|<([A-Za-z0-9_]+))/g
  let m
  while ((m = re.exec(src))) {
    let routePath = m[1]
    const page = m[2] || 'Navigate'
    if (routePath.includes('*')) continue
    if (!routePath.startsWith('/')) routePath = `/${routePath}`
    routes.push({ path: routePath, page })
  }
  return routes
}

function guessPageFile(page) {
  if (page === 'Navigate') return null
  const candidates = [
    `moe-admin/src/pages/${page}.tsx`,
    `moe-admin/src/pages/${page}.ts`,
  ]
  for (const c of candidates) {
    if (exists(c)) return c
  }
  if (page === 'PetDecorEditorPage' || page === 'PetContentHubPage') {
    return 'moe-admin/src/pages/PetContentHubPage.tsx'
  }
  return `moe-admin/src/pages/${page}.tsx`
}

export function generateAdmin() {
  const g = new GraphBuilder('admin')
  g.addNode({
    id: 'root:admin',
    kind: 'root',
    label: 'moe-admin',
    summary: 'workspace → nav → route → page',
    ref_id: 'moe-admin/src/App.tsx',
    weight: 4,
  })

  const navItems = parseNav(readText('moe-admin/src/config/workspaceNav.ts'))
  const routes = parseAppRoutes(readText('moe-admin/src/App.tsx'))

  for (const ws of ['biz', 'ai', 'infra']) {
    g.addNode({
      id: `ws:${ws}`,
      kind: 'workspace',
      label: ws,
      summary: 'WorkspaceId',
      ref_id: 'moe-admin/src/config/workspaceNav.ts',
      weight: 3,
    })
    g.addEdge('root:admin', `ws:${ws}`, 'contains')
  }

  const groupSeen = new Set()
  for (const item of navItems) {
    const wsId = `ws:${item.workspace}`
    let parent = wsId
    if (item.groupId) {
      const gid = `navgroup:${item.groupId}`
      if (!groupSeen.has(gid)) {
        groupSeen.add(gid)
        g.addNode({
          id: gid,
          kind: 'nav_group',
          label: item.groupLabel || item.groupId,
          summary: item.groupId,
          ref_id: 'moe-admin/src/config/workspaceNav.ts',
          weight: 2,
        })
        g.addEdge(wsId, gid, 'contains')
      }
      parent = gid
    }
    const navId = `nav:${item.to}`
    g.addNode({
      id: navId,
      kind: 'nav_item',
      label: item.label,
      summary: item.title || item.to,
      ref_id: item.to,
      meta: { to: item.to },
      weight: 2,
    })
    g.addEdge(parent, navId, 'nav_to')
  }

  for (const r of routes) {
    const routeId = `route:${r.path}`
    const pageFile = guessPageFile(r.page)
    g.addNode({
      id: routeId,
      kind: 'route',
      label: r.path,
      summary: r.page,
      ref_id: 'moe-admin/src/App.tsx',
      meta: { page: r.page },
    })
    g.addEdge('root:admin', routeId, 'registers')

    if (r.page !== 'Navigate' && pageFile) {
      const pageId = `page:${r.page}`
      g.addNode({
        id: pageId,
        kind: 'page',
        label: r.page,
        summary: pageFile,
        ref_id: pageFile,
        weight: 2,
      })
      g.addEdge(routeId, pageId, 'implements')
    }

    const navId = `nav:${r.path}`
    if (g.nodes.has(navId)) g.addEdge(navId, routeId, 'opens')
  }

  const featureRoot = path.join(REPO_ROOT, 'moe-admin/src/features')
  if (fs.existsSync(featureRoot)) {
    for (const name of fs.readdirSync(featureRoot)) {
      const full = path.join(featureRoot, name)
      if (!fs.statSync(full).isDirectory()) continue
      const fid = `feature:${name}`
      g.addNode({
        id: fid,
        kind: 'feature',
        label: name,
        summary: `moe-admin/src/features/${name}`,
        ref_id: `moe-admin/src/features/${name}`,
      })
      g.addEdge('root:admin', fid, 'contains')
      if (name.startsWith('moe-') || name.includes('pet') || name.includes('content')) {
        for (const page of ['PetContentHubPage', 'PetAvatarEditorPage', 'PetFurnitureEditorPage']) {
          const pageId = `page:${page}`
          if (g.nodes.has(pageId)) g.addEdge(pageId, fid, 'uses_feature')
        }
      }
    }
  }

  return writeJson(
    'admin.json',
    g.build({
      navItems: navItems.length,
      routes: routes.length,
    }),
  )
}
