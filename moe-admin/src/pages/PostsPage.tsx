import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { IdCell } from '../components/IdCell'
import { UserCell } from '../components/UserCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { moderationTag } from '../lib/adminLabels'
import { formatDateTime } from '../lib/format'
import { fieldNum, fieldStr } from '../lib/apiRecord'
import { DeployApiError } from '../api/deployClient'
import { AdminTable, AdminToolbar, ListPageLayout } from '../ui'
import type { AdminTableColumn } from '../ui'

type PostRow = {
  id: string
  user_id?: string
  user_name: string
  user_avatar?: string
  content: string
  moderation_status?: string
  likes: number
  comments: number
  created_at: string
}

export function PostsPage() {
  const { client } = useAdminAuth()
  const [items, setItems] = useState<PostRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listPosts({
        page,
        page_size: pageSize,
        keyword: search || undefined,
        moderation_status: status || undefined,
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
  }, [client, page, search, status])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  const columns = useMemo(
    (): AdminTableColumn<PostRow>[] => [
      {
        key: 'author',
        header: '作者',
        render: (row) => (
          <UserCell
            name={row.user_name}
            avatar={row.user_avatar}
            sub={row.user_id ? `UID ${row.user_id}` : undefined}
          />
        ),
      },
      { key: 'id', header: 'ID', render: (row) => <IdCell id={row.id} /> },
      {
        key: 'content',
        header: '内容',
        render: (row) => {
          const content = fieldStr(row as Record<string, unknown>, 'content')
          return (
            <span style={{ maxWidth: 320, display: 'inline-block' }}>
              {content.slice(0, 80)}
              {content.length > 80 ? '…' : ''}
            </span>
          )
        },
      },
      {
        key: 'status',
        header: '状态',
        render: (row) => <AdminTag spec={moderationTag(row.moderation_status)} />,
      },
      {
        key: 'stats',
        header: '赞/评',
        render: (row) => (
          <>
            <AdminTag label={`${fieldNum(row as Record<string, unknown>, 'likes')} 赞`} tone="neutral" />
            <span className="muted" style={{ margin: '0 4px' }}>
              /
            </span>
            <AdminTag label={`${fieldNum(row as Record<string, unknown>, 'comments')} 评`} tone="info" />
          </>
        ),
      },
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
              if (!confirm('确定删除该动态？')) return
              const res = await client.deletePost(row.id)
              if (!res.success) setError(res.message || '删除失败')
              else await load()
            }}
          >
            删除
          </button>
        ),
      },
    ],
    [client, load],
  )

  return (
    <ListPageLayout
      title="动态审核"
      description="查看与下架用户动态，支持按审核状态筛选"
      metrics={[{ label: '匹配结果', value: loading ? '…' : total }]}
      toolbar={
        <AdminToolbar
          search={{
            value: keyword,
            onChange: setKeyword,
            onSubmit: () => {
              setPage(1)
              setSearch(keyword.trim())
            },
            placeholder: '搜索正文',
          }}
          filters={
            <select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value)
                setPage(1)
              }}
            >
              <option value="">全部状态</option>
              <option value="ok">已通过</option>
              <option value="pending">待审核</option>
              <option value="rejected">已拒绝</option>
            </select>
          }
        />
      }
      error={error}
      pagination={{ page, totalPages, total, onPageChange: setPage }}
    >
      <AdminTable columns={columns} rows={items} rowKey={(row) => row.id} loading={loading} emptyText="暂无动态" />
    </ListPageLayout>
  )
}
