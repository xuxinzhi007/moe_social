import type { ReactNode } from 'react'

type AdminFormDrawerProps = {
  open: boolean
  title: string
  subtitle?: string
  error?: string
  saving?: boolean
  onClose: () => void
  onSave: () => void
  saveLabel?: string
  children: ReactNode
}

export function AdminFormDrawer({
  open,
  title,
  subtitle,
  error,
  saving = false,
  onClose,
  onSave,
  saveLabel = '保存',
  children,
}: AdminFormDrawerProps) {
  if (!open) return null

  return (
    <div className="drawer-backdrop" onClick={onClose}>
      <aside
        className="drawer"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="drawer-head">
          <div>
            <h3>{title}</h3>
            {subtitle ? <p className="drawer-subtitle">{subtitle}</p> : null}
          </div>
          <button type="button" className="btn btn-ghost drawer-close" onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="drawer-body">
          {error ? <p className="drawer-error">{error}</p> : null}
          {children}
        </div>
        <div className="drawer-foot">
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            取消
          </button>
          <button
            type="button"
            className="btn btn-primary"
            disabled={saving}
            onClick={onSave}
          >
            {saving ? '保存中…' : saveLabel}
          </button>
        </div>
      </aside>
    </div>
  )
}
