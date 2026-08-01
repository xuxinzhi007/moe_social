import { useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, PreviewAnimation } from '../types'
import { downloadGridTemplate } from '../editor/gridTemplate'
import { useSheetUpload } from '../editor/useSheetUpload'
import { LayerAssetRow } from './LayerAssetRow'

type BaseKey = 'body' | 'head' | 'face' | 'hair'

const BASE_KEYS: { key: BaseKey; label: string }[] = [
  { key: 'body', label: '身体 body' },
  { key: 'head', label: '头部 head' },
  { key: 'face', label: '脸部 face' },
  { key: 'hair', label: '头发 hair' },
]

type Props = {
  manifest: MoeAvatarManifest
  assetStore: AvatarAssetStore
  assetRevision?: number
  packBaseUrl: string
  onManifestChange: (next: MoeAvatarManifest) => void
  onAssetUploaded: () => void
  onError: (msg: string) => void
  onMessage?: (msg: string) => void
}

/** 素体 base 层生产 */
export function BaseLayerProductionPanel({
  manifest,
  assetStore,
  assetRevision = 0,
  packBaseUrl,
  onManifestChange,
  onAssetUploaded,
  onError,
  onMessage,
}: Props) {
  const [activeKey, setActiveKey] = useState<BaseKey>('body')
  const { uploadSheet, revertLayer, bindModal, pendingEditor } = useSheetUpload({
    manifest,
    packBaseUrl,
    assetStore,
    onAssetUploaded: () => {
      onManifestChange({ ...manifest })
      onAssetUploaded()
    },
    onMessage,
  })

  const handleUpload = (baseKey: BaseKey, anim: PreviewAnimation, file: File | null) => {
    const entry = manifest.base[baseKey]
    if (!entry) {
      onError(`manifest.base 缺少 ${baseKey}`)
      return
    }
    void uploadSheet(entry[anim], anim, file, baseKey, entry.idle)
  }

  return (
    <>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
          <p className="muted" style={{ fontSize: 11, margin: 0, maxWidth: 640 }}>
            素体四层 · 先选一个部位再导入。下载按钮输出的是完整模板 sheet，不是单个显示框。
          </p>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <button type="button" className="btn" style={{ fontSize: 10 }} onClick={() => void downloadGridTemplate(manifest, 'walk', undefined, packBaseUrl, assetStore)}>
              walk 完整模板
            </button>
            <button type="button" className="btn" style={{ fontSize: 10 }} onClick={() => void downloadGridTemplate(manifest, 'idle', undefined, packBaseUrl, assetStore)}>
              idle 完整模板
            </button>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {BASE_KEYS.map(({ key, label }) => (
            <button key={key} type="button" className={`btn${activeKey === key ? ' primary' : ''}`} onClick={() => setActiveKey(key)}>
              {label}
            </button>
          ))}
        </div>

        {(() => {
          const entry = manifest.base[activeKey]
          const label = BASE_KEYS.find((item) => item.key === activeKey)?.label ?? activeKey
          if (!entry) return null
          return (
            <div style={{ border: '1px solid #eee', borderRadius: 8, padding: 10 }}>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginBottom: 8,
                }}
              >
                <div style={{ fontWeight: 600, fontSize: 13 }}>{label}</div>
                <span className="muted" style={{ fontSize: 11 }}>当前部位</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <LayerAssetRow
                  manifest={manifest}
                  packBaseUrl={packBaseUrl}
                  relPath={entry.walk}
                  anim="walk"
                  layerKey={activeKey}
                  assetStore={assetStore}
                  assetRevision={assetRevision}
                  onFile={(f) => handleUpload(activeKey, 'walk', f)}
                  onRevert={() => revertLayer(entry.walk)}
                />
                <LayerAssetRow
                  manifest={manifest}
                  packBaseUrl={packBaseUrl}
                  relPath={entry.idle}
                  anim="idle"
                  layerKey={activeKey}
                  assetStore={assetStore}
                  assetRevision={assetRevision}
                  onFile={(f) => handleUpload(activeKey, 'idle', f)}
                  onRevert={() => revertLayer(entry.idle)}
                />
              </div>
            </div>
          )
        })()}

        <details style={{ border: '1px solid #f0e5da', borderRadius: 8, padding: 10 }}>
          <summary style={{ cursor: 'pointer', fontWeight: 600, color: '#5a4638' }}>全部部位</summary>
          <div style={{ display: 'grid', gap: 8, marginTop: 10 }}>
            {BASE_KEYS.map(({ key, label }) => {
              const entry = manifest.base[key]
              if (!entry) return null
              return (
                <button
                  key={key}
                  type="button"
                  className="btn"
                  style={{ textAlign: 'left', fontSize: 11, padding: '8px 10px' }}
                  onClick={() => setActiveKey(key)}
                >
                  {label} · {entry.walk}
                </button>
              )
            })}
          </div>
        </details>
        {pendingEditor}
      </div>
      {bindModal}
    </>
  )
}
