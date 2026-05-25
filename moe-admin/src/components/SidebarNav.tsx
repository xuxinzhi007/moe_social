import { useCallback, useEffect, useMemo, useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import {
  ADMIN_MENU_TREE,
  SIDEBAR_EXTERNAL_LINKS,
  type MenuEntry,
  type MenuGroup,
  type MenuItem,
  type MenuStatus,
} from '../config/menu'

const LS_OPEN = 'moe_admin_nav_open_v1'

function loadOpenState(): Record<string, boolean> {
  try {
    const raw = localStorage.getItem(LS_OPEN)
    if (!raw) return {}
    return JSON.parse(raw) as Record<string, boolean>
  } catch {
    return {}
  }
}

function saveOpenState(state: Record<string, boolean>) {
  localStorage.setItem(LS_OPEN, JSON.stringify(state))
}

function statusLabel(status: MenuStatus | undefined) {
  if (status === 'ready') return null
  if (status === 'partial') return '部分'
  return '待开发'
}

function itemActive(pathname: string, to: string, end?: boolean) {
  if (end || to === '/') {
    return pathname === to || pathname === `${to}/`
  }
  return pathname === to || pathname.startsWith(`${to}/`)
}

function groupHasActive(group: MenuGroup, pathname: string) {
  return group.children.some((c) => itemActive(pathname, c.to, c.end))
}

type SidebarNavProps = {
  legacyHref: string
  devtoolsHref: string
}

export function SidebarNav({ legacyHref, devtoolsHref }: SidebarNavProps) {
  const location = useLocation()
  const pathname = location.pathname

  const defaultOpen = useMemo(() => {
    const init: Record<string, boolean> = {}
    for (const entry of ADMIN_MENU_TREE) {
      if (entry.kind === 'group') {
        init[entry.id] =
          entry.defaultOpen === true || groupHasActive(entry, pathname)
      }
    }
    return init
  }, [pathname])

  const [openMap, setOpenMap] = useState<Record<string, boolean>>(() => ({
    ...defaultOpen,
    ...loadOpenState(),
  }))

  useEffect(() => {
    setOpenMap((prev) => {
      const next = { ...prev }
      for (const entry of ADMIN_MENU_TREE) {
        if (entry.kind === 'group' && groupHasActive(entry, pathname)) {
          next[entry.id] = true
        }
      }
      return next
    })
  }, [pathname])

  const toggleGroup = useCallback((id: string) => {
    setOpenMap((prev) => {
      const next = { ...prev, [id]: !prev[id] }
      saveOpenState(next)
      return next
    })
  }, [])

  function renderItem(item: MenuItem, topLevel = false) {
    const badge = statusLabel(item.status)
    const active = itemActive(pathname, item.to, item.end)
    const planned = item.status === 'planned'
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end === true}
        className={`nav-item${topLevel ? ' nav-item-top' : ' nav-item-child'}${active ? ' active' : ''}${
          planned ? ' nav-item-planned' : ' nav-item-ready'
        }`}
        title={item.appDomain ? `App: ${item.appDomain}` : undefined}
      >
        {item.icon ? (
          <span className="nav-item-icon" aria-hidden>
            {item.icon}
          </span>
        ) : topLevel ? null : (
          <span className="nav-item-dot" aria-hidden />
        )}
        <span className="nav-item-label">{item.label}</span>
        {badge ? <span className="nav-badge">{badge}</span> : null}
      </NavLink>
    )
  }

  function renderEntry(entry: MenuEntry) {
    if (entry.kind === 'item') {
      return renderItem(entry, true)
    }
    if (entry.kind === 'group') {
      const open = openMap[entry.id] ?? false
      const activeInGroup = groupHasActive(entry, pathname)
      return (
        <div
          key={entry.id}
          className={`nav-group${open ? ' is-open' : ''}${activeInGroup ? ' has-active' : ''}`}
        >
          <button
            type="button"
            className="nav-group-head"
            onClick={() => toggleGroup(entry.id)}
            aria-expanded={open}
          >
            <span className="nav-group-chevron" aria-hidden>
              {open ? '▾' : '▸'}
            </span>
            {entry.icon ? (
              <span className="nav-group-icon" aria-hidden>
                {entry.icon}
              </span>
            ) : null}
            <span className="nav-group-text">
              <span className="nav-group-title">{entry.label}</span>
              {entry.caption ? (
                <span className="nav-group-caption">{entry.caption}</span>
              ) : null}
            </span>
          </button>
          {open ? (
            <div className="nav-group-body">{entry.children.map((child) => renderItem(child))}</div>
          ) : null}
        </div>
      )
    }
    return null
  }

  return (
    <nav className="sidebar-nav">
      {ADMIN_MENU_TREE.map(renderEntry)}
      <div className="nav-external">
        <div className="nav-section">外链工具</div>
        {SIDEBAR_EXTERNAL_LINKS.map((link) => {
          const href =
            link.href === '__LEGACY__'
              ? legacyHref
              : link.href === '__DEVTOOLS__'
                ? devtoolsHref
                : link.href
          return (
            <a
              key={link.label}
              className="tool-link"
              href={href}
              target="_blank"
              rel="noopener noreferrer"
            >
              {link.label} ↗
            </a>
          )
        })}
      </div>
    </nav>
  )
}
