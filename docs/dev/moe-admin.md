# Moe Admin 与 gin-vue-admin 选型说明

## 你的两个方向

| 方案 | 含义 | 是否推荐 |
|------|------|----------|
| **A. 直接接 gin-vue-admin** | 用开源 gin-vue-admin 的前后端整套 | ❌ 不适合当前仓库 |
| **B. 自建专用 Admin（当前路线）** | 类似 gin-vue-admin 的产品形态，技术栈沿用 **go-zero + React ops-console** | ✅ 推荐 |

## 为什么不建议「直接接 gin-vue-admin」

gin-vue-admin 是一整套 **Gin + GORM + Vue3 + Element Plus** 工程，自带：

- 自己的用户/角色/菜单/Casbin 权限模型
- 自己的代码生成器与目录结构
- 自己的 JWT 与 API 约定

而 Moe Social 后端是：

- **go-zero**（`super.api` / `super.proto`）
- 业务 RPC 分层、已有 Deploy Agent 网关
- 已有 App 用户体系，不是 gin-vue-admin 那套表结构

若硬接，只有三种做法，成本都很高：

1. **再跑一套 Gin 服务** — 双后端、双库，数据和登录都不统一。  
2. **只拿 gin-vue-admin 的 Vue 前端** — 几乎所有接口要重写对接 go-zero，等于 fork 一份 UI 后全盘改 API。  
3. **把 go-zero 改成 Gin** — 推翻现有架构，不现实。

所以：**不是语法问题，是后端契约与工程体系不一致**，无法像插件一样「接上就用」。

## 推荐：Moe Admin（专用管理台）

目标与 gin-vue-admin 相同：

- 侧边栏菜单 + 工作台
- 业务模块（官网反馈、统计…）
- 运维模块（构建、Docker、发布…）
- 统一入口、环境切换

实现上沿用你现在的栈：

```
管理台前端 (Vue Element Plus 或过渡期 React ops-console)
  →  Deploy Agent :19010  →  go-zero API :8888  →  RPC
```

这就是 **「gin-vue-admin 类产品形态，但后端仍是 go-zero」**，而不是引入 gin-vue-admin 的 Gin 服务。

**完整后台设计方案（用户/菜单/公告/登录等）** 见：

👉 **[moe-admin-platform-design.md](./moe-admin-platform-design.md)**

按 P0 → P1 分期实现；当前仓库已完成工作台、用户管理、环境切换与跨平台启动脚本（官网反馈查询端点已于 2026-10 删除，仅保留落地页提交）。

## 工作区与导航

管理台按「一个壳 + 三个工作区」组织（2026-07 第一期实施，Sprint A–E 已于 2026-08 全部完成），顶栏三段切换、点击固定落区首页，默认落运营区：

| 工作区 | URL 前缀 | 区首页 | 内容 |
|--------|----------|--------|------|
| 运营 | `/ops/biz/...` | `/ops/biz` | 用户 · 内容 · 触达 |
| AI | `/ops/ai/...` | `/ops/ai/moe-brain` | Bot · 大脑 · 工具 |
| 运维 | `/ops/infra/...` | `/ops/infra/deploy` | 后端发布 · 配置 · 审计（App 版本在运营 `/biz/update`） |

- **菜单 / 归属 / 旧链重定向的唯一 SSOT 是 `moe-admin/src/config/workspaceNav.ts`**，禁止第二份手写菜单；占位说明在 `moe-admin/src/config/placeholders.ts`。
- 旧 path 由前端重定向兜底（`LEGACY_REDIRECTS`，标注 `remove after 2026-12`）。
- 角色可见性：`super_admin` 见全部三区；`admin` 仅运营+AI（`lib/adminAccess.ts` + `RequireWorkspace`）。
- 后端菜单表驱动方案已废弃：`admin_menu` 模型与 `/api/admin/menus` 接口 2026-10 已删除（见 [cleanup-2026-10-15.md](./cleanup-2026-10-15.md)），侧栏为前端静态配置。

## 模块索引（与 App 业务域对照）

实时菜单结构以 `workspaceNav.ts` 为准；下表按工作区给出模块与 App 域（`lib/pages`）的对应关系。新增模块：先改域 proto + `/api/admin/*` 路由，再在对应工作区挂列表页。

| 工作区 · 分组 | 菜单项 | App 域 |
|---------------|--------|--------|
| 运营 · 工作台 | 工作台 | — |
| 运营 · App 用户 | 用户列表 · 会员与套餐 · 钱包与订单 · 签到/等级/成就 · 好友与关注 | profile, auth, commerce, wallet, checkin, discover |
| 运营 · 养成内容 | 内容总览 · 序列帧工作台 · 家具 · 装饰（规划） | pet（见 [moe-avatar-admin.md](./moe-avatar-admin.md)） |
| 运营 · 内容运营 | 动态审核 · 评论管理 · 兴趣社区 · 举报处理 · 公告管理 · App 版本更新 · 通知推送 | feed, community, report, notification |
| 运营 · 商业与数据 | 礼物与扭蛋 · 统一标签中心 · 数据分析看板 · 云图库 | gifts, gacha |
| AI | AI 大脑 · AI 角色酒馆 · 社区 AI Bot · Bot 编排画布 · Moe 工具与 Bot · AI 对话日志 | ai, moe |
| 运维 · 平台治理 | 平台治理 · 管理员账号 · 操作日志 | admin_account, audit |
| 运维 · 构建与发布 | 云 Docker · 构建流水线 · GitHub APK 构建 · 任务审计 | Deploy Agent |
| 运维 · 开发工具 | CodeGraph | — |

登录注册、个人设置、扫码、演示页、AutoGLM 工具等属用户端或开发工具，不进管理台菜单。

## 功能文档索引

| 文档 | 内容 | 状态 |
|------|------|------|
| [moe-admin-platform-design.md](./moe-admin-platform-design.md) | 完整后台设计方案（鉴权、数据模型、API 规范） | 历史设计稿，产品定位部分仍有效（见文首横幅） |
| [moe-avatar-admin.md](./moe-avatar-admin.md) | 角色装扮 / 序列帧生产力工具（sprite-studio） | ✅ 已落地（`/ops/biz/pet/avatar`） |
| [moe-admin-memory-center-design.md](./moe-admin-memory-center-design.md) | 记忆中心（全站 / 按 Agent 双 Tab） | ⚠️ 未实施，后端前提已失效（见文首横幅） |

## 数据库迁移 vs 运营数据初始化

| 操作 | 命令 / 入口 | 作用 |
|------|-------------|------|
| **仅建表** | `cd backend && make db-migrate`（= `go run ./cmd/migrate`） | GORM AutoMigrate，**不**写入 VIP/礼物/成就等业务数据 |
| **首次超管** | 同上 `make db-migrate`（读 `admin.bootstrap.username` / `password`） | 迁移末尾执行：**仅当 `admin_accounts` 从未有过任何行**时创建 super_admin（口令经 bcrypt 落库），随后登录 Moe Admin |
| **运营目录** | Moe Admin 内「导入默认套餐/礼物」等 | 表为空时幂等导入；日常改价改文案走 CRUD |

成就定义：`POST /api/admin/achievements/bootstrap`（需 Admin Token，表为空时）。

> ⚠️ **不要再加回 `POST /api/admin/bootstrap/account`。** 该端点曾与 `/api/admin/login` 一起被
> `internal/server/auth.go` 列进免鉴权白名单，而 `AdminBootstrapAccountReq` 是**空消息**
> （没有任何字段能携带校验凭据），biz 层还写着 `_ = in`。后果是：只要 `admin_accounts`
> 为空，任何人都能 POST 一次造出 super_admin 再登录拿全权 token；又因为 `Count` 不含软删行，
> 把管理员全部软删即可**重新打开**这个洞。2026-09-16 已连同 RPC、消息、白名单条目、
> `utils.BootstrapAdminAccount` 一并删除，改由迁移在运维本地触发。
> 另：`admin.bootstrap.password` 未配置时**不再有 `admin123` 兜底**，迁移会打印
> `[admin] !! 未创建默认超管` 并跳过，管理后台因此无法登录 —— 这是刻意的响亮失败。

## 启动方式（跨平台）

### macOS / Linux

```bash
chmod +x scripts/start-admin.sh scripts/stop-admin.sh
./scripts/start-admin.sh
```

浏览器：**http://127.0.0.1:5173/ops/login**（Moe Admin 开发服）

Deploy Agent 在后台 `:19010`（仅运维 API，不托管管理台页面）。  
日志：`.run/admin/*.log` · 停止：`./scripts/stop-admin.sh`

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start-admin.ps1
```

### 分工（推荐）

| 场景 | 命令 |
|------|------|
| 用户/反馈等业务 | RPC + API + `cd moe-admin && npm run dev` |
| 构建/发布/Docker/RPC 监控 | 再加 `make deploy-agent` |
| 生产发布 | `cd moe-admin && npm run build`，自行托管 `dist/` |

```bash
cd backend && make deploy-agent   # 仅网关，不打开管理台页面
```

## 若坚持要用 Vue

可以新建 `admin-console-vue/`（Vue3 + Vite + Element Plus），**仍通过同一 Deploy Agent 与 `/api/admin/*` 对接**，不必上 gin-vue-admin 的 Gin 后端。

与继续打磨 `ops-console`（React）相比：多维护一套前端，收益主要是「语法换成 Vue」，业务接口层是一样的。

建议：**除非团队只熟悉 Vue，否则继续用 React ops-console 作为 Moe Admin 唯一前端。**

## 配置要点

`backend/deploy/config.yaml`：

```yaml
targets:
  - id: local
    kind: local
    api_base_url: "http://127.0.0.1:8888"
  - id: cloud
    kind: ssh
    api_base_url: "http://47.106.175.49:8888"
```

管理台顶栏「数据环境」在 local / cloud 间切换，无需改代码。
