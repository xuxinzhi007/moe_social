import type { SpriteResource } from './spriteTypes'

export type SpriteValidationIssue = {
  code: string
  message: string
  path?: string
}

export type SpriteValidationResult = {
  ok: boolean
  issues: SpriteValidationIssue[]
}

function issue(issues: SpriteValidationIssue[], code: string, message: string, path?: string): void {
  issues.push({ code, message, path })
}

function isPositiveInteger(value: number): boolean {
  return Number.isInteger(value) && value > 0
}

function isNonEmpty(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0
}

export function validateSpriteResource(resource: SpriteResource): SpriteValidationResult {
  const issues: SpriteValidationIssue[] = []

  if (!isNonEmpty(resource.id)) issue(issues, 'id-required', 'id must be non-empty', 'id')
  if (!isNonEmpty(resource.source.path)) issue(issues, 'source-path-required', 'source.path must be non-empty', 'source.path')

  for (const [name, value] of Object.entries(resource.canvas)) {
    if (!isPositiveInteger(value)) issue(issues, 'dimension-invalid', `${name} must be a positive integer`, `canvas.${name}`)
  }

  for (const [name, value] of Object.entries(resource.frameLayout)) {
    if (name !== 'mode' && !isPositiveInteger(value as number)) {
      issue(issues, 'frame-layout-invalid', `${name} must be a positive integer`, `frameLayout.${name}`)
    }
  }

  if (resource.anchor.x < 0 || resource.anchor.x > resource.canvas.width) {
    issue(issues, 'anchor-out-of-bounds', 'anchor.x must be within the canvas', 'anchor.x')
  }
  if (resource.anchor.y < 0 || resource.anchor.y > resource.canvas.height) {
    issue(issues, 'anchor-out-of-bounds', 'anchor.y must be within the canvas', 'anchor.y')
  }

  const capacity = resource.frameLayout.columns * resource.frameLayout.rows
  if (resource.frameLayout.frameWidth * resource.frameLayout.columns !== resource.canvas.width) {
    issue(issues, 'layout-dimension-mismatch', 'frame layout width must match canvas width', 'frameLayout')
  }
  if (resource.frameLayout.frameHeight * resource.frameLayout.rows !== resource.canvas.height) {
    issue(issues, 'layout-dimension-mismatch', 'frame layout height must match canvas height', 'frameLayout')
  }

  for (const [index, animation] of resource.animations.entries()) {
    const path = `animations.${index}`
    if (!isNonEmpty(animation.id)) issue(issues, 'animation-id-required', 'animation id must be non-empty', `${path}.id`)
    if (!isPositiveInteger(animation.frameCount)) issue(issues, 'frame-count-invalid', 'frameCount must be a positive integer', `${path}.frameCount`)
    if (animation.frameCount > capacity) issue(issues, 'frame-count-exceeds-layout', 'frameCount exceeds frame layout capacity', `${path}.frameCount`)
    if (animation.startFrame !== undefined && (!Number.isInteger(animation.startFrame) || animation.startFrame < 0 || animation.startFrame >= capacity)) {
      issue(issues, 'start-frame-invalid', 'startFrame must reference a frame in the layout', `${path}.startFrame`)
    }
  }

  const layerIds = new Set<string>()
  for (const [index, layer] of (resource.layers ?? []).entries()) {
    const path = `layers.${index}`
    if (!isNonEmpty(layer.id)) issue(issues, 'layer-id-required', 'layer id must be non-empty', `${path}.id`)
    if (!isNonEmpty(layer.path)) issue(issues, 'layer-path-required', 'layer path must be non-empty', `${path}.path`)
    if (layerIds.has(layer.id)) issue(issues, 'duplicate-layer-id', `layer id ${layer.id} is duplicated`, `${path}.id`)
    layerIds.add(layer.id)
  }

  return { ok: issues.length === 0, issues }
}

export const validateSpriteAsset = validateSpriteResource
