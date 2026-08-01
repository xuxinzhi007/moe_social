import fs from 'node:fs'
import path from 'node:path'
import { GraphBuilder, REPO_ROOT, exists, writeJson, walkFiles } from './lib.mjs'

/**
 * Lightweight OpenAPI paths extractor (no YAML dependency).
 * @returns {{ path: string, method: string, operationId: string, tag: string }[]}
 */
function parseOpenApiPaths(yamlText) {
  /** @type {{ path: string, method: string, operationId: string, tag: string }[]} */
  const ops = []
  const lines = yamlText.split(/\r?\n/)
  let inPaths = false
  /** @type {string|null} */
  let currentPath = null
  /** @type {string|null} */
  let currentMethod = null
  /** @type {string} */
  let operationId = ''
  /** @type {string} */
  let tag = ''
  let pathIndent = 0
  let inTags = false

  const methods = new Set(['get', 'post', 'put', 'patch', 'delete', 'options', 'head'])

  const flush = () => {
    if (!currentPath || !currentMethod) return
    ops.push({
      path: currentPath,
      method: currentMethod,
      operationId: operationId || `${currentMethod}_${currentPath}`,
      tag: tag || domainFromPath(currentPath),
    })
    currentMethod = null
    operationId = ''
    tag = ''
    inTags = false
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (/^paths:\s*$/.test(line)) {
      inPaths = true
      continue
    }
    if (inPaths && /^[a-zA-Z_]/.test(line) && !line.startsWith(' ')) {
      flush()
      break
    }
    if (!inPaths) continue

    const pathM = line.match(/^(\s+)(\/[^:]+):\s*$/)
    if (pathM) {
      flush()
      currentPath = pathM[2]
      pathIndent = pathM[1].length
      continue
    }

    if (!currentPath) continue

    const methodM = line.match(/^(\s+)([a-z]+):\s*$/)
    if (methodM && methods.has(methodM[2]) && methodM[1].length > pathIndent) {
      flush()
      currentMethod = methodM[2]
      operationId = ''
      tag = ''
      inTags = false
      continue
    }

    if (!currentMethod) continue

    if (/^\s+tags:\s*$/.test(line)) {
      inTags = true
      continue
    }
    if (inTags) {
      const tagItem = line.match(/^\s+-\s+([A-Za-z0-9_.-]+)\s*$/)
      if (tagItem) {
        tag = tagItem[1]
        inTags = false
        continue
      }
      inTags = false
    }

    const opM = line.match(/operationId:\s*['"]?([^\s'"]+)/)
    if (opM) operationId = opM[1]
  }

  flush()
  return ops
}

function domainFromPath(p) {
  // /api/user/v1/... or /api/admin/...
  const parts = p.split('/').filter(Boolean)
  if (parts[0] === 'api' && parts[1]) return parts[1]
  return parts[0] || 'unknown'
}

function listServiceDomains() {
  const root = path.join(REPO_ROOT, 'backend/internal/service')
  if (!fs.existsSync(root)) return []
  return fs
    .readdirSync(root)
    .filter((n) => fs.statSync(path.join(root, n)).isDirectory())
    .sort()
}

function listBizDomains() {
  const root = path.join(REPO_ROOT, 'backend/internal/biz')
  if (!fs.existsSync(root)) return []
  return fs
    .readdirSync(root)
    .filter((n) => fs.statSync(path.join(root, n)).isDirectory())
    .sort()
}

function listProtoDomains() {
  const root = path.join(REPO_ROOT, 'backend/api')
  if (!fs.existsSync(root)) return []
  return fs
    .readdirSync(root)
    .filter((n) => fs.statSync(path.join(root, n)).isDirectory())
    .sort()
}

export function generateBackend() {
  const g = new GraphBuilder('backend')
  g.addNode({
    id: 'root:backend',
    kind: 'root',
    label: 'backend',
    summary: 'proto / OpenAPI → service → biz',
    ref_id: 'backend',
    weight: 4,
  })

  const layerIds = {
    proto: 'layer:proto',
    service: 'layer:service',
    biz: 'layer:biz',
    http: 'layer:http',
  }
  for (const [k, id] of Object.entries(layerIds)) {
    g.addNode({
      id,
      kind: 'layer',
      label: k,
      summary: `internal/${k === 'http' ? 'server/protohttp' : k === 'proto' ? '../api' : k}`,
      ref_id:
        k === 'proto'
          ? 'backend/api'
          : k === 'http'
            ? 'backend/internal/server/protohttp'
            : `backend/internal/${k}`,
      weight: 3,
    })
    g.addEdge('root:backend', id, 'contains')
  }

  const serviceDomains = listServiceDomains()
  const bizDomains = listBizDomains()
  const protoDomains = listProtoDomains()

  for (const d of protoDomains) {
    const id = `proto:${d}`
    g.addNode({
      id,
      kind: 'domain',
      label: d,
      summary: `backend/api/${d}`,
      ref_id: `backend/api/${d}`,
      weight: 2,
      meta: { layer: 'proto' },
    })
    g.addEdge(layerIds.proto, id, 'contains')
  }

  for (const d of serviceDomains) {
    const id = `service:${d}`
    g.addNode({
      id,
      kind: 'service',
      label: `${d} service`,
      summary: `backend/internal/service/${d}`,
      ref_id: `backend/internal/service/${d}`,
      weight: 2,
    })
    g.addEdge(layerIds.service, id, 'contains')
    if (g.nodes.has(`proto:${d}`)) g.addEdge(`proto:${d}`, id, 'implements')
  }

  for (const d of bizDomains) {
    const id = `biz:${d}`
    g.addNode({
      id,
      kind: 'biz',
      label: `${d} biz`,
      summary: `backend/internal/biz/${d}`,
      ref_id: `backend/internal/biz/${d}`,
      weight: 2,
    })
    g.addEdge(layerIds.biz, id, 'contains')
    if (g.nodes.has(`service:${d}`)) g.addEdge(`service:${d}`, id, 'calls')
  }

  let ops = []
  if (exists('backend/openapi.yaml')) {
    ops = parseOpenApiPaths(fs.readFileSync(path.join(REPO_ROOT, 'backend/openapi.yaml'), 'utf8'))
  }

  // Fallback: scan *_http.pb.go route registrations if openapi empty
  if (ops.length === 0) {
    const httpFiles = walkFiles(path.join(REPO_ROOT, 'backend'), (f) =>
      f.endsWith('_http.pb.go'),
    )
    for (const f of httpFiles) {
      const text = fs.readFileSync(f, 'utf8')
      const re = /r\.(GET|POST|PUT|PATCH|DELETE)\("([^"]+)"/g
      let m
      while ((m = re.exec(text))) {
        ops.push({
          path: m[2],
          method: m[1].toLowerCase(),
          operationId: `${m[1]}_${m[2]}`,
          tag: domainFromPath(m[2]),
        })
      }
    }
  }

  /** @type {Map<string, number>} */
  const perDomain = new Map()
  for (const op of ops) {
    const domain = (op.tag || domainFromPath(op.path)).toLowerCase().replace(/[^a-z0-9_]/g, '')
    perDomain.set(domain, (perDomain.get(domain) || 0) + 1)

    const domainNode = `httpdomain:${domain}`
    if (!g.nodes.has(domainNode)) {
      g.addNode({
        id: domainNode,
        kind: 'http_domain',
        label: domain,
        summary: 'OpenAPI tag / path domain',
        ref_id: 'backend/openapi.yaml',
        weight: 2,
      })
      g.addEdge(layerIds.http, domainNode, 'contains')
    }

    const opId = `op:${op.method}:${op.path}`
    g.addNode({
      id: opId,
      kind: 'http_op',
      label: `${op.method.toUpperCase()} ${op.path}`,
      summary: op.operationId,
      ref_id: op.path,
      meta: {
        method: op.method,
        operationId: op.operationId,
        domain,
      },
    })
    g.addEdge(domainNode, opId, 'exposes')

    const svc = `service:${domain}`
    if (g.nodes.has(svc)) g.addEdge(opId, svc, 'http_to_service')
    else {
      // fuzzy: companion → companion, moe-admin → moe
      const fuzzy = serviceDomains.find(
        (d) => domain.includes(d) || d.includes(domain) || domain.startsWith(d),
      )
      if (fuzzy) g.addEdge(opId, `service:${fuzzy}`, 'http_to_service')
    }
  }

  // Update http_domain summaries with counts
  for (const [domain, count] of perDomain) {
    const n = g.nodes.get(`httpdomain:${domain}`)
    if (n) n.summary = `${count} operations`
  }

  return writeJson(
    'backend.json',
    g.build({
      httpOps: ops.length,
      serviceDomains: serviceDomains.length,
      bizDomains: bizDomains.length,
      protoDomains: protoDomains.length,
    }),
  )
}
