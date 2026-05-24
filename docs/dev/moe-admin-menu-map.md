# Moe Admin 菜单与 App 业务域对照

> 侧栏配置：`moe-admin/src/config/menu.ts`  
> 占位说明：`moe-admin/src/config/placeholders.ts`

## 设计原则

1. **按 App 业务域分组**，不是按 gin-vue-admin 模板目录抄菜单。  
2. **可折叠分组**，默认只展开「App 用户」「运营触达」，避免侧栏过长。  
3. **ready** = 已有页面与 `/api/admin` 或 Deploy；**待开发** = 规划项，点击看说明。

## 菜单结构

| 分组 | 菜单项 | 状态 | App 域 (`lib/pages`) |
|------|--------|------|----------------------|
| — | 工作台 | ready | — |
| App 用户 | 用户列表 | ready | profile, auth |
| | 会员与套餐 | P1 | commerce, vip |
| | 钱包与订单 | P2 | wallet |
| | 签到·等级·成就 | P2 | checkin, level, achievements |
| 内容与社区 | 动态审核 | P2 | feed |
| | 评论管理 | P2 | feed |
| | 兴趣社区 | P2 | community |
| | 举报处理 | P2 | report |
| 运营触达 | 官网反馈 | ready | website |
| | 公告管理 | P1 | — |
| | 通知推送 | P1 | notification |
| AI 与玩法 | AI 角色酒馆 | P2 | ai |
| | 礼物与扭蛋 | P2 | gacha, gifts |
| | 好友与关注 | P2 | discover, friend |
| 系统管理 | 管理员账号 | P1 | admin_account |
| | 侧栏菜单配置 | P1 | admin_menu |
| | 操作日志 | P2 | audit |
| 运维与监控 | 运维总览…RPC | ready | Deploy Agent |

## 不建议进管理台的 App 模块

登录注册、个人设置、扫码、演示页、AutoGLM 工具等——属于用户端或开发工具，不做运营菜单。

## 下一步实现建议

1. **P1**：公告、通知推送、管理员账号 CRUD  
2. **P2**：动态/社区审核、钱包订单、AI/礼物运营视图  

每增一项：后端 `super.api` + RPC → `moe-admin` 列表页，并把对应菜单 `status` 改为 `ready`。
