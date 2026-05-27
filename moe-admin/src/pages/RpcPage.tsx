import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { MonitorPageLayout } from '../ui'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'
import {
  fetchRpcGoroutineSummary,
  fetchRpcHeapTop,
  fetchRpcLive,
  fetchRpcLogs,
  fmtMb,
  type RpcHeapRow,
  type RpcLiveSnapshot,
  type RpcLogEntry,
} from '../lib/rpcMonitor'

type Tab = 'metrics' | 'logs'

const HEAP_HISTORY_MAX = 24

export function RpcPage() {
  const { client } = useAdminAuth()
  const [tab, setTab] = useState<Tab>('metrics')
  const [autoRefresh, setAutoRefresh] = useState(true)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [lastUpdate, setLastUpdate] = useState('')

  const [runtime, setRuntime] = useState<{
    layout: string
    processes_note: string
    estimated_rss_mb: number
    rpc_monitor_online: boolean
    api_process: {
      pid: number
      go_alloc_mb: number
      go_sys_mb: number
      rss_mb: number
      goroutines: number
      same_process?: boolean
    }
    rpc_process: {
      pid: number
      go_alloc_mb: number
      go_sys_mb: number
      rss_mb: number
      goroutines: number
      reachable: boolean
      same_process?: boolean
    }
  } | null>(null)

  const [live, setLive] = useState<RpcLiveSnapshot | null>(null)
  const [heapTop, setHeapTop] = useState<RpcHeapRow[]>([])
  const [heapHint, setHeapHint] = useState('')
  const [goroutineCount, setGoroutineCount] = useState(0)
  const [goroutineSamples, setGoroutineSamples] = useState<string[]>([])
  const [heapHistory, setHeapHistory] = useState<Array<{ t: string; mb: number }>>([])

  const [logs, setLogs] = useState<RpcLogEntry[]>([])
  const [logLevel, setLogLevel] = useState('')
  const [logKeyword, setLogKeyword] = useState('')
  const [logCounts, setLogCounts] = useState({ error: 0, warn: 0 })

  const connected = live !== null && !error

  const pushHeapPoint = useCallback((snap: RpcLiveSnapshot) => {
    const mb = snap.memory?.heap_inuse_mb ?? snap.process?.go_alloc_mb ?? 0
    const label = (snap.timestamp ?? new Date().toISOString()).slice(11, 19)
    setHeapHistory((prev) => {
      const next = [...prev, { t: label, mb }]
      if (next.length > HEAP_HISTORY_MAX) next.shift()
      return next
    })
  }, [])

  const refreshMetrics = useCallback(async () => {
    const liveRes = await fetchRpcLive()
    setLive(liveRes)
    pushHeapPoint(liveRes)
    const heapRes = await fetchRpcHeapTop(12)
    setHeapTop(heapRes.top ?? [])
    setHeapHint(heapRes.hint ?? '')
    const gRes = await fetchRpcGoroutineSummary()
    setGoroutineCount(gRes.goroutines ?? 0)
    setGoroutineSamples(gRes.sample_top ?? [])
  }, [pushHeapPoint])

  const refreshLogs = useCallback(async () => {
    const res = await fetchRpcLogs({
      level: logLevel || undefined,
      q: logKeyword.trim() || undefined,
      limit: 100,
    })
    setLogs(res.entries ?? [])
    setLogCounts({
      error: res.counts?.error ?? 0,
      warn: res.counts?.warn ?? 0,
    })
  }, [logKeyword, logLevel])

  const refreshAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const rtRes = await client.getRuntimeOverview()
      if (rtRes.success && rtRes.data) setRuntime(rtRes.data)
      try {
        await refreshMetrics()
        setError('')
      } catch (e) {
        setLive(null)
        setError(
          e instanceof Error
            ? `连接失败：${e.message}。请确认 make moe-social / make dev 已启动（含 -monitor）。`
            : '连接失败',
        )
      }
      setLastUpdate(new Date().toLocaleTimeString())
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '无法加载运行时概览')
    } finally {
      setLoading(false)
    }
  }, [client, refreshMetrics])

  useEffect(() => {
    void refreshAll()
  }, [refreshAll])

  useEffect(() => {
    if (!autoRefresh) return
    const id = window.setInterval(() => {
      if (tab === 'metrics') void refreshMetrics().catch(() => {})
      else void refreshLogs().catch(() => {})
    }, 3000)
    return () => window.clearInterval(id)
  }, [autoRefresh, tab, refreshMetrics, refreshLogs])

  useEffect(() => {
    if (tab === 'logs') void refreshLogs()
  }, [tab, refreshLogs])

  const metricCards = useMemo(() => {
    if (!live) return []
    const m = live.memory ?? {}
    const g = live.gc ?? {}
    return [
      { label: '当前分配', value: fmtMb(m.alloc_mb), sub: 'Alloc' },
      { label: '堆在用', value: fmtMb(m.heap_inuse_mb), sub: 'HeapInuse' },
      { label: '堆已申请', value: fmtMb(m.heap_sys_mb), sub: 'HeapSys' },
      { label: '系统总占用', value: fmtMb(m.sys_mb), sub: 'Sys' },
      { label: 'Goroutines', value: String(live.goroutines ?? '—'), sub: '协程' },
      { label: 'GC 次数', value: String(g.num_gc ?? 0), sub: '累计' },
      {
        label: 'GC 总暂停',
        value: `${(g.pause_total_ms ?? 0).toFixed(1)} ms`,
        sub: 'PauseTotal',
      },
      {
        label: 'GC CPU',
        value: `${((g.gc_cpu_fraction ?? 0) * 100).toFixed(2)}%`,
        sub: 'GCCPU',
      },
    ]
  }, [live])

  return (
    <MonitorPageLayout
      title="RPC 监控"
      description="原生管理台页面 · Go 堆内存与 RPC 日志 · 经 Agent 转发 debug API"
      headActions={
        <div className="btn-row">
          <label className="checkbox-inline">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
            />
            自动刷新 3s
          </label>
          <button
            type="button"
            className="btn btn-primary"
            disabled={loading}
            onClick={() => void refreshAll()}
          >
            {loading ? '刷新中…' : '立即刷新'}
          </button>
        </div>
      }
    >
      {runtime && (
        <div className="card rpc-runtime-card">
          <h3 className="rpc-section-title">本机服务内存</h3>
          <p className="muted rpc-runtime-note">{runtime.processes_note}</p>
          <div className="stat-grid">
            <div className="stat-card">
              <span className="stat-label">预估总 RSS</span>
              <strong className="stat-value">{runtime.estimated_rss_mb.toFixed(1)} MB</strong>
              <span className="stat-sub">布局：{runtime.layout}</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">API 进程 (PID {runtime.api_process.pid})</span>
              <strong className="stat-value">
                RSS {runtime.api_process.rss_mb.toFixed(1)} MB
              </strong>
              <span className="stat-sub">
                Go 堆 {runtime.api_process.go_alloc_mb.toFixed(1)} MB ·{' '}
                {runtime.api_process.goroutines} goroutines
              </span>
            </div>
            <div className="stat-card">
              <span className="stat-label">
                RPC 进程
                {runtime.rpc_process.pid > 0 ? ` (PID ${runtime.rpc_process.pid})` : ''}
              </span>
              <strong className="stat-value">
                {runtime.rpc_process.reachable
                  ? `RSS ${runtime.rpc_process.rss_mb.toFixed(1)} MB`
                  : '未连接'}
              </strong>
              <span className="stat-sub">
                {runtime.rpc_process.reachable
                  ? `Go 堆 ${runtime.rpc_process.go_alloc_mb.toFixed(1)} MB · ${runtime.rpc_process.goroutines} goroutines`
                  : '请启动 -monitor'}
              </span>
            </div>
          </div>
        </div>
      )}

      <div className="rpc-status-bar">
        <span className={`rpc-status-dot${connected ? ' ok' : ' err'}`} />
        <span>{connected ? 'RPC debug 已连接' : error || '等待连接…'}</span>
        {lastUpdate && <span className="muted rpc-status-time">更新 {lastUpdate}</span>}
      </div>

      {error && <p className="form-error">{error}</p>}

      <div className="tab-bar">
        <button
          type="button"
          className={`tab-btn${tab === 'metrics' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('metrics')}
        >
          性能指标
        </button>
        <button
          type="button"
          className={`tab-btn${tab === 'logs' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('logs')}
        >
          日志查询
          {(logCounts.error > 0 || logCounts.warn > 0) && (
            <span className="rpc-log-badge">
              {logCounts.error > 0 ? `${logCounts.error} err` : ''}
              {logCounts.warn > 0 ? ` ${logCounts.warn} warn` : ''}
            </span>
          )}
        </button>
      </div>

      {tab === 'metrics' && (
        <>
          <div className="rpc-metric-grid">
            {metricCards.map((c) => (
              <div key={c.sub} className="stat-card">
                <span className="stat-label">{c.label}</span>
                <strong className="stat-value">{c.value}</strong>
                <span className="stat-sub">{c.sub}</span>
              </div>
            ))}
          </div>

          <div className="chart-card">
            <h3 className="chart-card-title">堆内存趋势（采样）</h3>
            <div style={{ width: '100%', height: 200 }}>
              <ResponsiveContainer>
                <AreaChart data={heapHistory}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e8ecf2" />
                  <XAxis dataKey="t" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} width={48} unit=" MB" />
                  <Tooltip formatter={(v: number) => [`${v.toFixed(2)} MB`, '堆在用']} />
                  <Area
                    type="monotone"
                    dataKey="mb"
                    stroke="#7f7fd5"
                    fill="rgba(127,127,213,0.2)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="rpc-two-col">
            <div className="card">
              <h3 className="rpc-section-title">内存占用 Top（按函数）</h3>
              <table className="data-table">
                <thead>
                  <tr>
                    <th>函数</th>
                    <th>在用</th>
                    <th>对象数</th>
                  </tr>
                </thead>
                <tbody>
                  {heapTop.map((row) => (
                    <tr key={row.function}>
                      <td className="cell-mono">{row.function}</td>
                      <td>{row.inuse_mb.toFixed(2)} MB</td>
                      <td>{row.objects}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {heapHint && <p className="muted">{heapHint}</p>}
            </div>
            <div className="card">
              <h3 className="rpc-section-title">Goroutine 概况</h3>
              <p>
                当前 <strong>{goroutineCount}</strong> 个 goroutine
              </p>
              <pre className="rpc-stack-sample">
                {(goroutineSamples.length > 0
                  ? goroutineSamples
                  : ['暂无采样']
                ).join('\n\n')}
              </pre>
            </div>
          </div>
        </>
      )}

      {tab === 'logs' && (
        <div className="card">
          <h3 className="rpc-section-title">RPC 日志（内存环形缓冲）</h3>
          <div className="filter-bar rpc-log-filters">
            <button
              type="button"
              className={`level-chip${logLevel === '' ? ' active' : ''}`}
              onClick={() => setLogLevel('')}
            >
              全部
            </button>
            <button
              type="button"
              className={`level-chip${logLevel === 'error' ? ' err-active' : ''}`}
              onClick={() => setLogLevel('error')}
            >
              错误 {logCounts.error}
            </button>
            <button
              type="button"
              className={`level-chip${logLevel === 'warn' ? ' warn-active' : ''}`}
              onClick={() => setLogLevel('warn')}
            >
              警告 {logCounts.warn}
            </button>
            <input
              type="search"
              placeholder="搜索关键词…"
              value={logKeyword}
              onChange={(e) => setLogKeyword(e.target.value)}
            />
            <button type="button" className="btn btn-secondary" onClick={() => void refreshLogs()}>
              刷新日志
            </button>
          </div>
          <div className="table-card rpc-log-table">
            <table className="data-table">
              <thead>
                <tr>
                  <th>时间</th>
                  <th>级别</th>
                  <th>内容</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((row, i) => (
                  <tr key={`${row.id ?? i}-${row.timestamp ?? ''}`}>
                    <td className="log-time">{row.timestamp ?? '—'}</td>
                    <td>
                      <span className={`pill pill-${row.level === 'error' ? 'danger' : 'muted'}`}>
                        {row.level ?? '—'}
                      </span>
                    </td>
                    <td className="cell-pre cell-mono">{row.message ?? ''}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </MonitorPageLayout>
  )
}
