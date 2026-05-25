import { useCallback, useEffect, useState } from 'react'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { FormField } from '../components/FormField'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { announcementTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
type Row = { id: string; title: string; content: string; status: string; published_at?: string; created_at: string }

const emptyForm = { title: '', content: '' }

export function AnnouncementsPage() {
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
      const res = await client.listAnnouncements({ page, page_size: pageSize })
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
    const title = form.title.trim()
    const content = form.content.trim()
    if (!title) {
      setFormError('请填写标题')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      if (modal === 'create') {
        const res = await client.createAnnouncement({ title, content })
        if (!res.success) {
          setFormError(res.message || '创建失败')
          return
        }
        setMessage('公告已创建')
      } else if (editing) {
        const res = await client.updateAnnouncement(editing.id, { title, content })
        if (!res.success) {
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('公告已更新')
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
          <h2>公告管理</h2>
          <p>App 内公告运营 · 草稿与发布状态分色展示</p>
        </div>
        <button          type="button"
          className="btn btn-primary"
          onClick={() => {
            setEditing(null)
            setForm(emptyForm)
            setFormError('')
            setModal('create')
          }}
        >
          新建公告
        </button>
      </div>

      <DataEnvBar />

      {message ? (        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
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
                <th>标题</th>
                <th>状态</th>
                <th>发布时间</th>
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
                    暂无公告
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>
                      <IdCell id={row.id} />
                    </td>
                    <td>{row.title}</td>
                    <td>
                      <AdminTag spec={announcementTag(row.status)} />
                    </td>
                    <td className="muted">{formatDateTime(row.published_at)}</td>                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setEditing(row)
                          setForm({ title: row.title, content: row.content })
                          setFormError('')
                          setModal('edit')
                        }}
                      >
                        编辑
                      </button>
                      {row.status !== 'published' ? (
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={async () => {
                            const res = await client.publishAnnouncement(row.id)
                            if (!res.success) setError(res.message || '发布失败')
                            else {
                              setMessage('已发布')
                              await load()
                            }
                          }}
                        >
                          发布
                        </button>
                      ) : null}
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm(`删除公告「${row.title}」？`)) return
                          const res = await client.deleteAnnouncement(row.id)
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
        title={modal === 'create' ? '新建公告' : '编辑公告'}
        subtitle={editing ? `ID ${editing.id}` : undefined}
        error={formError}
        saving={saving}
        onClose={() => setModal(null)}
        onSave={() => void save()}
      >
        <FormField label="标题" required>
          <input value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
        </FormField>
        <FormField label="内容" required>
          <textarea
            rows={6}
            value={form.content}
            onChange={(e) => setForm((f) => ({ ...f, content: e.target.value }))}
          />
        </FormField>
      </AdminFormDrawer>
    </>
  )
}
