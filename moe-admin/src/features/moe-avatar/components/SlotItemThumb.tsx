import { useEffect, useRef } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, WearSlot } from '../types'
import { layerThumbCanvas } from '../composer/composeSheet'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  slot: WearSlot
  itemId: string
  assetStore?: AvatarAssetStore
  assetRevision?: number
  size?: number
}

/** 列表缩略图：仅该部件 idle·down·帧0 */
export function SlotItemThumb({
  manifest,
  packBaseUrl,
  slot,
  itemId,
  assetStore,
  assetRevision = 0,
  size = 48,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const idlePath = manifest.slots[slot]?.[itemId]?.idle

  useEffect(() => {
    if (!idlePath) return
    let cancelled = false
    void layerThumbCanvas(manifest, idlePath, packBaseUrl, size, assetStore).then((thumb) => {
      if (cancelled || !thumb) return
      const canvas = canvasRef.current
      if (!canvas) return
      const ctx = canvas.getContext('2d')
      if (!ctx) return
      ctx.clearRect(0, 0, size, size)
      ctx.drawImage(thumb, 0, 0)
    })
    return () => {
      cancelled = true
    }
  }, [manifest, packBaseUrl, slot, itemId, idlePath, size, assetStore, assetRevision])

  if (!itemId) {
    return (
      <span style={{ fontSize: 11, color: '#b0a090' }} aria-hidden>
        ∅
      </span>
    )
  }
  if (!idlePath) {
    return <span style={{ fontSize: 10, color: '#999' }}>—</span>
  }

  return (
    <canvas
      ref={canvasRef}
      width={size}
      height={size}
      style={{ width: size, height: size, imageRendering: 'pixelated' }}
    />
  )
}
