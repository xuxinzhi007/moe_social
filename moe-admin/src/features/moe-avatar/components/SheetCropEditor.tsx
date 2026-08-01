import { useCallback, useEffect, useState } from 'react'
import type { SmartCropMode } from '../editor/sheetSmartCrop'
import { smartCropSheet } from '../editor/sheetSmartCrop'

export type SheetCropEditorProps = {
  file: File
  targetW: number
  targetH: number
  label: string
  onConfirm: (processed: Blob, original: File) => void
  onCancel: () => void
  /** inline=嵌入生产区；modal=浮层（备用） */
  variant?: 'inline' | 'modal'
}

const MODES: { id: SmartCropMode; label: string }[] = [
  { id: 'trim-scale', label: '智能（去透明边+等比）' },
  { id: 'center-cover', label: '居中铺满' },
  { id: 'top-left', label: '左上对齐' },
]

/** 智能裁剪 UI：原图 vs 裁剪结果对比 · 确认后写入 layers/ + 原图进 _originals/ */
export function SheetCropEditor({
  file,
  targetW,
  targetH,
  label,
  onConfirm,
  onCancel,
  variant = 'inline',
}: SheetCropEditorProps) {
  const [mode, setMode] = useState<SmartCropMode>('trim-scale')
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [originalUrl, setOriginalUrl] = useState<string | null>(null)
  const [desc, setDesc] = useState('')
  const [processing, setProcessing] = useState(false)
  const [pendingBlob, setPendingBlob] = useState<Blob | null>(null)

  const runPreview = useCallback(async () => {
    setProcessing(true)
    try {
      const result = await smartCropSheet(file, targetW, targetH, mode)
      setDesc(result.description)
      setPendingBlob(result.blob)
      const url = URL.createObjectURL(result.blob)
      setPreviewUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev)
        return url
      })
    } finally {
      setProcessing(false)
    }
  }, [file, targetW, targetH, mode])

  useEffect(() => {
    const url = URL.createObjectURL(file)
    setOriginalUrl(url)
    void runPreview()
    return () => URL.revokeObjectURL(url)
  }, [file, runPreview])

  useEffect(() => {
    void runPreview()
  }, [mode, runPreview])

  useEffect(
    () => () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl)
    },
    [previewUrl],
  )

  const boxStyle =
    variant === 'inline'
      ? {
          border: '2px solid #e97891',
          borderRadius: 12,
          padding: 14,
          background: '#fffafb',
          marginTop: 8,
        }
      : {
          background: '#fff',
          borderRadius: 12,
          padding: 20,
          maxWidth: 720,
          width: '100%',
          maxHeight: '90vh',
          overflow: 'auto',
        }

  return (
    <div style={boxStyle}>
      <h4 style={{ margin: '0 0 8px', color: '#5a4638' }}>
        智能裁剪 · {label}
      </h4>
      <p className="muted" style={{ fontSize: 12, margin: '0 0 10px' }}>
        目标 <strong>{targetW}×{targetH}px</strong> · 原图{' '}
        <strong>{file.name}</strong>（{file.size > 0 ? `${Math.round(file.size / 1024)}KB` : ''}）
        。右侧为<strong>最终 sheet 效果</strong>；确认后中间「实时合成」立即更新。
      </p>

      <div style={{ marginBottom: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        {MODES.map((m) => (
          <button
            key={m.id}
            type="button"
            className={`btn${mode === m.id ? ' primary' : ''}`}
            style={{ fontSize: 12 }}
            onClick={() => setMode(m.id)}
          >
            {m.label}
          </button>
        ))}
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 12,
          marginBottom: 10,
        }}
      >
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, marginBottom: 6, color: '#8a7364' }}>
            ① 原图（完整保留 → _originals/）
          </div>
          {originalUrl ? (
            <div
              style={{
                border: '1px solid #ddd',
                borderRadius: 8,
                padding: 4,
                background: '#fafafa',
                maxHeight: 220,
                overflow: 'auto',
              }}
            >
              <img
                src={originalUrl}
                alt="原图"
                style={{ maxWidth: '100%', imageRendering: 'pixelated', display: 'block' }}
              />
            </div>
          ) : null}
        </div>
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, marginBottom: 6, color: '#e97891' }}>
            ② 裁剪结果（→ layers/ · App 用这个）{processing ? ' 生成中…' : ''}
          </div>
          {previewUrl ? (
            <div
              style={{
                border: '2px solid #e97891',
                borderRadius: 8,
                padding: 4,
                background: 'linear-gradient(180deg,#fff8f2,#ffe8dc)',
                maxHeight: 220,
                overflow: 'auto',
              }}
            >
              <img
                src={previewUrl}
                alt="裁剪结果"
                style={{ maxWidth: '100%', imageRendering: 'pixelated', display: 'block' }}
              />
            </div>
          ) : (
            <p className="muted" style={{ fontSize: 11 }}>
              生成预览…
            </p>
          )}
        </div>
      </div>

      {desc ? (
        <p className="muted" style={{ fontSize: 11, margin: '0 0 10px' }}>
          {desc}
        </p>
      ) : null}

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button type="button" className="btn" onClick={onCancel}>
          取消
        </button>
        <button
          type="button"
          className="btn primary"
          disabled={!pendingBlob || processing}
          onClick={() => {
            if (pendingBlob) onConfirm(pendingBlob, file)
          }}
        >
          确认使用裁剪结果（保留原图）
        </button>
      </div>
    </div>
  )
}
