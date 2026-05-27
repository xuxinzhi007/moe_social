import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { DataEnvBar } from '../components/DataEnvBar'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

type Tab = 'sessions' | 'messages'

type SessionRow = {
  id: string
  user_id: string
  username?: string
  session_id: string
  model?: string
  message_count?: number
  last_message_at?: string
  updated_at: string
}

type MessageRow = {
  id: string
  user_id: string
  username?: string
  session_id: string
  role: string
  content: string
  model?: string
  created_at: string
}

const emptyFilters = {
  userId: '',
  sessionId: '',
  role: '',
  keyword: '',
  from: '',
  to: '',
}

export function AiChatLogsPage() {
  const { client } = useAdminAuth()
  const [params, setParams] = useSearchParams()
  const tab: Tab = params.get('tab') === 'messages' ? 'messages' : 'sessions'

  const [filters, setFilters] = useState(emptyFilters)
  const [applied, setApplied] = useState(emptyFilters)
  const [sessions, setSessions] = useState<SessionRow[]>([])
  const [messages, setMessages] = useState<MessageRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [exporting, setExporting] = useState(false)
  const [message, setMessage] = useState('')
  const pageSize = tab === 'sessions' ? 20 : 30

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      if (tab === 'sessions') {
        const res = await client.listAiChatSessions({
          page,
          page_size: pageSize,
          user_id: applied.userId || undefined,
          session_id: applied.sessionId || undefined,
          from: applied.from || undefined,
          to: applied.to || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          setSessions([])
          setTotal(0)
          return
        }
        setSessions(res.data.items || [])
        setTotal(res.data.total || 0)
      } else {
        const res = await client.listAiChatMessages({
          page,
          page_size: pageSize,
          user_id: applied.userId || undefined,
          session_id: applied.sessionId || undefined,
          role: applied.role || undefined,
          keyword: applied.keyword || undefined,
          from: applied.from || undefined,
          to: applied.to || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          setMessages([])
          setTotal(0)
          return
        }
        setMessages(res.data.items || [])
        setTotal(res.data.total || 0)
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [applied, client, page, pageSize, tab])

  useEffect(() => {
    void load()
  }, [load])

  function setTab(next: Tab) {
    setParams({ tab: next })
    setPage(1)
  }

  function applyFilters() {
    setApplied({ ...filters })
    setPage(1)
  }

  async function exportCsv() {
    setExporting(true)
    setMessage('')
    try {
      const res = await client.exportAiChatMessages({
        user_id: applied.userId || undefined,
        session_id: applied.sessionId || undefined,
        role: applied.role || undefined,
        keyword: applied.keyword || undefined,
        from: applied.from || undefined,
        to: applied.to || undefined,
        limit: 5000,
      })
      if (!res.success || !res.data) {
        setMessage(res.message || '导出失败')
        return
      }
      const blob = new Blob([res.data.csv], { type: 'text/csv;charset=utf-8' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `ai_chat_messages_${Date.now()}.csv`
      a.click()
      URL.revokeObjectURL(url)
      setMessage(
        res.data.truncated
          ? `已导出 ${res.data.row_count} 条（已达上限，结果被截断）`
          : `已导出 ${res.data.row_count} 条`,
      )
    } catch (e) {
      setMessage(e instanceof DeployApiError ? e.message : '导出失败')
    } finally {
      setExporting(false)
    }
  }

  function openSessionMessages(sessionId: string) {
    setFilters((f) => ({ ...f, sessionId }))
    setApplied((f) => ({ ...f, sessionId }))
    setTab('messages')
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>AI 对话日志</h2>
          <p>查询 ai_chat_sessions / messages，用于审计与排障（非训练数据导出）</p>
        </div>
        {tab === 'messages' && (
          <button
            type="button"
            className="btn btn-secondary"
            disabled={exporting}
            onClick={() => void exportCsv()}
          >
            {exporting ? '导出中…' : '导出 CSV'}
          </button>
        )}
      </div>

      <DataEnvBar />

      <div className="tab-bar">
        <button
          type="button"
          className={`tab-btn${tab === 'sessions' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('sessions')}
        >
          会话
        </button>
        <button
          type="button"
          className={`tab-btn${tab === 'messages' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('messages')}
        >
          消息
        </button>
      </div>

      <div className="filter-bar card">
        <label>
          用户 ID
          <input
            value={filters.userId}
            onChange={(e) => setFilters((f) => ({ ...f, userId: e.target.value }))}
            placeholder="可选"
          />
        </label>
        <label>
          Session ID
          <input
            value={filters.sessionId}
            onChange={(e) => setFilters((f) => ({ ...f, sessionId: e.target.value }))}
            placeholder="可选"
          />
        </label>
        {tab === 'messages' && (
          <>
            <label>
              角色
              <select
                value={filters.role}
                onChange={(e) => setFilters((f) => ({ ...f, role: e.target.value }))}
              >
                <option value="">全部</option>
                <option value="user">user</option>
                <option value="assistant">assistant</option>
                <option value="system">system</option>
              </select>
            </label>
            <label>
              关键词
              <input
                value={filters.keyword}
                onChange={(e) => setFilters((f) => ({ ...f, keyword: e.target.value }))}
                placeholder="内容包含"
              />
            </label>
          </>
        )}
        <label>
          起始日期
          <input
            type="date"
            value={filters.from}
            onChange={(e) => setFilters((f) => ({ ...f, from: e.target.value }))}
          />
        </label>
        <label>
          结束日期
          <input
            type="date"
            value={filters.to}
            onChange={(e) => setFilters((f) => ({ ...f, to: e.target.value }))}
          />
        </label>
        <button type="button" className="btn btn-primary" onClick={applyFilters}>
          筛选
        </button>
      </div>

      {message && <p className="form-hint ok">{message}</p>}
      {error && <p className="form-error">{error}</p>}

      <div className="table-card">
        {loading ? (
          <p className="muted">加载中…</p>
        ) : tab === 'sessions' ? (
          <table className="data-table">
            <thead>
              <tr>
                <th>用户</th>
                <th>Session</th>
                <th>模型</th>
                <th>消息数</th>
                <th>最后消息</th>
                <th>更新</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {sessions.map((row) => (
                <tr key={row.id}>
                  <td>
                    {row.username || '—'}
                    <br />
                    <IdCell id={row.user_id} />
                  </td>
                  <td>
                    <IdCell id={row.session_id} />
                  </td>
                  <td>{row.model || '—'}</td>
                  <td>{row.message_count ?? 0}</td>
                  <td>{row.last_message_at ? formatDateTime(row.last_message_at) : '—'}</td>
                  <td>{formatDateTime(row.updated_at)}</td>
                  <td>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => openSessionMessages(row.session_id)}
                    >
                      查看消息
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>时间</th>
                <th>用户</th>
                <th>角色</th>
                <th>内容</th>
                <th>Session</th>
              </tr>
            </thead>
            <tbody>
              {messages.map((row) => (
                <tr key={row.id}>
                  <td>{formatDateTime(row.created_at)}</td>
                  <td>
                    {row.username || '—'}
                    <br />
                    <IdCell id={row.user_id} />
                  </td>
                  <td>
                    <span className={`pill pill-${row.role === 'user' ? 'primary' : 'muted'}`}>
                      {row.role}
                    </span>
                  </td>
                  <td className="cell-pre">{row.content}</td>
                  <td>
                    <IdCell id={row.session_id} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="pager">
        <button
          type="button"
          className="btn btn-ghost"
          disabled={page <= 1}
          onClick={() => setPage((p) => Math.max(1, p - 1))}
        >
          上一页
        </button>
        <span>
          第 {page} / {totalPages} 页 · 共 {total} 条
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
    </>
  )
}
