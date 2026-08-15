import { useCallback, useEffect, useState } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { AdminIcon } from '../components/AdminIcon'
import { AdminTag } from '../components/AdminTag'
import { BrainPipelinePanel } from '../components/BrainPipelinePanel'
import { BrainKnowledgeGraph } from '../components/BrainKnowledgeGraph'
import { BrainRpgPanel } from '../components/BrainRpgPanel'
import { MonitorPageLayout } from '../ui'
import { InferenceStatusBar } from '../components/InferenceStatusBar'
import { MemoryInfluencePanel } from '../components/MemoryInfluencePanel'
import { FormField } from '../components/FormField'
import { PageMessage } from '../components/PageMessage'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { DeployApiError } from '../api/deployClient'
import { waitMoeBrainPipelineWs } from '../lib/moePipelineWs'
import { normalizeBrainData, type BrainData } from '../lib/brainData'
import { normalizeBrainGraphData, type BrainGraphData, type BrainGraphNode } from '../lib/brainGraphData'
import { asArray } from '../lib/apiRecord'

const DEFAULT_FORBIDDEN = `risk:诗意腔
tone:官方
type:套路开场`

const DEFAULT_PREFERRED = `tone:口语
type:提问
topic:日常
topic:手绘`

type BrainTab = 'workbench' | 'graph' | 'rpg'

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
  const [messageTone, setMessageTone] = useState<'ok' | 'warn' | 'err'>('ok')
  const [opsRefresh, setOpsRefresh] = useState(0)
  const [runningOnce, setRunningOnce] = useState(false)
  const [pageTab, setPageTab] = useState<BrainTab>('workbench')
  const [graph, setGraph] = useState<BrainGraphData | null>(null)
  const [graphLoading, setGraphLoading] = useState(false)
  const [selectedGraphNode, setSelectedGraphNode] = useState<BrainGraphNode | null>(null)

  function bumpOpsRefresh() {
    setOpsRefresh((n) => n + 1)
  }

  const loadAgents = useCallback(async () => {
    try {
      const res = await client.listMoeRuntimes()
      if (res.success && res.data) {
        setAgents(
          asArray<{ agent_key: string; display_name?: string }>(res.data.items).map((item) => ({
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
      const normalized = normalizeBrainData(res.data)
      setBrain(normalized)
      setForbiddenText(normalized.forbidden_tags.join('\n') || DEFAULT_FORBIDDEN)
      setPreferredText(normalized.preferred_tags.join('\n') || DEFAULT_PREFERRED)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [agentKey, client])

  const loadGraph = useCallback(async () => {
    if (!agentKey) return
    setGraphLoading(true)
    try {
      const res = await client.getMoeBrainGraph(agentKey, 80)
      if (res.success && res.data) {
        setGraph(normalizeBrainGraphData(res.data))
      } else {
        setGraph(null)
      }
    } catch {
      setGraph(null)
    } finally {
      setGraphLoading(false)
    }
  }, [agentKey, client])

  useEffect(() => {
    void loadAgents()
  }, [loadAgents])

  useEffect(() => {
    void loadBrain()
  }, [loadBrain])

  useEffect(() => {
    if (pageTab === 'graph') void loadGraph()
  }, [pageTab, loadGraph])

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
      setBrain(normalizeBrainData(res.data))
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
      await loadGraph()
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
      await loadGraph()
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
    let pipelineFinal: Awaited<ReturnType<typeof waitMoeBrainPipelineWs>> = null
    try {
      const res = await client.runMoeAgentOnce(key, { async: true })
      if (!res.success) {
        showToast(res.message || '试跑失败')
        return
      }
      if (res.data?.already_running) {
        showToast('该 Bot 正在试跑中，请稍候')
        return
      }
      if (res.data?.accepted) {
        pipelineFinal = await waitMoeBrainPipelineWs(client.brainPipelineWsUrl(key))
        bumpOpsRefresh()
        await loadBrain()
        await loadGraph()
        if (pipelineFinal) {
          if (pipelineFinal.running) {
            showToast('试跑仍在进行，请查看流水线进度')
            setMessage('试跑进行中…')
            setMessageTone('warn')
          } else {
            const ok = Boolean(pipelineFinal.ok)
            const detail = pipelineFinal.detail?.trim() || (ok ? '试跑完成' : '试跑未成功')
            showToast(detail)
            setMessage(detail)
            setMessageTone(ok ? 'ok' : 'warn')
          }
        }
        return
      }
      const ok = Boolean(res.data?.ok)
      const detail = res.data?.detail?.trim() || (ok ? '试跑完成' : '试跑未成功')
      showToast(detail)
      setMessage(detail)
      setMessageTone(ok ? 'ok' : 'warn')
      bumpOpsRefresh()
      await loadBrain()
      await loadGraph()
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '试跑失败')
    } finally {
      if (!pipelineFinal?.running) {
        setRunningOnce(false)
      }
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
      await loadGraph()
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
  const episodes = brain?.episodes ?? []
  const tagStats = brain?.tag_stats ?? []
  const memories = brain?.memories ?? []
  const riskTags = tagStats.filter((tag) => tag.tag.startsWith('risk:'))
  const avgEpisodeQuality =
    brain?.avg_episode_quality ??
    (episodes.length > 0
      ? Math.round(
          episodes.reduce((sum, episode) => sum + (episode.quality_score || 0), 0) /
            episodes.length,
        )
      : 0)
  const stabilityScore = brain?.stability_score ?? 70
  const stabilityDelta = brain?.stability_delta ?? 0
  const approvedCount = episodes.filter((episode) => episode.approved).length

  return (
    <MonitorPageLayout
      title="AI 大脑"
      description="单 Bot 标签策略、生成结果与记忆整理 · 先选对象再编辑规则"
      headActions={
        <div className="btn-row page-head-toolbar">
          <Link className="btn btn-ghost btn-sm" to="/ai/moe-bots">
            <AdminIcon name="bot" />
            Bot 配置
          </Link>
          <button
            type="button"
            className="btn btn-primary btn-sm"
            disabled={runningOnce || curating}
            onClick={() => void runOncePost()}
          >
            {runningOnce ? '试跑中…' : '试跑发帖'}
          </button>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={curating || runningOnce}
            onClick={() => void curateMemories()}
          >
            {curating ? '整理中…' : '整理低分记忆'}
          </button>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={loading || runningOnce || curating}
            onClick={() => {
              bumpOpsRefresh()
              void loadBrain()
              void loadGraph()
            }}
          >
            {loading ? '刷新中…' : '刷新'}
          </button>
        </div>
      }
      metrics={[
        { label: '自传记录', value: loading ? '…' : episodes.length },
        { label: '认可记录', value: loading ? '…' : approvedCount },
        { label: '平均质量', value: loading ? '…' : avgEpisodeQuality },
        {
          label: '稳定度',
          value: loading ? '…' : stabilityScore,
          hint: stabilityDelta ? `${stabilityDelta > 0 ? '+' : ''}${stabilityDelta}` : undefined,
        },
      ]}
      error={error || undefined}
    >
      <InferenceStatusBar agentKey={activeKey} refreshKey={opsRefresh} />
      <BrainPipelinePanel
        agentKey={activeKey}
        refreshKey={opsRefresh}
        running={runningOnce}
        stabilityScore={stabilityScore}
      />
      <MemoryInfluencePanel meta={brain?.generation_meta} />
      <PageMessage message={message} tone={messageTone} onClose={() => setMessage('')} />

      <section className="panel content-panel-table brain-object-panel" aria-label="当前对象">
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
              <strong className="summary-value">{episodes.length}</strong>
              <span className="summary-note">已累计生成</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">认可记录</span>
              <strong className="summary-value">{approvedCount}</strong>
              <span className="summary-note">质量达标条数</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">稳定度评分</span>
              <strong className="summary-value">{stabilityScore}</strong>
              <span className="summary-note">
                试跑奖惩
                {stabilityDelta !== 0 ? (
                  <AdminTag
                    label={`${stabilityDelta > 0 ? '+' : ''}${stabilityDelta}`}
                    tone={stabilityDelta > 0 ? 'ok' : 'fail'}
                  />
                ) : (
                  ' · 末次无变化'
                )}
              </span>
            </div>
            <div className="summary-card">
              <span className="summary-label">自传均分</span>
              <strong className="summary-value">{avgEpisodeQuality}</strong>
              <span className="summary-note">已发内容质量</span>
            </div>
            <div className="summary-card">
              <span className="summary-label">记忆块行数</span>
              <strong className="summary-value">
                {brain?.generation_meta?.prompt_memory_lines ?? 0}
              </strong>
              <span className="summary-note">
                注入 prompt 行数 · 自传 {brain?.generation_meta?.episodes_in_prompt ?? 0} · 库{' '}
                {brain?.generation_meta?.memories_synced ?? 0}
              </span>
            </div>
          </div>
        </div>
      </section>

      {loading ? <p className="muted">加载中…</p> : null}

      {brain && !loading ? (
        <>
          <div className="brain-page-tabs" role="tablist" aria-label="大脑视图">
            <button
              type="button"
              role="tab"
              aria-selected={pageTab === 'workbench'}
              className={`brain-page-tab ${pageTab === 'workbench' ? 'brain-page-tab--active' : ''}`}
              onClick={() => setPageTab('workbench')}
            >
              工作台
              <span className="brain-page-tab-hint">策略 · 自传列表 · 标签 · 评分</span>
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={pageTab === 'graph'}
              className={`brain-page-tab ${pageTab === 'graph' ? 'brain-page-tab--active' : ''}`}
              onClick={() => setPageTab('graph')}
            >
              知识图谱
              <span className="brain-page-tab-hint">关联网络 · 可交互探索</span>
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={pageTab === 'rpg'}
              className={`brain-page-tab ${pageTab === 'rpg' ? 'brain-page-tab--active' : ''}`}
              onClick={() => setPageTab('rpg')}
            >
              记忆 RPG
              <span className="brain-page-tab-hint">入梦 · 压缩 · 技能 · 碎片</span>
            </button>
          </div>

          {pageTab === 'rpg' ? (
            <BrainRpgPanel
              agentKey={activeKey}
              client={client}
              refreshKey={opsRefresh}
              onRefreshBrain={() => {
                void loadBrain()
                void loadGraph()
              }}
              showToast={showToast}
            />
          ) : pageTab === 'graph' ? (
            <BrainKnowledgeGraph
              graph={graph}
              episodes={episodes}
              loading={graphLoading}
              selectedId={selectedGraphNode?.id ?? null}
              onSelect={setSelectedGraphNode}
              onRefresh={() => void loadGraph()}
              onOpenWorkbench={() => {
                setPageTab('workbench')
                setSelectedGraphNode(null)
              }}
            />
          ) : (
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
                    {episodes.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="muted table-empty">
                          暂无，请试跑发帖
                        </td>
                      </tr>
                    ) : (
                      episodes.map((episode) => (
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
              {tagStats.length === 0 ? (
                <p className="muted">暂无标签，试跑发帖后会自动生成</p>
              ) : (
                <div className="brain-tag-cluster">
                  {tagStats.map((tag) => (
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
                    {memories.length === 0 ? (
                      <tr>
                        <td colSpan={3} className="muted table-empty">
                          暂无 Bot 自传记忆
                        </td>
                      </tr>
                    ) : (
                      memories.map((memory) => (
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
          )}
        </>
      ) : null}
    </MonitorPageLayout>
  )
}
