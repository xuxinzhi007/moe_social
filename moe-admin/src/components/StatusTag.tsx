import { statusLabel } from '../lib/jobTarget'

export function StatusTag({ status }: { status: string }) {
  const s = (status || '').toLowerCase()
  const cls =
    s === 'succeeded'
      ? 'tag-ok'
      : s === 'failed'
        ? 'tag-fail'
        : s === 'running'
          ? 'tag-run'
          : 'tag-pending'
  return <span className={`tag ${cls}`}>{statusLabel(status)}</span>
}
