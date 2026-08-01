import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const REPO_ROOT = path.resolve(__dirname, '../..')
export const OUT_DIR = path.join(REPO_ROOT, 'moe-admin/public/dev/codegraph')

export function nowIso() {
  return new Date().toISOString()
}

export function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true })
}

export function readText(relOrAbs) {
  const p = path.isAbsolute(relOrAbs) ? relOrAbs : path.join(REPO_ROOT, relOrAbs)
  return fs.readFileSync(p, 'utf8')
}

export function exists(relOrAbs) {
  const p = path.isAbsolute(relOrAbs) ? relOrAbs : path.join(REPO_ROOT, relOrAbs)
  return fs.existsSync(p)
}

export function writeJson(filename, doc) {
  ensureDir(OUT_DIR)
  const out = path.join(OUT_DIR, filename)
  fs.writeFileSync(out, `${JSON.stringify(doc, null, 2)}\n`, 'utf8')
  return out
}

export function walkFiles(dir, pred, acc = []) {
  if (!fs.existsSync(dir)) return acc
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name)
    const st = fs.statSync(full)
    if (st.isDirectory()) walkFiles(full, pred, acc)
    else if (pred(full, name)) acc.push(full)
  }
  return acc
}

/** @typedef {{ id: string, kind: string, label: string, summary?: string, weight?: number, ref_id?: string, meta?: Record<string, unknown> }} CodeGraphNode */
/** @typedef {{ id: string, source: string, target: string, relation: string, weight?: number }} CodeGraphEdge */

export class GraphBuilder {
  /** @param {string} domain */
  constructor(domain) {
    this.domain = domain
    /** @type {Map<string, CodeGraphNode>} */
    this.nodes = new Map()
    /** @type {CodeGraphEdge[]} */
    this.edges = []
    this._edgeKeys = new Set()
  }

  /**
   * @param {Omit<CodeGraphNode, 'weight'> & { weight?: number }} node
   */
  addNode(node) {
    if (this.nodes.has(node.id)) return this.nodes.get(node.id)
    const n = {
      weight: 1,
      ...node,
    }
    this.nodes.set(n.id, n)
    return n
  }

  /**
   * @param {string} source
   * @param {string} target
   * @param {string} relation
   * @param {number} [weight]
   */
  addEdge(source, target, relation, weight = 1) {
    if (!this.nodes.has(source) || !this.nodes.has(target)) return
    const key = `${source}|${relation}|${target}`
    if (this._edgeKeys.has(key)) return
    this._edgeKeys.add(key)
    this.edges.push({
      id: `e:${key}`,
      source,
      target,
      relation,
      weight,
    })
  }

  /** @param {Record<string, number>} [stats] */
  build(stats = {}) {
    return {
      schemaVersion: 1,
      domain: this.domain,
      generatedAt: nowIso(),
      nodes: [...this.nodes.values()],
      edges: this.edges,
      stats: {
        nodeCount: this.nodes.size,
        edgeCount: this.edges.length,
        ...stats,
      },
    }
  }
}

export function relPosix(...parts) {
  return path.posix.join(...parts.map((p) => p.replace(/\\/g, '/')))
}
