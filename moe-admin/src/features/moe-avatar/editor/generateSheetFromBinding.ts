import type { MoeAvatarManifest, PreviewAnimation } from '../types'
import { AVATAR_LAYER_TEMPLATE } from './layerTemplate'
import {
  DEFAULT_LAYER_BINDING,
  directionScaleX,
  directionScaleY,
  IDLE_FRAME_DY,
  type LayerBinding,
  WALK_FRAME_DY,
} from './layerBindingTypes'
import { paintRectPx } from './layerTemplate'

function anchorForLayer(layerKey: string): { x: number; y: number } {
  const tpl = AVATAR_LAYER_TEMPLATE.anchors
  if (layerKey === 'hat') return { x: tpl.headCenter.x, y: tpl.headCenter.y - 8 }
  if (layerKey === 'top') return { x: tpl.torsoCenter.x, y: tpl.torsoCenter.y }
  if (layerKey === 'bottom') return { x: tpl.torsoCenter.x, y: tpl.torsoCenter.y + 18 }
  if (layerKey === 'shoes') return { x: tpl.origin.x, y: tpl.origin.y - 6 }
  if (layerKey === 'body') return { x: tpl.torsoCenter.x, y: tpl.torsoCenter.y }
  if (layerKey === 'head' || layerKey === 'face')
    return { x: tpl.headCenter.x, y: tpl.headCenter.y }
  if (layerKey === 'hair') return { x: tpl.headCenter.x, y: tpl.headCenter.y - 4 }
  return { x: tpl.torsoCenter.x, y: tpl.torsoCenter.y }
}

/** 单图初始缩放：fit 到该层 paintRect 宽度 */
export function initialFitScale(
  imgW: number,
  _imgH: number,
  layerKey: string,
  cellSize: number,
): number {
  const rule = AVATAR_LAYER_TEMPLATE.layerRules[layerKey]
  if (!rule) return 1
  const { w } = paintRectPx(rule.paintRect, cellSize)
  return w / Math.max(imgW, 1)
}

function frameDy(anim: PreviewAnimation, col: number): number {
  const arr = anim === 'walk' ? WALK_FRAME_DY : IDLE_FRAME_DY
  return arr[col % arr.length] ?? 0
}

/** 在单格内绘制绑定后的部件（透明底） */
export function drawBoundPartInCell(
  ctx: CanvasRenderingContext2D,
  img: CanvasImageSource,
  imgW: number,
  imgH: number,
  binding: LayerBinding,
  layerKey: string,
  cellSize: number,
  directionRow: number,
  anim: PreviewAnimation,
  frameCol: number,
): void {
  const anchor = anchorForLayer(layerKey)
  const fit = initialFitScale(imgW, imgH, layerKey, cellSize) * binding.scale
  const dx = binding.offsetX
  const dy = binding.offsetY + frameDy(anim, frameCol)
  const cx = anchor.x + dx
  const cy = anchor.y + dy
  const sx = fit * directionScaleX(directionRow)
  const sy = fit * directionScaleY(directionRow)

  ctx.save()
  ctx.translate(cx, cy)
  ctx.rotate((binding.rotation * Math.PI) / 180)
  ctx.scale(sx, sy)
  ctx.imageSmoothingEnabled = true
  ctx.drawImage(img, -imgW / 2, -imgH / 2, imgW, imgH)
  ctx.restore()
}

/** 从单图 + 绑定生成整张 walk/idle sheet */
export function generateLayerSheetCanvas(
  img: CanvasImageSource,
  imgW: number,
  imgH: number,
  manifest: MoeAvatarManifest,
  layerKey: string,
  anim: PreviewAnimation,
  binding: LayerBinding = DEFAULT_LAYER_BINDING,
): HTMLCanvasElement {
  const grid = manifest.animations[anim]
  const cell = manifest.cellSize
  const canvas = document.createElement('canvas')
  canvas.width = grid.cols * cell
  canvas.height = grid.rows * cell
  const ctx = canvas.getContext('2d')
  if (!ctx) return canvas

  for (let row = 0; row < grid.rows; row++) {
    for (let col = 0; col < grid.cols; col++) {
      ctx.save()
      ctx.beginPath()
      ctx.rect(col * cell, row * cell, cell, cell)
      ctx.clip()
      ctx.translate(col * cell, row * cell)
      drawBoundPartInCell(ctx, img, imgW, imgH, binding, layerKey, cell, row, anim, col)
      ctx.restore()
    }
  }
  return canvas
}

export async function canvasToPngBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png')
  })
}

export async function loadImageFromFile(file: File): Promise<HTMLImageElement> {
  const url = URL.createObjectURL(file)
  try {
    const img = new Image()
    await new Promise<void>((res, rej) => {
      img.onload = () => res()
      img.onerror = () => rej(new Error('load'))
      img.src = url
    })
    return img
  } finally {
    URL.revokeObjectURL(url)
  }
}
