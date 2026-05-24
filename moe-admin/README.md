# Moe Admin（React 管理后台）

Moe Social 专属管理台：浅色 Element 风格布局 + 现有 go-zero Admin API / Deploy Agent。

## 开发启动

| 终端 | 命令 |
|------|------|
| backend | RPC + API（你现有流程） |
| backend | `make deploy-agent`（**仅运维菜单需要**；登录/用户/反馈不必） |
| **本目录** | `npm install` → **`npm run dev`** |

**仅 RPC + API 时**：`npm run dev` 会通过 Vite 把 `/api/admin` 代理到 `:8888`，可直接登录。  
控制台里 Agent 相关报错可忽略，直到你要用构建/发布/RPC 监控再开 Agent。

浏览器：**http://127.0.0.1:5173/ops/**（登录 `/ops/login`）

生产构建（按需）：`npm run build` → `dist/`，由 CI 或静态服务器发布（Agent 不再托管 `/ops/`）

## 目录说明

由原 `ops-console/` 演进并重命名。若仓库中仍存在 `ops-console/`，可停掉占用进程后删除，统一使用本目录。

## 功能模块

- **业务**：工作台、App 用户、官网反馈（`X-Admin-Token`）
- **运维**：构建 / Docker / 发布 / 任务 / RPC（Deploy Token）

文档：[docs/dev/moe-admin.md](../docs/dev/moe-admin.md)
