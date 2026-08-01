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
        <p className="muted" style={{ fontSize: 11, margin: 0 }}>
          素体四层 · 单图上传将打开绑定弹窗 · 正式包须替换 LPC 底模
        </p>
        {BASE_KEYS.map(({ key, label }) => {
          const entry = manifest.base[key]
          if (!entry) return null
          return (
            <div key={key} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10 }}>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginBottom: 8,
                }}
              >
                <div style={{ fontWeight: 600, fontSize: 13 }}>{label}</div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button
                    type="button"
                    className="btn"
                    style={{ fontSize: 10 }}
                    onClick={() => void downloadGridTemplate(manifest, 'walk', key)}
                  >
                    walk 模板
                  </button>
                  <button
                    type="button"
                    className="btn"
                    style={{ fontSize: 10 }}
                    onClick={() => void downloadGridTemplate(manifest, 'idle', key)}
                  >
                    idle 模板
                  </button>
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <LayerAssetRow
                  manifest={manifest}
                  packBaseUrl={packBaseUrl}
                  relPath={entry.walk}
                  anim="walk"
                  layerKey={key}
                  assetStore={assetStore}
                  assetRevision={assetRevision}
                  onFile={(f) => handleUpload(key, 'walk', f)}
                  onRevert={() => revertLayer(entry.walk)}
                />
                <LayerAssetRow
                  manifest={manifest}
                  packBaseUrl={packBaseUrl}
                  relPath={entry.idle}
                  anim="idle"
                  layerKey={key}
                  assetStore={assetStore}
                  assetRevision={assetRevision}
                  onFile={(f) => handleUpload(key, 'idle', f)}
                  onRevert={() => revertLayer(entry.idle)}
                />
              </div>
            </div>
          )
        })}
        {pendingEditor}
      </div>
      {bindModal}
    </>
  )
}
