import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { feedbackCategoryTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'
import { AdminPanel, AdminTable, ListPageLayout } from '../ui'
import type { AdminTableColumn } from '../ui'

type FeedbackItem = {
  id: number
  email: string
  category: string
  content: string
  source: string
  client_ip?: string
  created_at: string
}

export function FeedbackPage() {
  const { client } = useAdminAuth()
  const { showToast } = useDeploy()
  const [items, setItems] = useState<FeedbackItem[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [category, setCategory] = useState('all')
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState<FeedbackItem | null>(null)
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const cat = category === 'all' ? undefined : category
      const res = await client.listLandingFeedback({
        page,
        page_size: pageSize,
        category: cat,
      })
      if (!res.success || !res.data) {
        showToast(res.message || '加载失败')
        setItems([])
        setTotal(0)
        return
      }
      setItems(res.data.items || [])
      setTotal(res.data.total || 0)
    } catch (e) {
      showToast(e instanceof DeployApiError ? e.message : '加载失败')
      setItems([])
      setTotal(0)
    } finally {
      setLoading(false)
    }
  }, [category, client, page, showToast])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  const columns = useMemo(
    (): AdminTableColumn<FeedbackItem>[] => [
      {
        key: 'id',
        header: 'ID',
        render: (row) => (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setSelected(row)}>
            #{row.id}
          </button>
        ),
      },
      {
        key: 'category',
        header: '类型',
        render: (row) => <AdminTag spec={feedbackCategoryTag(row.category)} />,
      },
      { key: 'email', header: '邮箱', render: (row) => row.email },
      {
        key: 'snippet',
        header: '摘要',
        cellClassName: 'fb-snippet',
        render: (row) => (row.content.length > 48 ? `${row.content.slice(0, 48)}…` : row.content),
      },
      { key: 'time', header: '时间', render: (row) => formatDateTime(row.created_at) },
    ],
    [],
  )

  return (
    <>
      <ListPageLayout
        title="官网意见反馈"
        description="来自落地页 #join 的提交"
        metrics={[{ label: '反馈总数', value: loading ? '…' : total }]}
        headActions={
          <div className="btn-row">
            <select
              className="select-inline"
              value={category}
              onChange={(e) => {
                setCategory(e.target.value)
                setPage(1)
              }}
            >
              <option value="all">全部类型</option>
              <option value="feature">功能建议</option>
              <option value="bug">问题反馈</option>
              <option value="other">其他</option>
            </select>
            <button type="button" className="btn btn-primary" disabled={loading} onClick={() => void load()}>
              {loading ? '刷新中…' : '刷新'}
            </button>
          </div>
        }
        pagination={{ page, totalPages, total, onPageChange: setPage }}
      >
        <AdminTable
          columns={columns}
          rows={items}
          rowKey={(row) => String(row.id)}
          loading={loading}
          emptyText="暂无反馈，或云端 API 尚未部署含列表接口的版本。"
        />
      </ListPageLayout>

      {selected ? (
        <AdminPanel className="fb-detail">
          <div className="panel-head">
            <h3>反馈 #{selected.id}</h3>
            <button type="button" className="btn btn-ghost" onClick={() => setSelected(null)}>
              关闭
            </button>
          </div>
          <div className="panel-body">
            <div className="env-kv">
              <div className="env-kv-row">
                <dt>类型</dt>
                <dd>
                  <AdminTag spec={feedbackCategoryTag(selected.category)} />
                </dd>
              </div>
              <div className="env-kv-row">
                <dt>邮箱</dt>
                <dd>{selected.email}</dd>
              </div>
              <div className="env-kv-row">
                <dt>来源</dt>
                <dd>{selected.source || 'official-site'}</dd>
              </div>
              <div className="env-kv-row">
                <dt>IP</dt>
                <dd>{selected.client_ip || '—'}</dd>
              </div>
              <div className="env-kv-row">
                <dt>时间</dt>
                <dd>{formatDateTime(selected.created_at)}</dd>
              </div>
            </div>
            <p className="fb-detail-content">{selected.content}</p>
          </div>
        </AdminPanel>
      ) : null}
    </>
  )
}
