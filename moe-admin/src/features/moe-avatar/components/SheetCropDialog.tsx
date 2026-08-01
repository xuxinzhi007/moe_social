import { createPortal } from 'react-dom'
import { SheetCropEditor, type SheetCropEditorProps } from './SheetCropEditor'

type Props = SheetCropEditorProps & {
  open: boolean
}

/** 浮层裁剪（备用）；生产区优先用 inline SheetCropEditor */
export function SheetCropDialog({ open, onCancel, ...rest }: Props) {
  if (!open) return null
  return createPortal(
    <div
      role="dialog"
      aria-modal
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 99999,
        background: 'rgba(0,0,0,0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
      onClick={onCancel}
    >
      <div onClick={(e) => e.stopPropagation()}>
        <SheetCropEditor {...rest} variant="modal" onCancel={onCancel} />
      </div>
    </div>,
    document.body,
  )
}
