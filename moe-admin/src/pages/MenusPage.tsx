import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { useAdminAuth } from '../context/AdminAuthContext'
import { boolTag, menuKindTag, menuStatusTag } from '../lib/adminLabels'
import { DeployApiError } from '../api/deployClient'

type MenuRow = {
  id: string
  key: string
  kind: string
  label: string
  path: string
  icon: string
  status: string
  sort_order: number
  enabled: boolean
}

export function MenusPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<MenuRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listMenus()
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setItems([])
        return
      }
      setItems(res.data.sort((a, b) => a.sort_order - b.sort_order))
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client])

  useEffect(() => {
    void load()
  }, [load])

  async function bootstrap() {
    if (!confirm('从默认配置同步侧栏菜单？已有 key 不会重复创建。')) return
    setError('')
    try {
      const res = await client.bootstrapMenus()
      if (!res.success) {
        setError(res.message || '同步失败')
        return
      }
      setMessage(`已同步 ${res.data?.created ?? 0} 条菜单项`)
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '同步失败')
    }
  }

  async function toggleEnabled(row: MenuRow) {
    setError('')
    try {
      const res = await client.upsertMenu({
        key: row.key,
        kind: row.kind,
        label: row.label,
        path: row.path,
        icon: row.icon,
        status: row.status,
        sort_order: row.sort_order,
        enabled: !row.enabled,
      })
      if (!res.success) {
        setError(res.message || '更新失败')
        return
      }
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '更新失败')
    }
  }

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>侧栏菜单配置</h2>
          <p>库表驱动菜单可见性与排序（v1 路由仍在前端注册）</p>
        </div>
        <button type="button" className="btn btn-primary" onClick={() => void bootstrap()}>
          同步默认菜单
        </button>
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
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Key</th>
                <th>标签</th>
                <th>路径</th>
                <th>类型</th>
                <th>状态</th>
                <th>排序</th>
                <th>启用</th>
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
                    暂无菜单，请点击「同步默认菜单」
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.key}>
                    <td>{row.key}</td>
                    <td>
                      {row.icon ? `${row.icon} ` : ''}
                      {row.label}
                    </td>
                    <td>{row.path || '—'}</td>
                    <td>
                      <AdminTag spec={menuKindTag(row.kind)} />
                    </td>
                    <td>
                      <AdminTag spec={menuStatusTag(row.status)} />
                    </td>
                    <td>{row.sort_order}</td>
                    <td>
                      <AdminTag spec={boolTag(row.enabled)} />
                    </td>                    <td>
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => void toggleEnabled(row)}
                      >
                        {row.enabled ? '禁用' : '启用'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
