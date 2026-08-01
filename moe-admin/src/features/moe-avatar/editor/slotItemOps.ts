import type { MoeAvatarManifest, PreviewAnimation, WearSlot } from '../types'

const SLOT_ITEM_ID = /^[a-z][a-z0-9_]*$/

export function isValidItemId(id: string): boolean {
  return SLOT_ITEM_ID.test(id)
}

export function defaultLayerPath(itemId: string, anim: PreviewAnimation): string {
  return `layers/slots/${itemId}_${anim}.png`
}

/** 新建槽位单品（路径占位，待上传 PNG） */
export function createSlotItem(
  manifest: MoeAvatarManifest,
  slot: WearSlot,
  itemId: string,
  label: string,
): MoeAvatarManifest {
  if (!isValidItemId(itemId)) {
    throw new Error('单品 id 需小写 snake_case，如 top_hoodie_v2')
  }
  if (manifest.slots[slot]?.[itemId]) {
    throw new Error(`槽位 ${slot} 已存在 ${itemId}`)
  }
  return {
    ...manifest,
    slots: {
      ...manifest.slots,
      [slot]: {
        ...manifest.slots[slot],
        [itemId]: {
          walk: defaultLayerPath(itemId, 'walk'),
          idle: defaultLayerPath(itemId, 'idle'),
          label,
        },
      },
    },
  }
}

export function updateSlotItemLabel(
  manifest: MoeAvatarManifest,
  slot: WearSlot,
  itemId: string,
  label: string,
): MoeAvatarManifest {
  const entry = manifest.slots[slot]?.[itemId]
  if (!entry) throw new Error('单品不存在')
  return {
    ...manifest,
    slots: {
      ...manifest.slots,
      [slot]: {
        ...manifest.slots[slot],
        [itemId]: { ...entry, label },
      },
    },
  }
}

export function removeSlotItem(
  manifest: MoeAvatarManifest,
  slot: WearSlot,
  itemId: string,
): MoeAvatarManifest {
  const slotMap = { ...manifest.slots[slot] }
  delete slotMap[itemId]
  return {
    ...manifest,
    slots: {
      ...manifest.slots,
      [slot]: slotMap,
    },
  }
}
