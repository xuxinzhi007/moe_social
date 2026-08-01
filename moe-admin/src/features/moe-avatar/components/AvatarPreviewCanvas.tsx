import { useEffect, useRef, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, OutfitSelection } from '../types'
import { DIR_DOWN } from '../types'
import { composeSheet, drawSheetFrame } from '../composer/composeSheet'

type Props = {
  manifest: MoeAvatarManifest
  outfit: OutfitSelection
  packBaseUrl: string
  assetStore?: AvatarAssetStore
  /** 上传 PNG 后递增，触发重绘 */
  assetRevision?: number
  size?: number
}

/** Canvas 实时合成（生产时含上传层） */
export function AvatarPreviewCanvas({
  manifest,
  outfit,
  packBaseUrl,
  assetStore,
  assetRevision = 0,
  size = 240,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [frame, setFrame] = useState(0)
  const [idleSheet, setIdleSheet] = useState<HTMLCanvasElement | null>(null)

  useEffect(() => {
    let cancelled = false
    void composeSheet(manifest, outfit, 'idle', packBaseUrl, assetStore).then((sheet) => {
      if (!cancelled) setIdleSheet(sheet)
    })
    return () => {
      cancelled = true
    }
  }, [manifest, outfit, packBaseUrl, assetStore, assetRevision])

  useEffect(() => {
    const t = window.setInterval(() => {
      setFrame((f) => (f + 1) % manifest.animations.idle.cols)
    }, 450)
    return () => window.clearInterval(t)
  }, [manifest.animations.idle.cols])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !idleSheet) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    drawSheetFrame(ctx, idleSheet, manifest, 'idle', DIR_DOWN, frame, 0, 0, size)
  }, [frame, idleSheet, manifest, size])

  return (
    <canvas
      ref={canvasRef}
      width={size}
      height={size}
      style={{
        width: size,
        height: size,
        imageRendering: 'pixelated',
        background: 'linear-gradient(180deg, #fff8f2, #ffe8dc)',
        borderRadius: 16,
      }}
    />
  )
}
