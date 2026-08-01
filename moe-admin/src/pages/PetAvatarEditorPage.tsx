import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { AdminPanel } from '../ui/AdminPanel'
import { ListPageLayout } from '../ui'
import { AvatarPreviewCanvas } from '../features/moe-avatar/components/AvatarPreviewCanvas'
import { SlotItemProductionPanel } from '../features/moe-avatar/components/SlotItemProductionPanel'
import { SlotItemThumb } from '../features/moe-avatar/components/SlotItemThumb'
import { AvatarAssetStore } from '../features/moe-avatar/assetStore'
import { itemLabel } from '../features/moe-avatar/labels'
import { itemIdsForSlot } from '../features/moe-avatar/composer/resolveLayers'
import {
  downloadBlob,
  exportMoePackZip,
} from '../features/moe-avatar/export/exportMoePack'
import type {
  MoeAvatarManifest,
  OutfitSelection,
  WearSlot,
} from '../features/moe-avatar/types'

import {
  MOE_AVATAR_MANIFEST_URL,
  MOE_AVATAR_PACK_BASE,
} from '../features/moe-avatar/constants'

const DEFAULT_OUTFIT: OutfitSelection = {
  hatId: '',
  topId: 'top_basic',
  bottomId: 'bottom_basic',
  shoesId: 'shoes_basic',
}

const SLOTS: { id: WearSlot; label: string }[] = [
  { id: 'hat', label: '帽' },
  { id: 'top', label: '衣' },
  { id: 'bottom', label: '裤' },
  { id: 'shoes', label: '鞋' },
]

type Tab = 'editor' | 'manifest'

/** 养成 · Moe Avatar 生产编辑器 */
export function PetAvatarEditorPage() {
  const assetStoreRef = useRef<AvatarAssetStore | null>(null)
  if (!assetStoreRef.current) {
    assetStoreRef.current = new AvatarAssetStore()
  }
  const assetStore = assetStoreRef.current

  const [tab, setTab] = useState<Tab>('editor')
  const [manifest, setManifest] = useState<MoeAvatarManifest | null>(null)
  const [manifestText, setManifestText] = useState('')
  const [parseError, setParseError] = useState('')
  const [message, setMessage] = useState('')
  const [outfit, setOutfit] = useState<OutfitSelection>(DEFAULT_OUTFIT)
  const [activeSlot, setActiveSlot] = useState<WearSlot>('top')
  const [exporting, setExporting] = useState(false)
  const [assetRevision, setAssetRevision] = useState(0)

  const loadManifest = useCallback(async () => {
    setParseError('')
    try {
      const res = await fetch(MOE_AVATAR_MANIFEST_URL)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = (await res.json()) as MoeAvatarManifest
      setManifest(data)
      setManifestText(JSON.stringify(data, null, 2))
      setMessage('已加载官方包 manifest · 可新建单品并上传 sheet')
    } catch (e) {
      setParseError(e instanceof Error ? e.message : '加载失败')
    }
  }, [])

  useEffect(() => {
    void loadManifest()
    return () => assetStore.dispose()
  }, [loadManifest, assetStore])

  const handleManifestChange = (next: MoeAvatarManifest) => {
    setManifest(next)
    setManifestText(JSON.stringify(next, null, 2))
    setParseError('')
    setMessage('manifest 已更新')
  }

  const bumpAssets = () => setAssetRevision((n) => n + 1)

  const activeItems = useMemo(() => {
    if (!manifest) return ['']
    return ['', ...itemIdsForSlot(manifest, activeSlot)]
  }, [manifest, activeSlot])

  const activeId = outfit[`${activeSlot}Id` as keyof OutfitSelection] as string

  const setSlotId = (id: string) => {
    setOutfit((o) => ({ ...o, [`${activeSlot}Id`]: id }))
  }

  const applyManifestText = () => {
    try {
      const data = JSON.parse(manifestText) as MoeAvatarManifest
      setManifest(data)
      setParseError('')
      setMessage('manifest 已应用到编辑器')
    } catch (e) {
      setParseError(e instanceof Error ? e.message : 'JSON 无效')
      setMessage('')
    }
  }

  const onExportPack = async () => {
    if (!manifest) return
    setExporting(true)
    setMessage('')
    try {
      const blob = await exportMoePackZip({
        manifest,
        packBaseUrl: MOE_AVATAR_PACK_BASE,
        assetStore,
        includeBaked: false,
      })
      downloadBlob(blob, `${manifest.packId}.zip`)
      setMessage(
        '已导出分层包（各部位 walk/idle sheet + manifest）→ assets/pet/moe_content/avatar/ · App 运行时任意槽位组合',
      )
    } catch (e) {
      setParseError(e instanceof Error ? e.message : '导出失败')
    } finally {
      setExporting(false)
    }
  }

  return (
    <ListPageLayout
      title="养成 · 角色装扮编辑器"
      description="生产 walk/idle 分层 · 新建单品 · 导出官方包 → App 消费"
      headActions={
        <>
          <Link to="/biz/pet/content" className="btn" style={{ marginRight: 8 }}>
            总览
          </Link>
          <button
            type="button"
            className="btn primary"
            disabled={!manifest || exporting}
            onClick={() => void onExportPack()}
          >
            {exporting ? '导出中…' : '导出官方包 zip'}
          </button>
        </>
      }
    >
      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <button
          type="button"
          className={`btn${tab === 'editor' ? ' primary' : ''}`}
          onClick={() => setTab('editor')}
        >
          生产编辑
        </button>
        <button
          type="button"
          className={`btn${tab === 'manifest' ? ' primary' : ''}`}
          onClick={() => setTab('manifest')}
        >
          manifest JSON
        </button>
      </div>

      {parseError ? <p style={{ color: 'crimson' }}>{parseError}</p> : null}
      {message ? <p className="muted">{message}</p> : null}

      {tab === 'editor' && manifest ? (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'minmax(260px, 1fr) minmax(200px, 240px) minmax(200px, 280px)',
            gap: 16,
            alignItems: 'start',
          }}
        >
          <AdminPanel title="单品生产">
            <SlotItemProductionPanel
              manifest={manifest}
              slot={activeSlot}
              itemId={activeId}
              assetStore={assetStore}
              onManifestChange={handleManifestChange}
              onSelectItem={setSlotId}
              onError={(msg) => {
                setParseError(msg)
                setMessage('')
              }}
              onAssetUploaded={bumpAssets}
            />
          </AdminPanel>

          <AdminPanel title="实时合成（App 同款叠层）">
            <div style={{ display: 'flex', justifyContent: 'center', padding: 8 }}>
              <AvatarPreviewCanvas
                manifest={manifest}
                outfit={outfit}
                packBaseUrl={MOE_AVATAR_PACK_BASE}
                assetStore={assetStore}
                assetRevision={assetRevision}
              />
            </div>
            <p className="muted" style={{ fontSize: 12, margin: 0 }}>
              {manifest.displayName} · cell {manifest.cellSize}px
            </p>
          </AdminPanel>

          <AdminPanel title="槽位 · 试穿选型">
            <div style={{ display: 'flex', gap: 4, marginBottom: 12, flexWrap: 'wrap' }}>
              {SLOTS.map((s) => (
                <button
                  key={s.id}
                  type="button"
                  className={`btn${activeSlot === s.id ? ' primary' : ''}`}
                  onClick={() => setActiveSlot(s.id)}
                >
                  {s.label}
                </button>
              ))}
            </div>
            <p className="muted" style={{ fontSize: 12 }}>
              当前：{activeId ? itemLabel(activeId, manifest, activeSlot) : '未穿'}
            </p>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(88px, 1fr))',
                gap: 8,
                maxHeight: 360,
                overflowY: 'auto',
              }}
            >
              {activeItems.map((id) => {
                const selected = id === activeId
                return (
                  <button
                    key={id || '__none'}
                    type="button"
                    className="btn"
                    onClick={() => setSlotId(id)}
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      gap: 4,
                      padding: 8,
                      border: selected ? '2px solid var(--accent, #e97891)' : '1px solid #ddd',
                      borderRadius: 12,
                      background: selected ? '#ffe4ec' : '#fff',
                    }}
                  >
                    <SlotItemThumb
                      manifest={manifest}
                      packBaseUrl={MOE_AVATAR_PACK_BASE}
                      slot={activeSlot}
                      itemId={id}
                      assetStore={assetStore}
                      assetRevision={assetRevision}
                    />
                    <span style={{ fontSize: 11, fontWeight: selected ? 700 : 500 }}>
                      {itemLabel(id, manifest, activeSlot)}
                    </span>
                  </button>
                )
              })}
            </div>
          </AdminPanel>
        </div>
      ) : null}

      {tab === 'manifest' ? (
        <AdminPanel title="manifest.json">
          <textarea
            rows={22}
            value={manifestText}
            onChange={(e) => setManifestText(e.target.value)}
            spellCheck={false}
            style={{ width: '100%', fontFamily: 'monospace', fontSize: 12 }}
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
            <button type="button" className="btn" onClick={() => void loadManifest()}>
              重新加载
            </button>
            <button type="button" className="btn primary" onClick={applyManifestText}>
              应用到编辑器
            </button>
          </div>
          <p className="muted" style={{ fontSize: 12, marginTop: 12 }}>
            生产流程：上传 PNG → 导出 zip →{' '}
            <code>assets/pet/moe_content/avatar/</code> → App 换衣/小家验证
          </p>
        </AdminPanel>
      ) : null}

      {!manifest && tab === 'editor' ? <p className="muted">加载 manifest…</p> : null}
    </ListPageLayout>
  )
}
