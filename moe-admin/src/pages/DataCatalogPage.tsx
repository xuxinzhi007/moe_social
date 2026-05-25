import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { AdminTag, TagRow } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { useAdminAuth } from '../context/AdminAuthContext'
import { capabilityTag, schemaCoverageTag } from '../lib/adminLabels'
import {
  RUNTIME_CONFIG_ACTION,
  schemaDomainHint,
  schemaQuickActions,
} from '../lib/schemaActions'
import { DeployApiError } from '../api/deployClient'

type Row = {
  key: string
  table_name: string
  label: string
  domain: string
  coverage: string
  capabilities: string[]
  admin_route?: string
  bootstrap_key?: string
  row_count: number
  note?: string
}

type Summary = {
  total_tables: number
  managed_full: number
  managed_partial: number
  unmanaged: number
  total_rows: number
}

function formatCount(n: number) {
  if (n < 0) return '—'
  return n.toLocaleString('zh-CN')
}

export function DataCatalogPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<Row[]>([])
  const [summary, setSummary] = useState<Summary | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [keyword, setKeyword] = useState('')
  const [openDomains, setOpenDomains] = useState<Record<string, boolean>>({})
  const [selectedKey, setSelectedKey] = useState<string>('__runtime_config__')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.getSchemaCatalog()
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setItems([])
        setSummary(null)
        return
      }
      setItems(res.data.items || [])
      setSummary(res.data.summary || null)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
      setItems([])
      setSummary(null)
    } finally {
      setLoading(false)
    }
  }, [client])

  useEffect(() => {
    void load()
  }, [load])

  const grouped = useMemo(() => {
    const kw = keyword.trim().toLowerCase()
    const map = new Map<string, Row[]>()
    for (const row of items) {
      if (kw) {
        const hit =
          row.label.toLowerCase().includes(kw) ||
          row.table_name.toLowerCase().includes(kw) ||
          row.key.toLowerCase().includes(kw)
        if (!hit) continue
      }
      const list = map.get(row.domain) || []
      list.push(row)
      map.set(row.domain, list)
    }
    return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b, 'zh-CN'))
  }, [items, keyword])

  useEffect(() => {
    setOpenDomains((prev) => {
      const next = { ...prev }
      for (const [domain] of grouped) {
        if (next[domain] === undefined) next[domain] = true
      }
      return next
    })
  }, [grouped])

  const selectedRow = useMemo(
    () => items.find((r) => r.key === selectedKey) || null,
    [items, selectedKey],
  )

  const quickActions = selectedRow ? schemaQuickActions(selectedRow.key) : []
  const domainHint = selectedRow ? schemaDomainHint(selectedRow.domain) : undefined

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>数据目录</h2>
          <p>左侧选择表 · 右侧查看能力与快捷编辑 · 支持 URL / 头像 / 配置入口</p>
        </div>
        <button type="button" className="btn btn-primary" disabled={loading} onClick={() => void load()}>
          {loading ? '刷新中…' : '刷新统计'}
        </button>
      </div>

      <DataEnvBar note="表结构与 db.go AutoMigrate 同步" />

      {summary ? (
        <div className="admin-metrics schema-summary" style={{ marginBottom: 16 }}>
          <div className="metric metric-accent-run">
            <div className="label">数据表</div>
            <div className="value">{summary.total_tables}</div>
          </div>
          <div className="metric metric-accent-ok">
            <div className="label">完整管理</div>
            <div className="value">{summary.managed_full}</div>
          </div>
          <div className="metric metric-accent-vip">
            <div className="label">部分/只读</div>
            <div className="value">{summary.managed_partial}</div>
          </div>
          <div className="metric">
            <div className="label">待接入</div>
            <div className="value">{summary.unmanaged}</div>
          </div>
          <div className="metric metric-accent-run">
            <div className="label">累计行数</div>
            <div className="value">{formatCount(summary.total_rows)}</div>
          </div>
        </div>
      ) : null}

      <div className="catalog-split">
        <aside className="catalog-tree panel">
          <input
            className="catalog-tree-search"
            placeholder="搜索表名 / 中文名"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
          />

          <button
            type="button"
            className={`catalog-tree-item catalog-tree-special${selectedKey === '__runtime_config__' ? ' is-active' : ''}`}
            onClick={() => setSelectedKey('__runtime_config__')}
          >
            <span className="catalog-tree-icon">⚙️</span>
            <span>应用配置</span>
            <AdminTag label="URL" tone="mint" />
          </button>

          {loading && items.length === 0 ? (
            <p className="muted" style={{ padding: 8 }}>
              加载中…
            </p>
          ) : (
            grouped.map(([domain, rows]) => {
              const open = openDomains[domain] !== false
              return (
                <div key={domain} className={`catalog-tree-group${open ? ' is-open' : ''}`}>
                  <button
                    type="button"
                    className="catalog-tree-group-head"
                    onClick={() => setOpenDomains((m) => ({ ...m, [domain]: !open }))}
                  >
                    <span className="catalog-tree-chevron">{open ? '▾' : '▸'}</span>
                    <span>{domain}</span>
                    <span className="catalog-tree-count">{rows.length}</span>
                  </button>
                  {open ? (
                    <div className="catalog-tree-children">
                      {rows.map((row) => (
                        <button
                          key={row.key}
                          type="button"
                          className={`catalog-tree-item${selectedKey === row.key ? ' is-active' : ''}`}
                          onClick={() => setSelectedKey(row.key)}
                        >
                          <span className="catalog-tree-dot" />
                          <span className="catalog-tree-label">{row.label}</span>
                          <AdminTag spec={schemaCoverageTag(row.coverage)} />
                        </button>
                      ))}
                    </div>
                  ) : null}
                </div>
              )
            })
          )}
        </aside>

        <section className="catalog-detail panel">
          {error ? <p className="text-danger">{error}</p> : null}

          {selectedKey === '__runtime_config__' ? (
            <>
              <div className="catalog-detail-head">
                <h3>{RUNTIME_CONFIG_ACTION.label}</h3>
                <p className="muted">{RUNTIME_CONFIG_ACTION.hint}</p>
              </div>
              <div className="catalog-action-cards">
                <div className="catalog-action-card">
                  <h4>可编辑项</h4>
                  <ul className="catalog-bullet">
                    <li>App client-config 公网 API 地址</li>
                    <li>OAuth 回调用 API 根地址</li>
                    <li>云端图库 Image.PublicBaseUrl</li>
                    <li>图片存储目录与云空间上限</li>
                  </ul>
                  <Link className="btn btn-primary" to={RUNTIME_CONFIG_ACTION.to}>
                    打开应用配置
                  </Link>
                </div>
              </div>
            </>
          ) : selectedRow ? (
            <>
              <div className="catalog-detail-head">
                <h3>{selectedRow.label}</h3>
                <code className="id-cell id-cell-mono">{selectedRow.table_name || selectedRow.key}</code>
              </div>

              <div className="catalog-detail-metrics">
                <div>
                  <span className="muted">行数</span>
                  <strong>{formatCount(selectedRow.row_count)}</strong>
                </div>
                <div>
                  <span className="muted">覆盖</span>
                  <AdminTag spec={schemaCoverageTag(selectedRow.coverage)} />
                </div>
                <div>
                  <span className="muted">分组</span>
                  <strong>{selectedRow.domain}</strong>
                </div>
              </div>

              {selectedRow.note ? <p className="catalog-note">{selectedRow.note}</p> : null}
              {domainHint ? <p className="admin-hint">{domainHint}</p> : null}

              <div className="catalog-detail-block">
                <h4>能力</h4>
                <TagRow>
                  {(selectedRow.capabilities || []).map((cap) => (
                    <AdminTag key={cap} spec={capabilityTag(cap)} />
                  ))}
                  {(selectedRow.capabilities || []).length === 0 ? (
                    <span className="muted">暂无 Admin 能力，需后续接入 CRUD</span>
                  ) : null}
                </TagRow>
              </div>

              <div className="catalog-detail-block">
                <h4>快捷操作</h4>
                <div className="btn-row catalog-action-row">
                  {selectedRow.admin_route ? (
                    <Link className="btn btn-primary" to={selectedRow.admin_route}>
                      进入管理页
                    </Link>
                  ) : null}
                  {quickActions.map((action) => (
                    <Link key={action.to + action.label} className="btn btn-mint" to={action.to}>
                      {action.label}
                    </Link>
                  ))}
                  {(selectedRow.key === 'users' || selectedRow.domain === '用户与会员') && (
                    <Link className="btn btn-ghost" to="/system/app-config">
                      图库 URL 配置
                    </Link>
                  )}
                </div>
                {quickActions.map((a) =>
                  a.hint ? (
                    <p key={a.label} className="muted catalog-action-hint">
                      {a.hint}
                    </p>
                  ) : null,
                )}
              </div>
            </>
          ) : (
            <p className="muted">请从左侧选择一张表或「应用配置」</p>
          )}
        </section>
      </div>
    </>
  )
}
