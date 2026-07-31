# Moe Admin 工作区改造（第一期）

> 状态：实施中 · 2026-07  
> 前端 SSOT：`moe-admin/src/config/workspaceNav.ts`

## 背景

管理台菜单把运营、AI、运维堆在同一侧栏，学习成本高、不像正规后台。  
第一期用「一个壳 + 三个工作区」切开，默认只暴露运营路径。

## 方案

| 工作区 | Tab | URL 前缀 | 区首页 |
|--------|-----|----------|--------|
| 运营 | 运营 | `/ops/biz/...` | `/ops/biz` |
| AI | AI | `/ops/ai/...` | `/ops/ai/moe-brain` |
| 运维 | 运维 | `/ops/infra/...` | `/ops/infra/deploy`（后端发布；App 版本在运营 `/biz/update`） |

- 顶栏三段切换；点 Tab 固定落区首页。  
- 三 Tab 全员可见；按角色隐藏留 P2。  
- 旧 path 前端重定向，标注 `remove after 2026-12`。  
- 菜单 / 归属 / 重定向同一 SSOT，禁止第二份手写菜单。

## 第一期范围

1. 壳：切换器 + 分区侧栏 + 前缀路由 + 旧链重定向  
2. 样板页：`UsersPage`（列表）· `MoeBrainPage`（配置）· `OverviewPage`（监控）  
3. 其余页：只搬家换 path，不重做布局  

## Sprint A（2026-08）「像控制台」

1. CSS 单体迁入 `moe-admin/src/styles/legacy/`，`index.css` 按架构排序 import  
2. 侧栏图标：`AdminIcon` 替 emoji（`workspaceNav` + `SidebarNav`）  
3. 运维页骨架：Docker / Build / Release / Jobs → `MonitorPageLayout`  

## Sprint B（2026-08）「像组织」

1. 角色可见性：`super_admin` → 运营+AI+运维；`admin` → 仅运营+AI（`lib/adminAccess.ts` + `RequireWorkspace`）  
2. 运营工作台：KPI（用户 / 举报 / 反馈 / API）+ 待办卡片；快捷入口按角色过滤  
3. 运维总览补充文档边界说明  

## Sprint C（2026-08）「像产品」

1. 列表筛选：公告状态 / 礼物分类 / 审计资源 → `AdminFilterPills`  
2. 后端：`/api/admin/accounts*` 写读要求 `super_admin`（`requireSuperAdmin`）  
3. 设置抽屉：非超管隐藏 Deploy Token；删除未挂路由死页（Placeholder / AppConfig / DataCatalog） 

## 回滚

还原 `App.tsx` / `SidebarNav` / `workspaceNav.ts`，去掉顶栏切换即可；旧书签在重定向期内仍可用。
