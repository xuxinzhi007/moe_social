export type SpriteAssetKind = 'character' | 'object' | 'effect'

export type SpriteTemplateMode =
  | 'single_frame'
  | 'animation_strip'
  | 'directional_grid'
  | 'layered_composition'

export type SpriteSize = {
  width: number
  height: number
}

export type SpriteAnchor = {
  x: number
  y: number
}

export type SpriteFrameLayout = {
  mode: SpriteTemplateMode
  frameWidth: number
  frameHeight: number
  columns: number
  rows: number
}

export type SpriteAnimation = {
  id: string
  frameCount: number
  startFrame?: number
  frameRate?: number
  loop?: boolean
  direction?: string
}

export type SpriteSourceMetadata = {
  path: string
  mimeType?: string
  width?: number
  height?: number
  provider?: string
  prompt?: string
  model?: string
  generatedAt?: string
}

export type SpriteLayer = {
  id: string
  path: string
  zIndex?: number
  opacity?: number
}

export type SpriteResource = {
  id: string
  kind: SpriteAssetKind
  templateId?: string
  /** Runtime-ready sprite sheet path. The source path remains the original AI asset. */
  sheet?: string
  canvas: SpriteSize
  anchor: SpriteAnchor
  animations: SpriteAnimation[]
  frameLayout: SpriteFrameLayout
  source: SpriteSourceMetadata
  layers?: SpriteLayer[]
}

export type AiSpriteResource = SpriteResource

export type SpriteTemplate = Omit<SpriteResource, 'id' | 'source'> & {
  id: string
  label: string
  description: string
}
