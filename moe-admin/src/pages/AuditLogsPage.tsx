import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { useAdminAuth } from '../context/AdminAuthContext'
import { auditActionTag, auditResourceTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
import { AdminTable, AdminToolbar, ListPageLayout } from '../ui'
import type { AdminTableColumn } from '../ui'

type AuditRow = {
  id: string
  admin_name: string
  action: string
  resource: string
  resource_id: string
  detail: string
  ip: string
  created_at: string
}

export function AuditLogsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<AuditRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [action, setAction] = useState('')
  const [resource, setResource] = useState('')
  const [filters, setFilters] = useState({ action: '', resource: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 30

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listAuditLogs({
        page,
        page_size: pageSize,
        action: filters.action || undefined,
        resource: filters.resource || undefined,
      })
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        return
      }
      setItems(res.data.items || [])
      setTotal(res.data.total || 0)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, page, filters])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  const columns = useMemo(
    (): AdminTableColumn<AuditRow>[] => [
      {
        key: 'time',
        header: '时间',
        cellClassName: 'muted',
        render: (row) => formatDateTime(row.created_at),
      },
      { key: 'admin', header: '管理员', render: (row) => row.admin_name || row.id },
      {
        key: 'action',
        header: '操作',
        render: (row) => <AdminTag spec={auditActionTag(row.action)} />,
      },
      {
        key: 'resource',
        header: '资源',
        render: (row) => (
          <>
            <AdminTag spec={auditResourceTag(row.resource)} />
            {row.resource_id ? (
              <span className="muted" style={{ marginLeft: 6, fontSize: 11 }}>
                #{row.resource_id}
              </span>
            ) : null}
          </>
        ),
      },
      { key: 'detail', header: '详情', render: (row) => row.detail || '—' },
      { key: 'ip', header: 'IP', cellClassName: 'muted', render: (row) => row.ip || '—' },
    ],
    [],
  )

  return (
    <ListPageLayout
      title="操作日志"
      description="管理员关键操作审计记录"
      metrics={[{ label: '匹配记录', value: loading ? '…' : total }]}
      toolbar={
        <AdminToolbar
          search={{
            value: action,
            onChange: setAction,
            onSubmit: () => {
              setPage(1)
              setFilters({ action: action.trim(), resource: resource.trim() })
            },
            placeholder: '操作 action',
            submitLabel: '筛选',
          }}
          filters={
            <input
              placeholder="资源 resource"
              value={resource}
              onChange={(e) => setResource(e.target.value)}
            />
          }
        />
      }
      error={error}
      pagination={{ page, totalPages, total, onPageChange: setPage }}
    >
      <AdminTable
        columns={columns}
        rows={items}
        rowKey={(row) => row.id}
        loading={loading}
        emptyText="暂无操作记录"
      />
    </ListPageLayout>
  )
}
