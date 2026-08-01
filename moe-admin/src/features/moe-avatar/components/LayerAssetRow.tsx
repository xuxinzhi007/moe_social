import { useCallback, useRef, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import { layerUploadStatus } from '../editor/useSheetUpload'
import { layerRuleForKey } from '../editor/layerTemplate'
import { sheetSpecLabel } from '../editor/sheetValidation'
import type { MoeAvatarManifest, PreviewAnimation } from '../types'
import { LayerSheetPreview } from './LayerSheetPreview'
import { SheetGridPreview } from './SheetGridPreview'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  relPath: string
  anim: PreviewAnimation
  /** 模板 layerRules 键：top/bottom/shoes/hat/body… */
  layerKey: string
  assetStore: AvatarAssetStore
  assetRevision: number
  onFile: (file: File | null) => void
  onRevert?: () => void
}

/** 单层资产行：单帧预览 + 拖拽上传 + 恢复官方 */
export function LayerAssetRow({
  manifest,
  packBaseUrl,
  relPath,
  anim,
  layerKey,
  assetStore,
  assetRevision,
  onFile,
  onRevert,
}: Props) {
  const [dragOver, setDragOver] = useState(false)
  const [showSheet, setShowSheet] = useState(true)
  const inputRef = useRef<HTMLInputElement>(null)
  const status = layerUploadStatus(relPath, assetStore)
  const isOverride = assetStore.has(relPath)
  const rule = layerRuleForKey(layerKey)

  const pickFile = useCallback(() => inputRef.current?.click(), [])

  const onDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      setDragOver(false)
      const f = e.dataTransfer.files?.[0]
      if (f) onFile(f)
    },
    [onFile],
  )

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault()
        setDragOver(true)
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={onDrop}
      style={{
        border: dragOver ? '2px dashed #e97891' : '1px solid #eee',
        borderRadius: 10,
        padding: 10,
        background: dragOver ? '#fff5f8' : '#fff',
        fontSize: 12,
      }}
    >
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
        <LayerSheetPreview
          manifest={manifest}
          packBaseUrl={packBaseUrl}
          relPath={relPath}
          assetStore={assetStore}
          assetRevision={assetRevision}
          mode="frame"
          maxWidth={72}
          maxHeight={72}
        />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 700, marginBottom: 2 }}>
            {anim} · {sheetSpecLabel(manifest, anim)}
          </div>
          <code style={{ fontSize: 9, wordBreak: 'break-all', display: 'block' }}>{relPath}</code>
          <p style={{ margin: '4px 0 8px', fontSize: 11, color: isOverride ? '#c45' : '#8a7364' }}>
            {status}
          </p>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <button type="button" className="btn primary" style={{ fontSize: 11 }} onClick={pickFile}>
              选择 / 替换
            </button>
            {isOverride && onRevert ? (
              <button type="button" className="btn" style={{ fontSize: 11 }} onClick={onRevert}>
                恢复官方
              </button>
            ) : null}
            <button
              type="button"
              className="btn"
              style={{ fontSize: 11 }}
              onClick={() => setShowSheet((v) => !v)}
            >
              {showSheet ? '收起 sheet' : '看整图'}
            </button>
          </div>
          <input
            ref={inputRef}
            type="file"
            accept="image/png,image/webp"
            style={{ display: 'none' }}
            onChange={(e) => {
              onFile(e.target.files?.[0] ?? null)
              e.target.value = ''
            }}
          />
        </div>
      </div>
      {showSheet ? (
        <div style={{ marginTop: 10, paddingTop: 8, borderTop: '1px dashed #eee' }}>
          <div style={{ fontSize: 10, color: '#5a8a5a', marginBottom: 4 }}>
            格线预览 · 绿框 = 该层允许绘制区（{rule?.hint ?? layerKey}）
          </div>
          <SheetGridPreview
            manifest={manifest}
            packBaseUrl={packBaseUrl}
            relPath={relPath}
            assetStore={assetStore}
            assetRevision={assetRevision}
            paintRect={rule?.paintRect}
            maxWidth={340}
          />
        </div>
      ) : null}
    </div>
  )
}
