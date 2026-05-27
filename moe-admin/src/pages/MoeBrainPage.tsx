import { useCallback, useEffect, useState } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { AdminIcon } from '../components/AdminIcon'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { BrainPipelinePanel } from '../components/BrainPipelinePanel'
import { InferenceStatusBar } from '../components/InferenceStatusBar'
import { MemoryInfluencePanel } from '../components/MemoryInfluencePanel'
import type { MoeBrainGenerationMeta } from '../api/adminClient'
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
  generation_meta?: MoeBrainGenerationMeta
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
  const [opsRefresh, setOpsRefresh] = useState(0)
  const [runningOnce, setRunningOnce] = useState(false)

  function bumpOpsRefresh() {
    setOpsRefresh((n) => n + 1)
  }

  const loadAgents = useCallback(async () => {
    try {
      const res = await client.listMoeRuntimes()
      if (res.success && res.data?.items) {
        setAgents(
          res.data.items.map((item) => ({
            agent_key: item.agent_key,
            display_name: item.display_name || item.agent_key,
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
      setBrain(res.data as BrainData)
      setForbiddenText((res.data.forbidden_tags || []).join('\n') || DEFAULT_FORBIDDEN)
      setPreferredText((res.data.preferred_tags || []).join('\n') || DEFAULT_PREFERRED)
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
      setBrain(res.data as BrainData)
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
      const detail = res.data
      showToast(
        detail.approved
          ? `已认可（${detail.quality_score} 分，${detail.attempts} 次）`
          : `已润色但未达阈值（${detail.quality_score} 分）`,
      )
      setMessage(detail.detail)
      await loadBrain()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '润色失败')
    } finally {
      setRefiningId(null)
    }
  }

  async function runOncePost() {
    const key = activeKey
    if (!key) return
    if (!confirm(`对 Bot「${key}」执行一次试跑发帖？将走完整流水线并写入运行日志。`)) {
      return
    }
    setRunningOnce(true)
    setMessage('')
    try {
      const res = await client.runMoeAgentOnce(key)
      if (!res.success) {
        showToast(res.message || '试跑失败')
        return
      }
      const detail = res.data?.detail?.trim() || (res.data?.ok ? '试跑完成' : '试跑未成功')
      showToast(detail)
      setMessage(detail)
      bumpOpsRefresh()
      await loadBrain()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '试跑失败')
    } finally {
      setRunningOnce(false)
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
      const detail = res.data
      showToast(`整理完成：${detail.approved}/${detail.total} 条已认可`)
      setMessage(`共处理 ${detail.total} 条，${detail.approved} 条达认可标准`)
      bumpOpsRefresh()
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
  const riskTags = (brain?.tag_stats || []).filter((tag) => tag.tag.startsWith('risk:'))
  const avgQuality = brain?.episodes.length
    ? Math.round(
        brain.episodes.reduce((sum, episode) => sum + (episode.quality_score || 0), 0) /
          brain.episodes.length,
      )
    : 0
  const approvedCount = (brain?.episodes || []).filter((episode) => episode.approved).length

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>AI 大脑</h2>
          <p className="muted">单 Bot 标签策略、生成结果与记忆整理 · 先选对象再编辑规则</p>
        </div>
        <div className="btn-row">
          <Link className="btn btn-ghost btn-sm" to="/app/moe-bots">
            <AdminIcon name="bot" />
            Bot 配置
          </Link>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => {
              bumpOpsRefresh()
              void loadBrain()
            }}
          >
            刷新
          </button>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={runningOnce}
            onClick={() => void runOncePost()}
          >
            {runningOnce ? '试跑中…' : '试跑发帖'}
          </button>
          <button
            type="button"
            className="btn btn-primary btn-sm"
            disabled={curating}
            onClick={() => void curateMemories()}
          >
            {curating ? '整理中…' : '整理低分记忆'}
          </button>
        </div>
      </div>

      <DataEnvBar />
      <InferenceStatusBar agentKey={activeKey} refreshKey={opsRefresh} />
      <BrainPipelinePanel
        agentKey={activeKey}
        refreshKey={opsRefresh}
        runningOnce={runningOnce}
        onRunOnce={() => void runOncePost()}
      />
      <MemoryInfluencePanel meta={brain?.generation_meta} />
      <PageMessage message={message} tone="ok" onClose={() => setMessage('')} />
      {error ? <p className="text-danger">{error}</p> : null}

      <section className="panel content-panel-table brain-object-panel">
        <div className="content-toolbar">
          <div className="content-toolbar-head">
            <strong>当前对象</strong>
            <span>先选择 Bot，再查看它的标签分布、规则和结果记录。</span>
          </div>
        </div>
        <div className="brain-object-grid">
          <div className="brain-object-select">
            <FormField label="选择 Bot">
              <select value={activeKey} onChange={(e) => onSelectAgent(e.target.value)}>
                {agents.length === 0 ? (
                  <option value={activeKey}>{activeKey}</option>
                ) : (
                  agents.map((agent) => (
                    <option key={agent.agent_key} value={agent.agent_key}>
                      {agent.display_name} ({agent.agent_key})
                    </option>
                  ))
                )}
              </select>
            </FormField>
          </div>
          <div className="brain-object-summary">
            <div className="summary-card">
              <span className="summary-label">Bot 用户 ID</span>
              <strong className="summary-value">{brain?.bot_user_id || '—'}</strong>
              <span className="summary-note">当前绑定用户</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">自传记录</span>
              <strong className="summary-value">{brain?.episodes.length || 0}</strong>
              <span className="summary-note">已累计生成</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">认可记录</span>
              <strong className="summary-value">{approvedCount}</strong>
              <span className="summary-note">质量达标条数</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">平均质量</span>
              <strong className="summary-value">{avgQuality}</strong>
              <span className="summary-note">生成稳定度</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">记忆注入</span>
              <strong className="summary-value">
                {brain?.generation_meta?.prompt_memory_lines ?? 0}
              </strong>
              <span className="summary-note">提示词行 · 自传 {brain?.generation_meta?.episodes_in_prompt ?? 0}</span>
            </div>
          </div>
        </div>
      </section>

      {loading ? <p className="muted">加载中…</p> : null}

      {brain && !loading ? (
        <section className="brain-workbench">
          <div className="brain-main-stack">
            <div className="panel content-panel-table">
              <div className="content-toolbar">
                <div className="content-toolbar-head">
                  <strong>标签策略</strong>
                  <span>配置生成前的硬性约束与偏好导向。</span>
                </div>
              </div>
              <div className="brain-policy-grid">
                <FormField label="禁止标签">
                  <textarea
                    rows={10}
                    value={forbiddenText}
                    onChange={(e) => setForbiddenText(e.target.value)}
                  />
                </FormField>
                <FormField label="偏好标签">
                  <textarea
                    rows={10}
                    value={preferredText}
                    onChange={(e) => setPreferredText(e.target.value)}
                  />
                </FormField>
              </div>
              <div className="brain-policy-foot">
                <p className="muted">
                  每行一个标签。命中禁止标签会触发重试，偏好标签会在生成前注入引导。
                </p>
                <button type="button" className="btn btn-primary" disabled={saving} onClick={() => void savePolicy()}>
                  {saving ? '保存中…' : '保存策略'}
                </button>
              </div>
            </div>

            <div className="panel content-panel-table">
              <div className="content-toolbar">
                <div className="content-toolbar-head">
                  <strong>自传记录</strong>
                  <span>查看每次发帖生成结果，低分内容可继续润色或删除。</span>
                </div>
              </div>
              <div className="table-wrap table-wrap-elevated">
                <table className="data-table data-table-users">
                  <thead>
                    <tr>
                      <th>时间 / ID</th>
                      <th>内容</th>
                      <th>标签</th>
                      <th>质量</th>
                      <th>操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {brain.episodes.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="muted table-empty">
                          暂无，请试跑发帖
                        </td>
                      </tr>
                    ) : (
                      brain.episodes.map((episode) => (
                        <tr key={episode.id}>
                          <td className="muted" style={{ whiteSpace: 'nowrap' }}>
                            {episode.created_at}
                            <div style={{ fontSize: 11 }}>#{episode.post_id}</div>
                            {episode.revision_count > 0 ? (
                              <div style={{ fontSize: 11 }}>润色×{episode.revision_count}</div>
                            ) : null}
                          </td>
                          <td style={{ maxWidth: 360 }}>{episode.content}</td>
                          <td>
                            <div className="btn-row" style={{ flexWrap: 'wrap', gap: 4 }}>
                              {(episode.tags || []).map((tag) => (
                                <AdminTag key={tag} label={tag} tone="neutral" />
                              ))}
                            </div>
                          </td>
                          <td>
                            <AdminTag
                              label={`${episode.quality_score ?? 0}${episode.approved ? ' ✓' : ''}`}
                              tone={qualityTone(episode.quality_score ?? 0, episode.approved)}
                            />
                            <div className="muted" style={{ fontSize: 11 }}>
                              文艺{episode.style_score}
                            </div>
                          </td>
                          <td>
                            <div className="btn-row" style={{ flexDirection: 'column', gap: 4 }}>
                              {!episode.approved ? (
                                <button
                                  type="button"
                                  className="btn btn-ghost btn-sm"
                                  disabled={refiningId === episode.id}
                                  onClick={() => void refineEpisode(episode.id)}
                                >
                                  {refiningId === episode.id ? '润色中…' : '润色'}
                                </button>
                              ) : null}
                              <button
                                type="button"
                                className="btn btn-ghost btn-sm"
                                onClick={() => void deleteEpisode(episode.id)}
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
          </div>

          <div className="brain-side-stack">
            <div className="panel content-panel-table">
              <div className="content-toolbar">
                <div className="content-toolbar-head">
                  <strong>标签分析</strong>
                  <span>看近期生成结果的标签分布与风险命中。</span>
                </div>
              </div>
              {brain.tag_stats.length === 0 ? (
                <p className="muted">暂无标签，试跑发帖后会自动生成</p>
              ) : (
                <div className="brain-tag-cluster">
                  {brain.tag_stats.map((tag) => (
                    <AdminTag
                      key={tag.tag}
                      spec={{
                        label: `${tag.tag} ×${tag.count}`,
                        tone: tag.tag.startsWith('risk:') ? 'warn' : 'neutral',
                      }}
                    />
                  ))}
                </div>
              )}
              <div className="brain-risk-box">
                <strong>风险观察</strong>
                {riskTags.length === 0 ? (
                  <p className="muted">近期没有风险标签命中。</p>
                ) : (
                  <ul className="brain-risk-list">
                    {riskTags.map((tag) => (
                      <li key={tag.tag}>
                        <span>{tag.tag}</span>
                        <strong>×{tag.count}</strong>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>

            <div className="panel content-panel-table">
              <div className="content-toolbar">
                <div className="content-toolbar-head">
                  <strong>记忆库</strong>
                  <span>bot_post:* 记忆内容与最近更新时间。</span>
                </div>
              </div>
              <div className="table-wrap table-wrap-elevated">
                <table className="data-table data-table-users">
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
                        <td colSpan={3} className="muted table-empty">
                          暂无 Bot 自传记忆
                        </td>
                      </tr>
                    ) : (
                      brain.memories.map((memory) => (
                        <tr key={memory.key}>
                          <td className="muted">{memory.key}</td>
                          <td style={{ maxWidth: 400 }}>{memory.value}</td>
                          <td className="muted">{memory.updated_at}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </section>
      ) : null}
    </>
  )
}
