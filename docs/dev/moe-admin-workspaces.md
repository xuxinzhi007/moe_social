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
| 运维 | 运维 | `/ops/infra/...` | `/ops/infra/deploy` |

- 顶栏三段切换；点 Tab 固定落区首页。  
- 三 Tab 全员可见；按角色隐藏留 P2。  
- 旧 path 前端重定向，标注 `remove after 2026-12`。  
- 菜单 / 归属 / 重定向同一 SSOT，禁止第二份手写菜单。

## 第一期范围

1. 壳：切换器 + 分区侧栏 + 前缀路由 + 旧链重定向  
2. 样板页：`UsersPage`（列表）· `MoeBrainPage`（配置）· `OverviewPage`（监控）  
3. 其余页：只搬家换 path，不重做布局  

## 回滚

还原 `App.tsx` / `SidebarNav` / `workspaceNav.ts`，去掉顶栏切换即可；旧书签在重定向期内仍可用。
