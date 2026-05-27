import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { DataEnvBar } from '../components/DataEnvBar'
import { FormField } from '../components/FormField'
import { IdCell } from '../components/IdCell'
import { useAdminAuth } from '../context/AdminAuthContext'
import { formatDateTime } from '../lib/format'
import { DeployApiError } from '../api/deployClient'

type Tab = 'topic' | 'dictionary'

type TopicRow = { id: string; name: string; color: string; created_at: string }

type DictRow = {
  id: string
  category: string
  tag: string
  label?: string
  note?: string
  sort_order: number
  enabled: boolean
  updated_at: string
}

const topicEmpty = { name: '', color: '#7f7fd5' }
const dictEmpty = {
  category: 'bot_forbidden',
  tag: '',
  label: '',
  note: '',
  sort_order: '0',
  enabled: true,
}

export function TagsCenterPage() {
  const { client } = useAdminAuth()
  const [params, setParams] = useSearchParams()
  const tab: Tab = params.get('tab') === 'dictionary' ? 'dictionary' : 'topic'

  const [keyword, setKeyword] = useState('')
  const [dictCategory, setDictCategory] = useState('')
  const [topicItems, setTopicItems] = useState<TopicRow[]>([])
  const [dictItems, setDictItems] = useState<DictRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [editingTopic, setEditingTopic] = useState<TopicRow | null>(null)
  const [editingDict, setEditingDict] = useState<DictRow | null>(null)
  const [topicForm, setTopicForm] = useState(topicEmpty)
  const [dictForm, setDictForm] = useState(dictEmpty)
  const [formError, setFormError] = useState('')
  const [saving, setSaving] = useState(false)

  const pageSize = 50

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      if (tab === 'topic') {
        const res = await client.listTopicTags({
          page,
          page_size: pageSize,
          keyword: keyword || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          return
        }
        setTopicItems(res.data.items || [])
        setTotal(res.data.total || 0)
      } else {
        const res = await client.listTagDictionary({
          page,
          page_size: pageSize,
          category: dictCategory || undefined,
          keyword: keyword || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          return
        }
        setDictItems(res.data.items || [])
        setTotal(res.data.total || 0)
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, dictCategory, keyword, page, pageSize, tab])

  useEffect(() => {
    void load()
  }, [load])

  function setTab(next: Tab) {
    setParams({ tab: next })
    setPage(1)
    setKeyword('')
  }

  async function saveTopic() {
    const name = topicForm.name.trim()
    if (!name) {
      setFormError('请填写标签名')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      if (modal === 'create') {
        const res = await client.createTopicTag({ name, color: topicForm.color })
        if (!res.success) {
          setFormError(res.message || '创建失败')
          return
        }
        setMessage('话题标签已创建')
      } else if (editingTopic) {
        const res = await client.updateTopicTag(editingTopic.id, {
          name,
          color: topicForm.color,
        })
        if (!res.success) {
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('话题标签已更新')
      }
      setModal(null)
      await load()
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  async function saveDict() {
    const tag = dictForm.tag.trim()
    if (!tag) {
      setFormError('请填写 tag 标识')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      const sortOrder = Number.parseInt(dictForm.sort_order, 10) || 0
      if (modal === 'create') {
        const res = await client.createTagDictionary({
          category: dictForm.category,
          tag,
          label: dictForm.label.trim(),
          note: dictForm.note.trim(),
          sort_order: sortOrder,
          enabled: dictForm.enabled,
        })
        if (!res.success) {
          setFormError(res.message || '创建失败')
          return
        }
        setMessage('策略标签已创建')
      } else if (editingDict) {
        const res = await client.updateTagDictionary(editingDict.id, {
          category: dictForm.category,
          tag,
          label: dictForm.label.trim(),
          note: dictForm.note.trim(),
          sort_order: sortOrder,
          enabled: dictForm.enabled,
          update_enabled: true,
        })
        if (!res.success) {
          setFormError(res.message || '保存失败')
          return
        }
        setMessage('策略标签已更新')
      }
      setModal(null)
      await load()
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  async function removeTopic(row: TopicRow) {
    if (!window.confirm(`删除话题标签「${row.name}」？`)) return
    const res = await client.deleteTopicTag(row.id)
    if (!res.success) {
      setError(res.message || '删除失败')
      return
    }
    setMessage('已删除')
    await load()
  }

  async function removeDict(row: DictRow) {
    if (!window.confirm(`删除策略标签「${row.tag}」？`)) return
    const res = await client.deleteTagDictionary(row.id)
    if (!res.success) {
      setError(res.message || '删除失败')
      return
    }
    setMessage('已删除')
    await load()
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const drawerOpen = modal !== null

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>统一标签中心</h2>
          <p>话题标签（动态）与 Bot 策略标签字典（禁止/偏好）分栏管理</p>
        </div>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            setFormError('')
            if (tab === 'topic') {
              setEditingTopic(null)
              setTopicForm(topicEmpty)
            } else {
              setEditingDict(null)
              setDictForm(dictEmpty)
            }
            setModal('create')
          }}
        >
          新建
        </button>
      </div>

      <DataEnvBar />

      <div className="tab-bar">
        <button
          type="button"
          className={`tab-btn${tab === 'topic' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('topic')}
        >
          话题标签
        </button>
        <button
          type="button"
          className={`tab-btn${tab === 'dictionary' ? ' tab-btn-active' : ''}`}
          onClick={() => setTab('dictionary')}
        >
          Bot 策略字典
        </button>
      </div>

      <div className="filter-bar card">
        <label>
          关键词
          <input value={keyword} onChange={(e) => setKeyword(e.target.value)} placeholder="名称 / tag" />
        </label>
        {tab === 'dictionary' && (
          <label>
            分类
            <select value={dictCategory} onChange={(e) => setDictCategory(e.target.value)}>
              <option value="">全部</option>
              <option value="bot_forbidden">禁止 (bot_forbidden)</option>
              <option value="bot_preferred">偏好 (bot_preferred)</option>
            </select>
          </label>
        )}
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            setPage(1)
            void load()
          }}
        >
          搜索
        </button>
      </div>

      {message && <p className="form-hint ok">{message}</p>}
      {error && <p className="form-error">{error}</p>}

      <div className="table-card">
        {loading ? (
          <p className="muted">加载中…</p>
        ) : tab === 'topic' ? (
          <table className="data-table">
            <thead>
              <tr>
                <th>名称</th>
                <th>颜色</th>
                <th>创建时间</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {topicItems.map((row) => (
                <tr key={row.id}>
                  <td>{row.name}</td>
                  <td>
                    <span
                      className="color-swatch"
                      style={{ background: row.color || '#7f7fd5' }}
                      title={row.color}
                    />
                    {row.color}
                  </td>
                  <td>{formatDateTime(row.created_at)}</td>
                  <td className="row-actions">
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => {
                        setEditingTopic(row)
                        setTopicForm({ name: row.name, color: row.color || '#7f7fd5' })
                        setModal('edit')
                      }}
                    >
                      编辑
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm danger"
                      onClick={() => void removeTopic(row)}
                    >
                      删除
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
                <th>分类</th>
                <th>Tag</th>
                <th>展示名</th>
                <th>排序</th>
                <th>状态</th>
                <th>更新</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {dictItems.map((row) => (
                <tr key={row.id}>
                  <td>{row.category}</td>
                  <td>
                    <code>{row.tag}</code>
                    <br />
                    <IdCell id={row.id} />
                  </td>
                  <td>{row.label || '—'}</td>
                  <td>{row.sort_order}</td>
                  <td>{row.enabled ? '启用' : '停用'}</td>
                  <td>{formatDateTime(row.updated_at)}</td>
                  <td className="row-actions">
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => {
                        setEditingDict(row)
                        setDictForm({
                          category: row.category,
                          tag: row.tag,
                          label: row.label || '',
                          note: row.note || '',
                          sort_order: String(row.sort_order),
                          enabled: row.enabled,
                        })
                        setModal('edit')
                      }}
                    >
                      编辑
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm danger"
                      onClick={() => void removeDict(row)}
                    >
                      删除
                    </button>
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

      <AdminFormDrawer
        open={drawerOpen}
        title={tab === 'topic' ? (modal === 'create' ? '新建话题标签' : '编辑话题标签') : modal === 'create' ? '新建策略标签' : '编辑策略标签'}
        onClose={() => setModal(null)}
        onSave={() => void (tab === 'topic' ? saveTopic() : saveDict())}
        saving={saving}
        saveLabel={modal === 'create' ? '创建' : '保存'}
        error={formError}
      >
        {tab === 'topic' ? (
          <>
            <FormField label="名称" required>
              <input
                value={topicForm.name}
                onChange={(e) => setTopicForm((f) => ({ ...f, name: e.target.value }))}
              />
            </FormField>
            <FormField label="颜色">
              <input
                type="color"
                value={topicForm.color}
                onChange={(e) => setTopicForm((f) => ({ ...f, color: e.target.value }))}
              />
            </FormField>
          </>
        ) : (
          <>
            <FormField label="分类" required>
              <select
                value={dictForm.category}
                onChange={(e) => setDictForm((f) => ({ ...f, category: e.target.value }))}
              >
                <option value="bot_forbidden">bot_forbidden（禁止）</option>
                <option value="bot_preferred">bot_preferred（偏好）</option>
              </select>
            </FormField>
            <FormField label="Tag 标识" required>
              <input
                value={dictForm.tag}
                onChange={(e) => setDictForm((f) => ({ ...f, tag: e.target.value }))}
              />
            </FormField>
            <FormField label="展示名">
              <input
                value={dictForm.label}
                onChange={(e) => setDictForm((f) => ({ ...f, label: e.target.value }))}
              />
            </FormField>
            <FormField label="备注">
              <textarea
                value={dictForm.note}
                onChange={(e) => setDictForm((f) => ({ ...f, note: e.target.value }))}
                rows={3}
              />
            </FormField>
            <FormField label="排序">
              <input
                type="number"
                value={dictForm.sort_order}
                onChange={(e) => setDictForm((f) => ({ ...f, sort_order: e.target.value }))}
              />
            </FormField>
            <FormField label="启用">
              <label className="checkbox-inline">
                <input
                  type="checkbox"
                  checked={dictForm.enabled}
                  onChange={(e) => setDictForm((f) => ({ ...f, enabled: e.target.checked }))}
                />
                启用此条目
              </label>
            </FormField>
          </>
        )}
      </AdminFormDrawer>
    </>
  )
}
