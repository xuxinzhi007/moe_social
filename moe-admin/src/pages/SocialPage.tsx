import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { IdCell } from '../components/IdCell'
import { UserCell } from '../components/UserCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { friendRequestTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
type Tab = 'follows' | 'requests'

export function SocialPage() {
  const { client } = useAdminAuth()
  const [tab, setTab] = useState<Tab>('follows')
  const [follows, setFollows] = useState<
    Array<{
      id: string
      follower_id?: string
      follower_name: string
      following_id?: string
      following_name: string
      created_at: string
    }>
  >([])
  const [requests, setRequests] = useState<
    Array<{
      id: string
      from_user_id?: string
      from_user_name: string
      to_user_id?: string
      to_user_name: string
      status: string
      created_at: string
    }>
  >([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      if (tab === 'follows') {
        const res = await client.listFollows({ page, page_size: pageSize })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          return
        }
        setFollows(res.data.items || [])
        setTotal(res.data.total || 0)
      } else {
        const res = await client.listFriendRequests({ page, page_size: pageSize })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          return
        }
        setRequests(res.data.items || [])
        setTotal(res.data.total || 0)
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, page, tab])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head">
        <h2>好友与关注</h2>
        <p>关系链只读与治理，展示用户头像与昵称</p>
      </div>
      <DataEnvBar />      <div className="panel">
        <div className="btn-row" style={{ marginBottom: 12 }}>
          <button
            type="button"
            className={`btn ${tab === 'follows' ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => {
              setTab('follows')
              setPage(1)
            }}
          >
            关注关系
          </button>
          <button
            type="button"
            className={`btn ${tab === 'requests' ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => {
              setTab('requests')
              setPage(1)
            }}
          >
            好友申请
          </button>
        </div>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          {tab === 'follows' ? (
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>关注者</th>
                  <th>被关注</th>
                  <th>时间</th>                  <th />
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      加载中…
                    </td>
                  </tr>
                ) : follows.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      暂无关注
                    </td>
                  </tr>
                ) : (
                  follows.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <IdCell id={row.id} />
                      </td>
                      <td>
                        <UserCell name={row.follower_name} sub={`UID ${row.follower_id || '—'}`} />
                      </td>
                      <td>
                        <UserCell name={row.following_name} sub={`UID ${row.following_id || '—'}`} />
                      </td>
                      <td className="muted">{formatDateTime(row.created_at)}</td>                      <td>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={async () => {
                            if (!confirm('解除该关注关系？')) return
                            const res = await client.deleteFollow(row.id)
                            if (!res.success) setError(res.message || '删除失败')
                            else await load()
                          }}
                        >
                          解除
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>发起人</th>
                  <th>接收人</th>
                  <th>状态</th>
                  <th>时间</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      加载中…
                    </td>
                  </tr>
                ) : requests.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      暂无申请
                    </td>
                  </tr>
                ) : (
                  requests.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <IdCell id={row.id} />
                      </td>
                      <td>
                        <UserCell name={row.from_user_name} sub={`UID ${row.from_user_id || '—'}`} />
                      </td>
                      <td>
                        <UserCell name={row.to_user_name} sub={`UID ${row.to_user_id || '—'}`} />
                      </td>
                      <td>
                        <AdminTag spec={friendRequestTag(row.status)} />
                      </td>
                      <td className="muted">{formatDateTime(row.created_at)}</td>
                    </tr>                  ))
                )}
              </tbody>
            </table>
          )}
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
