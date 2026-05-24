import { useCallback, useEffect, useState } from 'react'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { DeployApiError } from '../api/deployClient'

type UserRow = {
  id: string
  username: string
  email: string
  moe_no?: string
  role?: string
  is_vip: boolean
  created_at: string
}

export function UsersPage() {
  const { client } = useAdminAuth()
  const { apiTargetLabel } = usePlatform()
  const [items, setItems] = useState<UserRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<UserRow | null>(null)
  const [role, setRole] = useState('user')
  const [isVip, setIsVip] = useState(false)
  const [saving, setSaving] = useState(false)
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listUsers({
        page,
        page_size: pageSize,
        keyword: search || undefined,
      })
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
      setItems([])
      setTotal(0)
    } finally {
      setLoading(false)
    }
  }, [client, page, search])

  useEffect(() => {
    void load()
  }, [load])

  function openUser(row: UserRow) {
    setSelected(row)
    setRole(row.role || 'user')
    setIsVip(row.is_vip)
  }

  async function saveUser() {
    if (!selected) return
    setSaving(true)
    setError('')
    try {
      const res = await client.updateUser(selected.id, {
        role,
        is_vip: isVip,
        update_is_vip: true,
      })
      if (!res.success) {
        setError(res.message || '保存失败')
        return
      }
      setSelected(null)
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>App 用户</h2>
          <p>
            管理 App 注册用户（<code>users</code> 表）· 环境 {apiTargetLabel}
          </p>
        </div>
      </div>

      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setSearch(keyword.trim())
          }}
        >
          <input
            placeholder="搜索用户名 / 邮箱 / Moe 号"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
          />
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
                <th>用户名</th>
                <th>邮箱</th>
                <th>Moe 号</th>
                <th>角色</th>
                <th>VIP</th>
                <th>注册时间</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={8} className="muted">
                    暂无数据
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.username}</td>
                    <td>{row.email}</td>
                    <td>{row.moe_no || '—'}</td>
                    <td>{row.role || 'user'}</td>
                    <td>{row.is_vip ? '是' : '否'}</td>
                    <td>{row.created_at}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => openUser(row)}
                      >
                        编辑
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="pager">
          <button
            type="button"
            className="btn btn-ghost"
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
          >
            上一页
          </button>
          <span className="muted">
            {page} / {totalPages} · 共 {total} 条
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
      </div>

      {selected ? (
        <div className="drawer-backdrop" onClick={() => setSelected(null)}>
          <div className="drawer" onClick={(e) => e.stopPropagation()}>
            <h3>编辑用户 · {selected.username}</h3>
            <p className="muted">ID {selected.id}</p>
            <label>
              <span>App 角色</span>
              <select value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="user">user</option>
                <option value="admin">admin</option>
                <option value="super_admin">super_admin</option>
              </select>
            </label>
            <label className="checkbox-row">
              <input
                type="checkbox"
                checked={isVip}
                onChange={(e) => setIsVip(e.target.checked)}
              />
              <span>VIP 用户</span>
            </label>
            <div className="drawer-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setSelected(null)}
              >
                取消
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={saving}
                onClick={() => void saveUser()}
              >
                {saving ? '保存中…' : '保存'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  )
}
