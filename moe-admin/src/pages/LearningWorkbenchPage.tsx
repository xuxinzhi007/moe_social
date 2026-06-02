import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { AdminTag } from '../components/AdminTag'
import { FormField } from '../components/FormField'
import { InferenceStatusBar } from '../components/InferenceStatusBar'
import { PageMessage } from '../components/PageMessage'
import { TabbedPageLayout } from '../ui'
import type {
  AdminExportLearningDatasetData,
  AdminMemoryHealthData,
} from '../api/adminClient'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { DeployApiError } from '../api/deployClient'

type Tab = 'health' | 'reindex' | 'dataset' | 'training'

const TABS = [
  { key: 'health' as const, label: '记忆健康', hint: '检索 / embedding / llama' },
  { key: 'reindex' as const, label: '向量重建', hint: '单用户 reindex' },
  { key: 'dataset' as const, label: '训练集导出', hint: '角色卡 → JSONL' },
  { key: 'training' as const, label: 'LoRA 训练', hint: 'Deploy Agent 任务' },
]

function pct(n: number) {
  if (!Number.isFinite(n)) return '—'
  return `${Math.round(n * 1000) / 10}%`
}

export function LearningWorkbenchPage() {
  const { client } = useAdminAuth()
  const { runJob, showToast } = useDeploy()

  const [tab, setTab] = useState<Tab>('health')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const [health, setHealth] = useState<AdminMemoryHealthData | null>(null)
  const [healthRefresh, setHealthRefresh] = useState(0)

  const [userId, setUserId] = useState('')
  const [agentId, setAgentId] = useState('')
  const [reindexBusy, setReindexBusy] = useState(false)
  const [exportBusy, setExportBusy] = useState(false)
  const [lastExport, setLastExport] = useState<AdminExportLearningDatasetData | null>(null)
  const [datasetPath, setDatasetPath] = useState('')

  const loadHealth = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.getMemoryHealth()
      if (res.success && res.data) {
        setHealth(res.data)
      } else {
        setHealth(null)
        setError(res.message || '加载失败')
      }
    } catch (e) {
      setHealth(null)
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client])

  useEffect(() => {
    if (tab === 'health') void loadHealth()
  }, [tab, loadHealth, healthRefresh])

  async function onReindex() {
    const uid = userId.trim()
    if (!uid) {
      setError('请填写 user_id')
      return
    }
    setReindexBusy(true)
    setError('')
    setMessage('')
    try {
      const res = await client.rebuildMemoryEmbeddings({ user_id: uid })
      if (res.success && res.data) {
        setMessage(res.data.message || `已索引 ${res.data.indexed} 条`)
        setHealthRefresh((n) => n + 1)
      } else {
        setError(res.message || '重建失败')
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '重建失败')
    } finally {
      setReindexBusy(false)
    }
  }

  async function onExport() {
    const uid = userId.trim()
    const aid = agentId.trim()
    if (!uid || !aid) {
      setError('请填写 user_id 与 agent_id')
      return
    }
    setExportBusy(true)
    setError('')
    setMessage('')
    try {
      const res = await client.exportLearningDataset({
        user_id: uid,
        agent_id: aid,
      })
      if (res.success && res.data) {
        setLastExport(res.data)
        setMessage(
          `已导出 ${res.data.line_count} 行${res.data.agent_name ? `（${res.data.agent_name}）` : ''}`,
        )
      } else {
        setError(res.message || '导出失败')
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '导出失败')
    } finally {
      setExportBusy(false)
    }
  }

  function downloadJsonl() {
    if (!lastExport?.jsonl) return
    const blob = new Blob([lastExport.jsonl], { type: 'application/jsonl' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `learning-${userId.trim() || 'export'}.jsonl`
    a.click()
    URL.revokeObjectURL(url)
  }

  const stats = health?.stats

  return (
    <TabbedPageLayout
      title="学习工作台"
      description={
        <>
          记忆 RAG 健康与离线 LoRA 训练入口。向量走 llama.cpp embedding；训练脚本见{' '}
          <code>tools/character-finetune</code>（对接 ollama_web/finetune，非 Ollama）。
        </>
      }
      envNote="Admin API · 记忆 / 学习 / Deploy Agent"
      tabs={TABS}
      activeTab={tab}
      onTabChange={setTab}
      headActions={
        tab === 'health' ? (
          <button
            type="button"
            className="btn btn-ghost"
            disabled={loading}
            onClick={() => setHealthRefresh((n) => n + 1)}
          >
            刷新
          </button>
        ) : null
      }
    >
      {message ? (
        <PageMessage message={message} tone="ok" onClose={() => setMessage('')} />
      ) : null}
      {error ? <p className="text-danger">{error}</p> : null}

      {tab === 'health' ? (
        <div className="panel-stack">
          <InferenceStatusBar agentKey="moe_guide" refreshKey={healthRefresh} />
          {loading && !health ? (
            <p className="loading-hint">加载记忆健康…</p>
          ) : null}
          {health ? (
            <>
              <article className="panel">
                <div className="panel-head">
                  <h3>记忆统计</h3>
                  <AdminTag
                    label={health.llm_inference_online ? '推理在线' : '推理离线'}
                    tone={health.llm_inference_online ? 'ok' : 'fail'}
                    dot
                  />
                </div>
                <div className="panel-body env-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)' }}>
                  <div>
                    <span className="muted">记忆条数</span>
                    <p>{stats?.total_memories ?? '—'}</p>
                  </div>
                  <div>
                    <span className="muted">有记忆用户</span>
                    <p>{stats?.users_with_memories ?? '—'}</p>
                  </div>
                  <div>
                    <span className="muted">向量条数</span>
                    <p>{stats?.total_embeddings ?? '—'}</p>
                  </div>
                  <div>
                    <span className="muted">索引覆盖率</span>
                    <p>{pct(health.embedding_index_ratio)}</p>
                  </div>
                </div>
              </article>

              <article className="panel">
                <div className="panel-head">
                  <h3>检索配置</h3>
                </div>
                <div className="panel-body">
                  <p style={{ fontSize: 13, margin: '0 0 8px' }}>
                    混合检索 {health.hybrid_enabled ? '开' : '关'} · 向量权重{' '}
                    {health.vector_weight} · 关键词 {health.keyword_weight} · Rerank{' '}
                    {health.rerank_enabled ? '开' : '关'} · 图谱 {health.graph_enabled ? '开' : '关'}
                  </p>
                  <p style={{ fontSize: 12, color: 'var(--muted)', margin: 0 }}>
                    llama: <code>{health.llm_inference_base_url || '—'}</code> · 模型{' '}
                    {health.memory_model || '—'}
                  </p>
                </div>
              </article>

              {health.embedding_probe ? (
                <article className="panel">
                  <div className="panel-head">
                    <h3>Embedding 探针</h3>
                    <AdminTag
                      label={health.embedding_probe.ok ? '可用' : '失败'}
                      tone={health.embedding_probe.ok ? 'ok' : 'fail'}
                    />
                  </div>
                  <div className="panel-body" style={{ fontSize: 13 }}>
                    <p>
                      {health.embedding_probe.provider_type} / {health.embedding_probe.model}
                    </p>
                    <code>{health.embedding_probe.base_url}</code>
                    {health.embedding_probe.message ? (
                      <p className="muted" style={{ marginTop: 8 }}>
                        {health.embedding_probe.message}
                      </p>
                    ) : null}
                  </div>
                </article>
              ) : null}

              {health.hints?.length ? (
                <article className="panel">
                  <div className="panel-head">
                    <h3>建议</h3>
                  </div>
                  <ul className="hint-list" style={{ margin: 0, padding: '12px 24px' }}>
                    {health.hints.map((h) => (
                      <li key={h} style={{ fontSize: 13 }}>
                        {h}
                      </li>
                    ))}
                  </ul>
                </article>
              ) : null}
            </>
          ) : null}
        </div>
      ) : null}

      {tab === 'reindex' ? (
        <article className="panel">
          <div className="panel-head">
            <h3>单用户向量重建</h3>
          </div>
          <div className="panel-body">
            <FormField label="user_id" hint="必填 · 与 App 用户 ID 一致">
              <input
                className="input"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                placeholder="例如 10001"
              />
            </FormField>
            <div className="btn-row" style={{ marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-primary"
                disabled={reindexBusy}
                onClick={() => void onReindex()}
              >
                {reindexBusy ? '重建中…' : '开始重建'}
              </button>
              <Link to="/system/platform?tab=memory" className="btn btn-ghost">
                记忆治理
              </Link>
            </div>
          </div>
        </article>
      ) : null}

      {tab === 'dataset' ? (
        <article className="panel">
          <div className="panel-head">
            <h3>从角色卡导出 JSONL</h3>
          </div>
          <div className="panel-body">
            <FormField label="user_id" hint="ai_user_configs 所属用户">
              <input
                className="input"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
              />
            </FormField>
            <FormField label="agent_id" hint="角色卡 id 字段">
              <input
                className="input"
                value={agentId}
                onChange={(e) => setAgentId(e.target.value)}
              />
            </FormField>
            <div className="btn-row" style={{ marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-primary"
                disabled={exportBusy}
                onClick={() => void onExport()}
              >
                {exportBusy ? '导出中…' : '导出 JSONL'}
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={!lastExport?.jsonl}
                onClick={downloadJsonl}
              >
                下载文件
              </button>
            </div>
            {lastExport?.hint ? (
              <p className="muted" style={{ fontSize: 12, marginTop: 12 }}>
                {lastExport.hint}
              </p>
            ) : null}
          </div>
        </article>
      ) : null}

      {tab === 'training' ? (
        <article className="panel">
          <div className="panel-head">
            <h3>Deploy Agent · LoRA</h3>
          </div>
          <div className="panel-body">
            <p style={{ fontSize: 13, marginTop: 0 }}>
              在本机 workspace 执行 Python <strong>LoRA 离线训练</strong>（与「记忆健康」里的
              Embedding 探针无关）。需设置 <code>OLLAMA_WEB_FINETUNE_DIR</code> 指向
              ollama_web/finetune。
            </p>
            <p className="muted" style={{ fontSize: 12 }}>
              记忆向量请回到「记忆健康」Tab：llama-server 需带 <code>--embeddings</code>，再执行向量重建。
            </p>
            <FormField label="dataset_path（可选）" hint="导出 JSONL 的绝对路径">
              <input
                className="input"
                value={datasetPath}
                onChange={(e) => setDatasetPath(e.target.value)}
                placeholder="/path/to/train.jsonl"
              />
            </FormField>
            <div className="btn-row" style={{ marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => void runJob('learning_env_check')}
              >
                训练环境检查
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  const params: Record<string, string> = {}
                  const p = datasetPath.trim()
                  if (p) params.dataset_path = p
                  void runJob('learning_train_lora', params).then((id) => {
                    if (id) showToast('训练任务已提交，见任务审计')
                  })
                }}
              >
                启动 LoRA 训练
              </button>
              <Link to="/jobs" className="btn btn-ghost">
                任务审计
              </Link>
            </div>
          </div>
        </article>
      ) : null}
    </TabbedPageLayout>
  )
}
