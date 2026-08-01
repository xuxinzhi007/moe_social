import { AVATAR_TEMPLATE_PRESETS, type AvatarTemplateId } from './templateRegistry'
import type { MoeAvatarManifest } from './types'

export type ManifestValidationIssue = {
  level: 'error' | 'warning'
  code: string
  message: string
  path?: string
}

export type ManifestValidationResult = {
  ok: boolean
  issues: ManifestValidationIssue[]
}

function pushIssue(
  issues: ManifestValidationIssue[],
  level: 'error' | 'warning',
  code: string,
  message: string,
  path?: string,
): void {
  issues.push({ level, code, message, path })
}

function hasKeys<T extends Record<string, unknown>>(obj: T, keys: string[]): boolean {
  return keys.every((key) => Object.prototype.hasOwnProperty.call(obj, key))
}

function validateCommon(manifest: MoeAvatarManifest, issues: ManifestValidationIssue[]): void {
  if (manifest.specVersion !== '1') {
    pushIssue(issues, 'error', 'spec-version', `specVersion must be 1, got ${manifest.specVersion}`)
  }
  if (!manifest.packId) pushIssue(issues, 'error', 'pack-id', 'packId is required')
  if (!manifest.displayName) pushIssue(issues, 'warning', 'display-name', 'displayName is empty')
  if (!manifest.directionRows?.length) {
    pushIssue(issues, 'error', 'directions', 'directionRows is required')
  } else if (!manifest.directionRows.includes('down')) {
    pushIssue(issues, 'warning', 'directions', 'directionRows should include down for editor thumbnails')
  }

  for (const anim of ['walk', 'idle'] as const) {
    const grid = manifest.animations[anim]
    if (!grid) {
      pushIssue(issues, 'error', 'animation-missing', `${anim} animation grid is missing`, `animations.${anim}`)
      continue
    }
    if (grid.cols <= 0 || grid.rows <= 0) {
      pushIssue(issues, 'error', 'animation-grid', `${anim} grid must be positive`, `animations.${anim}`)
    }
  }
}

function validateAgainstPreset(
  manifest: MoeAvatarManifest,
  templateId: AvatarTemplateId,
  issues: ManifestValidationIssue[],
): void {
  const preset = AVATAR_TEMPLATE_PRESETS[templateId]
  if (manifest.cellSize !== preset.cellSize) {
    pushIssue(
      issues,
      'warning',
      'cell-size',
      `cellSize ${manifest.cellSize} differs from template default ${preset.cellSize}`,
      'cellSize',
    )
  }
  if (manifest.style !== preset.style) {
    pushIssue(issues, 'warning', 'style', `style ${manifest.style} differs from template default ${preset.style}`, 'style')
  }
  if (manifest.composeOrder.join('|') !== preset.composeOrder.join('|')) {
    pushIssue(
      issues,
      'warning',
      'compose-order',
      `composeOrder differs from template ${preset.label}`,
      'composeOrder',
    )
  }

  if (!hasKeys(manifest.base, preset.baseKeys)) {
    pushIssue(issues, 'error', 'base-keys', `base keys must include ${preset.baseKeys.join(', ')}`, 'base')
  }

  for (const key of Object.keys(manifest.base)) {
    const layer = manifest.base[key]
    if (!layer?.walk || !layer?.idle) {
      pushIssue(issues, 'error', 'base-layer', `base layer ${key} needs walk + idle`, `base.${key}`)
    }
  }

  const allowedSlots = new Set(preset.slotKeys)
  for (const slot of Object.keys(manifest.slots)) {
    if (!allowedSlots.has(slot)) {
      pushIssue(issues, 'warning', 'slot-unexpected', `slot ${slot} is not part of template ${preset.label}`, `slots.${slot}`)
    }
  }

  for (const slot of preset.requiredSlots) {
    const items = manifest.slots[slot]
    if (!items || Object.keys(items).length === 0) {
      pushIssue(
        issues,
        'error',
        'required-slot-missing',
        `required slot ${slot} has no items in template ${preset.label}`,
        `slots.${slot}`,
      )
    }
  }

  for (const slot of preset.optionalSlots) {
    if (!allowedSlots.has(slot)) {
      pushIssue(issues, 'warning', 'optional-slot-missing', `optional slot ${slot} is not defined in template ${preset.label}`)
    }
  }
}

export function validateManifestAgainstTemplate(
  manifest: MoeAvatarManifest,
  templateId: AvatarTemplateId,
): ManifestValidationResult {
  const issues: ManifestValidationIssue[] = []
  validateCommon(manifest, issues)
  validateAgainstPreset(manifest, templateId, issues)
  return { ok: !issues.some((issue) => issue.level === 'error'), issues }
}
