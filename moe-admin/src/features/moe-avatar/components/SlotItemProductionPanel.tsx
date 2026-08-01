import { useRef, useState } from 'react'

import type { AvatarAssetStore } from '../assetStore'

import type { MoeAvatarManifest, WearSlot } from '../types'

import { downloadGridTemplate } from '../editor/gridTemplate'

import {

  createSlotItem,

  isValidItemId,

  removeSlotItem,

  updateSlotItemLabel,

} from '../editor/slotItemOps'

import { useSheetUpload } from '../editor/useSheetUpload'

import { LayerAssetRow } from './LayerAssetRow'



type Props = {

  manifest: MoeAvatarManifest

  slot: WearSlot

  itemId: string

  assetStore: AvatarAssetStore

  assetRevision?: number

  packBaseUrl: string

  onManifestChange: (next: MoeAvatarManifest) => void

  onSelectItem: (id: string) => void

  onError: (msg: string) => void

  onMessage?: (msg: string) => void

  onAssetUploaded?: () => void

}



/** 槽位单品生产：资产行 + 裁剪/确认 + 恢复官方 */

export function SlotItemProductionPanel({

  manifest,

  slot,

  itemId,

  assetStore,

  onManifestChange,

  onSelectItem,

  onError,

  onMessage,

  onAssetUploaded,

  assetRevision = 0,

  packBaseUrl,

}: Props) {

  const [creating, setCreating] = useState(false)

  const [newId, setNewId] = useState('')

  const [newLabel, setNewLabel] = useState('')

  const bindInputRef = useRef<HTMLInputElement>(null)

  const { uploadSheet, revertLayer, openBind, bindModal, pendingEditor } = useSheetUpload({
    manifest,
    packBaseUrl,
    assetStore,
    onAssetUploaded: () => {
      onManifestChange({ ...manifest })
      onAssetUploaded?.()
    },
    onMessage,
  })



  const entry = itemId ? manifest.slots[slot]?.[itemId] : undefined

  const gridHint = `walk ${manifest.animations.walk.cols}×${manifest.animations.walk.rows} · idle ${manifest.animations.idle.cols}×${manifest.animations.idle.rows} · cell ${manifest.cellSize}px`



  const handleCreate = () => {

    try {

      const id = newId.trim()

      if (!isValidItemId(id)) {

        onError('id 需小写 snake_case，如 top_summer_01')

        return

      }

      const next = createSlotItem(manifest, slot, id, newLabel.trim() || id)

      onManifestChange(next)

      onSelectItem(id)

      setCreating(false)

      setNewId('')

      setNewLabel('')

    } catch (e) {

      onError(e instanceof Error ? e.message : '创建失败')

    }

  }



  const handleLabelBlur = (label: string) => {

    if (!itemId || !entry) return

    const trimmed = label.trim()

    if (trimmed === (entry.label ?? '')) return

    try {

      onManifestChange(updateSlotItemLabel(manifest, slot, itemId, trimmed || itemId))

    } catch (e) {

      onError(e instanceof Error ? e.message : '更新失败')

    }

  }



  const handleDelete = () => {

    if (!itemId) return

    if (!window.confirm(`删除单品 ${itemId}？`)) return

    try {

      const paths = manifest.slots[slot]?.[itemId]

      if (paths) {

        assetStore.revoke(paths.walk)

        assetStore.revoke(paths.idle)

      }

      onManifestChange(removeSlotItem(manifest, slot, itemId))

      onSelectItem('')

    } catch (e) {

      onError(e instanceof Error ? e.message : '删除失败')

    }

  }



  const revertAll = () => {

    if (!entry) return

    revertLayer(entry.walk)

    revertLayer(entry.idle)

  }



  if (creating) {

    return (

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>

        <p style={{ margin: 0, fontWeight: 600 }}>新建单品</p>

        <label style={{ fontSize: 12 }}>

          单品 id

          <input

            className="input"

            value={newId}

            onChange={(e) => setNewId(e.target.value)}

            placeholder={`${slot}_custom_01`}

            style={{ display: 'block', width: '100%', marginTop: 4 }}

          />

        </label>

        <label style={{ fontSize: 12 }}>

          显示名

          <input

            className="input"

            value={newLabel}

            onChange={(e) => setNewLabel(e.target.value)}

            placeholder="夏季 T 恤"

            style={{ display: 'block', width: '100%', marginTop: 4 }}

          />

        </label>

        <p className="muted" style={{ fontSize: 11, margin: 0 }}>

          创建后上传 walk / idle 分层 sheet（{gridHint}）

        </p>

        <div style={{ display: 'flex', gap: 8 }}>

          <button type="button" className="btn primary" onClick={handleCreate}>

            创建

          </button>

          <button type="button" className="btn" onClick={() => setCreating(false)}>

            取消

          </button>

        </div>

      </div>

    )

  }



  if (!itemId || !entry) {

    return (

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>

        <p style={{ margin: 0 }}>

          在右侧选择单品，或<strong>新建</strong>后上传 walk/idle 分层图。

        </p>

        <p className="muted" style={{ fontSize: 11, margin: 0 }}>

          可拖拽 PNG 到资产行 · 误传点「恢复官方」

        </p>

        <button type="button" className="btn primary" onClick={() => setCreating(true)}>

          ＋ 新建单品

        </button>

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>

          <button type="button" className="btn" onClick={() => void downloadGridTemplate(manifest, 'walk')}>

            walk 模板

          </button>

          <button type="button" className="btn" onClick={() => void downloadGridTemplate(manifest, 'idle')}>

            idle 模板

          </button>

        </div>

      </div>

    )

  }



  const hasOverride = assetStore.has(entry.walk) || assetStore.has(entry.idle)



  return (

    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>

        <strong>{itemId}</strong>

        <div style={{ display: 'flex', gap: 6 }}>

          {hasOverride ? (

            <button type="button" className="btn" style={{ fontSize: 11 }} onClick={revertAll}>

              全部恢复官方

            </button>

          ) : null}

          <button type="button" className="btn" style={{ fontSize: 11 }} onClick={() => setCreating(true)}>

            ＋ 新建

          </button>

        </div>

      </div>



      <label style={{ fontSize: 12 }}>

        显示名

        <input

          key={itemId}

          className="input"

          defaultValue={entry.label ?? itemId}

          onBlur={(e) => handleLabelBlur(e.target.value)}

          style={{ display: 'block', width: '100%', marginTop: 4 }}

        />

      </label>



      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>

        <button

          type="button"

          className="btn primary"

          style={{ fontSize: 11 }}

          onClick={() => bindInputRef.current?.click()}

        >

          上传单图并绑定官方模型

        </button>

        <span className="muted" style={{ fontSize: 10 }}>

          推荐：Fooocus 单张 → 拖拽对齐 → 自动生成 walk+idle 格线

        </span>

        <input

          ref={bindInputRef}

          type="file"

          accept="image/png,image/webp"

          style={{ display: 'none' }}

          onChange={(e) => {
            const f = e.target.files?.[0]
            if (f && entry) {
              openBind({
                file: f,
                layerKey: slot,
                walkPath: entry.walk,
                idlePath: entry.idle,
              })
            }
            e.target.value = ''
          }}

        />

      </div>

      <div style={{ fontSize: 11, fontWeight: 700, color: '#5a4638' }}>当前单品资产（2 文件）</div>



      <LayerAssetRow

        manifest={manifest}

        packBaseUrl={packBaseUrl}

        relPath={entry.walk}

        anim="walk"

        layerKey={slot}

        assetStore={assetStore}

        assetRevision={assetRevision}

        onFile={(f) => void uploadSheet(entry.walk, 'walk', f, slot, entry.idle)}

        onRevert={() => revertLayer(entry.walk)}

      />

      <LayerAssetRow

        manifest={manifest}

        packBaseUrl={packBaseUrl}

        relPath={entry.idle}

        anim="idle"

        layerKey={slot}

        assetStore={assetStore}

        assetRevision={assetRevision}

        onFile={(f) => void uploadSheet(entry.idle, 'idle', f, slot, entry.idle)}

        onRevert={() => revertLayer(entry.idle)}

      />



      {pendingEditor}
      {bindModal}



      <p className="muted" style={{ fontSize: 11, margin: 0 }}>

        {gridHint} · 中间预览可切换 walk/idle

      </p>



      <button type="button" className="btn" style={{ color: 'crimson' }} onClick={handleDelete}>

        删除此单品

      </button>

    </div>

  )

}


