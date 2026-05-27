/** RPC debug API（经 Vite → deploy-agent :19010 → RPC :19011） */

export type RpcLiveMemory = {
  alloc_mb?: number
  heap_inuse_mb?: number
  heap_sys_mb?: number
  sys_mb?: number
}

export type RpcLiveGC = {
  num_gc?: number
  pause_total_ms?: number
  gc_cpu_fraction?: number
}

export type RpcLiveSnapshot = {
  timestamp?: string
  pid?: number
  goroutines?: number
  memory?: RpcLiveMemory
  gc?: RpcLiveGC
  process?: {
    pid?: number
    rss_mb?: number
    go_alloc_mb?: number
    go_sys_mb?: number
    goroutines?: number
  }
}

export type RpcHeapRow = {
  function: string
  file?: string
  inuse_mb: number
  objects: number
}

export type RpcLogEntry = {
  id?: number
  timestamp?: string
  level?: string
  message?: string
}

export type RpcLogsResult = {
  entries?: RpcLogEntry[]
  counts?: { error?: number; warn?: number; info?: number }
}

const debugBase = () => window.location.origin

async function debugFetch<T>(path: string): Promise<T> {
  const res = await fetch(`${debugBase()}${path}`)
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}`)
  }
  return res.json() as Promise<T>
}

export function fetchRpcLive() {
  return debugFetch<RpcLiveSnapshot>('/debug/live')
}

export function fetchRpcHeapTop(limit = 12) {
  return debugFetch<{ top?: RpcHeapRow[]; hint?: string }>(`/debug/heap-top?limit=${limit}`)
}

export function fetchRpcGoroutineSummary() {
  return debugFetch<{ goroutines?: number; sample_top?: string[]; hint?: string }>(
    '/debug/goroutine-summary',
  )
}

export function fetchRpcLogs(params: {
  level?: string
  q?: string
  limit?: number
}) {
  const q = new URLSearchParams()
  if (params.level) q.set('level', params.level)
  if (params.q) q.set('q', params.q)
  if (params.limit) q.set('limit', String(params.limit))
  const qs = q.toString()
  return debugFetch<RpcLogsResult>(`/debug/logs${qs ? `?${qs}` : ''}`)
}

export function fmtMb(n: number | undefined) {
  if (n === undefined || Number.isNaN(n)) return '—'
  return `${n.toFixed(2)} MB`
}
