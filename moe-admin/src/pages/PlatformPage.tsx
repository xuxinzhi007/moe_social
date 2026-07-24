import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { DataDomainMap } from '../components/DataDomainMap'
import { TabbedPageLayout } from '../ui'
import { PageMessage } from '../components/PageMessage'
import { FormField } from '../components/FormField'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { formatBytes } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
import { useDirectAdminApi } from '../lib/adminApi'
import { resolveMediaViewUrl } from '../lib/mediaUrl'

type Tab = 'overview' | 'config' | 'media' | 'data'

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

const TABS: { key: Tab; label: string; hint: string }[] = [
  { key: 'overview', label: '概览', hint: '健康检查与关键指标' },
  { key: 'config', label: '连接与地址', hint: 'App API / 图库 URL' },
  { key: 'media', label: '媒体与图库', hint: '云图库文件预览' },
  { key: 'data', label: '数据地图', hint: '数据星系 · 域覆盖' },
]

export function PlatformPage() {
  const { client } = useAdminAuth()
  const { apiTarget, apiTargetLabel, health } = usePlatform()
  const devDirect = useDirectAdminApi()
  const apiBase = useMemo(() => {
    const h = apiTarget === 'cloud' ? health?.cloud_api : health?.local_api
    return h?.base_url?.replace(/\/$/, '') || ''
  }, [apiTarget, health])
  const [params, setParams] = useSearchParams()
  const tab = (params.get('tab') as Tab) || 'overview'

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

  const [dashboard, setDashboard] = useState<{ user_total: number; server_time: string } | null>(null)
  const [catalog, setCatalog] = useState<{ summary: Record<string, number>; items: CatalogRow[] } | null>(null)

  const [mediaItems, setMediaItems] = useState<Array<{ filename: string; url: string; size: number }>>([])
  const [mediaTotal, setMediaTotal] = useState(0)
  const [mediaOwnerCount, setMediaOwnerCount] = useState(0)
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
      const [cfgRes, dashRes, catRes] = await Promise.all([
        client.getRuntimeConfig(),
        client.dashboard(),
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
          server_time: dashRes.data.server_time,
        })
      }
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
      if (res.success && res.data) {
        setMediaItems(res.data.items || [])
        setMediaTotal(res.data.total || 0)
        setMediaOwnerCount(res.data.owners?.length || 0)
      } else {
        setMediaItems([])
        setMediaTotal(0)
        setMediaOwnerCount(0)
      }
    } catch {
      setMediaItems([])
      setMediaTotal(0)
      setMediaOwnerCount(0)
    }
  }, [client])

  useEffect(() => {
    void loadCore()
  }, [loadCore])

  useEffect(() => {
    if (tab === 'media') void loadMedia()
  }, [tab, loadMedia, apiTarget])

  function setTab(next: Tab) {
    setParams({ tab: next })
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

  return (
    <>
      <TabbedPageLayout
        title="平台治理"
        description="App → API → 数据资产 · 连接配置、图库与数据地图在同一页切换"
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
                测试
              </button>
            </div>
            <div className="platform-health-card">
              <div className="label">用户总数</div>
              <div className="value">{dashboard?.user_total ?? 0}</div>
              <p className="muted">注册用户</p>
            </div>
            <div className="platform-health-card">
              <div className="label">服务时间</div>
              <div className="value">{dashboard?.server_time ? '已返回' : '—'}</div>
              <p className="muted">API 时间：{dashboard?.server_time || '—'}</p>
            </div>
          </div>
          <section className="panel platform-panel">
            <div className="page-head-row">
              <div>
                <h3 style={{ margin: 0 }}>快速入口</h3>
                <p className="muted" style={{ margin: '4px 0 0' }}>常用配置与管理工具</p>
              </div>
            </div>
            <div className="platform-quick-grid">
              <div className="quick-item">
                <div className="quick-icon">🔗</div>
                <div>
                  <div className="quick-title">连接与地址</div>
                  <div className="quick-desc">API 地址、图库 URL 配置</div>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setTab('config')}>前往</button>
              </div>
              <div className="quick-item">
                <div className="quick-icon">🖼️</div>
                <div>
                  <div className="quick-title">媒体与图库</div>
                  <div className="quick-desc">云图库文件管理</div>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setTab('media')}>前往</button>
              </div>
              <div className="quick-item">
                <div className="quick-icon">🗺️</div>
                <div>
                  <div className="quick-title">数据地图</div>
                  <div className="quick-desc">数据表域覆盖与能力</div>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setTab('data')}>前往</button>
              </div>
            </div>
          </section>
        </div>
      ) : null}

      {tab === 'config' ? (
        <section className="panel platform-panel">
          <div className="page-head-row" style={{ marginBottom: 16 }}>
            <div>
              <h3 style={{ margin: 0 }}>连接与地址</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>
                配置文件：{config?.config_file || '—'}
              </p>
            </div>
          </div>
          <div className="config-form-grid">
            <FormField label="对外 API 地址 (public)" hint="App 端访问的 API 根地址">
              <input
                type="text"
                value={configForm.public_api_base_url}
                onChange={(e) => setConfigForm((f) => ({ ...f, public_api_base_url: e.target.value }))}
                placeholder="https://api.example.com"
              />
            </FormField>
            <FormField label="API 公共地址" hint="client-config 中返回的 API 地址">
              <input
                type="text"
                value={configForm.api_public_base_url}
                onChange={(e) => setConfigForm((f) => ({ ...f, api_public_base_url: e.target.value }))}
                placeholder="https://api.example.com"
              />
            </FormField>
            <FormField label="图片公开地址" hint="图片 CDN 或静态资源地址">
              <input
                type="text"
                value={configForm.image_public_base_url}
                onChange={(e) => setConfigForm((f) => ({ ...f, image_public_base_url: e.target.value }))}
                placeholder="https://images.example.com"
              />
            </FormField>
            <FormField label="图片本地目录" hint="服务器上存储图片的目录路径">
              <input
                type="text"
                value={configForm.image_local_dir}
                onChange={(e) => setConfigForm((f) => ({ ...f, image_local_dir: e.target.value }))}
                placeholder="/app/data/images"
              />
            </FormField>
            <FormField label="单图片大小上限 (bytes)" hint="上传图片的最大体积">
              <input
                type="text"
                value={configForm.image_max_bytes}
                onChange={(e) => setConfigForm((f) => ({ ...f, image_max_bytes: e.target.value }))}
                placeholder="1073741824"
              />
            </FormField>
          </div>
          <div style={{ marginTop: 20 }}>
            <button type="button" className="btn btn-primary" disabled={savingConfig} onClick={() => void saveConfig()}>
              {savingConfig ? '保存中…' : '保存配置'}
            </button>
          </div>
          {clientConfigPreview ? (
            <div className="config-preview" style={{ marginTop: 20 }}>
              <div className="muted" style={{ marginBottom: 6 }}>client-config 预览：</div>
              <pre>{clientConfigPreview}</pre>
            </div>
          ) : null}
        </section>
      ) : null}

      {tab === 'media' ? (
        <section className="panel platform-panel">
          <div className="page-head-row" style={{ marginBottom: 12 }}>
            <div>
              <h3 style={{ margin: 0 }}>媒体与图库</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>
                共 {mediaTotal} 个文件 · {mediaOwnerCount} 个所有者目录
              </p>
            </div>
          </div>
          {mediaItems.length === 0 ? (
            <p className="muted">暂无媒体文件</p>
          ) : (
            <div className="media-grid">
              {mediaItems.map((item) => (
                <div key={item.filename} className="media-item">
                  <div className="media-thumb">
                    <img src={resolveMediaViewUrl(item.url, apiBase, devDirect, apiTarget)} alt={item.filename} />
                  </div>
                  <div className="media-info">
                    <div className="media-name" title={item.filename}>{item.filename}</div>
                    <div className="muted">{formatBytes(item.size)}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
          <p className="muted" style={{ marginTop: 12, fontSize: 12 }}>
            完整管理请前往「系统管理 → 云图库」
          </p>
        </section>
      ) : null}

      {tab === 'data' ? (
        <section className="panel platform-panel">
          <div className="page-head-row" style={{ marginBottom: 12 }}>
            <div>
              <h3 style={{ margin: 0 }}>数据地图</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>
                {catalog?.summary?.total_tables ?? 0} 张表 · {catalog?.summary?.managed_full ?? 0} 全量托管
              </p>
            </div>
          </div>
          <DataDomainMap
            matrix={domainMatrix}
            items={catalog?.items || []}
            selectedDomain={dataDomain}
            onSelectDomain={setDataDomain}
          />
        </section>
      ) : null}
      </TabbedPageLayout>
    </>
  )
}
