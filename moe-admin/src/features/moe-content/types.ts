export type FurnitureItemDef = {
  path: string
  thumb?: string
  label: string
  scenes: string[]
  defaultScale?: number
  anchor?: 'bottom_center' | 'center'
}

export type FurnitureManifest = {
  specVersion: string
  packId: string
  kind: 'furniture'
  displayName: string
  items: Record<string, FurnitureItemDef>
}

export type DecorItemDef = FurnitureItemDef & {
  /** wall | floor | hanging */
  placement?: string
}

export type DecorManifest = {
  specVersion: string
  packId: string
  kind: 'decor'
  displayName: string
  items: Record<string, DecorItemDef>
}
