import { useCallback, useEffect, useState } from 'react'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { EmojiIconField } from '../components/EmojiIconField'
import { FormField } from '../components/FormField'
import { DataEnvBar } from '../components/DataEnvBar'
import { PageInsightStrip } from '../components/PageInsightStrip'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'
import { GIFT_CATEGORIES, giftCategoryLabel } from '../lib/giftCategories'

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

export function GiftsPage() {
  const { client } = useAdminAuth()
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
  const [formError, setFormError] = useState('')
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

  function openCreate() {
    setEditing(null)
    setForm(emptyForm)
    setFormError('')
    setModal('create')
  }

  function openEdit(row: GiftRow) {
    setEditing(row)
    setForm({
      name: row.name,
      price: String(row.price),
      icon: row.icon || '',
      description: row.description || '',
      category: row.category || 'special',
      sort_order: String(row.sort_order ?? 0),
    })
    setFormError('')
    setModal('edit')
  }

  function closeModal() {
    setModal(null)
    setFormError('')
  }

  async function saveGift() {
    const name = form.name.trim()
    const price = Number(form.price)
    const sortOrder = Number(form.sort_order)
    if (!name || !Number.isFinite(price) || price < 0) {
      setFormError('请填写名称与有效价格')
      return
    }
    setSaving(true)
    setFormError('')
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
          setFormError(res.message || '创建失败')
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
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('礼物已更新')
      }
      closeModal()
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
          <h2>礼物目录</h2>
          <p className="muted">扭蛋 / 打赏礼物运营配置</p>
        </div>
        <div className="btn-row">
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
          <button type="button" className="btn btn-primary" onClick={openCreate}>
            新建礼物
          </button>
        </div>
      </div>

      <DataEnvBar />
      <PageInsightStrip items={[{ label: '礼物数量', value: loading ? '…' : total }]} />

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
                    <td>{giftCategoryLabel(row.category)}</td>
                    <td>{row.sort_order}</td>
                    <td>
                      <button type="button" className="btn btn-ghost btn-sm" onClick={() => openEdit(row)}>
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

      <AdminFormDrawer
        open={modal !== null}
        title={modal === 'create' ? '新建礼物' : '编辑礼物'}
        subtitle={editing ? `ID ${editing.id}` : undefined}
        error={formError}
        saving={saving}
        onClose={closeModal}
        onSave={() => void saveGift()}
      >
        <FormField label="名称" required>
          <input
            value={form.name}
            placeholder="如：爱心"
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
          />
        </FormField>

        <div className="form-grid-2">
          <FormField label="价格（心意币）" required>
            <input
              type="number"
              min={0}
              value={form.price}
              onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
            />
          </FormField>
          <FormField label="排序" hint="数值越小越靠前">
            <input
              type="number"
              value={form.sort_order}
              onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))}
            />
          </FormField>
        </div>

        <EmojiIconField
          value={form.icon}
          onChange={(icon) => setForm((f) => ({ ...f, icon }))}
        />

        <FormField label="分类">
          <select value={form.category} onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}>
            {GIFT_CATEGORIES.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </select>
        </FormField>

        <FormField label="说明" hint="展示给用户的礼物描述">
          <textarea
            rows={3}
            value={form.description}
            placeholder="如：传递温暖的爱意"
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          />
        </FormField>
      </AdminFormDrawer>
    </>
  )
}
