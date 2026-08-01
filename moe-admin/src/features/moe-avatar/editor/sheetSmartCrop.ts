export type SmartCropMode = 'trim-scale' | 'center-cover' | 'top-left'

export type SmartCropResult = {
  blob: Blob
  description: string
}

type AlphaBounds = { x: number; y: number; w: number; h: number }

async function loadImageElement(file: Blob): Promise<HTMLImageElement> {
  const url = URL.createObjectURL(file)
  try {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve()
      img.onerror = () => reject(new Error('load failed'))
      img.src = url
    })
    return img
  } finally {
    URL.revokeObjectURL(url)
  }
}

function canvasToBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png')
  })
}

/** 非透明像素包围盒 */
function findAlphaBounds(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
): AlphaBounds | null {
  const data = ctx.getImageData(0, 0, w, h).data
  let minX = w
  let minY = h
  let maxX = 0
  let maxY = 0
  let found = false
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const a = data[(y * w + x) * 4 + 3]
      if (a > 8) {
        found = true
        if (x < minX) minX = x
        if (y < minY) minY = y
        if (x > maxX) maxX = x
        if (y > maxY) maxY = y
      }
    }
  }
  if (!found) return null
  return { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 }
}

/**
 * 智能裁剪至目标 sheet 尺寸。
 * - trim-scale：去透明边 → 等比缩放至目标内 → 居中（默认）
 * - center-cover：等比放大铺满目标 → 居中裁切
 * - top-left：等比缩小后取左上 target 区域
 */
export async function smartCropSheet(
  file: Blob,
  targetW: number,
  targetH: number,
  mode: SmartCropMode = 'trim-scale',
): Promise<SmartCropResult> {
  const img = await loadImageElement(file)
  const srcCanvas = document.createElement('canvas')
  srcCanvas.width = img.naturalWidth
  srcCanvas.height = img.naturalHeight
  const srcCtx = srcCanvas.getContext('2d')
  if (!srcCtx) throw new Error('canvas 2d unavailable')
  srcCtx.drawImage(img, 0, 0)

  const out = document.createElement('canvas')
  out.width = targetW
  out.height = targetH
  const outCtx = out.getContext('2d')
  if (!outCtx) throw new Error('canvas 2d unavailable')
  outCtx.clearRect(0, 0, targetW, targetH)

  const bounds = findAlphaBounds(srcCtx, img.naturalWidth, img.naturalHeight)
  const sx = bounds?.x ?? 0
  const sy = bounds?.y ?? 0
  const sw = bounds?.w ?? img.naturalWidth
  const sh = bounds?.h ?? img.naturalHeight

  if (mode === 'trim-scale') {
    const scale = Math.min(targetW / sw, targetH / sh)
    const dw = sw * scale
    const dh = sh * scale
    const dx = (targetW - dw) / 2
    const dy = (targetH - dh) / 2
    outCtx.imageSmoothingEnabled = scale < 1
    outCtx.drawImage(srcCanvas, sx, sy, sw, sh, dx, dy, dw, dh)
    return {
      blob: await canvasToBlob(out),
      description: `去透明边 · 等比缩放至 ${targetW}×${targetH}（原图 ${img.naturalWidth}×${img.naturalHeight}）`,
    }
  }

  if (mode === 'center-cover') {
    const scale = Math.max(targetW / sw, targetH / sh)
    const dw = sw * scale
    const dh = sh * scale
    const dx = (targetW - dw) / 2
    const dy = (targetH - dh) / 2
    outCtx.imageSmoothingEnabled = true
    outCtx.drawImage(srcCanvas, sx, sy, sw, sh, dx, dy, dw, dh)
    return {
      blob: await canvasToBlob(out),
      description: `居中铺满 ${targetW}×${targetH}（可能裁边）`,
    }
  }

  // top-left
  const scale = Math.min(1, targetW / sw, targetH / sh)
  const dw = Math.min(targetW, sw * scale)
  const dh = Math.min(targetH, sh * scale)
  outCtx.imageSmoothingEnabled = scale < 1
  outCtx.drawImage(srcCanvas, sx, sy, sw, sh, 0, 0, dw, dh)
  return {
    blob: await canvasToBlob(out),
    description: `左上对齐 ${targetW}×${targetH}`,
  }
}

export function expectedSheetSize(
  cellSize: number,
  cols: number,
  rows: number,
): { w: number; h: number } {
  return { w: cols * cellSize, h: rows * cellSize }
}
