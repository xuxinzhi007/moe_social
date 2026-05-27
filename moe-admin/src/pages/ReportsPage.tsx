import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { reportReasonTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
import { AdminTable, ListPageLayout } from '../ui'
import type { AdminTableColumn } from '../ui'

type ReportRow = {
  id: string
  post_id: string
  reporter_user_id: string
  reason: string
  post_content_preview: string
  created_at: string
}

export function ReportsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<ReportRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 30

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listPostReports({ page, page_size: pageSize })
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
  }, [client, page])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  const columns = useMemo(
    (): AdminTableColumn<ReportRow>[] => [
      { key: 'id', header: 'ID', render: (row) => <IdCell id={row.id} /> },
      { key: 'post', header: '动态', render: (row) => <IdCell id={row.post_id} /> },
      {
        key: 'reporter',
        header: '举报人',
        render: (row) => <IdCell id={row.reporter_user_id} title="举报人 UID" />,
      },
      {
        key: 'reason',
        header: '原因',
        render: (row) => <AdminTag spec={reportReasonTag(row.reason)} />,
      },
      { key: 'preview', header: '预览', render: (row) => row.post_content_preview || '—' },
      {
        key: 'time',
        header: '时间',
        cellClassName: 'muted',
        render: (row) => formatDateTime(row.created_at),
      },
      {
        key: 'actions',
        header: '',
        render: (row) => (
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={async () => {
              if (!confirm('删除被举报动态？')) return
              const res = await client.deletePost(row.post_id)
              if (!res.success) setError(res.message || '删除失败')
              else await load()
            }}
          >
            删动态
          </button>
        ),
      },
    ],
    [client, load],
  )

  return (
    <ListPageLayout
      title="举报处理"
      description="用户举报动态记录，可跳转动态页下架"
      metrics={[{ label: '待处理举报', value: loading ? '…' : total }]}
      error={error}
      pagination={{ page, totalPages, total, onPageChange: setPage }}
    >
      <AdminTable columns={columns} rows={items} rowKey={(row) => row.id} loading={loading} emptyText="暂无举报" />
    </ListPageLayout>
  )
}
