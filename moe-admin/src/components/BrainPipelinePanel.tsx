import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from './AdminTag'
import type { MoeBrainPipelineData, MoeGenAttemptItem, MoePipelineStepItem } from '../api/adminClient'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'
import type { TagTone } from '../lib/adminLabels'

type Props = {
  agentKey: string
  refreshKey?: number
  onRunOnce?: () => void
  runningOnce?: boolean
}

function stepTone(status: string): TagTone {
  const s = status.trim().toLowerCase()
  if (s === 'ok') return 'ok'
  if (s === 'fail' || s === 'error') return 'fail'
  if (s === 'running') return 'warn'
  return 'neutral'
}

function stepStatusLabel(status: string): string {
  const s = status.trim().toLowerCase()
  if (s === 'ok') return '完成'
  if (s === 'fail' || s === 'error') return '失败'
  if (s === 'running') return '进行中'
  if (s === 'skip') return '待执行'
  return status || '—'
}

function genOutcomeLabel(outcome: string): string {
  switch (outcome) {
    case 'ok':
      return '通过'
    case 'duplicate':
      return '与近期帖重复'
    case 'theme':
      return '主题/开头过像'
    case 'forbidden':
      return '命中禁止标签'
    case 'novel':
      return '偏剧本/诗意腔'
    case 'llm_error':
      return 'LLM 调用失败'
    default:
      return outcome || '—'
  }
}

function formatMs(ms?: number): string {
  if (ms === undefined || ms <= 0) return '—'
  if (ms < 1000) return `${ms} ms`
  return `${(ms / 1000).toFixed(2)} s`
}

function maxStepMs(steps: MoePipelineStepItem[]): number {
  let max = 1
  for (const s of steps) {
    if ((s.duration_ms ?? 0) > max) max = s.duration_ms ?? 0
  }
  return max
}

function PipelineStepRow({
  step,
  index,
  maxMs,
}: {
  step: MoePipelineStepItem
  index: number
  maxMs: number
}) {
  const ms = step.duration_ms ?? 0
  const widthPct = maxMs > 0 && ms > 0 ? Math.max(8, Math.round((ms / maxMs) * 100)) : 0
  const status = step.status.trim().toLowerCase() || 'skip'

  return (
    <div className={`brain-pipeline-step brain-pipeline-step--${status}`}>
      <div className="brain-pipeline-step-rail">
        <span className="brain-pipeline-step-num">{index + 1}</span>
        {index > 0 ? <span className="brain-pipeline-connector" aria-hidden /> : null}
      </div>
      <div className="brain-pipeline-step-body">
        <div className="brain-pipeline-step-head">
          <div>
            <strong>{step.label || step.key}</strong>
            <div className="muted brain-pipeline-step-key">{step.key}</div>
          </div>
          <div className="brain-pipeline-step-tags">
            <AdminTag label={stepStatusLabel(step.status)} tone={stepTone(step.status)} />
            <span className="brain-pipeline-duration">{formatMs(ms)}</span>
          </div>
        </div>
        {ms > 0 ? (
          <div className="brain-pipeline-bar-track" title={`耗时 ${formatMs(ms)}`}>
            <div className="brain-pipeline-bar-fill" style={{ width: `${widthPct}%` }} />
          </div>
        ) : null}
        {step.detail ? (
          <p
            className="muted brain-pipeline-step-detail"
            style={step.detail.includes('\n') ? { whiteSpace: 'pre-wrap' } : undefined}
          >
            {step.detail}
          </p>
        ) : null}
      </div>
    </div>
  )
}

/** 展示 Bot 试跑流水线：分步耗时、总耗时、进程与推理环境快照。 */
export function BrainPipelinePanel({ agentKey, refreshKey = 0, onRunOnce, runningOnce }: Props) {
  const { client } = useAdminAuth()
  const [data, setData] = useState<MoeBrainPipelineData | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    if (!agentKey.trim()) {
      setData(null)
      return
    }
    setLoading(true)
    setError('')
    try {
      const res = await client.getMoeBrainPipeline(agentKey)
      if (res.success && res.data) {
        setData(res.data)
      } else {
        setData(null)
        setError(res.message || '加载流水线失败')
      }
    } catch (e) {
      setData(null)
      setError(e instanceof DeployApiError ? e.message : '加载流水线失败')
    } finally {
      setLoading(false)
    }
  }, [agentKey, client])

  useEffect(() => {
    void load()
  }, [load, refreshKey])

  const steps = data?.steps ?? []
  const hasRun = Boolean(data?.run_at?.trim())
  const maxMs = useMemo(() => maxStepMs(steps), [steps])
  const generateMs = steps.find((s) => s.key === 'generate')?.duration_ms
  const hm = data?.host_metrics

  const empty = !hasRun && steps.every((s) => s.status === 'skip')
  const genAttempts = data?.generate_attempts ?? []

  return (
    <section className="panel brain-pipeline-panel">
      <header className="platform-section-head brain-pipeline-head">
        <div>
          <h3>发帖流水线</h3>
          <p className="muted">
            试跑时按代码路径逐步执行；<strong>LLM 生成</strong> 通常占绝大部分时间。
          </p>
        </div>
        <div className="btn-row">
          {onRunOnce ? (
            <button
              type="button"
              className="btn btn-primary btn-sm"
              disabled={runningOnce}
              onClick={onRunOnce}
            >
              {runningOnce ? '试跑中…' : '试跑并刷新'}
            </button>
          ) : null}
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={loading}
            onClick={() => void load()}
          >
            {loading ? '刷新中…' : '刷新'}
          </button>
        </div>
      </header>

      {error ? <p className="text-danger">{error}</p> : null}

      {loading && !data ? <p className="muted">加载流水线…</p> : null}

      {data && !loading ? (
        <>
          <div className="admin-metrics page-insight-strip brain-pipeline-metrics">
            <div className="metric">
              <div className="label">末次结果</div>
              <div className="value">
                <AdminTag
                  label={hasRun ? (data.ok ? '成功' : '失败') : '无记录'}
                  tone={!hasRun ? 'neutral' : data.ok ? 'ok' : 'fail'}
                />
              </div>
            </div>
            <div className="metric">
              <div className="label">总耗时</div>
              <div className="value">{formatMs(data.total_duration_ms)}</div>
            </div>
            <div className="metric">
              <div className="label">生成耗时</div>
              <div className="value">{formatMs(generateMs)}</div>
            </div>
            <div className="metric">
              <div className="label">末次运行</div>
              <div className="value" style={{ fontSize: 13 }}>
                {data.run_at || '—'}
              </div>
            </div>
          </div>

          {data.detail || data.post_id ? (
            <div className="brain-pipeline-meta">
              {data.post_id ? (
                <span className="muted">
                  帖子 <code>{data.post_id}</code>
                </span>
              ) : null}
              {data.detail ? (
                <span className="muted brain-pipeline-summary" title={data.detail}>
                  {data.detail}
                </span>
              ) : null}
            </div>
          ) : null}

          {genAttempts.length > 0 ? (
            <details className="brain-pipeline-gen-attempts" open={!data.ok}>
              <summary>
                本次试跑生成明细（共 {genAttempts.length} 次，仅本请求）
              </summary>
              <ol className="brain-gen-attempt-list">
                {genAttempts.map((item: MoeGenAttemptItem) => (
                  <li key={`${item.attempt}-${item.outcome}-${item.snippet ?? ''}`}>
                    <strong>第 {item.attempt} 次</strong> · {genOutcomeLabel(item.outcome)}
                    {item.snippet ? (
                      <span className="muted"> — 「{item.snippet}」</span>
                    ) : null}
                    {item.note ? <span className="muted">（{item.note}）</span> : null}
                  </li>
                ))}
              </ol>
            </details>
          ) : null}

          {empty ? (
            <div className="brain-pipeline-empty">
              <p>尚无试跑记录。请先在本页点击「试跑发帖」，或到「社区 AI Bot」列表试跑后再查看。</p>
              <p className="muted">
                推理服务需已启动（llm-server）；离线时会看到生成步骤失败。
              </p>
            </div>
          ) : (
            <div className="brain-pipeline-steps">{steps.map((step, i) => (
                <PipelineStepRow key={step.key || `${i}`} step={step} index={i} maxMs={maxMs} />
              ))}</div>
          )}

          {hm ? (
            <details className="brain-pipeline-host" open>
              <summary>运行环境快照（RPC 进程 · 推理服务）</summary>
              <div className="admin-metrics page-insight-strip">
                <div className="metric">
                  <div className="label">RPC 内存</div>
                  <div className="value">
                    {hm.proc_alloc_mb ?? 0} MB
                    <span className="summary-note">堆 · 系统 {hm.proc_sys_mb ?? 0} MB</span>
                  </div>
                </div>
                <div className="metric">
                  <div className="label">CPU / 协程</div>
                  <div className="value" style={{ fontSize: 14 }}>
                    {hm.num_cpu ?? '—'} 核 · {hm.num_goroutine ?? '—'} goroutine
                  </div>
                </div>
                <div className="metric">
                  <div className="label">推理服务</div>
                  <div className="value">
                    <AdminTag
                      label={hm.inference_online ? '在线' : '离线'}
                      tone={hm.inference_online ? 'ok' : 'fail'}
                      dot
                    />
                    <span className="summary-note">
                      {hm.inference_models ?? 0} 个模型
                    </span>
                  </div>
                </div>
              </div>
              {hm.inference_base_url ? (
                <code className="data-env-url">{hm.inference_base_url}</code>
              ) : null}
              {hm.gpu_note ? <p className="muted brain-pipeline-gpu-note">{hm.gpu_note}</p> : null}
            </details>
          ) : null}
        </>
      ) : null}
    </section>
  )
}
