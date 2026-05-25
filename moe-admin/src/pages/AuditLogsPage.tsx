import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { useAdminAuth } from '../context/AdminAuthContext'
import { auditActionTag, auditResourceTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
export function AuditLogsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<
    Array<{
      id: string
      admin_name: string
      action: string
      resource: string
      resource_id: string
      detail: string
      ip: string
      created_at: string
    }>
  >([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [action, setAction] = useState('')
  const [resource, setResource] = useState('')
  const [filters, setFilters] = useState({ action: '', resource: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 30

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listAuditLogs({
        page,
        page_size: pageSize,
        action: filters.action || undefined,
        resource: filters.resource || undefined,
      })
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        return
      }
      setItems(res.data.items || [])
      setTotal(res.data.total || 0)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, page, filters])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head">
        <h2>操作日志</h2>
        <p>管理员关键操作审计记录</p>
      </div>
      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setFilters({ action: action.trim(), resource: resource.trim() })
          }}
        >
          <input placeholder="操作 action" value={action} onChange={(e) => setAction(e.target.value)} />
          <input placeholder="资源 resource" value={resource} onChange={(e) => setResource(e.target.value)} />
          <button type="submit" className="btn btn-primary">
            筛选
          </button>
        </form>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>时间</th>
                <th>管理员</th>
                <th>操作</th>
                <th>资源</th>
                <th>详情</th>
                <th>IP</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="muted">
                    暂无操作记录
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td className="muted">{formatDateTime(row.created_at)}</td>
                    <td>{row.admin_name || row.id}</td>
                    <td>
                      <AdminTag spec={auditActionTag(row.action)} />
                    </td>
                    <td>
                      <AdminTag spec={auditResourceTag(row.resource)} />
                      {row.resource_id ? (
                        <span className="muted" style={{ marginLeft: 6, fontSize: 11 }}>
                          #{row.resource_id}
                        </span>
                      ) : null}
                    </td>
                    <td>{row.detail || '—'}</td>
                    <td className="muted">{row.ip || '—'}</td>
                  </tr>                ))
              )}
            </tbody>
          </table>
        </div>
        {totalPages > 1 ? (
          <div className="pager">
            <button type="button" className="btn btn-ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              上一页
            </button>
            <span className="muted">
              {page}/{totalPages} · 共 {total} 条
            </span>
            <button
              type="button"
              className="btn btn-ghost"
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              下一页
            </button>
          </div>
        ) : null}
      </div>
    </>
  )
}
