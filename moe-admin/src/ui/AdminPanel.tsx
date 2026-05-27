import type { ReactNode } from 'react'

type AdminPanelProps = {
  children: ReactNode
  className?: string
}

export function AdminPanel({ children, className = '' }: AdminPanelProps) {
  return <div className={`panel admin-panel${className ? ` ${className}` : ''}`}>{children}</div>
}
