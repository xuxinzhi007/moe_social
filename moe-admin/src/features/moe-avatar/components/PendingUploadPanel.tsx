import { useEffect, useState } from 'react'
import type { MoeAvatarManifest, PreviewAnimation } from '../types'

type Props = {
  file: File
  relPath: string
  anim: PreviewAnimation
  manifest: MoeAvatarManifest
  onConfirm: () => void
  onCancel: () => void
}

async function frameFromFile(
  file: File,
  manifest: MoeAvatarManifest,
  thumb = 72,
): Promise<string | null> {
  const bitmap = await createImageBitmap(file)
  const cell = manifest.cellSize
  const row = 2
  const col = 0
  const canvas = document.createElement('canvas')
  canvas.width = thumb
  canvas.height = thumb
  const ctx = canvas.getContext('2d')
  if (!ctx) {
    bitmap.close()
    return null
  }
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(bitmap, col * cell, row * cell, cell, cell, 0, 0, thumb, thumb)
  bitmap.close()
  return canvas.toDataURL()
}

async function sheetFromFile(
  file: File,
  maxW: number,
  maxH: number,
): Promise<string | null> {
  const bitmap = await createImageBitmap(file)
  const scale = Math.min(maxW / bitmap.width, maxH / bitmap.height, 1)
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.floor(bitmap.width * scale))
  canvas.height = Math.max(1, Math.floor(bitmap.height * scale))
  const ctx = canvas.getContext('2d')
  if (!ctx) {
    bitmap.close()
    return null
  }
  ctx.imageSmoothingEnabled = scale < 1
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  bitmap.close()
  return canvas.toDataURL()
}

/** 尺寸已匹配时的确认步：单帧 + 整图预览后再写入 */
export function PendingUploadPanel({
  file,
  relPath,
  anim,
  manifest,
  onConfirm,
  onCancel,
}: Props) {
  const [frameUrl, setFrameUrl] = useState<string | null>(null)
  const [sheetUrl, setSheetUrl] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      const [frame, sheet] = await Promise.all([
        frameFromFile(file, manifest),
        sheetFromFile(file, 240, 90),
      ])
      if (!cancelled) {
        setFrameUrl(frame)
        setSheetUrl(sheet)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [file, manifest, anim])

  return (
    <div
      style={{
        border: '2px solid #7eb8da',
        borderRadius: 12,
        padding: 12,
        background: '#f4faff',
        marginTop: 8,
      }}
    >
      <div style={{ fontWeight: 700, marginBottom: 6, color: '#3a6a8a' }}>
        确认上传 · {anim}
      </div>
      <p className="muted" style={{ fontSize: 11, margin: '0 0 8px' }}>
        尺寸已匹配格线。请确认<strong>单帧</strong>与<strong>整图</strong>是否为正确的分层 sheet（勿误选其它贴图）。
      </p>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-start' }}>
        {frameUrl ? (
          <div>
            <div style={{ fontSize: 10, marginBottom: 4, color: '#666' }}>朝向·下 单帧</div>
            <img
              src={frameUrl}
              alt="单帧"
              style={{
                width: 72,
                height: 72,
                imageRendering: 'pixelated',
                border: '1px solid #7eb8da',
                borderRadius: 8,
                background: '#fff',
              }}
            />
          </div>
        ) : null}
        {sheetUrl ? (
          <div>
            <div style={{ fontSize: 10, marginBottom: 4, color: '#666' }}>整张 sheet</div>
            <img
              src={sheetUrl}
              alt="整图"
              style={{
                maxWidth: 240,
                maxHeight: 90,
                imageRendering: 'pixelated',
                border: '1px solid #7eb8da',
                borderRadius: 8,
                background: '#fff',
                display: 'block',
              }}
            />
          </div>
        ) : null}
        <div style={{ fontSize: 11, minWidth: 120 }}>
          <div>
            文件：<strong>{file.name}</strong>
          </div>
          <code style={{ fontSize: 9, wordBreak: 'break-all' }}>{relPath}</code>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
        <button type="button" className="btn" onClick={onCancel}>
          取消
        </button>
        <button type="button" className="btn primary" onClick={onConfirm}>
          确认使用
        </button>
      </div>
    </div>
  )
}
