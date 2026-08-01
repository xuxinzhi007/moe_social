/**
 * Avatar 分层 sheet 生产模板（对齐 assets/pet/config/avatar_layer_template.json）
 * SSOT 文档：docs/dev/pet-avatar-layer-template.md
 */

export type PaintRect = { x0: number; y0: number; x1: number; y1: number }

export type LayerRule = {
  label: string
  group: 'base' | 'slot'
  paintRect: PaintRect
  mustPaint?: boolean
  hint: string
}

export type AvatarLayerTemplate = {
  version: number
  templateId: string
  cellSize: number
  directionRows: string[]
  animations: Record<string, { cols: number; rows: number }>
  anchors: Record<string, { x: number; y: number; note?: string }>
  baseStyle: {
    target: string
    officialMannequin: string
    forbiddenSource: string
    transitionNote?: string
  }
  composeOrder: string[]
  layerRules: Record<string, LayerRule>
  exportRules: Record<string, string | number | boolean>
  pipeline: Record<string, string>
}

/** admin 内置模板（与 Flutter assets 同步内容） */
export const AVATAR_LAYER_TEMPLATE: AvatarLayerTemplate = {
  version: 1,
  templateId: 'moe-chibi-grid-v1',
  cellSize: 64,
  directionRows: ['up', 'left', 'down', 'right'],
  animations: {
    walk: { cols: 9, rows: 4 },
    idle: { cols: 2, rows: 4 },
  },
  anchors: {
    origin: { x: 32, y: 58, note: '脚底中心 · down 行 idle 帧0' },
    headCenter: { x: 32, y: 16 },
    torsoCenter: { x: 32, y: 34 },
  },
  baseStyle: {
    target: 'soft_chibi',
    officialMannequin: 'assets/pet/character/',
    forbiddenSource: 'lpc_ulpc_pixel_base',
    transitionNote:
      '当前 public pack 为 LPC 64px 过渡；正式包须换官方底模或 128 格软 Q 重绘',
  },
  composeOrder: ['body', 'bottom', 'top', 'shoes', 'head', 'face', 'hat', 'hair'],
  layerRules: {
    body: {
      label: '素体·身体',
      group: 'base',
      paintRect: { x0: 0.12, y0: 0.22, x1: 0.88, y1: 0.92 },
      mustPaint: true,
      hint: '躯干+腿 · 无脸无发型',
    },
    head: {
      label: '素体·头型',
      group: 'base',
      paintRect: { x0: 0.18, y0: 0.02, x1: 0.82, y1: 0.38 },
      mustPaint: true,
      hint: '头型轮廓 · 无表情',
    },
    face: {
      label: '素体·表情',
      group: 'base',
      paintRect: { x0: 0.22, y0: 0.08, x1: 0.78, y1: 0.32 },
      mustPaint: true,
      hint: '眼嘴腮红 · 透明底',
    },
    hair: {
      label: '素体·发型',
      group: 'base',
      paintRect: { x0: 0.1, y0: 0, x1: 0.9, y1: 0.42 },
      mustPaint: true,
      hint: '可盖住部分头型 · 不画身体',
    },
    top: {
      label: '槽位·上衣',
      group: 'slot',
      paintRect: { x0: 0.14, y0: 0.24, x1: 0.86, y1: 0.62 },
      hint: '仅躯干上衣区 · 禁止整格铺满 · 禁止画头/裤/鞋',
    },
    bottom: {
      label: '槽位·下装',
      group: 'slot',
      paintRect: { x0: 0.16, y0: 0.48, x1: 0.84, y1: 0.88 },
      hint: '腰以下裤裙 · 不画鞋',
    },
    shoes: {
      label: '槽位·鞋',
      group: 'slot',
      paintRect: { x0: 0.18, y0: 0.78, x1: 0.82, y1: 0.98 },
      hint: '仅脚部区域',
    },
    hat: {
      label: '槽位·帽',
      group: 'slot',
      paintRect: { x0: 0.08, y0: 0, x1: 0.92, y1: 0.28 },
      hint: '头顶帽饰 · 不画脸',
    },
  },
  exportRules: {
    walkSize: '576x256',
    idleSize: '128x256',
    alphaRequired: true,
    thumbFrom: 'idle.down.col0',
    maxAnchorDeviationPx: 2,
  },
  pipeline: {
    templateValidate: 'moe-admin',
    batchAlign: 'scripts/pet/align_layer_to_template.py',
    aiGenerateOptional: 'local_fooocus',
    publishStore: 'go_backend_p4',
  },
}

/** 槽位 WearSlot → template layerRules key */
export function slotToLayerKey(slot: string): string {
  return slot
}

/** compose/base key → layer rule */
export function layerRuleForKey(layerKey: string): LayerRule | undefined {
  return AVATAR_LAYER_TEMPLATE.layerRules[layerKey]
}

export function paintRectPx(
  rect: PaintRect,
  cellSize: number,
): { x: number; y: number; w: number; h: number } {
  return {
    x: Math.round(rect.x0 * cellSize),
    y: Math.round(rect.y0 * cellSize),
    w: Math.round((rect.x1 - rect.x0) * cellSize),
    h: Math.round((rect.y1 - rect.y0) * cellSize),
  }
}
