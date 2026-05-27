import { useCallback, useEffect, useState } from 'react'
import { PageInsightStrip } from '../components/PageInsightStrip'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { AdminTag } from '../components/AdminTag'
import { FormField } from '../components/FormField'
import { IdCell } from '../components/IdCell'
import { UserCell } from '../components/UserCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { roleTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

type Row = { id: string; username: string; role: string; last_login_at?: string; created_at: string }

const emptyForm = { username: '', password: '', role: 'admin' }

export function AdminAccountsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<Row[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [editing, setEditing] = useState<Row | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')
  const [saving, setSaving] = useState(false)
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listAccounts({ page, page_size: pageSize })
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
  }, [client, page])

  useEffect(() => {
    void load()
  }, [load])

  async function save() {
    const username = form.username.trim()
    if (!username) {
      setFormError('请填写用户名')
      return
    }
    if (modal === 'create' && !form.password.trim()) {
      setFormError('请填写密码')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      if (modal === 'create') {
        const res = await client.createAccount({
          username,
          password: form.password,
          role: form.role,
        })
        if (!res.success) {
          setFormError(res.message || '创建失败')
          return
        }
        setMessage('管理员已创建')
      } else if (editing) {
        const body: { username?: string; password?: string; role?: string } = {
          username,
          role: form.role,
        }
        if (form.password.trim()) body.password = form.password
        const res = await client.updateAccount(editing.id, body)
        if (!res.success) {
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('已更新')
      }
      setModal(null)
      await load()
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>管理员账号</h2>
          <p className="muted">Moe Admin 后台账号（与 App 用户分离）</p>
        </div>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            setEditing(null)
            setForm(emptyForm)
            setFormError('')
            setModal('create')
          }}
        >
          新建管理员
        </button>
      </div>

      <PageInsightStrip items={[{ label: '管理员', value: loading ? '…' : total }]} />

      {message ? (
        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
          {message}
          <button type="button" className="btn btn-ghost" style={{ marginLeft: 8 }} onClick={() => setMessage('')}>
            关闭
          </button>
        </div>
      ) : null}

      <div className="panel">
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>用户名</th>
                <th>角色</th>
                <th>上次登录</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={5} className="muted">
                    暂无账号
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <IdCell id={row.id} />
                    </td>
                    <td>
                      <UserCell name={row.username} sub="Moe Admin" />
                    </td>
                    <td>
                      <AdminTag spec={roleTag(row.role)} />
                    </td>
                    <td className="muted">{formatDateTime(row.last_login_at)}</td>                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setEditing(row)
                          setForm({ username: row.username, password: '', role: row.role })
                          setFormError('')
                          setModal('edit')
                        }}
                      >
                        编辑
                      </button>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm(`删除管理员「${row.username}」？`)) return
                          const res = await client.deleteAccount(row.id)
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

      <AdminFormDrawer
        open={modal !== null}
        title={modal === 'create' ? '新建管理员' : '编辑管理员'}
        subtitle={editing ? `ID ${editing.id}` : undefined}
        error={formError}
        saving={saving}
        onClose={() => setModal(null)}
        onSave={() => void save()}
      >
        <FormField label="用户名" required>
          <input value={form.username} onChange={(e) => setForm((f) => ({ ...f, username: e.target.value }))} />
        </FormField>
        <FormField label="密码" required={modal === 'create'} hint={modal === 'edit' ? '留空则不修改' : undefined}>
          <input
            type="password"
            value={form.password}
            onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
          />
        </FormField>
        <FormField label="角色">
          <select value={form.role} onChange={(e) => setForm((f) => ({ ...f, role: e.target.value }))}>
            <option value="admin">admin</option>
            <option value="super_admin">super_admin</option>
          </select>
        </FormField>
      </AdminFormDrawer>
    </>
  )
}
