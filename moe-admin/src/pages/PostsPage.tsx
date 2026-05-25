import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { IdCell } from '../components/IdCell'
import { UserCell } from '../components/UserCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { moderationTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

export function PostsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<
    Array<{
      id: string
      user_id?: string
      user_name: string
      user_avatar?: string
      content: string
      moderation_status?: string
      likes: number
      comments: number
      created_at: string
    }>
  >([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listPosts({
        page,
        page_size: pageSize,
        keyword: search || undefined,
        moderation_status: status || undefined,
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
  }, [client, page, search, status])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head">
        <h2>动态审核</h2>
        <p>查看与下架用户动态，支持审核状态筛选</p>
      </div>
      <DataEnvBar />
      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setSearch(keyword.trim())
          }}
        >
          <input placeholder="搜索正文" value={keyword} onChange={(e) => setKeyword(e.target.value)} />
          <select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1) }}>
            <option value="">全部状态</option>
            <option value="ok">已通过</option>
            <option value="pending">待审核</option>
            <option value="rejected">已拒绝</option>
          </select>
          <button type="submit" className="btn btn-primary">
            搜索
          </button>
        </form>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>作者</th>
                <th>ID</th>
                <th>内容</th>
                <th>状态</th>
                <th>赞/评</th>
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
                    暂无动态
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <UserCell
                        name={row.user_name}
                        avatar={row.user_avatar}
                        sub={row.user_id ? `UID ${row.user_id}` : undefined}
                      />
                    </td>
                    <td>
                      <IdCell id={row.id} />
                    </td>
                    <td style={{ maxWidth: 320 }}>
                      {row.content.slice(0, 80)}
                      {row.content.length > 80 ? '…' : ''}
                    </td>
                    <td>
                      <AdminTag spec={moderationTag(row.moderation_status)} />
                    </td>
                    <td>
                      <AdminTag label={`${row.likes} 赞`} tone="neutral" />
                      <span className="muted" style={{ margin: '0 4px' }}>/</span>
                      <AdminTag label={`${row.comments} 评`} tone="info" />
                    </td>
                    <td className="muted">{formatDateTime(row.created_at)}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm('确定删除该动态？')) return
                          const res = await client.deletePost(row.id)
                          if (!res.success) setError(res.message || '删除失败')
                          else await load()
                        }}
                      >
                        删除
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
