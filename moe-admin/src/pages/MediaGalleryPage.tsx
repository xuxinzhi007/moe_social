import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { AdminTag } from '../components/AdminTag'
import { DataEnvBar } from '../components/DataEnvBar'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { formatBytes } from '../lib/format'
import type { TagTone } from '../lib/adminLabels'
import { useDirectAdminApi } from '../lib/adminApi'
import { DeployApiError } from '../api/deployClient'

type OwnerRow = {
  owner_folder: string
  user_id?: string
  username_hint?: string
  file_count: number
  total_bytes: number
}

type ImageRow = {
  filename: string
  file_name: string
  owner_folder: string
  media_kind: string
  url: string
  size: number
  created_at: string
  owner_hint?: string
}

type MediaKindFilter = '' | 'gallery' | 'hand_draw' | 'avatar'

const KIND_TABS: Array<{ id: MediaKindFilter; label: string }> = [
  { id: '', label: '全部' },
  { id: 'gallery', label: '云图库' },
  { id: 'hand_draw', label: '手绘缩略图' },
  { id: 'avatar', label: '头像' },
]

function mediaKindLabel(kind: string) {
  switch (kind) {
    case 'hand_draw':
      return '手绘缩略图'
    case 'avatar':
      return '头像'
    case 'gallery':
      return '云图库'
    default:
      return kind || '其他'
  }
}

function mediaKindTone(kind: string): TagTone {
  switch (kind) {
    case 'hand_draw':
      return 'warn'
    case 'avatar':
      return 'info'
    case 'gallery':
      return 'run'
    default:
      return 'neutral'
  }
}

function resolveMediaViewUrl(
  rawUrl: string,
  apiBase: string,
  devDirect: boolean,
  apiTarget: 'local' | 'cloud',
): string {
  const pathMatch = rawUrl.match(/\/api\/images\/[^?#]+/)
  if (!pathMatch) return rawUrl
  const path = pathMatch[0]
  if (devDirect) {
    if (apiTarget === 'cloud' && apiBase) return `${apiBase.replace(/\/$/, '')}${path}`
    return path
  }
  const base = apiBase.replace(/\/$/, '')
  if (!base) return rawUrl
  return `${base}${path}`
}

export function MediaGalleryPage() {
  const { client } = useAdminAuth()
  const { apiTarget, health } = usePlatform()
  const devDirect = useDirectAdminApi()
  const apiBase = useMemo(() => {
    const h = apiTarget === 'cloud' ? health?.cloud_api : health?.local_api
    return h?.base_url?.replace(/\/$/, '') || ''
  }, [apiTarget, health])
  const [items, setItems] = useState<ImageRow[]>([])
  const [owners, setOwners] = useState<OwnerRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [ownerFolder, setOwnerFolder] = useState('')
  const [mediaKind, setMediaKind] = useState<MediaKindFilter>('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const pageSize = 30

  const activeOwner = useMemo(
    () => owners.find((o) => o.owner_folder === ownerFolder),
    [ownerFolder, owners],
  )

  useEffect(() => {
    setPage(1)
    setOwnerFolder('')
    setMediaKind('')
    setSearch('')
    setKeyword('')
  }, [apiTarget])

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.listMediaImages({
        page,
        page_size: pageSize,
        keyword: search || undefined,
        owner_folder: ownerFolder || undefined,
        media_kind: mediaKind || undefined,
      })
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setItems([])
        setOwners([])
        setTotal(0)
        return
      }
      setItems(res.data.items || [])
      setOwners(res.data.owners || [])
      setTotal(res.data.total || 0)
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
      setItems([])
      setOwners([])
      setTotal(0)
    } finally {
      setLoading(false)
    }
  }, [client, mediaKind, ownerFolder, page, search])

  useEffect(() => {
    void load()
  }, [load])

  async function remove(filename: string) {
    if (!window.confirm(`确定删除 ${filename}？此操作不可恢复。`)) return
    setError('')
    try {
      const res = await client.deleteMediaImage(filename)
      if (!res.success) {
        setError(res.message || '删除失败')
        return
      }
      setMessage(`已删除 ${filename}`)
      await load()
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '删除失败')
    }
  }

  const totalAllFiles = useMemo(
    () => owners.reduce((sum, o) => sum + o.file_count, 0),
    [owners],
  )
  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>云图库</h2>
          <p>
            App 云图库、发帖图片、手绘缩略图、头像等，均通过 <code>/api/upload</code> 存到同一目录{' '}
            <code>Image.LocalDir/{'{userId_用户名}'}/</code>，此处统一治理。
          </p>
        </div>
        <Link to="/system/app-config" className="btn btn-ghost">
          应用配置
        </Link>
      </div>

      <DataEnvBar note="本机 API 只看本机磁盘；VPS 上的 scaled_*.jpg 等云图库文件请切到「云端 API」" />

      {message ? (
        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
          {message}
          <button type="button" className="btn btn-ghost" style={{ marginLeft: 8 }} onClick={() => setMessage('')}>
            关闭
          </button>
        </div>
      ) : null}

      <div className="media-gallery-layout panel">
        <aside className="media-owner-sidebar">
          <div className="media-owner-head">
            <strong>用户目录</strong>
            <span className="muted">{owners.length} 个</span>
          </div>
          <button
            type="button"
            className={`media-owner-item${ownerFolder === '' ? ' is-active' : ''}`}
            onClick={() => {
              setOwnerFolder('')
              setPage(1)
            }}
          >
            <span>全部用户</span>
            <span className="muted">{totalAllFiles} 张</span>
          </button>
          {owners.map((owner) => (
            <button
              key={owner.owner_folder}
              type="button"
              className={`media-owner-item${ownerFolder === owner.owner_folder ? ' is-active' : ''}`}
              onClick={() => {
                setOwnerFolder(owner.owner_folder)
                setPage(1)
              }}
            >
              <span className="media-owner-label" title={owner.owner_folder}>
                {owner.user_id ? `#${owner.user_id}` : owner.owner_folder}
                {owner.username_hint ? ` · ${owner.username_hint}` : ''}
              </span>
              <span className="muted">
                {owner.file_count} · {formatBytes(owner.total_bytes)}
              </span>
            </button>
          ))}
        </aside>

        <div className="media-gallery-main">
          <div className="media-kind-tabs">
            {KIND_TABS.map((tab) => (
              <button
                key={tab.id || 'all'}
                type="button"
                className={`btn btn-sm${mediaKind === tab.id ? ' btn-primary' : ' btn-ghost'}`}
                onClick={() => {
                  setMediaKind(tab.id)
                  setPage(1)
                }}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <form
            className="inline-form"
            style={{ marginTop: 12 }}
            onSubmit={(e) => {
              e.preventDefault()
              setPage(1)
              setSearch(keyword.trim())
            }}
          >
            <input
              placeholder="按文件名 / 用户目录搜索"
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
            />
            <button type="submit" className="btn btn-primary">
              搜索
            </button>
          </form>

          {ownerFolder ? (
            <p className="muted" style={{ margin: '8px 0 0' }}>
              当前目录：<code>{ownerFolder}</code>
              {activeOwner?.user_id ? (
                <>
                  {' '}
                  · <Link to={`/users/${activeOwner.user_id}`}>打开用户详情</Link>
                </>
              ) : null}
            </p>
          ) : null}

          {error ? <p className="text-danger">{error}</p> : null}

          <div className="table-wrap" style={{ marginTop: 12 }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>预览</th>
                  <th>文件</th>
                  <th>类型</th>
                  <th>用户目录</th>
                  <th>大小</th>
                  <th>上传时间</th>
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
                      {apiTarget === 'local'
                        ? '本机暂无匹配图片。云图库上传在 VPS 上，请切到「云端 API」后点左侧 #1 · xxz 等目录'
                        : '当前筛选下暂无图片'}
                    </td>
                  </tr>
                ) : (
                  items.map((row) => {
                    const viewUrl = resolveMediaViewUrl(row.url, apiBase, devDirect, apiTarget)
                    return (
                      <tr key={row.filename}>
                        <td>
                          <a href={viewUrl} target="_blank" rel="noreferrer" title="新窗口查看原图">
                            <img src={viewUrl} alt="" className="media-thumb" loading="lazy" />
                          </a>
                        </td>
                        <td className="muted" style={{ maxWidth: 200, wordBreak: 'break-all' }}>
                          <div>{row.file_name}</div>
                          <div className="muted" style={{ fontSize: 12, opacity: 0.75 }}>
                            {row.filename}
                          </div>
                        </td>
                        <td>
                          <AdminTag label={mediaKindLabel(row.media_kind)} tone={mediaKindTone(row.media_kind)} />
                        </td>
                        <td className="muted">
                          <button
                            type="button"
                            className="btn btn-ghost btn-sm"
                            onClick={() => {
                              setOwnerFolder(row.owner_folder)
                              setPage(1)
                            }}
                          >
                            {row.owner_folder}
                          </button>
                        </td>
                        <td className="muted">{formatBytes(row.size)}</td>
                        <td className="muted">{row.created_at}</td>
                        <td>
                          <a href={viewUrl} target="_blank" rel="noreferrer" className="btn btn-ghost btn-sm" style={{ marginRight: 6 }}>
                            查看
                          </a>
                          <button type="button" className="btn btn-ghost btn-sm text-danger" onClick={() => void remove(row.filename)}>
                            删除
                          </button>
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>

          <div className="pager">
            <button type="button" className="btn btn-ghost" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
              上一页
            </button>
            <span className="muted">
              {page} / {totalPages} · 当前 {total} 张
            </span>
            <button type="button" className="btn btn-ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              下一页
            </button>
          </div>
        </div>
      </div>
    </>
  )
}
