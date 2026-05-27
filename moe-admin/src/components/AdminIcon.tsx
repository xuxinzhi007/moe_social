type AdminIconName = 'bot' | 'data'

const ICONS: Record<AdminIconName, string[]> = {
  bot: [
    'M8 7V4h8v3',
    'M7 8h10a3 3 0 0 1 3 3v4a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3v-4a3 3 0 0 1 3-3Z',
    'M9 12h.01',
    'M15 12h.01',
    'M9 16h6',
  ],
  data: ['M4 18h16', 'M7 18V9', 'M12 18V5', 'M17 18v-7'],
}

type AdminIconProps = {
  name: AdminIconName
  className?: string
}

export function AdminIcon({ name, className = 'admin-icon' }: AdminIconProps) {
  const paths = ICONS[name]
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths.map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  )
}
