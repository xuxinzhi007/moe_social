# Moe 部署平台（Deploy Agent + 管理台）

一体化运维后台：在**运行 Deploy Agent 的机器**上执行构建与 Docker 操作，通过浏览器管理。

## 架构

```text
web/deploy/index.html  ──HTTP──►  Deploy Agent (:9100)
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
              make / go build   docker compose    GitHub API
              (按 OS 选命令)     (binary 编排)      (可选触发 APK)
```

- **本机 (local)**：Flutter、`make build-linux`、本机构建、环境巡检——在运行 Agent 的 Mac/Windows 上执行。
- **云平台 (cloud)**：**仅** `docker compose` 相关任务，经 **SSH** 在 VPS（如 `47.106.175.49`）执行，与 `docker-compose.binary.yml`、`/root/gowork/moe_images` 一致。
- 创建任务时 Agent 会按任务类型**自动**选择 `local` / `cloud`，顶部下拉主要用于查看对应主机信息。
- 本机自动识别 `GOOS`；远程一律按 **Linux + docker compose**。
- 默认只监听 `127.0.0.1`，需 Token；**不要**把 Agent 无鉴权暴露公网。

## 路径如何在不同设备上正确

| 配置项 | 作用 | 示例 |
|--------|------|------|
| `workspace_root` | 本机仓库根目录，**相对** `backend/deploy/config.yaml` 解析 | `../..` → 任意 Mac 上克隆目录均可 |
| `backend_dir` | 相对 workspace 的后端目录 | `backend` |
| `MOE_DEPLOY_WORKSPACE` | 可选环境变量，覆盖本机 workspace 绝对路径 | `/Users/you/moe_social` |
| `targets.cloud.backend_dir` | **VPS 上** backend 的绝对路径 | `/root/gowork/moe_social/backend` |

Flutter / `make build` 使用解析后的本机 `workspace`；Docker 任务 SSH 到云后 `cd` 到云上的 `backend_dir`。

## 快速开始

```bash
# 1. 复制配置
cp backend/deploy/config.example.yaml backend/deploy/config.yaml
# 编辑 token、workspace_root

# 2. 启动 Agent（在 backend 目录）
make deploy-agent
# 或: go run ./cmd/deploy-agent -f deploy/config.yaml

# 3. 打开管理台（必须由 Agent 托管，勿用 IDE 预览 HTML）
open http://127.0.0.1:9100/
# 侧栏填写 Token（与 config.yaml 中 token 一致）→「保存并验证」
# Docker 任务选「云平台」；Flutter 任务选「本机」
```

若 `address already in use`，先 `make deploy-agent-stop` 再 `make deploy-agent`，否则浏览器连到**旧进程**，Flutter 修复不会生效。

## API 摘要

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/deploy/info` | 鉴权说明（无需 token） |
| GET | `/api/deploy/session` | 验证 Deploy Token 是否有效 |
| GET | `/api/deploy/targets` | 部署目标列表（local / cloud SSH） |
| GET | `/api/deploy/ssh-check?target=cloud` | 测试 SSH 能否登录云平台 |
| GET | `/api/deploy/host?target=cloud` | 主机信息（本地或 SSH 探测） |
| GET | `/api/deploy/status` | Docker 容器状态（compose ps） |
| GET | `/api/deploy/releases` | 本地 git tags + GitHub 最新 Release（需配置） |
| GET | `/api/deploy/jobs` | 任务列表 |
| GET | `/api/deploy/jobs/{id}` | 任务详情与日志 |
| POST | `/api/deploy/jobs` | 创建任务，`{"type":"docker_up","target":"cloud"}` |

### 任务类型 `type`

| type | 说明 |
|------|------|
| `env_inspect` | 环境巡检（只读） |
| `backend_build_linux` | 交叉编译 Linux 二进制（`make build-linux` 或等价 go build） |
| `backend_build_local` | 本机 api+rpc 构建 |
| `docker_ps` | `docker compose ps` |
| `docker_up` | `up -d --build` |
| `docker_stop` | `stop` |
| `docker_down` | `down` |
| `docker_restart` | 重启 `api` / `rpc` / `all`（body: `{"service":"api"}`） |
| `docker_logs` | 拉日志（`service`, `tail`） |
| `github_list_workflows` | 列出 Actions（需 `github.token`） |
| `github_trigger_apk` | 触发 APK 构建（`ref` 如 `v1.0.4` 或分支名） |
| `flutter_doctor` | 本机 `flutter doctor -v`（目标 `local`） |
| `flutter_pub_get` | 本机 `flutter pub get`（目标 `local`） |
| `flutter_build_apk` | 本机 `flutter build apk`（目标 `local`） |
| `remote_inspect` | 云平台路径巡检（`backend_dir` / compose 是否存在） |

请求头：`X-Deploy-Token: <config.token>`

### 云平台巡检与远程配置

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/deploy/remote-check?target=cloud` | 检查 VPS 上 `backend_dir`、compose 是否存在，并搜索常见 compose 路径 |
| GET | `/api/deploy/remote-config?target=cloud&file=docker-compose.binary.yml` | 读取远程白名单配置文件 |
| PUT | `/api/deploy/remote-config` | 写入远程配置（body: `target`, `file`, `content`），自动 `.bak` 备份 |

允许编辑的文件：`docker-compose.binary.yml`、`docker-compose.yml`、`config.yaml`、`config/config.yaml`。

### 鉴权（不是 Moe App 账号登录）

- **管理台**：`config.yaml` 里的 `token`，页面「保存并验证」调用 `GET /api/deploy/session`。
- **云平台 Docker**：`targets.cloud` 配置 **`identity_file`**（推荐，`ssh-copy-id`）或 **`password`**（仅写在已 gitignore 的 `config.yaml`）。Agent 使用原生 SSH 客户端，不再依赖交互式密码提示。

```bash
# 推荐：本机生成密钥并写入 VPS
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@47.106.175.49
# config.yaml:
#   identity_file: "~/.ssh/id_ed25519"
```

### Flutter 任务失败排查

| 现象 | 处理 |
|------|------|
| `exit=255` + `AndroidSdk.locateAndroidSdk` 空指针 | Agent 子进程缺 `ANDROID_HOME`；重启 Agent 后重试（已用 `zsh -l` + 合并登录环境） |
| `Failed to fetch` | Agent 未启动，或打开了 `file://` / IDE 63342 预览而非 `http://127.0.0.1:9100/` |
| `local` 上 `docker_*` 失败 | 本机无 Docker；Docker 任务选 **cloud** |
| 总览仍显示本机无 Docker | 部署目标未切到 **cloud**，或 host 未带 `?target=cloud` |

## 各系统命令差异（Agent 内部）

| 能力 | macOS / Linux | Windows |
|------|---------------|---------|
| 后端 Linux 包 | `make build-linux` | 无 make 时用 `go build` + `GOOS=linux` |
| Docker 编排 | `docker compose` 优先，否则 `docker-compose` | 同左 |
| Shell | macOS: `zsh -l -c`；Linux: `bash -l -c` | `cmd.exe /C` |
| Flutter | 登录 shell + `ANDROID_HOME` 兜底 `~/sdk/Android` 等 | 同左（若已装 SDK） |
| 工作目录 | `workspace/backend` | 同上（路径自动处理） |

## 安全建议

1. `listen` 保持 `127.0.0.1`；远程访问用 SSH 隧道或 VPN。
2. `token` 使用长随机串；勿提交 `config.yaml` 到 Git。
3. 生产部署建议二次确认（管理台已对 `docker_down` 等做 confirm）。
4. GitHub Token 仅需 `actions:write` + `contents:read`（触发 workflow）。

## 与现有流程的关系

- **APK 发布**：仍可由 tag 触发 Actions；管理台可额外 `workflow_dispatch`。
- **后端上线**：与 README 中 `docker-compose.binary.yml` 一致，由 Agent 代为执行。
