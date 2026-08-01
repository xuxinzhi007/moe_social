import { useCallback, useEffect, useRef, useState } from 'react'
import type { ViewportTransform } from '../editor/slotBindViewport'

const VIEW_SCALE = 5
const HANDLE_PX = 14

type HandleKind =
  | 'move'
  | 'rotate'
  | 'scale-nw'
  | 'scale-ne'
  | 'scale-se'
  | 'scale-sw'
  | 'scale-n'
  | 'scale-s'
  | 'scale-e'
  | 'scale-w'

type DragState = {
  kind: HandleKind
  pointerId: number
  anchorWorld: { x: number; y: number }
  startPointer: { x: number; y: number }
  startTransform: ViewportTransform
  startAngle: number
}

type Props = {
  slotW: number
  slotH: number
  baseCanvas: HTMLCanvasElement | null
  partImg: HTMLImageElement | null
  transform: ViewportTransform
  onTransformChange: (next: ViewportTransform) => void
}

function clampScale(s: number) {
  return Math.max(0.02, Math.min(8, s))
}

function resizeFromAnchor(
  anchor: { x: number; y: number },
  drag: { x: number; y: number },
  imgW: number,
  imgH: number,
  rotation: number,
): ViewportTransform {
  const centerX = (anchor.x + drag.x) / 2
  const centerY = (anchor.y + drag.y) / 2
  const dx = drag.x - centerX
  const dy = drag.y - centerY
  const rad = (-rotation * Math.PI) / 180
  const lx = Math.abs(dx * Math.cos(rad) - dy * Math.sin(rad))
  const ly = Math.abs(dx * Math.sin(rad) + dy * Math.cos(rad))
  const scaleW = (2 * lx) / Math.max(imgW, 1)
  const scaleH = (2 * ly) / Math.max(imgH, 1)
  return {
    centerX,
    centerY,
    uniformScale: clampScale(Math.min(scaleW, scaleH)),
    rotation,
  }
}

function resizeFromEdge(
  st: ViewportTransform,
  kind: 'scale-n' | 'scale-s' | 'scale-e' | 'scale-w',
  pointer: { x: number; y: number },
  imgW: number,
  imgH: number,
): ViewportTransform {
  const rad = (st.rotation * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  const hw = (imgW * st.uniformScale) / 2
  const hh = (imgH * st.uniformScale) / 2

  const localPointer = {
    x: (pointer.x - st.centerX) * cos + (pointer.y - st.centerY) * sin,
    y: -(pointer.x - st.centerX) * sin + (pointer.y - st.centerY) * cos,
  }

  let newHw = hw
  let newHh = hh
  let shiftLocalX = 0
  let shiftLocalY = 0

  if (kind === 'scale-e' || kind === 'scale-w') {
    const sign = kind === 'scale-e' ? 1 : -1
    newHw = Math.max(4, Math.abs(localPointer.x))
    shiftLocalX = sign * (newHw - hw) * 0.5
  } else {
    const sign = kind === 'scale-s' ? 1 : -1
    newHh = Math.max(4, Math.abs(localPointer.y))
    shiftLocalY = sign * (newHh - hh) * 0.5
  }

  const scaleW = (2 * newHw) / Math.max(imgW, 1)
  const scaleH = (2 * newHh) / Math.max(imgH, 1)
  const uniformScale = clampScale(
    kind === 'scale-e' || kind === 'scale-w' ? scaleW : scaleH,
  )

  return {
    centerX: st.centerX + (shiftLocalX * cos - shiftLocalY * sin),
    centerY: st.centerY + (shiftLocalX * sin + shiftLocalY * cos),
    uniformScale,
    rotation: st.rotation,
  }
}

function worldCorners(
  t: ViewportTransform,
  imgW: number,
  imgH: number,
): { x: number; y: number }[] {
  const hw = (imgW * t.uniformScale) / 2
  const hh = (imgH * t.uniformScale) / 2
  const rad = (t.rotation * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  return [
    { x: -hw, y: -hh },
    { x: hw, y: -hh },
    { x: hw, y: hh },
    { x: -hw, y: hh },
  ].map((c) => ({
    x: t.centerX + c.x * cos - c.y * sin,
    y: t.centerY + c.x * sin + c.y * cos,
  }))
}

const CORNER_ANCHOR: Record<string, number> = {
  'scale-nw': 2,
  'scale-ne': 3,
  'scale-se': 0,
  'scale-sw': 1,
}

/** 槽位视口 · 截图式框选变换 */
export function ImageTransformCanvas({
  slotW,
  slotH,
  baseCanvas,
  partImg,
  transform,
  onTransformChange,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [drag, setDrag] = useState<DragState | null>(null)
  const transformRef = useRef(transform)
  transformRef.current = transform

  const displayW = slotW * VIEW_SCALE
  const displayH = slotH * VIEW_SCALE

  const screenToSlot = useCallback(
    (clientX: number, clientY: number) => {
      const el = containerRef.current
      if (!el) return { x: 0, y: 0 }
      const rect = el.getBoundingClientRect()
      return {
        x: ((clientX - rect.left) / rect.width) * slotW,
        y: ((clientY - rect.top) / rect.height) * slotH,
      }
    },
    [slotW, slotH],
  )

  const redraw = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    const t = transformRef.current
    ctx.clearRect(0, 0, displayW, displayH)
    ctx.save()
    ctx.scale(VIEW_SCALE, VIEW_SCALE)

    if (baseCanvas) {
      ctx.imageSmoothingEnabled = false
      ctx.drawImage(baseCanvas, 0, 0, slotW, slotH)
    } else {
      ctx.fillStyle = '#fff5ef'
      ctx.fillRect(0, 0, slotW, slotH)
    }

    ctx.strokeStyle = 'rgba(233, 120, 145, 0.85)'
    ctx.lineWidth = 1.5 / VIEW_SCALE
    ctx.setLineDash([3 / VIEW_SCALE, 2 / VIEW_SCALE])
    ctx.strokeRect(0.5, 0.5, slotW - 1, slotH - 1)
    ctx.setLineDash([])

    if (partImg) {
      ctx.save()
      ctx.translate(t.centerX, t.centerY)
      ctx.rotate((t.rotation * Math.PI) / 180)
      ctx.scale(t.uniformScale, t.uniformScale)
      ctx.imageSmoothingEnabled = true
      ctx.drawImage(
        partImg,
        -partImg.naturalWidth / 2,
        -partImg.naturalHeight / 2,
        partImg.naturalWidth,
        partImg.naturalHeight,
      )
      ctx.restore()
    }
    ctx.restore()
  }, [baseCanvas, partImg, slotW, slotH, displayW, displayH])

  useEffect(() => {
    redraw()
  }, [redraw, transform])

  const startDrag = (kind: HandleKind) => (e: React.PointerEvent) => {
    if (!partImg) return
    e.preventDefault()
    e.stopPropagation()
    const st = { ...transformRef.current }
    const p = screenToSlot(e.clientX, e.clientY)
    const corners = worldCorners(st, partImg.naturalWidth, partImg.naturalHeight)
    const anchorWorld =
      kind in CORNER_ANCHOR ? corners[CORNER_ANCHOR[kind]] : p
    setDrag({
      kind,
      pointerId: e.pointerId,
      anchorWorld,
      startPointer: p,
      startTransform: st,
      startAngle: Math.atan2(p.y - st.centerY, p.x - st.centerX),
    })
  }

  useEffect(() => {
    if (!drag || !partImg) return

    const onMove = (e: PointerEvent) => {
      if (e.pointerId !== drag.pointerId) return
      e.preventDefault()
      const p = screenToSlot(e.clientX, e.clientY)
      const st = drag.startTransform
      const imgW = partImg.naturalWidth
      const imgH = partImg.naturalHeight

      if (drag.kind === 'move') {
        onTransformChange({
          ...st,
          centerX: st.centerX + (p.x - drag.startPointer.x),
          centerY: st.centerY + (p.y - drag.startPointer.y),
        })
        return
      }

      if (drag.kind === 'rotate') {
        const angle = Math.atan2(p.y - st.centerY, p.x - st.centerX)
        const delta = ((angle - drag.startAngle) * 180) / Math.PI
        onTransformChange({ ...st, rotation: st.rotation + delta })
        return
      }

      if (drag.kind in CORNER_ANCHOR) {
        onTransformChange(resizeFromAnchor(drag.anchorWorld, p, imgW, imgH, st.rotation))
        return
      }

      if (
        drag.kind === 'scale-n' ||
        drag.kind === 'scale-s' ||
        drag.kind === 'scale-e' ||
        drag.kind === 'scale-w'
      ) {
        onTransformChange(resizeFromEdge(st, drag.kind, p, imgW, imgH))
      }
    }

    const onUp = (e: PointerEvent) => {
      if (e.pointerId !== drag.pointerId) return
      setDrag(null)
    }

    window.addEventListener('pointermove', onMove, { passive: false })
    window.addEventListener('pointerup', onUp)
    window.addEventListener('pointercancel', onUp)
    return () => {
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', onUp)
      window.removeEventListener('pointercancel', onUp)
    }
  }, [drag, partImg, onTransformChange, screenToSlot])

  const onWheel = (e: React.WheelEvent) => {
    if (!partImg) return
    e.preventDefault()
    const factor = e.deltaY > 0 ? 0.92 : 1.08
    const t = transformRef.current
    onTransformChange({
      ...t,
      uniformScale: clampScale(t.uniformScale * factor),
    })
  }

  const boxW = partImg ? partImg.naturalWidth * transform.uniformScale * VIEW_SCALE : 0
  const boxH = partImg ? partImg.naturalHeight * transform.uniformScale * VIEW_SCALE : 0

  const handleStyle = (cursor: string): React.CSSProperties => ({
    position: 'absolute',
    width: HANDLE_PX,
    height: HANDLE_PX,
    marginLeft: -HANDLE_PX / 2,
    marginTop: -HANDLE_PX / 2,
    background: '#fff',
    border: '2px solid #e97891',
    borderRadius: 2,
    cursor,
    touchAction: 'none',
    boxShadow: '0 1px 4px rgba(0,0,0,0.15)',
    zIndex: 2,
    pointerEvents: 'auto',
  })

  const handles: [HandleKind, string, string, string][] = [
    ['scale-nw', '0%', '0%', 'nwse-resize'],
    ['scale-ne', '100%', '0%', 'nesw-resize'],
    ['scale-se', '100%', '100%', 'nwse-resize'],
    ['scale-sw', '0%', '100%', 'nesw-resize'],
    ['scale-n', '50%', '0%', 'ns-resize'],
    ['scale-s', '50%', '100%', 'ns-resize'],
    ['scale-w', '0%', '50%', 'ew-resize'],
    ['scale-e', '100%', '50%', 'ew-resize'],
  ]

  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <div
        ref={containerRef}
        onWheel={onWheel}
        style={{
          position: 'relative',
          width: displayW,
          height: displayH,
          border: '2px solid #e97891',
          borderRadius: 10,
          overflow: 'visible',
          background: 'linear-gradient(180deg,#fff8f2,#ffe8dc)',
          touchAction: 'none',
          userSelect: 'none',
        }}
      >
        <canvas
          ref={canvasRef}
          width={displayW}
          height={displayH}
          style={{
            display: 'block',
            width: displayW,
            height: displayH,
            imageRendering: 'pixelated',
            pointerEvents: 'none',
          }}
        />

        {partImg ? (
          <div
            style={{
              position: 'absolute',
              left: transform.centerX * VIEW_SCALE,
              top: transform.centerY * VIEW_SCALE,
              width: boxW,
              height: boxH,
              transform: `translate(-50%, -50%) rotate(${transform.rotation}deg)`,
              transformOrigin: 'center center',
              pointerEvents: 'none',
            }}
          >
            <div
              style={{
                position: 'absolute',
                inset: 0,
                border: '2px solid #e97891',
                boxShadow: '0 0 0 1px rgba(255,255,255,0.6)',
                pointerEvents: 'auto',
                cursor: drag?.kind === 'move' ? 'grabbing' : 'grab',
              }}
              onPointerDown={startDrag('move')}
            />

            {handles.map(([kind, left, top, cursor]) => (
              <div
                key={kind}
                style={{ ...handleStyle(cursor), left, top }}
                onPointerDown={startDrag(kind)}
              />
            ))}

            <div
              style={{
                position: 'absolute',
                left: '50%',
                top: -24,
                width: 2,
                height: 20,
                marginLeft: -1,
                background: '#8a7364',
                pointerEvents: 'none',
              }}
            />
            <div
              style={{
                ...handleStyle('grab'),
                left: '50%',
                top: -28,
                borderRadius: '50%',
                background: '#8a7364',
                borderColor: '#fff',
              }}
              onPointerDown={startDrag('rotate')}
            />
          </div>
        ) : null}
      </div>
      <p className="muted" style={{ fontSize: 10, margin: '6px 0 0' }}>
        框内拖动 · 角/边缩放（对角固定）· 上方圆点旋转 · 滚轮缩放
      </p>
    </div>
  )
}

export { VIEW_SCALE }
