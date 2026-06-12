// 页面路由定义 — 从 lib/app/app_routes.dart 提取
// 新增页面只需在这里加一行，冒烟测试会自动覆盖

export interface PageDef {
  name: string;           // 测试报告中的页面名称
  path: string;           // Flutter 命名路由
  needsAuth?: boolean;    // 是否需要登录
  allowErrors?: string[]; // 允许的 console 错误（某些第三方错误不可避免）
  // 验证要点：页面标题中至少包含一个关键字
  verifyKeywords?: string[];
}

export const PAGES: PageDef[] = [
  // ===== 公开页面（无需登录）=====
  { name: '登录页', path: '/login', verifyKeywords: ['登录', 'Login', 'login'] },
  { name: '注册页', path: '/register', verifyKeywords: ['注册', 'Register', '邮箱'] },
  { name: '忘记密码页', path: '/forgot-password', verifyKeywords: ['找回密码', '重置', '邮箱'] },
  { name: '主页(未登录跳登录)', path: '/home', needsAuth: false },

  // ===== 需要登录的页面 =====
  { name: '个人资料', path: '/profile', needsAuth: true },
  { name: '编辑资料', path: '/edit-profile', needsAuth: true },
  { name: '设置', path: '/settings', needsAuth: true, verifyKeywords: ['设置', 'Setting'] },
  { name: '消息保留设置', path: '/message-retention-settings', needsAuth: true },
  { name: '虚拟形象设置', path: '/virtual-avatar-settings', needsAuth: true },
  { name: '签到', path: '/checkin', needsAuth: true, verifyKeywords: ['签到', '连续'] },
  { name: '发帖页', path: '/create-post', needsAuth: true, verifyKeywords: ['发布', '发帖', '动态'] },
  { name: '通知中心', path: '/notifications', needsAuth: true },
  { name: '公告', path: '/announcements', needsAuth: true },
  { name: '我的二维码', path: '/user-qr-code', needsAuth: true },
  { name: '好友列表', path: '/friends', needsAuth: true },
  { name: '消息中心', path: '/messages', needsAuth: true },
  { name: '社区首页', path: '/community', needsAuth: true },
  { name: '积分记录', path: '/achievements', needsAuth: true },
  { name: 'VIP 中心', path: '/vip-center', needsAuth: true },
  { name: '钱包', path: '/wallet', needsAuth: true },
  { name: '充值', path: '/recharge', needsAuth: true },
  { name: '订单中心', path: '/orders', needsAuth: true },
  { name: '扭蛋', path: '/gacha', needsAuth: true },
  { name: '扫码', path: '/scan', needsAuth: true },
  { name: '云端图库', path: '/cloud-gallery', needsAuth: true },
  { name: '匹配页', path: '/match', needsAuth: true },
];

// 关键流程的入口路由
export const KEY_FLOWS = {
  LOGIN_FLOW: ['/login', '/home'],
  POST_FLOW: ['/login', '/home', '/create-post'],
  CHAT_FLOW: ['/login', '/home', '/messages'],
};
