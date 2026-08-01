import type { MoeAvatarManifest, PreviewAnimation } from '../types'
import { downloadBlob } from '../../moe-content/exportPack'
import { layerRuleForKey, paintRectPx, type PaintRect } from './layerTemplate'
import { composeMannequinCell } from '../composer/composeMannequin'
import type { AvatarAssetStore } from '../assetStore'

const DIR_LABELS = ['up', 'left', 'down', 'right']

/** 生成 walk/idle 模板 PNG（带人偶基准和格线，而不是纯显示框） */
export async function buildGridTemplateCanvas(
  manifest: MoeAvatarManifest,
  anim: PreviewAnimation,
  layerKey?: string,
  packBaseUrl = '/pet/moe_avatar',
  assetStore?: AvatarAssetStore,
): Promise<HTMLCanvasElement> {
  const grid = manifest.animations[anim]
  const cell = manifest.cellSize
  const w = grid.cols * cell
  const h = grid.rows * cell
  const canvas = document.createElement('canvas')
  canvas.width = w
  canvas.height = h
  const ctx = canvas.getContext('2d')
  if (!ctx) return canvas

  ctx.fillStyle = '#fbf7f2'
  ctx.fillRect(0, 0, w, h)

  const mannequinRows = await Promise.all(
    Array.from({ length: grid.rows }, (_, row) =>
      composeMannequinCell(manifest, packBaseUrl, assetStore, anim, row, 0),
    ),
  )

  for (let row = 0; row < grid.rows; row++) {
    for (let col = 0; col < grid.cols; col++) {
      const x = col * cell
      const y = row * cell
      ctx.save()
      ctx.globalAlpha = row === 2 ? 1 : 0.86
      const mannequin = mannequinRows[row]
      if (mannequin) ctx.drawImage(mannequin, x, y)
      ctx.restore()
      const rule = layerKey ? layerRuleForKey(layerKey) : undefined
      if (rule?.paintRect) {
        drawPaintRectInCell(ctx, rule.paintRect, x, y, cell)
      }
      ctx.strokeStyle = '#e0d8e8'
      ctx.lineWidth = 1
      ctx.strokeRect(x + 0.5, y + 0.5, cell - 1, cell - 1)
    }
  }

  ctx.strokeStyle = '#c4a8d8'
  ctx.lineWidth = 2
  ctx.strokeRect(1, 1, w - 2, h - 2)

  ctx.fillStyle = '#8a7364'
  ctx.font = 'bold 11px sans-serif'
  ctx.textAlign = 'center'
  for (let row = 0; row < grid.rows; row++) {
    const label = DIR_LABELS[row] ?? `r${row}`
    ctx.fillText(label, w / 2, row * cell + 14)
  }

  ctx.font = '10px sans-serif'
  for (let col = 0; col < grid.cols; col++) {
    ctx.fillText(String(col), col * cell + cell / 2, h - 6)
  }

  ctx.fillStyle = '#5a4638'
  ctx.font = '12px sans-serif'
  ctx.textAlign = 'left'
  ctx.fillText(
    layerKey
      ? `Moe ${anim} · ${layerKey} · ${grid.cols}×${grid.rows} · cell ${cell}px`
      : `Moe ${anim} template · ${grid.cols}×${grid.rows} · cell ${cell}px`,
    8,
    h - 8,
  )

  return canvas
}

function drawPaintRectInCell(
  ctx: CanvasRenderingContext2D,
  rect: PaintRect,
  cellX: number,
  cellY: number,
  cell: number,
): void {
  const { x, y, w, h } = paintRectPx(rect, cell)
  ctx.fillStyle = 'rgba(80, 200, 120, 0.2)'
  ctx.fillRect(cellX + x, cellY + y, w, h)
  ctx.strokeStyle = 'rgba(40, 160, 80, 0.8)'
  ctx.strokeRect(cellX + x + 0.5, cellY + y + 0.5, w - 1, h - 1)
}

export async function downloadGridTemplate(
  manifest: MoeAvatarManifest,
  anim: PreviewAnimation,
  layerKey?: string,
  packBaseUrl = '/pet/moe_avatar',
  assetStore?: AvatarAssetStore,
): Promise<void> {
  const canvas = await buildGridTemplateCanvas(manifest, anim, layerKey, packBaseUrl, assetStore)
  const blob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png')
  })
  const suffix = layerKey ? `_${layerKey}` : ''
  downloadBlob(blob, `moe_${anim}_template${suffix}_${manifest.cellSize}px.png`)
}
