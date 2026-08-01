import { useEffect, useRef, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, OutfitSelection, PreviewAnimation } from '../types'
import { DIR_DOWN } from '../types'
import { composeSheet, drawSheetFrame } from '../composer/composeSheet'
import { resolveLayerPaths } from '../composer/resolveLayers'

type Props = {
  manifest: MoeAvatarManifest
  outfit: OutfitSelection
  packBaseUrl: string
  assetStore?: AvatarAssetStore
  assetRevision?: number
  size?: number
}

/** Canvas 实时合成 · 可切换 walk/idle */
export function AvatarPreviewCanvas({
  manifest,
  outfit,
  packBaseUrl,
  assetStore,
  assetRevision = 0,
  size = 240,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [anim, setAnim] = useState<PreviewAnimation>('idle')
  const [frame, setFrame] = useState(0)
  const [sheet, setSheet] = useState<HTMLCanvasElement | null>(null)

  const overrideCount = resolveLayerPaths(manifest, outfit, anim).filter((p) =>
    assetStore?.has(p),
  ).length

  useEffect(() => {
    let cancelled = false
    void composeSheet(manifest, outfit, anim, packBaseUrl, assetStore).then((s) => {
      if (!cancelled) setSheet(s)
    })
    return () => {
      cancelled = true
    }
  }, [manifest, outfit, anim, packBaseUrl, assetStore, assetRevision])

  useEffect(() => {
    setFrame(0)
  }, [anim, outfit, assetRevision])

  useEffect(() => {
    const cols = manifest.animations[anim].cols
    const ms = anim === 'walk' ? 120 : 450
    const t = window.setInterval(() => {
      setFrame((f) => (f + 1) % cols)
    }, ms)
    return () => window.clearInterval(t)
  }, [manifest, anim])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !sheet) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    drawSheetFrame(ctx, sheet, manifest, anim, DIR_DOWN, frame, 0, 0, size)
  }, [frame, sheet, manifest, anim, size])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
      <div style={{ display: 'flex', gap: 4 }}>
        {(['idle', 'walk'] as const).map((a) => (
          <button
            key={a}
            type="button"
            className={`btn${anim === a ? ' primary' : ''}`}
            style={{ fontSize: 11, padding: '4px 10px' }}
            onClick={() => setAnim(a)}
          >
            {a}
          </button>
        ))}
      </div>
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
          border: overrideCount > 0 ? '2px solid #e97891' : 'none',
        }}
      />
      {overrideCount > 0 ? (
        <p style={{ margin: 0, fontSize: 10, color: '#c45' }}>
          {overrideCount} 层为会话覆盖 · 切换 {anim} 查看效果
        </p>
      ) : null}
    </div>
  )
}
