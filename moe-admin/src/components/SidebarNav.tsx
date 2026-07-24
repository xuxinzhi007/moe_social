import { useEffect, useMemo, useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'

type NavItem = {
  kind: 'item'
  to: string
  label: string
  end?: boolean
  icon?: string
  title?: string
}

type NavGroup = {
  kind: 'group'
  id: string
  label: string
  icon?: string
  caption?: string
  defaultOpen?: boolean
  children: NavItem[]
}

type NavEntry = NavItem | NavGroup

const NAV_TREE: NavEntry[] = [
  {
    kind: 'item',
    to: '/',
    label: '工作台',
    icon: '🏠',
    end: true,
    title: '管理员首页',
  },
  {
    kind: 'group',
    id: 'app-users',
    label: 'App 用户',
    icon: '👤',
    caption: '账号 · 会员 · 成长',
    defaultOpen: true,
    children: [
      { kind: 'item', to: '/users', label: '用户列表', title: '用户与账号管理' },
      { kind: 'item', to: '/vip/plans', label: '会员与套餐', title: 'VIP 套餐管理' },
      { kind: 'item', to: '/wallet/orders', label: '钱包与订单', title: '钱包与订单管理' },
      { kind: 'item', to: '/app/growth', label: '签到 · 等级 · 成就', title: '成长体系管理' },
      { kind: 'item', to: '/app/social', label: '好友与关注', title: '关系链管理' },
    ],
  },
  {
    kind: 'group',
    id: 'content-ops',
    label: '内容运营',
    icon: '📝',
    caption: '动态 · 社区 · 公告',
    defaultOpen: false,
    children: [
      { kind: 'item', to: '/content/posts', label: '动态审核', title: '动态内容审核' },
      { kind: 'item', to: '/content/comments', label: '评论管理', title: '评论内容审核' },
      { kind: 'item', to: '/content/community', label: '兴趣社区', title: '社区与圈子管理' },
      { kind: 'item', to: '/content/reports', label: '举报处理', title: '举报工单处理' },
      { kind: 'item', to: '/app/announcements', label: '公告管理', title: 'App 公告管理' },
      { kind: 'item', to: '/app/notify', label: '通知推送', title: '通知广播' },
    ],
  },
  {
    kind: 'group',
    id: 'app-play',
    label: 'AI 与玩法',
    icon: '🎮',
    caption: '酒馆 · 礼物 · 工具',
    defaultOpen: false,
    children: [
      { kind: 'item', to: '/app/ai', label: 'AI 角色酒馆', title: 'AI 角色管理' },
      { kind: 'item', to: '/app/moe-bots', label: '社区 AI Bot', title: 'Bot 配置' },
      { kind: 'item', to: '/app/moe-brain', label: 'AI 大脑', title: '脑图与推理监控' },
      { kind: 'item', to: '/app/moe-flow', label: 'Bot 编排画布', title: 'Bot 流程编排' },
      { kind: 'item', to: '/app/moe', label: 'Moe 工具与 Bot', title: 'Moe 工具总览' },
      { kind: 'item', to: '/app/ai/chat-logs', label: 'AI 对话日志', title: 'AI 审计日志' },
      { kind: 'item', to: '/app/analytics', label: '数据分析看板', title: '分析看板' },
      { kind: 'item', to: '/app/tags', label: '统一标签中心', title: '标签与分类' },
      { kind: 'item', to: '/gifts/catalog', label: '礼物与扭蛋', title: '礼物与扭蛋管理' },
    ],
  },
  {
    kind: 'group',
    id: 'system-ops',
    label: '系统运维',
    icon: '⚙️',
    caption: '账号 · 图库 · 发布',
    defaultOpen: false,
    children: [
      { kind: 'item', to: '/system/media-gallery', label: '云图库', title: '媒体资源管理' },
      { kind: 'item', to: '/system/platform', label: '平台治理', title: '平台配置与数据地图' },
      { kind: 'item', to: '/system/admins', label: '管理员账号', title: '管理员管理' },
      { kind: 'item', to: '/system/audit', label: '操作日志', title: '后台操作日志' },
      { kind: 'item', to: '/deploy', label: '运维总览', title: '部署总览' },
      { kind: 'item', to: '/docker', label: '云 Docker', title: 'Docker 管理' },
      { kind: 'item', to: '/build', label: '构建流水线', title: '构建任务' },
      { kind: 'item', to: '/release', label: '应用发布', title: '发布任务' },
      { kind: 'item', to: '/jobs', label: '任务审计', title: '任务列表' },
    ],
  },
]

function itemActive(pathname: string, to: string, end?: boolean) {
  if (end || to === '/') {
    return pathname === to || pathname === `${to}/`
  }
  return pathname === to || pathname.startsWith(`${to}/`)
}

function groupHasActive(group: NavGroup, pathname: string) {
  return group.children.some((c) => itemActive(pathname, c.to, c.end))
}

export function SidebarNav() {
  const location = useLocation()
  const pathname = location.pathname

  const initialOpen = useMemo(() => {
    const init: Record<string, boolean> = {}
    for (const entry of NAV_TREE) {
      if (entry.kind === 'group') {
        init[entry.id] = entry.defaultOpen === true || groupHasActive(entry, pathname)
      }
    }
    return init
  }, [pathname])

  const [openMap, setOpenMap] = useState<Record<string, boolean>>(initialOpen)

  useEffect(() => {
    setOpenMap((prev) => {
      const next = { ...prev }
      for (const entry of NAV_TREE) {
        if (entry.kind === 'group' && groupHasActive(entry, pathname)) {
          next[entry.id] = true
        }
      }
      return next
    })
  }, [pathname])

  function toggleGroup(id: string) {
    setOpenMap((prev) => ({ ...prev, [id]: !prev[id] }))
  }

  function renderItem(item: NavItem, topLevel = false) {
    const active = itemActive(pathname, item.to, item.end)
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end === true}
        className={`nav-item${topLevel ? ' nav-item-top' : ' nav-item-child'}${active ? ' active' : ''}`}
        title={item.title}
      >
        {item.icon ? (
          <span className="nav-item-icon" aria-hidden>
            {item.icon}
          </span>
        ) : topLevel ? null : (
          <span className="nav-item-dot" aria-hidden />
        )}
        <span className="nav-item-label">{item.label}</span>
      </NavLink>
    )
  }

  function renderEntry(entry: NavEntry) {
    if (entry.kind === 'item') {
      return renderItem(entry, true)
    }
    const open = openMap[entry.id] ?? false
    const activeInGroup = groupHasActive(entry, pathname)
    return (
      <div key={entry.id} className={`nav-group${open ? ' is-open' : ''}${activeInGroup ? ' has-active' : ''}`}>
        <button type="button" className="nav-group-head" onClick={() => toggleGroup(entry.id)} aria-expanded={open}>
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
            {entry.caption ? <span className="nav-group-caption">{entry.caption}</span> : null}
          </span>
        </button>
        {open ? <div className="nav-group-body">{entry.children.map((child) => renderItem(child))}</div> : null}
      </div>
    )
  }

  return <nav className="sidebar-nav">{NAV_TREE.map(renderEntry)}</nav>
}
