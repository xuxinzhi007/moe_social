import { useState } from 'react'
import type { AvatarAssetStore } from '../assetStore'
import type { MoeAvatarManifest, WearSlot } from '../types'
import {
  createSlotItem,
  isValidItemId,
  removeSlotItem,
  updateSlotItemLabel,
} from '../editor/slotItemOps'

type Props = {
  manifest: MoeAvatarManifest
  slot: WearSlot
  itemId: string
  assetStore: AvatarAssetStore
  onManifestChange: (next: MoeAvatarManifest) => void
  onSelectItem: (id: string) => void
  onError: (msg: string) => void
  onAssetUploaded?: () => void
}

function layerStatus(rel: string | undefined, assetStore: AvatarAssetStore): string {
  if (!rel) return '未配置'
  if (assetStore.has(rel)) return '已上传（待导出）'
  return '使用官方包 / 待上传'
}

/** 槽位单品生产：新建 / 改 label / 上传 walk·idle sheet */
export function SlotItemProductionPanel({
  manifest,
  slot,
  itemId,
  assetStore,
  onManifestChange,
  onSelectItem,
  onError,
  onAssetUploaded,
}: Props) {
  const [creating, setCreating] = useState(false)
  const [newId, setNewId] = useState('')
  const [newLabel, setNewLabel] = useState('')

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

  const handleUpload = (anim: 'walk' | 'idle', file: File | null) => {
    if (!itemId || !entry || !file) return
    if (!file.type.startsWith('image/')) {
      onError('请上传 PNG 图片')
      return
    }
    assetStore.set(entry[anim], file)
    onAssetUploaded?.()
    onManifestChange({ ...manifest })
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
          在右侧选择单品，或<strong>新建</strong>后上传 walk/idle 分层图进行生产。
        </p>
        <p className="muted" style={{ fontSize: 11, margin: 0 }}>
          格线：{gridHint}。导出为<strong>各部位分层 sheet</strong>，App 按槽位 id
          任意组合（非整身图）。解压到{' '}
          <code>assets/pet/moe_content/avatar/</code>。
        </p>
        <button type="button" className="btn primary" onClick={() => setCreating(true)}>
          ＋ 新建单品
        </button>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <strong>{itemId}</strong>
        <button
          type="button"
          className="btn"
          style={{ fontSize: 12 }}
          onClick={() => setCreating(true)}
        >
          ＋ 新建
        </button>
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

      <LayerUploadRow
        label="walk 分层 sheet"
        path={entry.walk}
        status={layerStatus(entry.walk, assetStore)}
        onFile={(f) => handleUpload('walk', f)}
      />
      <LayerUploadRow
        label="idle 分层 sheet"
        path={entry.idle}
        status={layerStatus(entry.idle, assetStore)}
        onFile={(f) => handleUpload('idle', f)}
      />

      <p className="muted" style={{ fontSize: 11, margin: 0 }}>
        {gridHint} · 上传后立即参与合成预览
      </p>

      <button type="button" className="btn" style={{ color: 'crimson' }} onClick={handleDelete}>
        删除此单品
      </button>
    </div>
  )
}

function LayerUploadRow({
  label,
  path,
  status,
  onFile,
}: {
  label: string
  path: string
  status: string
  onFile: (file: File | null) => void
}) {
  return (
    <div
      style={{
        border: '1px dashed #ddd',
        borderRadius: 8,
        padding: 10,
        fontSize: 12,
      }}
    >
      <div style={{ fontWeight: 600, marginBottom: 4 }}>{label}</div>
      <code style={{ fontSize: 10, wordBreak: 'break-all' }}>{path}</code>
      <p className="muted" style={{ margin: '6px 0', fontSize: 11 }}>
        {status}
      </p>
      <input
        type="file"
        accept="image/png,image/webp"
        onChange={(e) => onFile(e.target.files?.[0] ?? null)}
      />
    </div>
  )
}
