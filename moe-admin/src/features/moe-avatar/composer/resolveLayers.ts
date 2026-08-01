import type { MoeAvatarManifest, OutfitSelection, PreviewAnimation, WearSlot } from '../types'

const SLOT_TO_COMPOSE_KEY: Record<WearSlot, string> = {
  hat: 'hat',
  top: 'top',
  bottom: 'bottom',
  shoes: 'shoes',
}

/** manifest 内相对路径 → admin public URL */
export function assetUrl(packBaseUrl: string, relativePath: string): string {
  const base = packBaseUrl.replace(/\/$/, '')
  const rel = relativePath.replace(/^\//, '')
  return `${base}/${rel}`
}

/** 可加载 URL：优先会话内上传 blob */
export function resolveAssetUrl(
  packBaseUrl: string,
  relativePath: string,
  uploadedUrl?: string,
): string {
  if (uploadedUrl) return uploadedUrl
  return assetUrl(packBaseUrl, relativePath)
}

function layerPath(
  manifest: MoeAvatarManifest,
  composeKey: string,
  outfit: OutfitSelection,
  anim: PreviewAnimation,
): string | null {
  if (manifest.base[composeKey]) {
    return manifest.base[composeKey][anim]
  }
  const slot = Object.entries(SLOT_TO_COMPOSE_KEY).find(([, v]) => v === composeKey)?.[0] as
    | WearSlot
    | undefined
  if (!slot) return null
  const id = outfit[`${slot}Id` as keyof OutfitSelection] as string
  if (!id) return null
  const entry = manifest.slots[slot]?.[id]
  if (!entry) return null
  return entry[anim]
}

/** 按 composeOrder 解析当前装扮的层路径（相对 pack 根） */
export function resolveLayerPaths(
  manifest: MoeAvatarManifest,
  outfit: OutfitSelection,
  anim: PreviewAnimation,
): string[] {
  const out: string[] = []
  for (const key of manifest.composeOrder) {
    const p = layerPath(manifest, key, outfit, anim)
    if (p) out.push(p)
  }
  return out
}

export function itemIdsForSlot(manifest: MoeAvatarManifest, slot: WearSlot): string[] {
  const m = manifest.slots[slot]
  if (!m) return []
  return Object.keys(m).sort()
}
