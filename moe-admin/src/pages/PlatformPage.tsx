import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { AdminTag, TagRow } from '../components/AdminTag'
import { DataDomainMap } from '../components/DataDomainMap'
import { TabbedPageLayout } from '../ui'
import { PageMessage } from '../components/PageMessage'
import { FormField } from '../components/FormField'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { formatBytes, formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

type Tab = 'overview' | 'config' | 'media' | 'data' | 'memory'

type ConfigData = {
  public_api_base_url: string
  api_public_base_url: string
  image_public_base_url: string
  image_local_dir: string
  image_max_bytes: number
  config_file: string
}

type CatalogRow = {
  key: string
  table_name: string
  label: string
  domain: string
  coverage: string
  capabilities: string[]
  admin_route?: string
  row_count: number
  note?: string
}

type MemoryRow = {
  id: string
  user_id: string
  username?: string
  key: string
  value: string
  memory_type: string
  confidence: number
  source: string
  updated_at: string
}

const TABS: { key: Tab; label: string; hint: string }[] = [
  { key: 'overview', label: '概览', hint: '健康检查与关键指标' },
  { key: 'config', label: '连接与地址', hint: 'App API / 图库 URL' },
  { key: 'media', label: '媒体与图库', hint: '云图库文件预览' },
  { key: 'data', label: '数据地图', hint: '数据星系 · 域覆盖' },
  { key: 'memory', label: '记忆治理', hint: '用户记忆条目' },
]

export function PlatformPage() {
  const { client } = useAdminAuth()
  const { apiTargetLabel, health } = usePlatform()
  const [params, setParams] = useSearchParams()
  const tab = (params.get('tab') as Tab) || 'overview'
  const memoryUserId = params.get('user_id') || ''

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const [config, setConfig] = useState<ConfigData | null>(null)
  const [configForm, setConfigForm] = useState({
    public_api_base_url: '',
    api_public_base_url: '',
    image_public_base_url: '',
    image_local_dir: '',
    image_max_bytes: '1073741824',
  })
  const [savingConfig, setSavingConfig] = useState(false)
  const [clientConfigPreview, setClientConfigPreview] = useState('')
  const [clientConfigOk, setClientConfigOk] = useState<boolean | null>(null)

  const [dashboard, setDashboard] = useState<{ user_total: number; landing_feedback_total: number } | null>(null)
  const [memoryStats, setMemoryStats] = useState<{
    total_memories: number
    users_with_memories: number
    total_feedbacks: number
    total_embeddings: number
    by_type?: Array<{ memory_type: string; count: number }>
  } | null>(null)
  const [catalog, setCatalog] = useState<{ summary: Record<string, number>; items: CatalogRow[] } | null>(null)

  const [mediaItems, setMediaItems] = useState<Array<{ filename: string; url: string; size: number }>>([])
  const [memories, setMemories] = useState<MemoryRow[]>([])
  const [memoryTotal, setMemoryTotal] = useState(0)
  const [memoryPage, setMemoryPage] = useState(1)
  const [memoryKeyword, setMemoryKeyword] = useState('')
  const [memorySearch, setMemorySearch] = useState('')
  const [memoryUserFilter, setMemoryUserFilter] = useState(memoryUserId)
  const [dataDomain, setDataDomain] = useState<string | null>(null)

  const apiOnline = health?.local_api?.online ?? health?.cloud_api?.online

  const domainMatrix = useMemo(() => {
    if (!catalog?.items) return []
    const map = new Map<string, { domain: string; tables: number; full: number; partial: number; rows: number }>()
    for (const row of catalog.items) {
      const cur = map.get(row.domain) || { domain: row.domain, tables: 0, full: 0, partial: 0, rows: 0 }
      cur.tables += 1
      if (row.coverage === 'full') cur.full += 1
      else if (row.coverage === 'readonly' || row.coverage === 'partial') cur.partial += 1
      if (row.row_count >= 0) cur.rows += row.row_count
      map.set(row.domain, cur)
    }
    return Array.from(map.values()).sort((a, b) => a.domain.localeCompare(b.domain, 'zh-CN'))
  }, [catalog])

  const testClientConfig = useCallback(async (baseUrl: string) => {
    const base = baseUrl.replace(/\/$/, '')
    if (!base) {
      setClientConfigOk(false)
      setClientConfigPreview('未配置 API 地址')
      return
    }
    try {
      const res = await fetch(`${base}/api/public/client-config`)
      const text = await res.text()
      setClientConfigPreview(text.slice(0, 400))
      setClientConfigOk(res.ok)
    } catch {
      setClientConfigOk(false)
      setClientConfigPreview('无法连接 client-config')
    }
  }, [])

  const loadCore = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [cfgRes, dashRes, memRes, catRes] = await Promise.all([
        client.getRuntimeConfig(),
        client.dashboard(),
        client.getMemoryStats(),
        client.getSchemaCatalog(),
      ])
      if (cfgRes.success && cfgRes.data) {
        setConfig(cfgRes.data)
        setConfigForm({
          public_api_base_url: cfgRes.data.public_api_base_url || '',
          api_public_base_url: cfgRes.data.api_public_base_url || '',
          image_public_base_url: cfgRes.data.image_public_base_url || '',
          image_local_dir: cfgRes.data.image_local_dir || '',
          image_max_bytes: String(cfgRes.data.image_max_bytes || 0),
        })
        void testClientConfig(cfgRes.data.public_api_base_url || cfgRes.data.api_public_base_url)
      }
      if (dashRes.success && dashRes.data) {
        setDashboard({
          user_total: dashRes.data.user_total,
          landing_feedback_total: dashRes.data.landing_feedback_total,
        })
      }
      if (memRes.success && memRes.data) setMemoryStats(memRes.data)
      if (catRes.success && catRes.data) {
        setCatalog({ summary: catRes.data.summary as Record<string, number>, items: catRes.data.items || [] })
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, testClientConfig])

  const loadMedia = useCallback(async () => {
    try {
      const res = await client.listMediaImages({ page: 1, page_size: 12 })
      if (res.success && res.data) setMediaItems(res.data.items || [])
    } catch {
      setMediaItems([])
    }
  }, [client])

  const loadMemories = useCallback(async () => {
    try {
      const res = await client.listMemories({
        page: memoryPage,
        page_size: 20,
        user_id: memoryUserFilter || undefined,
        keyword: memorySearch || undefined,
      })
      if (res.success && res.data) {
        setMemories(res.data.items || [])
        setMemoryTotal(res.data.total || 0)
      }
    } catch {
      setMemories([])
      setMemoryTotal(0)
    }
  }, [client, memoryPage, memorySearch, memoryUserFilter])

  useEffect(() => {
    void loadCore()
  }, [loadCore])

  useEffect(() => {
    if (tab === 'media') void loadMedia()
  }, [tab, loadMedia])

  useEffect(() => {
    if (tab === 'memory') void loadMemories()
  }, [tab, loadMemories])

  useEffect(() => {
    setMemoryUserFilter(memoryUserId)
  }, [memoryUserId])

  function setTab(next: Tab) {
    const nextParams: Record<string, string> = { tab: next }
    if (next === 'memory' && memoryUserFilter) nextParams.user_id = memoryUserFilter
    setParams(nextParams)
  }

  async function saveConfig() {
    const maxBytes = Number(configForm.image_max_bytes)
    if (configForm.image_max_bytes.trim() && (Number.isNaN(maxBytes) || maxBytes < 0)) {
      setError('云空间上限须为非负整数')
      return
    }
    setSavingConfig(true)
    setError('')
    try {
      const res = await client.updateRuntimeConfig({
        public_api_base_url: configForm.public_api_base_url.trim(),
        update_public_api_base_url: true,
        api_public_base_url: configForm.api_public_base_url.trim(),
        update_api_public_base_url: true,
        image_public_base_url: configForm.image_public_base_url.trim(),
        update_image_public_base_url: true,
        image_local_dir: configForm.image_local_dir.trim(),
        update_image_local_dir: true,
        image_max_bytes: maxBytes,
        update_image_max_bytes: true,
      })
      if (!res.success || !res.data) {
        setError(res.message || '保存失败')
        return
      }
      setConfig(res.data)
      setMessage('配置已保存并热更新')
      void testClientConfig(res.data.public_api_base_url || res.data.api_public_base_url)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSavingConfig(false)
    }
  }

  async function removeMemory(id: string) {
    if (!window.confirm('确定删除该记忆条目？')) return
    const res = await client.deleteMemory(id)
    if (!res.success) {
      setError(res.message || '删除失败')
      return
    }
    setMessage('记忆已删除')
    void loadMemories()
    void loadCore()
  }

  const memoryPages = Math.max(1, Math.ceil(memoryTotal / 20))

  return (
    <>
      <TabbedPageLayout
        title="平台治理"
        description="App → API → 数据资产 · 连接配置、图库、数据地图与记忆治理在同一页切换"
        envNote={`当前数据环境：${apiTargetLabel} · 配置写入 backend/config/config.yaml`}
        headActions={
          <button type="button" className="btn btn-ghost" disabled={loading} onClick={() => void loadCore()}>
            刷新
          </button>
        }
        tabs={TABS}
        activeTab={tab}
        onTabChange={setTab}
      >
      {message ? (
        <PageMessage message={message} tone="ok" onClose={() => setMessage('')} />
      ) : null}
      {error ? <p className="text-danger">{error}</p> : null}

      {tab === 'overview' ? (
        <div className="platform-overview">
          <div className="platform-health-grid">
            <div className={`platform-health-card${apiOnline ? ' is-ok' : ''}`}>
              <div className="label">业务 API</div>
              <div className="value">{apiOnline ? '可达' : '不可达'}</div>
              <p className="muted">{apiTargetLabel}</p>
            </div>
            <div className={`platform-health-card${clientConfigOk ? ' is-ok' : clientConfigOk === false ? ' is-err' : ''}`}>
              <div className="label">client-config</div>
              <div className="value">{clientConfigOk === null ? '检测中' : clientConfigOk ? '正常' : '异常'}</div>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => void testClientConfig(configForm.public_api_base_url || configForm.api_public_base_url)}>
                重新检测
              </button>
            </div>
            <div className="platform-health-card">
              <div className="label">注册用户</div>
              <div className="value">{dashboard?.user_total ?? '—'}</div>
            </div>
            <div className="platform-health-card">
              <div className="label">记忆条目</div>
              <div className="value">{memoryStats?.total_memories ?? '—'}</div>
              <p className="muted">{memoryStats?.users_with_memories ?? 0} 位用户有记忆</p>
            </div>
          </div>

          {clientConfigPreview ? (
            <section className="panel platform-panel platform-preview">
              <h3>client-config 预览</h3>
              <pre className="platform-code">{clientConfigPreview}</pre>
            </section>
          ) : null}

          {catalog?.summary ? (
            <section className="panel platform-panel">
              <h3>数据资产概览</h3>
                            <div className="platform-asset-rings">
                <div className="platform-asset-ring">
                  <strong>{catalog.summary.total_tables}</strong>
                  <span>数据表</span>
                </div>
                <div className="platform-asset-ring is-ok">
                  <strong>{catalog.summary.managed_full}</strong>
                  <span>完整治理</span>
                </div>
                <div className="platform-asset-ring is-warn">
                  <strong>{catalog.summary.unmanaged}</strong>
                  <span>待加强</span>
                </div>
              </div>
              <button type="button" className="btn btn-primary btn-sm" onClick={() => setTab('data')}>
                进入数据星系 →
              </button>
            </section>
          ) : null}
        </div>
      ) : null}

      {tab === 'config' && config ? (
        <section className="panel platform-panel platform-config-form">
          <header className="platform-section-head">
            <h3>连接与地址</h3>
            <p className="muted">用业务语言配置 App 冷启动与图片 URL，保存后立即生效。</p>
          </header>
          <div className="platform-config-sections">
            <div className="platform-config-block">
              <h4>🌐 App 与 API</h4>
              <div className="platform-form-grid">
                <FormField label="App 使用的 API 地址">
                  <input value={configForm.public_api_base_url} onChange={(e) => setConfigForm((f) => ({ ...f, public_api_base_url: e.target.value }))} spellCheck={false} placeholder="http://47.106.175.49:8888" />
                </FormField>
                <FormField label="OAuth / 对外回调 API 根">
                  <input value={configForm.api_public_base_url} onChange={(e) => setConfigForm((f) => ({ ...f, api_public_base_url: e.target.value }))} spellCheck={false} placeholder="http://47.106.175.49:8888" />
                </FormField>
              </div>
            </div>
            <div className="platform-config-block">
              <h4>🖼️ 云端图库</h4>
              <div className="platform-form-grid">
                <FormField label="图片公网地址（留空 = 按请求 Host 自动拼接）">
                  <input value={configForm.image_public_base_url} onChange={(e) => setConfigForm((f) => ({ ...f, image_public_base_url: e.target.value }))} spellCheck={false} />
                </FormField>
                <FormField label="服务端图片存储目录">
                  <input value={configForm.image_local_dir} onChange={(e) => setConfigForm((f) => ({ ...f, image_local_dir: e.target.value }))} spellCheck={false} placeholder="/app/data/images" />
                </FormField>
                <div className="platform-form-span">
                <FormField label="用户云空间上限（字节，0 = 不限制）">
                  <input value={configForm.image_max_bytes} onChange={(e) => setConfigForm((f) => ({ ...f, image_max_bytes: e.target.value }))} inputMode="numeric" />
                  <p className="muted platform-field-hint">当前：{formatBytes(config.image_max_bytes)} · 1 GB = 1073741824</p>
                </FormField>
                </div>
              </div>
            </div>
          </div>
          <div className="btn-row">
            <button type="button" className="btn btn-primary" disabled={savingConfig} onClick={() => void saveConfig()}>
              {savingConfig ? '保存中…' : '保存配置'}
            </button>
            <button type="button" className="btn btn-ghost" onClick={() => void testClientConfig(configForm.public_api_base_url || configForm.api_public_base_url)}>
              测试 client-config
            </button>
          </div>
          <p className="muted" style={{ marginTop: 12, fontSize: 12 }}>
            配置文件：<code>{config.config_file}</code>
          </p>
        </section>
      ) : null}

      {tab === 'media' ? (
        <section className="panel platform-panel">
          <div className="page-head-row" style={{ marginBottom: 12 }}>
            <h3 style={{ margin: 0 }}>云图库预览</h3>
            <Link to="/system/platform?tab=config" className="btn btn-ghost btn-sm">图库 URL 配置</Link>
          </div>
          <div className="platform-media-grid">
            {mediaItems.length === 0 ? (
              <p className="muted">暂无图片，或请确认 Image.LocalDir 路径</p>
            ) : (
              mediaItems.map((item) => (
                <a key={item.filename} className="platform-media-thumb" href={item.url} target="_blank" rel="noreferrer">
                  <img src={item.url} alt="" loading="lazy" />
                  <span>{item.filename}</span>
                </a>
              ))
            )}
          </div>
        </section>
      ) : null}

      {tab === 'data' && catalog ? (
        <section className="panel platform-panel platform-data-stage">
          <DataDomainMap
            matrix={domainMatrix}
            items={catalog.items}
            selectedDomain={dataDomain}
            onSelectDomain={setDataDomain}
          />
          <div className="platform-data-foot">
            <Link className="btn btn-ghost btn-sm" to="/system/data">完整数据目录（树形 + 快捷操作）</Link>
            {dataDomain ? (
              <div className="platform-data-actions">
                {catalog.items
                  .filter((r) => r.domain === dataDomain && r.admin_route)
                  .slice(0, 6)
                  .map((row) => (
                    <Link key={row.key} className="btn btn-mint btn-sm" to={row.admin_route!}>
                      {row.label}
                    </Link>
                  ))}
              </div>
            ) : null}
          </div>
        </section>
      ) : null}

      {tab === 'memory' ? (
        <section className="panel platform-panel">
          <div className="page-head-row" style={{ marginBottom: 12 }}>
            <div>
              <h3 style={{ margin: 0 }}>记忆治理</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>
                共 {memoryStats?.total_memories ?? 0} 条 · {memoryStats?.users_with_memories ?? 0} 用户 · 向量 {memoryStats?.total_embeddings ?? 0}
              </p>
            </div>
          </div>
          {memoryStats?.by_type?.length ? (
            <TagRow>
              {memoryStats.by_type.map((t) => (
                <AdminTag key={t.memory_type} label={`${t.memory_type} ${t.count}`} tone="mint" />
              ))}
            </TagRow>
          ) : null}
          <form
            className="inline-form"
            style={{ marginTop: 12 }}
            onSubmit={(e) => {
              e.preventDefault()
              setMemoryPage(1)
              setMemorySearch(memoryKeyword.trim())
            }}
          >
            <input placeholder="用户 ID" value={memoryUserFilter} onChange={(e) => setMemoryUserFilter(e.target.value)} style={{ maxWidth: 100 }} />
            <input placeholder="搜索 key / 内容" value={memoryKeyword} onChange={(e) => setMemoryKeyword(e.target.value)} />
            <button type="submit" className="btn btn-primary">搜索</button>
          </form>
          <div className="table-wrap" style={{ marginTop: 12 }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>用户</th>
                  <th>Key</th>
                  <th>类型</th>
                  <th>内容</th>
                  <th>更新</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {memories.length === 0 ? (
                  <tr><td colSpan={6} className="muted">暂无记忆数据</td></tr>
                ) : (
                  memories.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <Link to={`/users`}>{row.username || row.user_id}</Link>
                        <div className="muted" style={{ fontSize: 11 }}><IdCell id={row.user_id} /></div>
                      </td>
                      <td><code style={{ fontSize: 11 }}>{row.key}</code></td>
                      <td>{row.memory_type}</td>
                      <td className="muted" style={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis' }}>{row.value}</td>
                      <td className="muted">{formatDateTime(row.updated_at)}</td>
                      <td>
                        <button type="button" className="btn btn-ghost btn-sm text-danger" onClick={() => void removeMemory(row.id)}>删除</button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          {memoryPages > 1 ? (
            <div className="pager">
              <button type="button" className="btn btn-ghost" disabled={memoryPage <= 1} onClick={() => setMemoryPage((p) => p - 1)}>上一页</button>
              <span className="muted">{memoryPage}/{memoryPages}</span>
              <button type="button" className="btn btn-ghost" disabled={memoryPage >= memoryPages} onClick={() => setMemoryPage((p) => p + 1)}>下一页</button>
            </div>
          ) : null}
        </section>
      ) : null}
      </TabbedPageLayout>
    </>
  )
}
