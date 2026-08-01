import type { LayerBinding } from './layerBindingTypes'
import { initialFitScale } from './generateSheetFromBinding'
import { layerRuleForKey, paintRectPx } from './layerTemplate'
import { AVATAR_LAYER_TEMPLATE } from './layerTemplate'

/** 绑定编辑区 · 仅 slot paintRect 视口内坐标 */
export type ViewportTransform = {
  /** 部件中心 · 相对视口左上角 px */
  centerX: number
  centerY: number
  /** 视口内 uniform scale：1 源像素 → N 视口像素 */
  uniformScale: number
  rotation: number
}

export function slotViewportRect(layerKey: string, cellSize: number) {
  const rule = layerRuleForKey(layerKey)
  if (!rule) {
    return { x: 0, y: 0, w: cellSize, h: cellSize }
  }
  return paintRectPx(rule.paintRect, cellSize)
}

/** 从官方底模裁出该槽位参考区（固定底图） */
export function cropSlotBaseFromMannequin(
  mannequin: HTMLCanvasElement,
  layerKey: string,
  cellSize: number,
): HTMLCanvasElement {
  const { x, y, w, h } = slotViewportRect(layerKey, cellSize)
  const out = document.createElement('canvas')
  out.width = w
  out.height = h
  const ctx = out.getContext('2d')
  if (!ctx) return out
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(mannequin, x, y, w, h, 0, 0, w, h)
  return out
}

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

/** 视口变换 → 整格 sheet 用的 LayerBinding */
export function viewportToLayerBinding(
  vp: ViewportTransform,
  layerKey: string,
  cellSize: number,
  imgW: number,
  imgH: number,
): LayerBinding {
  const slot = slotViewportRect(layerKey, cellSize)
  const anchor = anchorForLayer(layerKey)
  const fit = initialFitScale(imgW, imgH, layerKey, cellSize)
  return {
    offsetX: slot.x + vp.centerX - anchor.x,
    offsetY: slot.y + vp.centerY - anchor.y,
    scale: fit > 0 ? vp.uniformScale / fit : 1,
    rotation: vp.rotation,
  }
}

export function layerBindingToViewport(
  binding: LayerBinding,
  layerKey: string,
  cellSize: number,
  imgW: number,
  imgH: number,
): ViewportTransform {
  const slot = slotViewportRect(layerKey, cellSize)
  const anchor = anchorForLayer(layerKey)
  const fit = initialFitScale(imgW, imgH, layerKey, cellSize)
  return {
    centerX: anchor.x + binding.offsetX - slot.x,
    centerY: anchor.y + binding.offsetY - slot.y,
    uniformScale: fit * binding.scale,
    rotation: binding.rotation,
  }
}

/** 单图初始放入视口：居中 + 宽约 85% 槽位宽 */
export function initialViewportTransform(
  imgW: number,
  imgH: number,
  layerKey: string,
  cellSize: number,
): ViewportTransform {
  const slot = slotViewportRect(layerKey, cellSize)
  const fit = initialFitScale(imgW, imgH, layerKey, cellSize)
  const targetW = slot.w * 0.85
  const uniformScale = targetW / Math.max(imgW, 1)
  return {
    centerX: slot.w / 2,
    centerY: slot.h / 2,
    uniformScale: Math.min(uniformScale, fit * 2.5),
    rotation: 0,
  }
}
