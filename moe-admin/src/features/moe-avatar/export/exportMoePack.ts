import JSZip from 'jszip'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest } from '../types'
import { assetUrl } from '../composer/resolveLayers'
import { layerThumbCanvas } from '../composer/composeSheet'
import { composeSheet } from '../composer/composeSheet'
import type { OutfitSelection } from '../types'

function collectAssetPaths(manifest: MoeAvatarManifest): Set<string> {
  const paths = new Set<string>()
  for (const b of Object.values(manifest.base)) {
    paths.add(b.walk)
    paths.add(b.idle)
  }
  for (const slot of Object.values(manifest.slots)) {
    for (const item of Object.values(slot)) {
      paths.add(item.walk)
      paths.add(item.idle)
    }
  }
  return paths
}

async function canvasToPngBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob failed'))), 'image/png')
  })
}

async function fetchBlob(url: string): Promise<Blob> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`fetch ${url}: ${res.status}`)
  return res.blob()
}

export type ExportPackOptions = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  assetStore?: AvatarAssetStore
  previewOutfit?: OutfitSelection
  /** 仅 admin 调试预览用；App 运行时按 manifest 逐层 compose，不读 baked */
  includeBaked?: boolean
}

/** 导出官方包 zip：manifest + 各部位分层 PNG + 部件 thumbs */
export async function exportMoePackZip(options: ExportPackOptions): Promise<Blob> {
  const { manifest, packBaseUrl, assetStore, previewOutfit, includeBaked = false } = options
  const zip = new JSZip()
  const paths = collectAssetPaths(manifest)

  for (const rel of paths) {
    try {
      const blob = assetStore?.get(rel) ?? (await fetchBlob(assetUrl(packBaseUrl, rel)))
      zip.file(rel, blob)
    } catch (e) {
      console.warn('skip layer', rel, e)
    }
  }

  if (assetStore) {
    for (const origKey of assetStore.originalPaths()) {
      const blob = assetStore.get(origKey)
      if (blob) zip.file(origKey, blob)
    }
  }

  const manifestOut = structuredClone(manifest)
  for (const [, items] of Object.entries(manifestOut.slots)) {
    for (const [itemId, layers] of Object.entries(items)) {
      const thumbCanvas = await layerThumbCanvas(
        manifestOut,
        layers.idle,
        packBaseUrl,
        64,
        assetStore,
      )
      if (!thumbCanvas) continue
      const blob = await canvasToPngBlob(thumbCanvas)
      zip.file(`thumbs/${itemId}.png`, blob)
      layers.thumb = `thumbs/${itemId}.png`
    }
  }

  if (includeBaked && previewOutfit) {
    const walk = await composeSheet(manifestOut, previewOutfit, 'walk', packBaseUrl, assetStore)
    const idle = await composeSheet(manifestOut, previewOutfit, 'idle', packBaseUrl, assetStore)
    if (walk) zip.file('baked/hero_walk.png', await canvasToPngBlob(walk))
    if (idle) zip.file('baked/hero_idle.png', await canvasToPngBlob(idle))
  }

  zip.file('manifest.json', JSON.stringify(manifestOut, null, 2))
  return zip.generateAsync({ type: 'blob' })
}

export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
