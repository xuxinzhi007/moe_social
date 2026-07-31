# Moe 部署平台（Deploy Agent + 管理台运维区）

在**本机**交叉编译后端单二进制；在**云 VPS** 的 `/root/gowork/backend` 用 Docker 跑 **`moe-social`**；**Flutter APK** 由 GitHub tag / Actions 构建，**不在 VPS 上编前端**。

> 手机 App「检查更新」元数据见 [app-release-cheatsheet.md](./app-release-cheatsheet.md)，与本文（后端部署）分开。

## 实际分工

| 环节 | 在哪里做 | 管理台 / 命令 |
|------|----------|----------------|
| 日常开发、联调 | 本机 | Flutter / `go run ./cmd/moe-social` |
| 后端 Linux 二进制 | 本机 Agent | `backend_build_linux` → `backend/bin/moe-social` |
| 上传到云 | Agent `backend_upload_binaries`（SFTP） | 本机 `bin/moe-social` → VPS `backend_dir/bin/`；默认停容器 → 上传 → 再启动 |
| 后端容器 | 云 VPS SSH | `docker_*` → `docker-compose.binary.yml` 服务 **`moe-social`**（:8888） |
| 持久化图片等 | 云路径 | `/root/gowork/moe_images`（compose 卷） |
| 前端 APK | GitHub | 推 `v*` tag → `flutter-release.yml`；运维区「GitHub APK 构建」可 `workflow_dispatch` |

```text
本机仓库 (moe_social)
  └─ make build-linux / Agent backend_build_linux
        └─ 上传 bin/moe-social ──►  /root/gowork/backend/bin/
                                        └─ docker compose up（容器 moe-social）
GitHub tag ──► Actions 打 APK（与 VPS 无关；可回写 app_releases）
```

## 管理台入口（moe-admin 运维区）

| 页面 | 路由 | 做什么 |
|------|------|--------|
| 运维总览 | `/infra/deploy` | 「一键发布（仅后端）」= 编 → 传 → 健康检查 |
| 构建流水线 | `/infra/build` | 本机交叉编译；Flutter 区仅调试 |
| 云 Docker | `/infra/docker` | SSH 管 compose / 容器 / 白名单配置 |
| GitHub APK 构建 | `/infra/release` | 触发 Actions；**不写** `app_releases` |
| 任务审计 | `/infra/jobs` | Agent 任务队列 |
| App 版本更新 | `/biz/update`（**运营区**） | 客户端更新元数据 / 强制更新 |

静态旧台（可选）：`docs/dev/tools/deploy-ops.html` → Agent `:19010`。

## 架构

```text
moe-admin 运维区 / deploy-ops.html  ──HTTP──►  Deploy Agent (:19010)
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
              本机 go build      云 SSH docker      GitHub API
              (local)            (cloud)            (APK 可选)
```

- **local**：`backend_build_linux`、`env_inspect`；可选 Flutter（本机调试）。
- **cloud**：`docker_*`、`remote-check`、`remote-config`；SSH 到 `targets.cloud.backend_dir`。
- Agent 按任务类型**自动**选 local/cloud。

## 路径配置（SSOT）

| 配置项 | 本机 | 云 VPS |
|--------|------|--------|
| `workspace_root` | 仓库根（相对 `deploy/config.yaml` 的 `../..`） | — |
| `backend_dir` | 相对路径 `backend` | **绝对路径** `/root/gowork/backend` |
| `compose_file` | `docker-compose.binary.yml` | 同上（在 VPS backend 目录内） |
| 镜像/数据卷 | — | `/root/gowork/moe_images` |

**不要**把云路径写成 `/root/gowork/moe_social/backend`，除非整仓克隆到 VPS。

## 云 Docker 检查

- 管理台「容器状态」= SSH 执行 `docker compose -f docker-compose.binary.yml ps`。
- 应看到容器 **`moe-social`**（映射 :8888），不再是旧的 `moe-social-api` / `moe-social-rpc`。
- **改 `deploy/config.yaml` 后必须重启 Agent**。

正确 compose：`/root/gowork/backend/docker-compose.binary.yml`

## 上传二进制（`backend_upload_binaries`）

1. 先 `backend_build_linux` → 本机 `backend/bin/moe-social`。
2. 再 `backend_upload_binaries`（云目标），默认：
   - **停止** compose 服务 `moe-social`
   - **SFTP** 上传到远程 `bin/moe-social`
   - **启动** `docker compose up -d`
   - 上传中途失败且已 stop 时，Agent 会尝试恢复 `up -d`
3. 一般不必再单独点「云 Docker Up」，除非首次部署或改了 compose。

### 一键发布（`backend_release_pipeline`）

运维总览 **「一键发布（仅后端）」** 串联：

1. 本机编 Linux（`bin/moe-social`）
2. 上传（停 → 传 → 启）
3. 检查容器 `moe-social` 健康；异常时拉 `docker logs`

**不含** GitHub APK、**不写** `app_releases`。

## 本机 Windows / macOS

Deploy Agent 在本机执行任务时按 OS 选 shell。详见历史约定：

- `windows_shell: auto`（推荐 Git Bash）
- Agent **不**依赖 `make build-linux` 的 Unix 一行写法，而是直接：

```text
go build -o bin/moe-social ./cmd/moe-social   （GOOS=linux GOARCH=amd64）
```

终端里仍可用 `cd backend && make build-linux`。

改 Agent 代码后：`make deploy-agent-stop && make deploy-agent`。

### PATH / 多机 config

| 文件 | 是否进 Git | 作用 |
|------|------------|------|
| `config.example.yaml` | ✅ | 模板 |
| `config.yaml` | ❌ | 每台机器一份 |
| `config.local.yaml` | ❌ | 可选私密覆盖 |

```bash
cd backend
make deploy-config-init   # 无 config.yaml 时从 example 复制
make deploy-agent
# http://127.0.0.1:19010/
```

## 远程配置白名单

运维台「远程 Docker 配置」仅允许：

- `docker-compose.binary.yml` / `docker-compose.yml`
- `config.yaml` / `config/config.yaml`
- `api/etc/moe.yaml`

## 安全建议

1. `listen` 保持 `127.0.0.1`。
2. 勿提交 `deploy/config.yaml`。
3. 推荐 `identity_file`，少用明文 password。

## 与手机发版的边界

| | 后端部署（本文） | App 版本更新 |
|--|------------------|--------------|
| 产物 | `bin/moe-social` + 容器 | APK + `app_releases` 行 |
| 管理台 | 运维区 | 运营区 `/biz/update` |
| CI | Deploy Agent 本机任务 | `.github/workflows/flutter-release.yml` |

## 相关文件

- 管理台：`moe-admin/src/pages/OverviewPage.tsx` 等；导航 `workspaceNav.ts`
- Agent：`backend/deploy/`
- Compose：`backend/docker-compose.binary.yml`
- App 发版速查：[app-release-cheatsheet.md](./app-release-cheatsheet.md)
- 通用：`backend/DEPLOY.md`

---

## 附录：历史 api/rpc 双进程（已退役）

旧文档曾描述 `moe-social-api` + `moe-social-rpc` 双二进制与双容器。当前仓库已合并为单进程 **`moe-social`**；若 VPS 上仍残留旧容器名，请按新 compose 迁移后删除旧容器。
