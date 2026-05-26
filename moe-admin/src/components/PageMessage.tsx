type PageMessageTone = 'ok' | 'err' | 'warn'

type Props = {
  message: string
  tone?: PageMessageTone
  onClose?: () => void
}

export function PageMessage({ message, tone = 'ok', onClose }: Props) {
  if (!message) return null
  const cls =
    tone === 'err'
      ? 'admin-hint admin-hint-err'
      : tone === 'warn'
        ? 'admin-hint admin-hint-warn'
        : 'admin-hint admin-hint-ok'
  return (
    <div className={cls} role="status">
      {message}
      {onClose ? (
        <button
          type="button"
          className="btn btn-ghost"
          style={{ marginLeft: 8, padding: '2px 8px' }}
          onClick={onClose}
        >
          关闭
        </button>
      ) : null}
    </div>
  )
}
