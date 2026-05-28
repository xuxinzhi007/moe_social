/** 菜单就绪状态：ready 可进；partial 有部分能力；planned 仅占位 */
export type MenuStatus = 'ready' | 'partial' | 'planned'

export type MenuItem = {
  kind: 'item'
  to: string
  label: string
  end?: boolean
  status?: MenuStatus
  /** 侧栏图标（emoji / 单字符） */
  icon?: string
  /** 对应 App / lib/pages 域，便于对照 */
  appDomain?: string
}

export type MenuGroup = {
  kind: 'group'
  id: string
  label: string
  /** 侧栏图标（emoji / 单字符） */
  icon?: string
  /** 侧栏分组说明（可选） */
  caption?: string
  defaultOpen?: boolean
  children: MenuItem[]
}

export type MenuExternalLink = {
  kind: 'link'
  label: string
  href: string
  external?: boolean
}

export type MenuEntry = MenuItem | MenuGroup | MenuExternalLink

/**
 * 与 Flutter App（lib/pages）及 moe-admin-platform-design 对齐的侧栏结构。
 * ready = 已有页面+接口；planned = 规划项，点击进占位说明页。
 */
export const ADMIN_MENU_TREE: MenuEntry[] = [
  {
    kind: 'item',
    to: '/',
    label: '工作台',
    icon: '🏠',
    end: true,
    status: 'ready',
    appDomain: 'dashboard',
  },
  {
    kind: 'group',
    id: 'app-users',
    label: 'App 用户',
    icon: '👤',
    caption: '账号 · 会员 · 成长',
    defaultOpen: true,
    children: [
      {
        kind: 'item',
        to: '/users',
        label: '用户列表',
        status: 'ready',
        appDomain: 'profile / auth',
      },
      {
        kind: 'item',
        to: '/vip/plans',
        label: '会员与套餐',
        status: 'ready',
        appDomain: 'commerce / vip',
      },
      {
        kind: 'item',
        to: '/wallet/orders',
        label: '钱包与订单',
        status: 'ready',
        appDomain: 'commerce / wallet',
      },
      {
        kind: 'item',
        to: '/app/growth',
        label: '签到 · 等级 · 成就',
        status: 'ready',
        appDomain: 'checkin / level / achievements',
      },
      {
        kind: 'item',
        to: '/app/social',
        label: '好友与关注',
        status: 'ready',
        appDomain: 'discover / friend',
      },
    ],
  },
  {
    kind: 'group',
    id: 'app-content',
    label: '内容与社区',
    icon: '📝',
    caption: '动态 · 社区 · 审核',
    defaultOpen: false,
    children: [
      {
        kind: 'item',
        to: '/content/posts',
        label: '动态审核',
        status: 'ready',
        appDomain: 'feed',
      },
      {
        kind: 'item',
        to: '/content/comments',
        label: '评论管理',
        status: 'ready',
        appDomain: 'feed / comments',
      },
      {
        kind: 'item',
        to: '/content/community',
        label: '兴趣社区',
        status: 'ready',
        appDomain: 'community',
      },
      {
        kind: 'item',
        to: '/content/reports',
        label: '举报处理',
        status: 'ready',
        appDomain: 'feed / report',
      },
    ],
  },
  {
    kind: 'group',
    id: 'app-ops',
    label: '运营触达',
    icon: '📢',
    caption: '官网 · 公告 · 推送',
    defaultOpen: true,
    children: [
      {
        kind: 'item',
        to: '/feedback',
        label: '官网反馈',
        status: 'ready',
        appDomain: 'website / landing',
      },
      {
        kind: 'item',
        to: '/app/announcements',
        label: '公告管理',
        status: 'ready',
        appDomain: '—',
      },
      {
        kind: 'item',
        to: '/app/notify',
        label: '通知推送',
        status: 'ready',
        appDomain: 'notification',
      },
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
      {
        kind: 'item',
        to: '/app/ai',
        label: 'AI 角色酒馆',
        status: 'ready',
        appDomain: 'ai',
      },
      {
        kind: 'item',
        to: '/app/moe-bots',
        label: '社区 AI Bot',
        status: 'ready',
        appDomain: 'moe / bot',
      },
      {
        kind: 'item',
        to: '/app/moe-brain?agent=moe_guide',
        label: 'AI 大脑',
        status: 'ready',
        appDomain: 'moe / brain',
      },
      {
        kind: 'item',
        to: '/app/moe-flow?agent=moe_guide',
        label: 'Bot 编排画布',
        status: 'ready',
        appDomain: 'moe / flow · OpenClaw 式',
      },
      {
        kind: 'item',
        to: '/app/moe',
        label: 'Moe 工具与 Bot',
        status: 'ready',
        appDomain: 'moe — 概览 / 工具 / 调用',
      },
      {
        kind: 'item',
        to: '/app/ai/chat-logs',
        label: 'AI 对话日志',
        status: 'ready',
        appDomain: 'ai / audit',
      },
      {
        kind: 'item',
        to: '/app/analytics',
        label: '数据分析看板',
        status: 'ready',
        appDomain: 'analytics',
      },
      {
        kind: 'item',
        to: '/app/tags',
        label: '统一标签中心',
        status: 'ready',
        appDomain: 'tags',
      },
      {
        kind: 'item',
        to: '/gifts/catalog',
        label: '礼物与扭蛋',
        status: 'ready',
        appDomain: 'gacha / gifts',
      },
    ],
  },
  {
    kind: 'group',
    id: 'system',
    label: '系统管理',
    icon: '⚙️',
    caption: '账号 · 菜单 · 审计',
    defaultOpen: false,
    children: [
      {
        kind: 'item',
        to: '/system/platform',
        label: '平台治理',
        status: 'ready',
        appDomain: 'platform',
      },
      {
        kind: 'item',
        to: '/system/admins',
        label: '管理员账号',
        status: 'ready',
        appDomain: 'admin_account',
      },
      {
        kind: 'item',
        to: '/system/menus',
        label: '侧栏菜单配置',
        status: 'ready',
        appDomain: 'admin_menu',
      },
      {
        kind: 'item',
        to: '/system/audit',
        label: '操作日志',
        status: 'ready',
        appDomain: 'admin_audit_log',
      },
    ],
  },
  {
    kind: 'group',
    id: 'devops',
    label: '运维与监控',
    icon: '🚀',
    caption: '构建 · 发布 · Agent',
    defaultOpen: false,
    children: [
      {
        kind: 'item',
        to: '/deploy',
        label: '运维总览',
        status: 'ready',
        appDomain: '—',
      },
      { kind: 'item', to: '/docker', label: '云 Docker', status: 'ready' },
      { kind: 'item', to: '/build', label: '构建流水线', status: 'ready' },
      { kind: 'item', to: '/release', label: '应用发布', status: 'ready' },
      { kind: 'item', to: '/jobs', label: '任务审计', status: 'ready' },
      {
        kind: 'item',
        to: '/rpc',
        label: 'RPC 监控',
        status: 'ready',
        appDomain: '—',
      },
    ],
  },
]

export const SIDEBAR_EXTERNAL_LINKS: MenuExternalLink[] = [
  { kind: 'link', label: '经典 HTML 运维', href: '__LEGACY__', external: true },
  {
    kind: 'link',
    label: '记忆系统监控',
    href: '__DEVTOOLS__',
    external: true,
  },
]

/** 扁平列表（兼容旧逻辑：判断是否业务首页隐藏 banner） */
export function flattenMenuItems(
  tree: MenuEntry[] = ADMIN_MENU_TREE,
): MenuItem[] {
  const out: MenuItem[] = []
  for (const entry of tree) {
    if (entry.kind === 'item') out.push(entry)
    else if (entry.kind === 'group') out.push(...entry.children)
  }
  return out
}

export const READY_ROUTES = new Set(
  flattenMenuItems().filter((i) => i.status === 'ready').map((i) => i.to),
)
