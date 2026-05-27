export type PageTabItem<T extends string> = {
  key: T
  label: string
  hint?: string
}

type PageTabsProps<T extends string> = {
  tabs: PageTabItem<T>[]
  active: T
  onChange: (key: T) => void
  className?: string
}

/** 全站统一 Tab 导航（与平台治理 / Moe 工具同款样式） */
export function PageTabs<T extends string>({
  tabs,
  active,
  onChange,
  className = '',
}: PageTabsProps<T>) {
  return (
    <div className={`platform-tab-rail${className ? ` ${className}` : ''}`}>
      {tabs.map((t) => (
        <button
          key={t.key}
          type="button"
          className={`platform-tab-pill${active === t.key ? ' is-active' : ''}`}
          onClick={() => onChange(t.key)}
        >
          <span className="platform-tab-label">{t.label}</span>
          {t.hint ? <span className="platform-tab-hint">{t.hint}</span> : null}
        </button>
      ))}
    </div>
  )
}
