import { useMemo, useState } from 'react'

import { ORIGINALS_PREFIX, type AvatarAssetStore } from '../assetStore'
import { collectManifestAssets, layersForOutfit } from '../editor/collectManifestAssets'
import { RESOURCE_GROUP_ORDER, classifyResourcePath, resourceGroupSortIndex } from '../editor/resourceCatalog'
import type { MoeAvatarManifest, OutfitSelection, WearSlot } from '../types'
import { LayerSheetPreview } from './LayerSheetPreview'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  assetStore: AvatarAssetStore
  assetRevision: number
  outfit: OutfitSelection
  focusSlot?: WearSlot
  focusItemId?: string
  onRevert?: (relPath: string) => void
  onDeleteResource?: (relPath: string) => void
}

type SessionBlob = { key: string; blob: Blob }

type SessionBundle = {
  processed?: SessionBlob
  original?: SessionBlob
}

type PackItem = {
  path: string
  label: string
  group: string
  category: string
  slot?: string
  inManifest: boolean
  ext: string
  session?: SessionBundle
}

type FilterMode = 'all' | 'manifest' | 'session' | 'original' | 'inUse' | 'png' | 'svg' | 'other'

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(bytes >= 10 * 1024 ? 0 : 1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function assetStatus(item: PackItem): string {
  const hasProcessed = !!item.session?.processed
  const hasOriginal = !!item.session?.original
  if (hasProcessed && hasOriginal) return '会话 · 已裁剪'
  if (hasProcessed) return '会话覆盖'
  if (hasOriginal) return '原图归档'
  return item.inManifest ? '官方包' : '会话资源'
}

function previewPath(item: PackItem): string {
  if (item.session?.processed) return item.path
  if (item.session?.original) return item.session.original.key
  return item.path
}

function isLikelyRaster(ext: string): boolean {
  return ext === 'png' || ext === 'jpg' || ext === 'jpeg' || ext === 'webp'
}

function kindLabel(kind: FilterMode): string {
  switch (kind) {
    case 'manifest':
      return '官方'
    case 'session':
      return '会话'
    case 'original':
      return '原图'
    case 'inUse':
      return '试穿中'
    case 'png':
      return 'PNG'
    case 'svg':
      return 'SVG'
    case 'other':
      return '其他'
    default:
      return '全部'
  }
}

/** 合并资产包：同一路径的官方项 + 会话覆盖 + 原图归档放在同一条记录里 */
export function ResourcePackPanel({
  manifest,
  packBaseUrl,
  assetStore,
  assetRevision,
  outfit,
  focusSlot,
  focusItemId,
  onRevert,
  onDeleteResource,
}: Props) {
  const [filter, setFilter] = useState<FilterMode>('all')
  const [query, setQuery] = useState('')
  const allEntries = useMemo(() => collectManifestAssets(manifest), [manifest])
  const idleInUse = useMemo(() => layersForOutfit(manifest, outfit, 'idle'), [manifest, outfit])
  const walkInUse = useMemo(() => layersForOutfit(manifest, outfit, 'walk'), [manifest, outfit])

  const items = useMemo(() => {
    const manifestMap = new Map(allEntries.map((entry) => [entry.path, entry]))
    const sessionMap = new Map<string, SessionBundle>()

    for (const { key, blob } of assetStore.entries()) {
      const baseKey = key.startsWith(ORIGINALS_PREFIX) ? key.slice(ORIGINALS_PREFIX.length) : key
      const bundle = sessionMap.get(baseKey) ?? {}
      if (key.startsWith(ORIGINALS_PREFIX)) bundle.original = { key, blob }
      else bundle.processed = { key, blob }
      sessionMap.set(baseKey, bundle)
    }

    const logicalPaths = new Set<string>([...manifestMap.keys(), ...sessionMap.keys()])
    const list: PackItem[] = []

    for (const path of logicalPaths) {
      const manifestEntry = manifestMap.get(path)
      const session = sessionMap.get(path)
      const inManifest = !!manifestEntry
      const label = manifestEntry?.label ?? path.split('/').pop() ?? path
      const classification = classifyResourcePath(path, inManifest)
      list.push({
        path,
        label,
        group: classification.group,
        category: classification.category,
        slot: classification.slot,
        inManifest,
        ext: classification.ext,
        session,
      })
    }

    list.sort((a, b) => {
      const groupDelta = resourceGroupSortIndex(a.group as (typeof RESOURCE_GROUP_ORDER)[number]) - resourceGroupSortIndex(b.group as (typeof RESOURCE_GROUP_ORDER)[number])
      if (groupDelta !== 0) return groupDelta
      if (a.category !== b.category) return a.category.localeCompare(b.category, 'zh-Hans-CN')
      return a.path.localeCompare(b.path)
    })
    return list
  }, [allEntries, assetStore, assetRevision])

  const filteredItems = useMemo(() => {
    const q = query.trim().toLowerCase()
    return items.filter((item) => {
      if (q) {
        const hay = `${item.path} ${item.label} ${item.group} ${item.category} ${item.slot ?? ''} ${item.ext}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      if (filter === 'manifest' && !item.inManifest) return false
      if (filter === 'session' && !item.session?.processed && !item.session?.original) return false
      if (filter === 'original' && !item.session?.original) return false
      if (filter === 'inUse' && !(idleInUse.has(item.path) || walkInUse.has(item.path))) return false
      if (filter === 'png' && item.ext !== 'png') return false
      if (filter === 'svg' && item.ext !== 'svg') return false
      if (filter === 'other' && (item.ext === 'png' || item.ext === 'svg' || isLikelyRaster(item.ext))) return false
      return true
    })
  }, [items, filter, query, idleInUse, walkInUse])

  const groupedItems = useMemo(() => {
    const map = new Map<string, PackItem[]>()
    for (const item of filteredItems) {
      const list = map.get(item.group)
      if (list) list.push(item)
      else map.set(item.group, [item])
    }
    return [...map.entries()]
  }, [filteredItems])

  const sessionBytes = useMemo(
    () =>
      assetStore.entries().reduce((sum, entry) => sum + entry.blob.size, 0),
    [assetStore, assetRevision],
  )

  const summary = useMemo(() => {
    const inUse = items.filter((item) => idleInUse.has(item.path) || walkInUse.has(item.path)).length
    const manifestCount = items.filter((item) => item.inManifest).length
    const sessionCount = items.filter((item) => !!item.session?.processed).length
    const originalCount = items.filter((item) => !!item.session?.original).length
    const pngCount = items.filter((item) => item.ext === 'png').length
    const svgCount = items.filter((item) => item.ext === 'svg').length
    const groupCounts = items.reduce<Record<string, number>>((acc, item) => {
      acc[item.group] = (acc[item.group] ?? 0) + 1
      return acc
    }, {})
    return { inUse, manifestCount, sessionCount, originalCount, pngCount, svgCount, groupCounts }
  }, [items, idleInUse, walkInUse])

  const currentFocus = focusSlot && focusItemId ? manifest.slots[focusSlot]?.[focusItemId] : undefined

  return (
    <div style={{ fontSize: 12 }}>
      <div style={{ marginBottom: 12, padding: '8px 10px', border: '1px solid #eee', borderRadius: 8, background: '#fffdfa' }}>
        <div style={{ fontWeight: 600, marginBottom: 4 }}>合并资产包</div>
        <div className="muted" style={{ fontSize: 11 }}>
          {filteredItems.length}/{items.length} 个逻辑资源 · 会话 {formatBytes(sessionBytes)} · 同一路径的官方项、覆盖项、原图归档已合并展示。
        </div>
        {currentFocus ? (
          <div className="muted" style={{ fontSize: 11, marginTop: 4 }}>
            当前单品：{currentFocus.walk} / {currentFocus.idle}
          </div>
        ) : null}
      </div>

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
        {(['all', 'manifest', 'session', 'original', 'inUse', 'png', 'svg', 'other'] as FilterMode[]).map((kind) => (
          <button
            key={kind}
            type="button"
            className={`btn${filter === kind ? ' primary' : ''}`}
            style={{ fontSize: 11 }}
            onClick={() => setFilter(kind)}
          >
            {kindLabel(kind)}
          </button>
        ))}
        <input
          className="input"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="搜索路径 / 名称 / 类型"
          style={{ minWidth: 220, flex: '1 1 220px' }}
        />
      </div>

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>官方 {summary.manifestCount}</span>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>会话 {summary.sessionCount}</span>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>原图 {summary.originalCount}</span>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>试穿 {summary.inUse}</span>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>PNG {summary.pngCount}</span>
        <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>SVG {summary.svgCount}</span>
        {RESOURCE_GROUP_ORDER.map((group) => (
          <span key={group} className="btn" style={{ fontSize: 10, cursor: 'default' }}>
            {group} {summary.groupCounts[group] ?? 0}
          </span>
        ))}
      </div>

      <div style={{ display: 'grid', gap: 10 }}>
        {groupedItems.map(([group, groupItems]) => (
          <details key={group} open={group !== '其他'} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10, background: '#fff' }}>
            <summary style={{ cursor: 'pointer', fontWeight: 600 }}>
              {group} · {groupItems.length}
            </summary>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
                gap: 10,
                marginTop: 10,
              }}
            >
              {groupItems.map((item) => {
                const inUse = idleInUse.has(item.path) || walkInUse.has(item.path)
                const hasProcessed = !!item.session?.processed
                const hasOriginal = !!item.session?.original
                const status = assetStatus(item)
                const previewRelPath = previewPath(item)
                const previewMode = item.inManifest ? 'frame' : 'sheet'

                return (
                  <div
                    key={item.path}
                    style={{
                      border: inUse ? '2px solid #e97891' : '1px solid #eee',
                      borderRadius: 10,
                      padding: 10,
                      background: inUse ? '#fffafb' : '#fff',
                    }}
                  >
                    <div style={{ fontWeight: 600, fontSize: 11, marginBottom: 4 }}>{item.label}</div>
                    <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 4 }}>
                      <span className="muted" style={{ fontSize: 9 }}>
                        {item.group}
                      </span>
                      <span className="muted" style={{ fontSize: 9 }}>
                        {item.category}
                      </span>
                      {item.slot ? (
                        <span className="muted" style={{ fontSize: 9 }}>
                          {item.slot}
                        </span>
                      ) : null}
                    </div>
                    <code style={{ fontSize: 9, wordBreak: 'break-all', display: 'block' }}>{item.path}</code>
                    <p style={{ margin: '4px 0 6px', fontSize: 10, color: hasProcessed ? '#c45' : '#8a7364' }}>
                      {status}
                      {inUse ? ' · 试穿中' : ''}
                      {hasProcessed ? ` · 成品 ${formatBytes(item.session?.processed?.blob.size ?? 0)}` : ''}
                      {hasOriginal ? ` · 原图 ${formatBytes(item.session?.original?.blob.size ?? 0)}` : ''}
                    </p>
                    <LayerSheetPreview
                      manifest={manifest}
                      packBaseUrl={packBaseUrl}
                      relPath={previewRelPath}
                      assetStore={assetStore}
                      assetRevision={assetRevision}
                      mode={previewMode}
                      maxWidth={64}
                      maxHeight={64}
                    />
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 8 }}>
                      {hasProcessed && onRevert ? (
                        <button
                          type="button"
                          className="btn"
                          style={{ fontSize: 10 }}
                          onClick={() => onRevert(item.path)}
                        >
                          恢复官方
                        </button>
                      ) : null}
                      {hasProcessed && onDeleteResource ? (
                        <button
                          type="button"
                          className="btn"
                          style={{ fontSize: 10, color: 'crimson' }}
                          onClick={() => onDeleteResource(item.path)}
                        >
                          删除会话资源
                        </button>
                      ) : null}
                      {hasOriginal && onDeleteResource ? (
                        <button
                          type="button"
                          className="btn"
                          style={{ fontSize: 10 }}
                          onClick={() => onDeleteResource(item.session?.original?.key ?? '')}
                        >
                          删除原图
                        </button>
                      ) : null}
                    </div>
                  </div>
                )
              })}
            </div>
          </details>
        ))}
      </div>
    </div>
  )
}
