import { useCallback, useEffect, useState } from 'react'
import { DataEnvBar } from '../components/DataEnvBar'
import { PageInsightStrip } from '../components/PageInsightStrip'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'

export function CommunityGroupsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<
    Array<{
      id: string
      name: string
      description: string
      creator_name: string
      member_count: number
      status: string
      is_public: boolean
      created_at: string
    }>
  >([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listGroups({ page, page_size: pageSize, keyword: search || undefined })
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
  }, [client, page, search])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>兴趣社区</h2>
          <p className="muted">社区小组列表与运营下架</p>
        </div>
      </div>
      <DataEnvBar />
      <PageInsightStrip items={[{ label: '小组数量', value: loading ? '…' : total }]} />
      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setSearch(keyword.trim())
          }}
        >
          <input placeholder="搜索名称 / 简介" value={keyword} onChange={(e) => setKeyword(e.target.value)} />
          <button type="submit" className="btn btn-primary">
            搜索
          </button>
        </form>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>名称</th>
                <th>创建者</th>
                <th>成员</th>
                <th>公开</th>
                <th>状态</th>
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
                    暂无社区
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.name}</td>
                    <td>{row.creator_name}</td>
                    <td>{row.member_count}</td>
                    <td>{row.is_public ? '是' : '否'}</td>
                    <td>{row.status}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm(`删除社区「${row.name}」？`)) return
                          const res = await client.deleteGroup(row.id)
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
