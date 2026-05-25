import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { IdCell } from '../components/IdCell'
import { UserCell } from '../components/UserCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'

export function AiAgentsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<
    Array<{ id: string; owner_user_id: string; owner_name: string; payload_json: string }>
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
      const res = await client.listAiAgents({ page, page_size: pageSize, keyword: search || undefined })
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setItems([])
        setTotal(0)
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

  function parseName(payload: string) {
    try {
      const o = JSON.parse(payload) as { name?: string }
      return o.name || '—'
    } catch {
      return '—'
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head">
        <h2>AI 角色酒馆</h2>
        <p>公开 Agent 列表与治理</p>
      </div>
      <DataEnvBar />      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setSearch(keyword.trim())
          }}
        >
          <input placeholder="搜索角色名 / 用户" value={keyword} onChange={(e) => setKeyword(e.target.value)} />
          <button type="submit" className="btn btn-primary">
            搜索
          </button>
        </form>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Agent ID</th>
                <th>角色名</th>
                <th>所属用户</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={4} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={4} className="muted">
                    暂无公开 Agent
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={`${row.owner_user_id}-${row.id}`}>
                    <td>
                      <IdCell id={row.id} />
                    </td>
                    <td>
                      <AdminTag label={parseName(row.payload_json)} tone="purple" />
                    </td>
                    <td>
                      <UserCell
                        name={row.owner_name || row.owner_user_id}
                        sub={`UID ${row.owner_user_id}`}
                      />
                    </td>                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm('删除该 Agent？')) return
                          const res = await client.deleteAiAgent({
                            user_id: row.owner_user_id,
                            agent_id: row.id,
                          })
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
