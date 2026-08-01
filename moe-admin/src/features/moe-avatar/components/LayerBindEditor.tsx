import { useCallback, useEffect, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import { composeMannequinCell } from '../composer/composeMannequin'
import {
  canvasToPngBlob,
  generateLayerSheetCanvas,
  loadImageFromFile,
} from '../editor/generateSheetFromBinding'
import { DEFAULT_LAYER_BINDING, type LayerBinding } from '../editor/layerBindingTypes'
import { blobToImage, smartCutout } from '../editor/smartCutout'
import { layerRuleForKey } from '../editor/layerTemplate'
import {
  cropSlotBaseFromMannequin,
  initialViewportTransform,
  slotViewportRect,
  viewportToLayerBinding,
  type ViewportTransform,
} from '../editor/slotBindViewport'
import type { MoeAvatarManifest, PreviewAnimation } from '../types'
import { ImageTransformCanvas } from './ImageTransformCanvas'

export type LayerBindConfirmResult = {
  walkBlob?: Blob
  idleBlob?: Blob
  original: File
  binding: LayerBinding
}

type Props = {
  file: File
  layerKey: string
  walkPath: string
  idlePath?: string
  singleAnim?: PreviewAnimation
  manifest: MoeAvatarManifest
  packBaseUrl: string
  assetStore: AvatarAssetStore
  onConfirm: (result: LayerBindConfirmResult) => void
  onCancel: () => void
}

/** 单图绑定 · 仅显示该槽位范围框 + 官方底图裁切 + 画布手势变换 */
export function LayerBindEditor({
  file,
  layerKey,
  walkPath,
  idlePath,
  singleAnim,
  manifest,
  packBaseUrl,
  assetStore,
  onConfirm,
  onCancel,
}: Props) {
  const cell = manifest.cellSize
  const slot = slotViewportRect(layerKey, cell)
  const [sourceFile] = useState(file)
  const [slotBase, setSlotBase] = useState<HTMLCanvasElement | null>(null)
  const [partImg, setPartImg] = useState<HTMLImageElement | null>(null)
  const [viewport, setViewport] = useState<ViewportTransform | null>(null)
  const [previewWalk, setPreviewWalk] = useState<string | null>(null)
  const [previewIdle, setPreviewIdle] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [cutoutBusy, setCutoutBusy] = useState(false)

  const genWalk = !singleAnim || singleAnim === 'walk'
  const genIdle = !singleAnim || singleAnim === 'idle'
  const rule = layerRuleForKey(layerKey)

  const loadPart = useCallback(
    async (f: File) => {
      const img = await loadImageFromFile(f)
      setPartImg(img)
      setViewport(initialViewportTransform(img.naturalWidth, img.naturalHeight, layerKey, cell))
    },
    [layerKey, cell],
  )

  useEffect(() => {
    void composeMannequinCell(manifest, packBaseUrl, assetStore).then((mannequin) => {
      if (!mannequin) {
        setSlotBase(null)
        return
      }
      setSlotBase(cropSlotBaseFromMannequin(mannequin, layerKey, cell))
    })
  }, [manifest, packBaseUrl, assetStore, layerKey, cell])

  useEffect(() => {
    void loadPart(file)
  }, [file, loadPart])

  const binding = (): LayerBinding => {
    if (!partImg || !viewport) return { ...DEFAULT_LAYER_BINDING }
    return viewportToLayerBinding(
      viewport,
      layerKey,
      cell,
      partImg.naturalWidth,
      partImg.naturalHeight,
    )
  }

  const refreshPreviews = useCallback(async () => {
    if (!partImg || !viewport) return
    const b = viewportToLayerBinding(
      viewport,
      layerKey,
      cell,
      partImg.naturalWidth,
      partImg.naturalHeight,
    )
    if (genWalk) {
      const walkC = generateLayerSheetCanvas(
        partImg,
        partImg.naturalWidth,
        partImg.naturalHeight,
        manifest,
        layerKey,
        'walk',
        b,
      )
      const walkBlob = await canvasToPngBlob(walkC)
      setPreviewWalk((prev) => {
        if (prev) URL.revokeObjectURL(prev)
        return URL.createObjectURL(walkBlob)
      })
    }
    if (genIdle) {
      const idleC = generateLayerSheetCanvas(
        partImg,
        partImg.naturalWidth,
        partImg.naturalHeight,
        manifest,
        layerKey,
        'idle',
        b,
      )
      const idleBlob = await canvasToPngBlob(idleC)
      setPreviewIdle((prev) => {
        if (prev) URL.revokeObjectURL(prev)
        return URL.createObjectURL(idleBlob)
      })
    }
  }, [partImg, viewport, manifest, layerKey, cell, genWalk, genIdle])

  useEffect(() => {
    void refreshPreviews()
  }, [refreshPreviews])

  const handleSmartCutout = async () => {
    setCutoutBusy(true)
    try {
      const blob = await smartCutout(sourceFile)
      const img = await blobToImage(blob)
      setPartImg(img)
      setViewport(initialViewportTransform(img.naturalWidth, img.naturalHeight, layerKey, cell))
    } finally {
      setCutoutBusy(false)
    }
  }

  const handleSave = async () => {
    if (!partImg || !viewport) return
    setBusy(true)
    try {
      const b = binding()
      let walkBlob: Blob | undefined
      let idleBlob: Blob | undefined
      if (genWalk) {
        const walkC = generateLayerSheetCanvas(
          partImg,
          partImg.naturalWidth,
          partImg.naturalHeight,
          manifest,
          layerKey,
          'walk',
          b,
        )
        walkBlob = await canvasToPngBlob(walkC)
      }
      if (genIdle) {
        const idleC = generateLayerSheetCanvas(
          partImg,
          partImg.naturalWidth,
          partImg.naturalHeight,
          manifest,
          layerKey,
          'idle',
          b,
        )
        idleBlob = await canvasToPngBlob(idleC)
      }
      onConfirm({ walkBlob, idleBlob, original: sourceFile, binding: b })
    } finally {
      setBusy(false)
    }
  }

  const saveLabel = singleAnim
    ? `保存绑定并生成 ${singleAnim} sheet`
    : '保存绑定并生成 walk + idle'

  return (
    <div>
      <p className="muted" style={{ fontSize: 12, margin: '0 0 12px', lineHeight: 1.5 }}>
        编辑区 = <strong>{rule?.label ?? layerKey}</strong> 的范围框（{slot.w}×{slot.h}px）
        ，不是整身人物。虚线框内为允许绘制区域；<strong>官方底图</strong>（裁切自底模）固定作对齐参考，
        你的图片在框内自由调整，保存后只映射到该部位。文件：<code>{sourceFile.name}</code>
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 200px', gap: 16, marginBottom: 12 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, marginBottom: 6, color: '#8a7364' }}>
            {rule?.label} · 绑定区
          </div>
          {viewport ? (
            <ImageTransformCanvas
              slotW={slot.w}
              slotH={slot.h}
              baseCanvas={slotBase}
              partImg={partImg}
              transform={viewport}
              onTransformChange={setViewport}
            />
          ) : null}
          <p className="muted" style={{ fontSize: 10, margin: '4px 0 0' }}>
            {rule?.hint}
          </p>
        </div>

        <div style={{ fontSize: 12 }}>
          <button
            type="button"
            className="btn primary"
            style={{ width: '100%', marginBottom: 10 }}
            disabled={cutoutBusy}
            onClick={() => void handleSmartCutout()}
          >
            {cutoutBusy ? '抠图中…' : '智能抠图'}
          </button>
          <p className="muted" style={{ fontSize: 10, margin: '0 0 12px', lineHeight: 1.45 }}>
            去白/灰底并裁透明边（本地处理）
          </p>
          <div
            style={{
              padding: 10,
              background: '#faf6f2',
              borderRadius: 8,
              fontSize: 10,
              color: '#8a7364',
              lineHeight: 1.5,
            }}
          >
            <div>
              <strong>槽位</strong> {slot.w}×{slot.h}px
            </div>
            <div>
              <strong>旋转</strong> {viewport?.rotation.toFixed(0) ?? 0}°
            </div>
            <div>
              <strong>缩放</strong> {((viewport?.uniformScale ?? 0) * 100).toFixed(0)}%
            </div>
          </div>
        </div>
      </div>

      <div style={{ fontSize: 11, fontWeight: 700, marginBottom: 6, color: '#5a4638' }}>
        生成的格线关键帧预览（整 sheet · 仅该层）
      </div>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 14 }}>
        {genWalk ? (
          <div>
            <div className="muted" style={{ fontSize: 10, marginBottom: 4 }}>
              walk · {walkPath}
            </div>
            {previewWalk ? (
              <img
                src={previewWalk}
                alt="walk"
                style={{ maxWidth: 280, imageRendering: 'pixelated', border: '1px solid #ddd' }}
              />
            ) : null}
          </div>
        ) : null}
        {genIdle && idlePath ? (
          <div>
            <div className="muted" style={{ fontSize: 10, marginBottom: 4 }}>
              idle · {idlePath}
            </div>
            {previewIdle ? (
              <img
                src={previewIdle}
                alt="idle"
                style={{ maxWidth: 140, imageRendering: 'pixelated', border: '1px solid #ddd' }}
              />
            ) : null}
          </div>
        ) : null}
      </div>

      <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
        <button type="button" className="btn" onClick={onCancel} disabled={busy}>
          取消
        </button>
        <button
          type="button"
          className="btn primary"
          onClick={() => void handleSave()}
          disabled={busy || !partImg || !viewport}
        >
          {busy ? '生成中…' : saveLabel}
        </button>
      </div>
    </div>
  )
}
