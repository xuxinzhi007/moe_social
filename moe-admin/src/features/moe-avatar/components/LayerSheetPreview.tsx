import { useEffect, useRef, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import { layerThumbCanvas } from '../composer/composeSheet'
import { resolveAssetUrl } from '../composer/resolveLayers'
import type { MoeAvatarManifest } from '../types'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  relPath: string
  assetStore?: AvatarAssetStore
  assetRevision?: number
  /** 显示整张 sheet 或 idle·down 单帧 */
  mode?: 'sheet' | 'frame'
  maxWidth?: number
  maxHeight?: number
}

/** 单层 sheet 预览（上传/裁剪后立即可见） */
export function LayerSheetPreview({
  manifest,
  packBaseUrl,
  relPath,
  assetStore,
  assetRevision = 0,
  mode = 'sheet',
  maxWidth = 280,
  maxHeight = 100,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setError(false)

    async function draw() {
      const url = resolveAssetUrl(packBaseUrl, relPath, assetStore?.objectUrl(relPath))
      if (mode === 'frame') {
        const thumb = await layerThumbCanvas(
          manifest,
          relPath,
          packBaseUrl,
          64,
          assetStore,
        )
        if (cancelled || !thumb) {
          if (!cancelled) setError(true)
          return
        }
        const canvas = canvasRef.current
        if (!canvas) return
        const scale = Math.min(maxWidth / thumb.width, maxHeight / thumb.height, 1)
        canvas.width = thumb.width * scale
        canvas.height = thumb.height * scale
        const ctx = canvas.getContext('2d')
        if (!ctx) return
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        ctx.imageSmoothingEnabled = false
        ctx.drawImage(thumb, 0, 0, canvas.width, canvas.height)
        return
      }

      const img = new Image()
      img.crossOrigin = 'anonymous'
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = () => reject(new Error('load failed'))
        img.src = url
      })
      if (cancelled) return
      const canvas = canvasRef.current
      if (!canvas) return
      const scale = Math.min(maxWidth / img.naturalWidth, maxHeight / img.naturalHeight, 1)
      canvas.width = Math.max(1, Math.floor(img.naturalWidth * scale))
      canvas.height = Math.max(1, Math.floor(img.naturalHeight * scale))
      const ctx = canvas.getContext('2d')
      if (!ctx) return
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      ctx.imageSmoothingEnabled = scale < 1
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
    }

    void draw().catch(() => {
      if (!cancelled) setError(true)
    })
    return () => {
      cancelled = true
    }
  }, [manifest, packBaseUrl, relPath, assetStore, assetRevision, mode, maxWidth, maxHeight])

  if (error) {
    return (
      <span className="muted" style={{ fontSize: 10, display: 'inline-block', padding: 8 }}>
        无预览
      </span>
    )
  }

  return (
    <canvas
      ref={canvasRef}
      style={{
        width: maxWidth,
        height: maxHeight,
        imageRendering: 'pixelated',
        border: '1px solid #e97891',
        borderRadius: 6,
        background: 'linear-gradient(180deg,#fff8f2,#ffe8dc)',
        display: 'block',
      }}
    />
  )
}
