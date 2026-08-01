/**
 * World Object 定义（v2 草案 · 尚未接入 runtime）
 * SSOT：docs/dev/moe-pet-world-object.md
 */

export type WorldObjectKind = 'furniture' | 'decor' | 'pickup' | 'prop'

export type WorldObjectInteraction = {
  draggable?: boolean
  rotatable?: boolean
  scalable?: boolean
  pickupable?: boolean
  interactable?: boolean
  useAction?: string
  collision?: 'none' | 'block' | 'platform'
  dropTo?: 'floor' | 'hand' | 'inventory'
}

export type WorldObjectDef = {
  id: string
  kind: WorldObjectKind
  label: string
  asset: { path: string; thumb?: string }
  scenes: string[]
  transform: {
    anchor?: 'bottom_center' | 'center'
    defaultScale?: number
    zIndex?: number
  }
  interaction?: WorldObjectInteraction
  placement?: 'floor' | 'wall' | 'hanging'
}

/** 统一内容包 v1（当前） */
export type PetContentPackManifestV1 = {
  specVersion: '1'
  packId: string
  displayName: string
  avatar?: import('../moe-avatar/types').MoeAvatarSection
  objects: Record<string, WorldObjectDef>
}

/** 统一内容包 v2（规划 · 含场景 preset） */
export type PetContentPackManifest = {
  specVersion: '2'
  packId: string
  displayName: string
  avatar?: import('../moe-avatar/types').MoeAvatarSection
  objects: Record<string, WorldObjectDef>
  /** 可选：官方房间预设布局 */
  scenePresets?: Record<
    string,
    { scene: string; objects: Array<{ id: string; x: number; y: number; rotation?: number; scale?: number }> }
  >
}
