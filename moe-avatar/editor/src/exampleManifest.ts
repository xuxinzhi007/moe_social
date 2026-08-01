import type { MoeAvatarManifest } from '../../core/src'

export const exampleManifest: MoeAvatarManifest = {
  specVersion: '1',
  packId: 'moe-official-chibi-v1',
  displayName: 'Moe 官方 · 软 Q 版',
  cellSize: 128,
  style: 'soft_chibi',
  directionRows: ['up', 'left', 'down', 'right'],
  animations: {
    walk: { cols: 9, rows: 4 },
    idle: { cols: 2, rows: 4 },
  },
  composeOrder: ['body', 'bottom', 'top', 'shoes', 'head', 'face', 'hat', 'hair'],
  base: {
    body: { walk: 'layers/base/body_walk.png', idle: 'layers/base/body_idle.png' },
    head: { walk: 'layers/base/head_walk.png', idle: 'layers/base/head_idle.png' },
    face: { walk: 'layers/base/face_walk.png', idle: 'layers/base/face_idle.png' },
    hair: { walk: 'layers/base/hair_walk.png', idle: 'layers/base/hair_idle.png' },
  },
  slots: {
    hat: {
      hat_cap: {
        walk: 'layers/slots/hat_cap_walk.png',
        idle: 'layers/slots/hat_cap_idle.png',
        thumb: 'thumbs/hat_cap.png',
        label: '鸭舌帽',
      },
    },
    top: {
      top_basic: {
        walk: 'layers/slots/top_basic_walk.png',
        idle: 'layers/slots/top_basic_idle.png',
        thumb: 'thumbs/top_basic.png',
        label: '基础上衣',
      },
    },
    bottom: {
      bottom_basic: {
        walk: 'layers/slots/bottom_basic_walk.png',
        idle: 'layers/slots/bottom_basic_idle.png',
        thumb: 'thumbs/bottom_basic.png',
        label: '基础下装',
      },
    },
    shoes: {
      shoes_basic: {
        walk: 'layers/slots/shoes_basic_walk.png',
        idle: 'layers/slots/shoes_basic_idle.png',
        thumb: 'thumbs/shoes_basic.png',
        label: '基础鞋',
      },
    },
  },
}
