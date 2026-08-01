import type { MoeAvatarManifest, PreviewAnimation } from '../types'

export type SheetValidation = {
  ok: boolean
  message: string
  width?: number
  height?: number
}

function expectedSize(manifest: MoeAvatarManifest, anim: PreviewAnimation): {
  w: number
  h: number
} {
  const grid = manifest.animations[anim]
  return {
    w: grid.cols * manifest.cellSize,
    h: grid.rows * manifest.cellSize,
  }
}

/** 读取 File 尺寸并校验是否符合 manifest 格线 */
export async function validateSheetFile(
  file: File,
  manifest: MoeAvatarManifest,
  anim: PreviewAnimation,
): Promise<SheetValidation> {
  if (!file.type.startsWith('image/')) {
    return { ok: false, message: '请上传 PNG / WebP 图片' }
  }
  const { w, h } = expectedSize(manifest, anim)
  try {
    const bitmap = await createImageBitmap(file)
    const width = bitmap.width
    const height = bitmap.height
    bitmap.close()
    if (width === w && height === h) {
      return { ok: true, message: `尺寸正确 ${w}×${h}`, width: w, height: h }
    }
    return {
      ok: false,
      message: `尺寸应为 ${w}×${h}（${anim} · cell ${manifest.cellSize}），实际 ${width}×${height}`,
      width,
      height,
    }
  } catch {
    return { ok: false, message: '无法读取图片' }
  }
}

export function sheetSpecLabel(manifest: MoeAvatarManifest, anim: PreviewAnimation): string {
  const grid = manifest.animations[anim]
  const { w, h } = expectedSize(manifest, anim)
  return `${anim} ${grid.cols}×${grid.rows} 格 · ${w}×${h}px`
}
