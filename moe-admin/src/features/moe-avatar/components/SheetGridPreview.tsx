import { useEffect, useRef, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import { assetUrlCandidates } from '../composer/resolveLayers'
import type { PaintRect } from '../editor/layerTemplate'
import type { MoeAvatarManifest } from '../types'
import { loadImageFromUrls } from '../../../../../moe-avatar/core/src/loadImage'
import { MOE_AVATAR_LEGACY_PACK_BASE } from '../../moe-content/constants'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  relPath: string
  assetStore?: AvatarAssetStore
  assetRevision?: number
  /** 每格内允许绘制区（相对 cell 0~1） */
  paintRect?: PaintRect
  maxWidth?: number
}

/**
 * 整 sheet 格线预览（与 top_hoodie 展开一致）
 * · 9×4 / 2×4 每格边框
 * · 可选 paintRect 绿色 overlay
 */
export function SheetGridPreview({
  manifest,
  packBaseUrl,
  relPath,
  assetStore,
  assetRevision = 0,
  paintRect,
  maxWidth = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setError(false)

    async function draw() {
      const img = await loadImageFromUrls(
        assetUrlCandidates(packBaseUrl, relPath, assetStore?.objectUrl(relPath), [MOE_AVATAR_LEGACY_PACK_BASE]),
      )
      if (cancelled) return
      const canvas = canvasRef.current
      if (!canvas) return

      const scale = Math.min(maxWidth / img.naturalWidth, 1)
      const w = Math.max(1, Math.floor(img.naturalWidth * scale))
      const h = Math.max(1, Math.floor(img.naturalHeight * scale))
      canvas.width = w
      canvas.height = h
      const ctx = canvas.getContext('2d')
      if (!ctx) return

      ctx.clearRect(0, 0, w, h)
      ctx.imageSmoothingEnabled = scale < 1
      ctx.drawImage(img, 0, 0, w, h)

      const cell = manifest.cellSize * scale
      const cols = Math.round(img.naturalWidth / manifest.cellSize)
      const rows = Math.round(img.naturalHeight / manifest.cellSize)

      if (paintRect) {
        ctx.fillStyle = 'rgba(80, 200, 120, 0.12)'
        ctx.strokeStyle = 'rgba(40, 160, 80, 0.7)'
        ctx.lineWidth = 1
        for (let row = 0; row < rows; row++) {
          for (let col = 0; col < cols; col++) {
            const cx = col * cell
            const cy = row * cell
            const rx = cx + paintRect.x0 * cell
            const ry = cy + paintRect.y0 * cell
            const rw = (paintRect.x1 - paintRect.x0) * cell
            const rh = (paintRect.y1 - paintRect.y0) * cell
            ctx.fillRect(rx, ry, rw, rh)
            ctx.strokeRect(rx + 0.5, ry + 0.5, rw - 1, rh - 1)
          }
        }
      }

      ctx.strokeStyle = 'rgba(233, 120, 145, 0.85)'
      ctx.lineWidth = 1
      for (let col = 0; col <= cols; col++) {
        ctx.beginPath()
        ctx.moveTo(col * cell + 0.5, 0)
        ctx.lineTo(col * cell + 0.5, h)
        ctx.stroke()
      }
      for (let row = 0; row <= rows; row++) {
        ctx.beginPath()
        ctx.moveTo(0, row * cell + 0.5)
        ctx.lineTo(w, row * cell + 0.5)
        ctx.stroke()
      }

      ctx.strokeStyle = '#e97891'
      ctx.lineWidth = 2
      ctx.strokeRect(1, 1, w - 2, h - 2)
    }

    void draw().catch(() => {
      if (!cancelled) setError(true)
    })
    return () => {
      cancelled = true
    }
  }, [manifest, packBaseUrl, relPath, assetStore, assetRevision, paintRect, maxWidth])

  if (error) {
    return <span className="muted" style={{ fontSize: 10 }}>格线预览加载失败</span>
  }

  return (
    <canvas
      ref={canvasRef}
      style={{
        maxWidth,
        width: '100%',
        imageRendering: 'pixelated',
        border: '1px solid #e97891',
        borderRadius: 6,
        background: '#fff',
        display: 'block',
      }}
    />
  )
}
