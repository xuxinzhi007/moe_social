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

**曾参考的 gin-vue-admin 能力清单**（仓库内已删除上游拷贝）见：  
👉 **[gva-reference.md](./gva-reference.md)** · 历史整合笔记 **[moe-admin-gva-integration.md](./moe-admin-gva-integration.md)**

**完整后台设计方案（用户/菜单/公告/登录等）** 见：

👉 **[moe-admin-platform-design.md](./moe-admin-platform-design.md)**

按 P0 → P1 分期实现；当前仓库已完成工作台、官网反馈、环境切换与跨平台启动脚本。

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
