import { useCallback, useEffect, useState } from 'react'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { usePlatform } from '../context/PlatformContext'
import { DeployApiError } from '../api/deployClient'

type FeedbackItem = {
  id: number
  email: string
  category: string
  content: string
  source: string
  client_ip?: string
  created_at: string
}

const CATEGORY_LABEL: Record<string, string> = {
  feature: '功能建议',
  bug: '问题反馈',
  other: '其他',
  all: '全部',
}

function categoryTagClass(cat: string) {
  if (cat === 'feature') return 'fb-tag fb-tag-feature'
  if (cat === 'bug') return 'fb-tag fb-tag-bug'
  return 'fb-tag fb-tag-other'
}

function formatTime(iso: string) {
  try {
    return new Date(iso).toLocaleString('zh-CN', { hour12: false })
  } catch {
    return iso
  }
}

export function FeedbackPage() {
  const { client } = useAdminAuth()
  const { showToast } = useDeploy()
  const { apiTargetLabel } = usePlatform()
  const [items, setItems] = useState<FeedbackItem[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [category, setCategory] = useState('all')
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState<FeedbackItem | null>(null)
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const cat = category === 'all' ? undefined : category
      const res = await client.listLandingFeedback({
        page,
        page_size: pageSize,
        category: cat,
      })
      if (!res.success || !res.data) {
        showToast(res.message || '加载失败')
        setItems([])
        setTotal(0)
        return
      }
      setItems(res.data.items || [])
      setTotal(res.data.total || 0)
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '加载失败')
      setItems([])
      setTotal(0)
    } finally {
      setLoading(false)
    }
  }, [category, client, page, showToast])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>官网意见反馈</h2>
          <p>
            来自落地页 <code>#join</code> 的提交 · 数据环境{' '}
            <code>{apiTargetLabel}</code>
          </p>
        </div>
        <div className="btn-row">
          <select
            className="select-inline"
            value={category}
            onChange={(e) => {
              setCategory(e.target.value)
              setPage(1)
            }}
          >
            <option value="all">全部类型</option>
            <option value="feature">功能建议</option>
            <option value="bug">问题反馈</option>
            <option value="other">其他</option>
          </select>
          <button
            type="button"
            className="btn btn-primary"
            disabled={loading}
            onClick={() => void load()}
          >
            {loading ? '刷新中…' : '刷新'}
          </button>
        </div>
      </div>

      <div className="panel fb-panel">
        <div className="panel-head">
          <h3>反馈列表</h3>
          <span className="tag tag-pending">共 {total} 条</span>
        </div>
        <div className="panel-body" style={{ padding: 0 }}>
          {loading && items.length === 0 ? (
            <p className="loading-hint" style={{ padding: 16 }}>
              正在加载…
            </p>
          ) : items.length === 0 ? (
            <p className="loading-hint" style={{ padding: 16 }}>
              暂无反馈，或云端 API 尚未部署含列表接口的版本。
            </p>
          ) : (
            <table className="jobs-table fb-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>类型</th>
                  <th>邮箱</th>
                  <th>摘要</th>
                  <th>时间</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row) => (
                  <tr
                    key={row.id}
                    className={selected?.id === row.id ? 'selected' : ''}
                    onClick={() => setSelected(row)}
                  >
                    <td>#{row.id}</td>
                    <td>
                      <span className={categoryTagClass(row.category)}>
                        {CATEGORY_LABEL[row.category] || row.category}
                      </span>
                    </td>
                    <td>{row.email}</td>
                    <td className="fb-snippet">
                      {row.content.length > 48
                        ? `${row.content.slice(0, 48)}…`
                        : row.content}
                    </td>
                    <td>{formatTime(row.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        {total > pageSize ? (
          <div className="panel-body fb-pager">
            <button
              type="button"
              className="btn btn-ghost"
              disabled={page <= 1 || loading}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              上一页
            </button>
            <span>
              {page} / {totalPages}
            </span>
            <button
              type="button"
              className="btn btn-ghost"
              disabled={page >= totalPages || loading}
              onClick={() => setPage((p) => p + 1)}
            >
              下一页
            </button>
          </div>
        ) : null}
      </div>

      {selected ? (
        <div className="panel fb-detail">
          <div className="panel-head">
            <h3>反馈 #{selected.id}</h3>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => setSelected(null)}
            >
              关闭
            </button>
          </div>
          <div className="panel-body">
            <div className="env-kv">
              <div className="env-kv-row">
                <dt>类型</dt>
                <dd>
                  <span className={categoryTagClass(selected.category)}>
                    {CATEGORY_LABEL[selected.category] || selected.category}
                  </span>
                </dd>
              </div>
              <div className="env-kv-row">
                <dt>邮箱</dt>
                <dd>{selected.email}</dd>
              </div>
              <div className="env-kv-row">
                <dt>来源</dt>
                <dd>{selected.source || 'official-site'}</dd>
              </div>
              <div className="env-kv-row">
                <dt>IP</dt>
                <dd>{selected.client_ip || '—'}</dd>
              </div>
              <div className="env-kv-row">
                <dt>时间</dt>
                <dd>{formatTime(selected.created_at)}</dd>
              </div>
            </div>
            <p className="fb-detail-content">{selected.content}</p>
          </div>
        </div>
      ) : null}
    </>
  )
}
