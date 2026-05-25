import { useCallback, useEffect, useState } from 'react'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { FormField } from '../components/FormField'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { DeployApiError } from '../api/deployClient'

type VipPlanRow = {
  id: string
  name: string
  description: string
  price: number
  duration_days: number
  created_at: string
  updated_at: string
}

const emptyForm = {
  name: '',
  description: '',
  price: '',
  duration_days: '30',
}

export function VipPlansPage() {
  const { client } = useAdminAuth()
  const { apiTargetLabel } = usePlatform()
  const [items, setItems] = useState<VipPlanRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [includeDeleted, setIncludeDeleted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [editing, setEditing] = useState<VipPlanRow | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')
  const [saving, setSaving] = useState(false)

  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listVipPlans({
        page,
        page_size: pageSize,
        keyword: search || undefined,
        include_deleted: includeDeleted,
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
  }, [client, page, search, includeDeleted])

  useEffect(() => {
    void load()
  }, [load])

  function openCreate() {
    setEditing(null)
    setForm(emptyForm)
    setFormError('')
    setModal('create')
  }

  function openEdit(row: VipPlanRow) {
    setEditing(row)
    setForm({
      name: row.name,
      description: row.description || '',
      price: String(row.price),
      duration_days: String(row.duration_days),
    })
    setFormError('')
    setModal('edit')
  }

  function closeModal() {
    setModal(null)
    setFormError('')
  }

  async function savePlan() {
    const name = form.name.trim()
    const price = Number(form.price)
    const durationDays = Number(form.duration_days)
    if (!name) {
      setFormError('请填写套餐名称')
      return
    }
    if (!Number.isFinite(price) || price < 0) {
      setFormError('请填写有效价格')
      return
    }
    if (!Number.isFinite(durationDays) || durationDays <= 0) {
      setFormError('有效期天数必须大于 0')
      return
    }

    setSaving(true)
    setFormError('')
    try {
      if (modal === 'create') {
        const res = await client.createVipPlan({
          name,
          description: form.description.trim(),
          price,
          duration_days: durationDays,
        })
        if (!res.success) {
          setFormError(res.message || '创建失败')
          return
        }
        setMessage('套餐已创建')
      } else if (editing) {
        const res = await client.updateVipPlan(editing.id, {
          name,
          description: form.description.trim(),
          update_name: true,
          update_description: true,
          price,
          update_price: true,
          duration_days: durationDays,
          update_duration_days: true,
        })
        if (!res.success) {
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('套餐已更新')
      }
      closeModal()
      await load()
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  async function removePlan(row: VipPlanRow) {
    if (!confirm(`确定删除套餐「${row.name}」？已购用户记录不受影响。`)) return
    setError('')
    try {
      const res = await client.deleteVipPlan(row.id)
      if (!res.success) {
        setError(res.message || '删除失败')
        return
      }
      setMessage('已删除')
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '删除失败')
    }
  }

  async function bootstrap() {
    if (!confirm('仅在套餐表为空时导入月/季/年默认套餐，是否继续？')) return
    setError('')
    try {
      const res = await client.bootstrapVipPlans()
      if (!res.success) {
        setError(res.message || '初始化失败')
        return
      }
      setMessage(res.message || `已导入 ${res.data?.created ?? 0} 条`)
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '初始化失败')
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>会员与套餐</h2>
          <p>
            运营配置 VIP 套餐（App 只读展示）· 环境 {apiTargetLabel}
          </p>
        </div>
        <div className="inline-form" style={{ flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-ghost" onClick={() => void bootstrap()}>
            导入默认套餐
          </button>
          <button type="button" className="btn btn-primary" onClick={openCreate}>
            新建套餐
          </button>
        </div>
      </div>

      {message ? (
        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
          {message}
          <button
            type="button"
            className="btn btn-ghost"
            style={{ marginLeft: 8, padding: '2px 8px' }}
            onClick={() => setMessage('')}
          >
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
          <input
            placeholder="搜索套餐名称 / 说明"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
          />
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={includeDeleted}
              onChange={(e) => {
                setIncludeDeleted(e.target.checked)
                setPage(1)
              }}
            />
            <span>含已删除</span>
          </label>
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
                <th>价格</th>
                <th>天数</th>
                <th>说明</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="muted">
                    暂无套餐，可点击「导入默认套餐」或「新建套餐」
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.name}</td>
                    <td>¥{row.price.toFixed(2)}</td>
                    <td>{row.duration_days}</td>
                    <td>{row.description || '—'}</td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => openEdit(row)}
                      >
                        编辑
                      </button>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => void removePlan(row)}
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
            <button
              type="button"
              className="btn btn-ghost"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              上一页
            </button>
            <span>
              {page} / {totalPages}（共 {total} 条）
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
        <AdminFormDrawer
          open
          title={modal === 'create' ? '新建 VIP 套餐' : '编辑 VIP 套餐'}
          subtitle={editing ? `ID ${editing.id}` : undefined}
          error={formError}
          saving={saving}
          onClose={closeModal}
          onSave={() => void savePlan()}
        >
          <FormField label="名称" required>
            <input
              value={form.name}
              placeholder="如：月度会员"
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
          </FormField>
          <div className="form-grid-2">
            <FormField label="价格（元）" required>
              <input
                type="number"
                min={0}
                step={0.01}
                value={form.price}
                onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
              />
            </FormField>
            <FormField label="有效天数" required>
              <input
                type="number"
                min={1}
                value={form.duration_days}
                onChange={(e) =>
                  setForm((f) => ({ ...f, duration_days: e.target.value }))
                }
              />
            </FormField>
          </div>
          <FormField label="说明" hint="App 端展示的套餐描述">
            <textarea
              rows={3}
              value={form.description}
              placeholder="如：解锁全部 VIP 特权"
              onChange={(e) =>
                setForm((f) => ({ ...f, description: e.target.value }))
              }
            />
          </FormField>
        </AdminFormDrawer>
      ) : null}
    </>
  )
}
