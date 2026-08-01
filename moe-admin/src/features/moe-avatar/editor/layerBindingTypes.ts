/** 单图绑定到官方底模 · 相对 cell 坐标系 */
export type LayerBinding = {
  /** 相对锚点偏移 px */
  offsetX: number
  offsetY: number
  /** 相对初始 fit 缩放 */
  scale: number
  /** 度数 */
  rotation: number
}

export const DEFAULT_LAYER_BINDING: LayerBinding = {
  offsetX: 0,
  offsetY: 0,
  scale: 1,
  rotation: 0,
}

/** walk 9 帧 · 轻微上下 bob（像素） */
export const WALK_FRAME_DY = [0, -1, -2, -2, -1, 0, 1, 2, 1]

/** idle 2 帧 */
export const IDLE_FRAME_DY = [0, 1]

/** 方向行：0 up 1 left 2 down 3 right */
export function directionScaleX(row: number): number {
  if (row === 1 || row === 3) return -1
  return 1
}

export function directionScaleY(row: number): number {
  if (row === 0) return -1
  return 1
}
