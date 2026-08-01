import { useCallback, useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import { LayerBindEditor } from '../components/LayerBindEditor'
import { LayerBindModal } from '../components/LayerBindModal'
import { PendingUploadPanel } from '../components/PendingUploadPanel'
import { validateSheetFile } from '../editor/sheetValidation'
import type { MoeAvatarManifest, PreviewAnimation } from '../types'

export type BindModalState = {
  file: File
  layerKey: string
  walkPath: string
  idlePath?: string
  singleAnim?: PreviewAnimation
}

type PendingConfirmState = {
  file: File
  relPath: string
  anim: PreviewAnimation
}

type Options = {
  manifest: MoeAvatarManifest
  packBaseUrl: string
  assetStore: AvatarAssetStore
  onAssetUploaded?: () => void
  onMessage?: (msg: string) => void
}

/** 上传：整 sheet 确认 · 否则弹窗绑定（替代内联智能裁剪） */
export function useSheetUpload(options: Options) {
  const { manifest, packBaseUrl, assetStore, onAssetUploaded, onMessage } = options
  const [bind, setBind] = useState<BindModalState | null>(null)
  const [pending, setPending] = useState<PendingConfirmState | null>(null)

  const closeBind = useCallback(() => setBind(null), [])
  const cancelPending = useCallback(() => setPending(null), [])

  const commitBlob = useCallback(
    (relPath: string, processed: Blob, original: File, cropped: boolean) => {
      assetStore.setWithOriginal(relPath, processed, original, !cropped)
      onAssetUploaded?.()
      onMessage?.(`已写入 ${relPath}`)
      setPending(null)
    },
    [assetStore, onAssetUploaded, onMessage],
  )

  const revertLayer = useCallback(
    (relPath: string) => {
      assetStore.revoke(relPath)
      onAssetUploaded?.()
      onMessage?.(`已恢复官方包 · ${relPath}`)
    },
    [assetStore, onAssetUploaded, onMessage],
  )

  const openBind = useCallback((state: BindModalState) => {
    setPending(null)
    setBind(state)
    onMessage?.('请在弹窗中将单图贴合官方底模')
  }, [onMessage])

  const uploadSheet = useCallback(
    async (
      relPath: string,
      anim: PreviewAnimation,
      file: File | null,
      layerKey: string,
      idlePath?: string,
    ) => {
      if (!file) return
      setPending(null)
      setBind(null)
      const validation = await validateSheetFile(file, manifest, anim)
      if (validation.ok) {
        setPending({ file, relPath, anim })
        return
      }
      openBind({
        file,
        layerKey,
        walkPath: anim === 'walk' ? relPath : relPath.replace('_idle', '_walk'),
        idlePath: idlePath ?? (anim === 'idle' ? relPath : relPath.replace('_walk', '_idle')),
        singleAnim: anim,
      })
    },
    [manifest, openBind],
  )

  const bindModal = (
    <LayerBindModal
      open={bind !== null}
      title={`绑定到官方底模 · ${bind?.layerKey ?? ''}`}
      onClose={closeBind}
    >
      {bind ? (
        <LayerBindEditor
          file={bind.file}
          layerKey={bind.layerKey}
          walkPath={bind.walkPath}
          idlePath={bind.idlePath}
          singleAnim={bind.singleAnim}
          manifest={manifest}
          packBaseUrl={packBaseUrl}
          assetStore={assetStore}
          onCancel={closeBind}
          onConfirm={({ walkBlob, idleBlob, original }) => {
            if (walkBlob && bind.walkPath) {
              assetStore.setWithOriginal(bind.walkPath, walkBlob, original, false)
            }
            if (idleBlob && bind.idlePath) {
              assetStore.setWithOriginal(bind.idlePath, idleBlob, original, false)
            }
            onAssetUploaded?.()
            onMessage?.(
              bind.singleAnim
                ? `已绑定并生成 ${bind.singleAnim} sheet`
                : '已绑定并生成 walk + idle sheet',
            )
            closeBind()
          }}
        />
      ) : null}
    </LayerBindModal>
  )

  const pendingEditor = pending ? (
    <PendingUploadPanel
      file={pending.file}
      relPath={pending.relPath}
      anim={pending.anim}
      manifest={manifest}
      onConfirm={() => commitBlob(pending.relPath, pending.file, pending.file, false)}
      onCancel={cancelPending}
    />
  ) : null

  return {
    uploadSheet,
    openBind,
    revertLayer,
    bindModal,
    pendingEditor,
    closeBind,
    cancelPending,
  }
}

export function layerUploadStatus(
  rel: string | undefined,
  assetStore: AvatarAssetStore,
): string {
  if (!rel) return '未配置'
  if (assetStore.has(rel) && assetStore.hasOriginal(rel)) {
    return '会话覆盖 · 已绑定（原图在 _originals/）'
  }
  if (assetStore.has(rel)) return '会话覆盖 · 待导出'
  return '官方包'
}
