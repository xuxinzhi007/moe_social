import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, OutfitSelection, WearSlot } from '../types'
import { ResourcePackPanel } from './ResourcePackPanel'

type Props = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  assetStore: AvatarAssetStore
  assetRevision: number
  outfit: OutfitSelection
  focusSlot?: WearSlot
  focusItemId?: string
  onRevert?: (relPath: string) => void
  onDeleteResource?: (relPath: string) => void
}

/** 资产包总入口：当前资产与合并资源共用一个面板，避免拆成两个区块 */
export function AssetPackPanel({
  manifest,
  packBaseUrl,
  assetStore,
  assetRevision,
  outfit,
  focusSlot,
  focusItemId,
  onRevert,
  onDeleteResource,
}: Props) {
  return (
    <ResourcePackPanel
      manifest={manifest}
      packBaseUrl={packBaseUrl}
      assetStore={assetStore}
      assetRevision={assetRevision}
      outfit={outfit}
      focusSlot={focusSlot}
      focusItemId={focusItemId}
      onRevert={onRevert}
      onDeleteResource={onDeleteResource}
    />
  )
}
