/** 客户端智能抠图：去白/灰底 + 裁透明边（无后端） */

async function loadBitmap(source: Blob): Promise<ImageBitmap> {
  return createImageBitmap(source)
}

function trimAlphaBounds(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
): { x: number; y: number; w: number; h: number } | null {
  const data = ctx.getImageData(0, 0, w, h).data
  let minX = w
  let minY = h
  let maxX = 0
  let maxY = 0
  let found = false
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const a = data[(y * w + x) * 4 + 3]
      if (a > 12) {
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

function isBackgroundPixel(r: number, g: number, b: number, a: number): boolean {
  if (a < 12) return true
  const lum = (r + g + b) / 3
  const spread = Math.max(r, g, b) - Math.min(r, g, b)
  if (lum > 235 && spread < 30) return true
  if (lum < 18 && spread < 20) return true
  if (spread < 15 && lum > 200) return true
  return false
}

/** 智能抠图 → 透明 PNG Blob */
export async function smartCutout(source: File | Blob): Promise<Blob> {
  const bitmap = await loadBitmap(source)
  const canvas = document.createElement('canvas')
  canvas.width = bitmap.width
  canvas.height = bitmap.height
  const ctx = canvas.getContext('2d')
  if (!ctx) {
    bitmap.close()
    throw new Error('canvas')
  }
  ctx.drawImage(bitmap, 0, 0)
  bitmap.close()

  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
  const d = imageData.data
  for (let i = 0; i < d.length; i += 4) {
    if (isBackgroundPixel(d[i], d[i + 1], d[i + 2], d[i + 3])) {
      d[i + 3] = 0
    }
  }
  ctx.putImageData(imageData, 0, 0)

  const bounds = trimAlphaBounds(ctx, canvas.width, canvas.height)
  if (bounds && (bounds.w < canvas.width || bounds.h < canvas.height)) {
    const trimmed = document.createElement('canvas')
    trimmed.width = bounds.w
    trimmed.height = bounds.h
    const tctx = trimmed.getContext('2d')
    if (tctx) {
      tctx.drawImage(canvas, bounds.x, bounds.y, bounds.w, bounds.h, 0, 0, bounds.w, bounds.h)
      return new Promise((resolve, reject) => {
        trimmed.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png')
      })
    }
  }

  return new Promise((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png')
  })
}

export async function blobToImage(blob: Blob): Promise<HTMLImageElement> {
  const url = URL.createObjectURL(blob)
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
