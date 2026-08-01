import { useMemo, useState } from 'react'

import { ORIGINALS_PREFIX, type AvatarAssetStore } from '../assetStore'
import { collectManifestAssets, layersForOutfit } from '../editor/collectManifestAssets'
import { classifyResourcePath, resourceGroupSortIndex, RESOURCE_GROUP_ORDER } from '../editor/resourceCatalog'
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

type FilterMode = 'all' | 'outfit' | 'item'

function assetStatus(rel: string, assetStore: AvatarAssetStore): string {
  if (assetStore.has(rel) && assetStore.hasOriginal(rel)) return '会话 · 已裁剪'
  if (assetStore.has(rel)) return '会话覆盖'
  return '官方包'
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(bytes >= 10 * 1024 ? 0 : 1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

/** manifest 引用资源 + 会话生成资源 + 删除 / 恢复官方 */
export function UnifiedAssetFolderPanel({
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
  const [filter, setFilter] = useState<FilterMode>(focusItemId ? 'item' : 'all')

  const allEntries = useMemo(() => collectManifestAssets(manifest), [manifest])
  const idleInUse = useMemo(() => layersForOutfit(manifest, outfit, 'idle'), [manifest, outfit])
  const walkInUse = useMemo(() => layersForOutfit(manifest, outfit, 'walk'), [manifest, outfit])

  const entries = useMemo(() => {
    if (filter === 'outfit') {
      const paths = new Set([...idleInUse, ...walkInUse])
      return allEntries.filter((e) => paths.has(e.path))
    }
    if (filter === 'item' && focusSlot && focusItemId) {
      const item = manifest.slots[focusSlot]?.[focusItemId]
      if (!item) return allEntries
      const paths = new Set([item.walk, item.idle])
      return allEntries.filter((e) => paths.has(e.path))
    }
    return allEntries
  }, [filter, allEntries, idleInUse, walkInUse, focusSlot, focusItemId, manifest.slots])

  const sessionResources = useMemo(
    () =>
      assetStore.entries().map((entry) => ({
        ...entry,
        ...classifyResourcePath(entry.key, false),
      })),
    [assetStore, assetRevision],
  )

  const groupedSessionResources = useMemo(() => {
    const groups = new Map<string, typeof sessionResources>()
    for (const item of sessionResources) {
      const list = groups.get(item.group)
      if (list) list.push(item)
      else groups.set(item.group, [item])
    }
    return [...groups.entries()].sort(
      ([a], [b]) => resourceGroupSortIndex(a as (typeof RESOURCE_GROUP_ORDER)[number]) - resourceGroupSortIndex(b as (typeof RESOURCE_GROUP_ORDER)[number]),
    )
  }, [sessionResources])

  const sessionTotalBytes = sessionResources.reduce((sum, item) => sum + item.blob.size, 0)

  return (
    <div style={{ fontSize: 12 }}>
      <div
        style={{
          marginBottom: 12,
          padding: '8px 10px',
          border: '1px solid #eee',
          borderRadius: 8,
          background: '#fffdfa',
        }}
      >
        <div style={{ fontWeight: 600, marginBottom: 4 }}>会话资源</div>
        <div className="muted" style={{ fontSize: 11 }}>
          {sessionResources.length} 个 · {formatBytes(sessionTotalBytes)} · 当前只显示浏览器会话里生成/覆盖的资源，不含官方底图本体。
        </div>
        <div className="muted" style={{ fontSize: 11, marginTop: 4 }}>
          生成流程是抠图 + 绑定 + 画布对齐 + 导出，不是模型生成。
        </div>

        {sessionResources.length > 0 ? (
          <div style={{ display: 'grid', gap: 8, marginTop: 10 }}>
            {groupedSessionResources.map(([group, items]) => {
              const total = items.reduce((sum, item) => sum + item.blob.size, 0)
              return (
                <details key={group} open={group !== '其他'}>
                  <summary style={{ cursor: 'pointer', fontWeight: 600 }}>
                    {group} · {items.length} · {formatBytes(total)}
                  </summary>
                  <div style={{ display: 'grid', gap: 6, marginTop: 8 }}>
                    {items.map((item) => {
                      const isOriginal = item.key.startsWith(ORIGINALS_PREFIX)
                      return (
                        <div
                          key={item.key}
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            gap: 10,
                            alignItems: 'center',
                            border: '1px solid #eee',
                            borderRadius: 8,
                            padding: '6px 8px',
                            background: '#fff',
                          }}
                        >
                          <div style={{ minWidth: 0 }}>
                      <div style={{ fontWeight: 600, fontSize: 11, wordBreak: 'break-all' }}>{item.key}</div>
                      <div className="muted" style={{ fontSize: 10 }}>
                        {item.ext} · {formatBytes(item.blob.size)} · {isOriginal ? '原图' : '成品'} · {item.group} · {item.category}
                      </div>
                    </div>
                          <button
                            type="button"
                            className="btn"
                            style={{ fontSize: 10, color: 'crimson', flexShrink: 0 }}
                            onClick={() => onDeleteResource?.(item.key)}
                            disabled={!onDeleteResource}
                          >
                            删除
                          </button>
                        </div>
                      )
                    })}
                  </div>
                </details>
              )
            })}
          </div>
        ) : (
          <p className="muted" style={{ margin: '8px 0 0', fontSize: 11 }}>
            还没有生成资源。上传并绑定后，这里会出现当前会话的成品和原图归档。
          </p>
        )}
      </div>

      <div style={{ display: 'flex', gap: 6, marginBottom: 10, flexWrap: 'wrap' }}>
        {(
          [
            ['all', '全部'],
            ['outfit', '当前试穿'],
            ['item', '当前单品'],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={`btn${filter === id ? ' primary' : ''}`}
            style={{ fontSize: 11 }}
            onClick={() => setFilter(id)}
            disabled={id === 'item' && !focusItemId}
          >
            {label}
          </button>
        ))}
      </div>

      <p className="muted" style={{ margin: '0 0 10px', fontSize: 11 }}>
        正在使用的 pack 文件 · 左侧为<strong>单帧</strong>（与 App 一致）· 会话覆盖可恢复官方
      </p>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
          gap: 10,
          maxHeight: 480,
          overflowY: 'auto',
        }}
      >
        {entries.map((e) => {
          const inUse = idleInUse.has(e.path) || walkInUse.has(e.path)
          const isOverride = assetStore.has(e.path)
          const status = assetStatus(e.path, assetStore)
          const processed = assetStore.get(e.path)
          const original = assetStore.getOriginal(e.path)

          return (
            <div
              key={e.path}
              style={{
                border: inUse ? '2px solid #e97891' : '1px solid #eee',
                borderRadius: 10,
                padding: 8,
                background: inUse ? '#fffafb' : '#fff',
              }}
            >
              <div style={{ fontWeight: 600, fontSize: 11, marginBottom: 4 }}>{e.label}</div>
              <code style={{ fontSize: 9, wordBreak: 'break-all', display: 'block' }}>{e.path}</code>
              <p style={{ margin: '4px 0 6px', fontSize: 10, color: isOverride ? '#c45' : '#8a7364' }}>
                {status}
                {inUse ? ' · 试穿中' : ''}
                {processed ? ` · 成品 ${formatBytes(processed.size)}` : ''}
                {original ? ` · 原图 ${formatBytes(original.size)}` : ''}
              </p>
              <LayerSheetPreview
                manifest={manifest}
                packBaseUrl={packBaseUrl}
                relPath={e.path}
                assetStore={assetStore}
                assetRevision={assetRevision}
                mode="frame"
                maxWidth={64}
                maxHeight={64}
              />
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
                {isOverride && onRevert ? (
                  <button
                    type="button"
                    className="btn"
                    style={{ fontSize: 10 }}
                    onClick={() => onRevert(e.path)}
                  >
                    恢复官方
                  </button>
                ) : null}
                {isOverride && onDeleteResource ? (
                  <button
                    type="button"
                    className="btn"
                    style={{ fontSize: 10, color: 'crimson' }}
                    onClick={() => onDeleteResource(e.path)}
                  >
                    删除会话资源
                  </button>
                ) : null}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
