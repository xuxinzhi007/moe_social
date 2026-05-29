import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { useAdminAuth } from '../context/AdminAuthContext'
import { boolTag, menuKindTag, menuStatusTag } from '../lib/adminLabels'
import { unwrapListItems } from '../lib/apiResponse'
import { DeployApiError } from '../api/deployClient'
import { AdminTable, ListPageLayout } from '../ui'
import type { AdminTableColumn } from '../ui'

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
      setItems(
        unwrapListItems(res.data).sort((a, b) => a.sort_order - b.sort_order),
      )
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

  const columns = useMemo(
    (): AdminTableColumn<MenuRow>[] => [
      { key: 'key', header: 'Key', render: (row) => row.key },
      {
        key: 'label',
        header: '标签',
        render: (row) => (
          <>
            {row.icon ? `${row.icon} ` : ''}
            {row.label}
          </>
        ),
      },
      { key: 'path', header: '路径', render: (row) => row.path || '—' },
      {
        key: 'kind',
        header: '类型',
        render: (row) => <AdminTag spec={menuKindTag(row.kind)} />,
      },
      {
        key: 'status',
        header: '状态',
        render: (row) => <AdminTag spec={menuStatusTag(row.status)} />,
      },
      { key: 'sort', header: '排序', render: (row) => row.sort_order },
      {
        key: 'enabled',
        header: '启用',
        render: (row) => <AdminTag spec={boolTag(row.enabled)} />,
      },
      {
        key: 'actions',
        header: '',
        render: (row) => (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => void toggleEnabled(row)}>
            {row.enabled ? '禁用' : '启用'}
          </button>
        ),
      },
    ],
    [load],
  )

  return (
    <ListPageLayout
      title="侧栏菜单配置"
      description="库表驱动菜单可见性与排序（v1 路由仍在前端注册）"
      headActions={
        <button type="button" className="btn btn-primary" onClick={() => void bootstrap()}>
          同步默认菜单
        </button>
      }
      banner={message ? { message, tone: 'ok', onClose: () => setMessage('') } : undefined}
      error={error}
    >
      <AdminTable
        columns={columns}
        rows={items}
        rowKey={(row) => row.key}
        loading={loading}
        emptyText="暂无菜单，请点击「同步默认菜单」"
      />
    </ListPageLayout>
  )
}
