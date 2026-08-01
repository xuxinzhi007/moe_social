import { useMemo, useState } from 'react'

import type { AvatarAssetStore } from '../assetStore'
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
  /** 生产区当前槽位单品，用于「仅看当前单品」筛选 */
  focusSlot?: WearSlot
  focusItemId?: string
  onRevert?: (relPath: string) => void
}

type FilterMode = 'all' | 'outfit' | 'item'

function assetStatus(rel: string, assetStore: AvatarAssetStore): string {
  if (assetStore.has(rel) && assetStore.hasOriginal(rel)) return '会话 · 已裁剪'
  if (assetStore.has(rel)) return '会话覆盖'
  return '官方包'
}

/** manifest 引用的全部资产 + 单帧预览 + 恢复官方 */
export function AssetFolderPanel({
  manifest,
  packBaseUrl,
  assetStore,
  assetRevision,
  outfit,
  focusSlot,
  focusItemId,
  onRevert,
}: Props) {
  const [filter, setFilter] = useState<FilterMode>(focusItemId ? 'item' : 'all')

  const allEntries = useMemo(() => collectManifestAssets(manifest), [manifest])
  const idleInUse = useMemo(() => layersForOutfit(manifest, outfit, 'idle'), [manifest, outfit])
  const walkInUse = useMemo(() => layersForOutfit(manifest, outfit, 'walk'), [manifest, outfit])

  const entries = useMemo(() => {
    if (filter === 'outfit') {
      const paths = new Set([...idleInUse, ...walkInUse])
      return allEntries.filter((entry) => paths.has(entry.path))
    }
    if (filter === 'item' && focusSlot && focusItemId) {
      const item = manifest.slots[focusSlot]?.[focusItemId]
      if (!item) return allEntries
      const paths = new Set([item.walk, item.idle])
      return allEntries.filter((entry) => paths.has(entry.path))
    }
    return allEntries
  }, [allEntries, filter, focusItemId, focusSlot, idleInUse, manifest.slots, walkInUse])

  const sessionSummary = useMemo(() => {
    const counts = entries.reduce<Record<string, number>>((acc, entry) => {
      const meta = classifyResourcePath(entry.path, true)
      acc[meta.group] = (acc[meta.group] ?? 0) + 1
      return acc
    }, {})
    return counts
  }, [entries])

  const sortedGroups = useMemo(
    () =>
      ([...new Set(entries.map((entry) => classifyResourcePath(entry.path, true).group))] as (typeof RESOURCE_GROUP_ORDER)[number][]).sort(
        (a, b) => resourceGroupSortIndex(a) - resourceGroupSortIndex(b),
      ),
    [entries],
  )

  return (
    <div style={{ fontSize: 12 }}>
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

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
        {RESOURCE_GROUP_ORDER.map((group) => (
          <span key={group} className="btn" style={{ fontSize: 10, cursor: 'default' }}>
            {group} {sessionSummary[group] ?? 0}
          </span>
        ))}
      </div>

      <p className="muted" style={{ margin: '0 0 10px', fontSize: 11 }}>
        正在使用的 pack 文件 · 左侧为<strong>单帧</strong>（与 App 一致）· 会话覆盖可恢复官方
      </p>

      <div
        style={{
          display: 'grid',
          gap: 10,
          maxHeight: 480,
          overflowY: 'auto',
        }}
      >
        {sortedGroups.map((group) => {
          const groupItems = entries.filter((entry) => classifyResourcePath(entry.path, true).group === group)
          return (
            <details key={group} open={group !== '其他'} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10 }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600 }}>
                {group} · {groupItems.length}
              </summary>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
                  gap: 10,
                  marginTop: 10,
                }}
              >
                {groupItems.map((entry) => {
                  const inUse = idleInUse.has(entry.path) || walkInUse.has(entry.path)
                  const isOverride = assetStore.has(entry.path)
                  const meta = classifyResourcePath(entry.path, true)
                  const status = assetStatus(entry.path, assetStore)

                  return (
                    <div
                      key={entry.path}
                      style={{
                        border: inUse ? '2px solid #e97891' : '1px solid #eee',
                        borderRadius: 10,
                        padding: 8,
                        background: inUse ? '#fffafb' : '#fff',
                      }}
                    >
                      <div style={{ fontWeight: 600, fontSize: 11, marginBottom: 4 }}>{entry.label}</div>
                      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 4 }}>
                        <span className="muted" style={{ fontSize: 9 }}>{meta.group}</span>
                        <span className="muted" style={{ fontSize: 9 }}>{meta.category}</span>
                      </div>
                      <code style={{ fontSize: 9, wordBreak: 'break-all', display: 'block' }}>{entry.path}</code>
                      <p style={{ margin: '4px 0 6px', fontSize: 10, color: isOverride ? '#c45' : '#8a7364' }}>
                        {status}
                        {inUse ? ' · 试穿中' : ''}
                      </p>
                      <LayerSheetPreview
                        manifest={manifest}
                        packBaseUrl={packBaseUrl}
                        relPath={entry.path}
                        assetStore={assetStore}
                        assetRevision={assetRevision}
                        mode="frame"
                        maxWidth={64}
                        maxHeight={64}
                      />
                      {isOverride && onRevert ? (
                        <button
                          type="button"
                          className="btn"
                          style={{ fontSize: 10, marginTop: 6 }}
                          onClick={() => onRevert(entry.path)}
                        >
                          恢复官方
                        </button>
                      ) : null}
                    </div>
                  )
                })}
              </div>
            </details>
          )
        })}
      </div>
    </div>
  )
}
