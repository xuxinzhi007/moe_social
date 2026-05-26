import { useCallback, useEffect, useState } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { FormField } from '../components/FormField'
import { PageMessage } from '../components/PageMessage'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { DeployApiError } from '../api/deployClient'

type BrainData = {
  agent_key: string
  display_name: string
  bot_user_id: string
  forbidden_tags: string[]
  preferred_tags: string[]
  tag_stats: Array<{ tag: string; count: number }>
  episodes: Array<{
    id: number
    post_id: string
    content: string
    tags: string[]
    mood_tag: string
    style_score: number
    quality_score: number
    approved: boolean
    revision_count: number
    memory_key: string
    source: string
    created_at: string
  }>
  memories: Array<{
    key: string
    value: string
    memory_type: string
    updated_at: string
  }>
}

const DEFAULT_FORBIDDEN = `risk:诗意腔
tone:官方
type:套路开场`

const DEFAULT_PREFERRED = `tone:口语
type:提问
topic:日常
topic:手绘`

export function MoeBrainPage() {
  const { agentKey: paramKey } = useParams<{ agentKey: string }>()
  const [searchParams, setSearchParams] = useSearchParams()
  const { client } = useAdminAuth()
  const { showToast } = useDeploy()

  const [agents, setAgents] = useState<Array<{ agent_key: string; display_name: string }>>([])
  const agentKey = paramKey || searchParams.get('agent') || 'moe_guide'

  const [brain, setBrain] = useState<BrainData | null>(null)
  const [forbiddenText, setForbiddenText] = useState(DEFAULT_FORBIDDEN)
  const [preferredText, setPreferredText] = useState(DEFAULT_PREFERRED)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [curating, setCurating] = useState(false)
  const [refiningId, setRefiningId] = useState<number | null>(null)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const loadAgents = useCallback(async () => {
    try {
      const res = await client.listMoeRuntimes()
      if (res.success && res.data?.items) {
        setAgents(
          res.data.items.map((i) => ({
            agent_key: i.agent_key,
            display_name: i.display_name || i.agent_key,
          })),
        )
      }
    } catch {
      /* ignore */
    }
  }, [client])

  const loadBrain = useCallback(async () => {
    if (!agentKey) return
    setLoading(true)
    setError('')
    try {
      const res = await client.getMoeBrain(agentKey)
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setBrain(null)
        return
      }
      setBrain(res.data)
      setForbiddenText(
        (res.data.forbidden_tags || []).join('\n') || DEFAULT_FORBIDDEN,
      )
      setPreferredText(
        (res.data.preferred_tags || []).join('\n') || DEFAULT_PREFERRED,
      )
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [agentKey, client])

  useEffect(() => {
    void loadAgents()
  }, [loadAgents])

  useEffect(() => {
    void loadBrain()
  }, [loadBrain])

  function onSelectAgent(key: string) {
    setSearchParams({ agent: key })
  }

  async function savePolicy() {
    setSaving(true)
    setMessage('')
    try {
      const forbidden = forbiddenText
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean)
      const preferred = preferredText
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean)
      const res = await client.updateMoeBrainPolicy(agentKey, {
        forbidden_tags: forbidden,
        preferred_tags: preferred,
      })
      if (!res.success || !res.data) {
        setError(res.message || '保存失败')
        return
      }
      setBrain(res.data)
      setMessage('标签策略已保存')
      showToast('AI 大脑策略已更新')
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  async function deleteEpisode(id: number) {
    if (!confirm('删除该自传记录？将同时尝试删除对应记忆 key。')) return
    try {
      const res = await client.deleteMoeBrainEpisode(id)
      if (!res.success) {
        showToast(res.message || '删除失败')
        return
      }
      showToast('已删除')
      await loadBrain()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '删除失败')
    }
  }

  async function refineEpisode(id: number) {
    setRefiningId(id)
    setMessage('')
    try {
      const res = await client.refineMoeBrainEpisode(id)
      if (!res.success || !res.data) {
        showToast(res.message || '润色失败')
        return
      }
      const d = res.data
      showToast(
        d.approved
          ? `已认可（${d.quality_score} 分，${d.attempts} 次）`
          : `已润色但未达阈值（${d.quality_score} 分）`,
      )
      setMessage(d.detail)
      await loadBrain()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '润色失败')
    } finally {
      setRefiningId(null)
    }
  }

  async function curateMemories() {
    if (
      !confirm(
        '整理低分/未认可记忆？将调用 LLM 逐条润色并更新动态与记忆库，可能需要数分钟。',
      )
    ) {
      return
    }
    setCurating(true)
    setMessage('')
    try {
      const res = await client.curateMoeBrain(activeKey)
      if (!res.success || !res.data) {
        showToast(res.message || '整理失败')
        return
      }
      const d = res.data
      showToast(`整理完成：${d.approved}/${d.total} 条已认可`)
      setMessage(`共处理 ${d.total} 条，${d.approved} 条达认可标准`)
      await loadBrain()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '整理失败')
    } finally {
      setCurating(false)
    }
  }

  function qualityTone(score: number, approved: boolean): 'ok' | 'warn' | 'fail' {
    if (approved || score >= 70) return 'ok'
    if (score >= 50) return 'warn'
    return 'fail'
  }

  const activeKey = brain?.agent_key || agentKey

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>AI 大脑</h2>
          <p>
            查看 Bot 说过的话、标签统计与禁止/偏好策略。试跑成功后会自动写入自传与记忆库。
          </p>
        </div>
        <div className="btn-row">
          <Link className="btn btn-ghost" to="/app/moe-bots">
            ← Bot 配置
          </Link>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => void loadBrain()}
          >
            刷新
          </button>
          <button
            type="button"
            className="btn btn-primary"
            disabled={curating}
            onClick={() => void curateMemories()}
          >
            {curating ? '整理中…' : '整理低分记忆'}
          </button>
        </div>
      </div>
      <DataEnvBar />
      <PageMessage message={message} tone="ok" onClose={() => setMessage('')} />
      {error ? <p className="text-danger">{error}</p> : null}

      <div className="panel" style={{ marginBottom: 16 }}>
        <FormField label="选择 Bot">
          <select
            value={activeKey}
            onChange={(e) => onSelectAgent(e.target.value)}
          >
            {agents.length === 0 ? (
              <option value={activeKey}>{activeKey}</option>
            ) : (
              agents.map((a) => (
                <option key={a.agent_key} value={a.agent_key}>
                  {a.display_name} ({a.agent_key})
                </option>
              ))
            )}
          </select>
        </FormField>
        {brain ? (
          <p className="muted" style={{ marginTop: 8 }}>
            Bot 用户 ID：{brain.bot_user_id} · 自传 {brain.episodes.length} 条 ·
            记忆 {brain.memories.length} 条
          </p>
        ) : null}
      </div>

      {loading ? <p className="muted">加载中…</p> : null}

      {brain && !loading ? (
        <>
          <div className="panel" style={{ marginBottom: 16 }}>
            <h3 style={{ marginTop: 0 }}>标签云（近期发帖）</h3>
            {brain.tag_stats.length === 0 ? (
              <p className="muted">暂无标签，试跑发帖后会自动生成</p>
            ) : (
              <div className="btn-row" style={{ flexWrap: 'wrap', gap: 8 }}>
                {brain.tag_stats.map((t) => (
                  <AdminTag
                    key={t.tag}
                    spec={{
                      label: `${t.tag} ×${t.count}`,
                      tone: t.tag.startsWith('risk:') ? 'warn' : 'neutral',
                    }}
                  />
                ))}
              </div>
            )}
          </div>

          <div className="panel" style={{ marginBottom: 16 }}>
            <h3 style={{ marginTop: 0 }}>标签策略（硬性规则）</h3>
            <p className="muted" style={{ fontSize: 13 }}>
              每行一个标签。生成前会注入「禁止/偏好」；命中禁止标签会重试。
            </p>
            <div className="form-grid-2" style={{ display: 'grid', gap: 16, gridTemplateColumns: '1fr 1fr' }}>
              <FormField label="禁止标签">
                <textarea
                  rows={8}
                  value={forbiddenText}
                  onChange={(e) => setForbiddenText(e.target.value)}
                />
              </FormField>
              <FormField label="偏好标签">
                <textarea
                  rows={8}
                  value={preferredText}
                  onChange={(e) => setPreferredText(e.target.value)}
                />
              </FormField>
            </div>
            <button
              type="button"
              className="btn btn-primary"
              style={{ marginTop: 12 }}
              disabled={saving}
              onClick={() => void savePolicy()}
            >
              {saving ? '保存中…' : '保存策略'}
            </button>
          </div>

          <div className="panel" style={{ marginBottom: 16 }}>
            <h3 style={{ marginTop: 0 }}>自传记录（每次发帖）</h3>
            <p className="muted" style={{ fontSize: 13 }}>
              质量分 1–100，≥70 为认可。低分或未认可可点「润色」由 LLM 改写并同步记忆与动态。
            </p>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>时间</th>
                    <th>内容</th>
                    <th>标签</th>
                    <th>质量</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {brain.episodes.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="muted">
                        暂无，请试跑发帖
                      </td>
                    </tr>
                  ) : (
                    brain.episodes.map((ep) => (
                      <tr key={ep.id}>
                        <td className="muted" style={{ whiteSpace: 'nowrap' }}>
                          {ep.created_at}
                          <div style={{ fontSize: 11 }}>#{ep.post_id}</div>
                          {ep.revision_count > 0 ? (
                            <div style={{ fontSize: 11 }}>润色×{ep.revision_count}</div>
                          ) : null}
                        </td>
                        <td style={{ maxWidth: 360 }}>{ep.content}</td>
                        <td>
                          <div className="btn-row" style={{ flexWrap: 'wrap', gap: 4 }}>
                            {(ep.tags || []).map((t) => (
                              <AdminTag key={t} label={t} tone="neutral" />
                            ))}
                          </div>
                        </td>
                        <td>
                          <AdminTag
                            label={`${ep.quality_score ?? 0}${ep.approved ? ' ✓' : ''}`}
                            tone={qualityTone(ep.quality_score ?? 0, ep.approved)}
                          />
                          <div className="muted" style={{ fontSize: 11 }}>
                            文艺{ep.style_score}
                          </div>
                        </td>
                        <td>
                          <div className="btn-row" style={{ flexDirection: 'column', gap: 4 }}>
                            {!ep.approved ? (
                              <button
                                type="button"
                                className="btn btn-ghost btn-sm"
                                disabled={refiningId === ep.id}
                                onClick={() => void refineEpisode(ep.id)}
                              >
                                {refiningId === ep.id ? '润色中…' : '润色'}
                              </button>
                            ) : null}
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              onClick={() => void deleteEpisode(ep.id)}
                            >
                              删除
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="panel">
            <h3 style={{ marginTop: 0 }}>记忆库（bot_post:*）</h3>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Key</th>
                    <th>内容</th>
                    <th>更新</th>
                  </tr>
                </thead>
                <tbody>
                  {brain.memories.length === 0 ? (
                    <tr>
                      <td colSpan={3} className="muted">
                        暂无 Bot 自传记忆
                      </td>
                    </tr>
                  ) : (
                    brain.memories.map((m) => (
                      <tr key={m.key}>
                        <td className="muted">{m.key}</td>
                        <td style={{ maxWidth: 400 }}>{m.value}</td>
                        <td className="muted">{m.updated_at}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      ) : null}
    </>
  )
}
