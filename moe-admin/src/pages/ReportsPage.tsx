import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { reportReasonTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

export function ReportsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<
    Array<{
      id: string
      post_id: string
      reporter_user_id: string
      reason: string
      post_content_preview: string
      created_at: string
    }>
  >([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 30

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listPostReports({ page, page_size: pageSize })
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
  }, [client, page])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head">
        <h2>举报处理</h2>
        <p>用户举报动态记录，可跳转动态页下架</p>
      </div>
      <div className="panel">
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>动态</th>
                <th>举报人</th>
                <th>原因</th>
                <th>预览</th>
                <th>时间</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="muted">
                    暂无举报
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <IdCell id={row.id} />
                    </td>
                    <td>
                      <IdCell id={row.post_id} />
                    </td>
                    <td>
                      <IdCell id={row.reporter_user_id} title="举报人 UID" />
                    </td>
                    <td>
                      <AdminTag spec={reportReasonTag(row.reason)} />
                    </td>
                    <td>{row.post_content_preview || '—'}</td>
                    <td className="muted">{formatDateTime(row.created_at)}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm('删除被举报动态？')) return
                          const res = await client.deletePost(row.post_id)
                          if (!res.success) setError(res.message || '删除失败')
                          else await load()
                        }}
                      >
                        删动态
                      </button>
                    </td>
                  </tr>
                ))
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
              {page}/{totalPages}
            </span>
            <button type="button" className="btn btn-ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              下一页
            </button>
          </div>
        ) : null}
      </div>
    </>
  )
}
