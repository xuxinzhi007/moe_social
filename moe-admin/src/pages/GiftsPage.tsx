import { useCallback, useEffect, useState } from 'react'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { DeployApiError } from '../api/deployClient'

type GiftRow = {
  id: string
  name: string
  price: number
  icon: string
  description: string
  category: string
  sort_order: number
}

const emptyForm = {
  name: '',
  price: '1',
  icon: '',
  description: '',
  category: 'special',
  sort_order: '0',
}

const categories = ['emotion', 'food', 'luxury', 'special']

export function GiftsPage() {
  const { client } = useAdminAuth()
  const { apiTargetLabel } = usePlatform()
  const [items, setItems] = useState<GiftRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [editing, setEditing] = useState<GiftRow | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listGifts({ page, page_size: pageSize, keyword: search || undefined })
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

  async function saveGift() {
    const name = form.name.trim()
    const price = Number(form.price)
    const sortOrder = Number(form.sort_order)
    if (!name || !Number.isFinite(price) || price < 0) {
      setError('请填写名称与有效价格')
      return
    }
    setSaving(true)
    setError('')
    try {
      if (modal === 'create') {
        const res = await client.createGift({
          name,
          price,
          icon: form.icon.trim(),
          description: form.description.trim(),
          category: form.category,
          sort_order: Number.isFinite(sortOrder) ? sortOrder : 0,
        })
        if (!res.success) {
          setError(res.message || '创建失败')
          return
        }
        setMessage('礼物已创建')
      } else if (editing) {
        const res = await client.updateGift(editing.id, {
          name,
          price,
          icon: form.icon.trim(),
          description: form.description.trim(),
          category: form.category,
          sort_order: Number.isFinite(sortOrder) ? sortOrder : 0,
          update_name: true,
          update_price: true,
          update_icon: true,
          update_description: true,
          update_category: true,
          update_sort_order: true,
        })
        if (!res.success) {
          setError(res.message || '保存失败')
          return
        }
        setMessage('礼物已更新')
      }
      setModal(null)
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
          <h2>礼物目录</h2>
          <p>扭蛋 / 打赏礼物运营配置 · {apiTargetLabel}</p>
        </div>
        <div className="inline-form" style={{ flexWrap: 'wrap' }}>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={async () => {
              if (!confirm('仅在礼物表为空时导入默认目录，是否继续？')) return
              const res = await client.bootstrapGifts()
              setMessage(res.message || `已导入 ${res.data?.created ?? 0} 条`)
              await load()
            }}
          >
            导入默认礼物
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => {
              setEditing(null)
              setForm(emptyForm)
              setModal('create')
            }}
          >
            新建礼物
          </button>
        </div>
      </div>

      {message ? (
        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
          {message}
          <button type="button" className="btn btn-ghost" style={{ marginLeft: 8 }} onClick={() => setMessage('')}>
            关闭
          </button>
        </div>
      ) : null}

      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setSearch(keyword.trim())
          }}
        >
          <input placeholder="搜索名称 / 说明" value={keyword} onChange={(e) => setKeyword(e.target.value)} />
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
                <th>图标</th>
                <th>名称</th>
                <th>价格</th>
                <th>分类</th>
                <th>排序</th>
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
                    暂无礼物
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.icon || '—'}</td>
                    <td>{row.name}</td>
                    <td>{row.price}</td>
                    <td>{row.category}</td>
                    <td>{row.sort_order}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setEditing(row)
                          setForm({
                            name: row.name,
                            price: String(row.price),
                            icon: row.icon || '',
                            description: row.description || '',
                            category: row.category || 'special',
                            sort_order: String(row.sort_order ?? 0),
                          })
                          setModal('edit')
                        }}
                      >
                        编辑
                      </button>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={async () => {
                          if (!confirm(`删除礼物「${row.name}」？`)) return
                          const res = await client.deleteGift(row.id)
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

      {modal ? (
        <div className="drawer-backdrop" onClick={() => setModal(null)}>
          <div className="drawer" onClick={(e) => e.stopPropagation()}>
            <h3>{modal === 'create' ? '新建礼物' : '编辑礼物'}</h3>
            <label>
              <span>名称</span>
              <input value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
            </label>
            <label>
              <span>价格（心意币）</span>
              <input type="number" min={0} value={form.price} onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))} />
            </label>
            <label>
              <span>图标（emoji）</span>
              <input value={form.icon} onChange={(e) => setForm((f) => ({ ...f, icon: e.target.value }))} />
            </label>
            <label>
              <span>分类</span>
              <select value={form.category} onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}>
                {categories.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>排序</span>
              <input type="number" value={form.sort_order} onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))} />
            </label>
            <label>
              <span>说明</span>
              <textarea rows={2} value={form.description} onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))} />
            </label>
            <div className="drawer-actions">
              <button type="button" className="btn btn-ghost" onClick={() => setModal(null)}>
                取消
              </button>
              <button type="button" className="btn btn-primary" disabled={saving} onClick={() => void saveGift()}>
                {saving ? '保存中…' : '保存'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  )
}
