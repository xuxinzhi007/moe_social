# Moe Ops Console (React)

React 版运维部署台，对接本机 **Deploy Agent**（`:19010`）。现有 HTML 工具（`docs/dev/tools/deploy-ops.html` 等）保持不变，作为对照与回退。

## 开发

```bash
# 终端 1：Agent API
cd backend && make deploy-agent

# 终端 2：React 热更新（代理 /api → :19010）
cd ops-console && npm run dev
```

浏览器打开 http://127.0.0.1:5173/ops/ ，在 **连接设置** 中填写与 `backend/deploy/config.yaml` 一致的 Deploy Token。

## 生产（由 Agent 托管）

```bash
cd backend && make deploy-agent
```

会自动构建 `ops-console/dist`（若不存在）、启动 Agent，并打开浏览器到 http://127.0.0.1:19010/ops/ 。根路径 `/` 会跳转到 React；HTML 备用：http://127.0.0.1:19010/tools/deploy-ops.html

禁止自动打开浏览器：`set MOE_DEPLOY_NO_BROWSER=1`（Windows）或 `export MOE_DEPLOY_NO_BROWSER=1`（Mac/Linux）。

## 目录

- `src/api/` — Deploy Agent HTTP 客户端
- `src/context/` — 连接、Token、任务状态
- `src/pages/` — 总览 / Docker / 构建 / 发布 / RPC / 任务
- `src/layout/` — 侧栏与顶栏

## 文档

- 部署分工 SSOT：`docs/dev/deploy-platform.md`
- 端口表：`docs/dev/ports.md`
