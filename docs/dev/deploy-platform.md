# Moe 部署平台（Deploy Agent + 管理台）

在**本机**开发、交叉编译后端二进制；在**云 VPS** 的 `/root/gowork/backend` 用 Docker 跑 API/RPC；**Flutter APK** 由 GitHub tag 触发 Actions，不在 VPS 上编前端。

## 实际分工（合并后）

| 环节 | 在哪里做 | 管理台 / 命令 |
|------|----------|----------------|
| 日常开发、联调 | 本机 Windows/Mac | Flutter / `go run`（本地测） |
| 后端 Linux 二进制 | 本机 Agent | `backend_build_linux` → 产物在 `backend/api`、`backend/rpc` |
| 上传到云 | 你自行 SCP/面板 | 把编好的二进制放到 VPS `backend` 目录 |
| API/RPC 容器 | 云 VPS SSH | `docker_*` 任务 → `cd /root/gowork/backend` + `docker-compose.binary.yml` |
| 持久化图片等 | 云路径 | `/root/gowork/moe_images`（compose 卷挂载） |
| 前端 APK | GitHub | 打 tag → `flutter-release.yml`；可选管理台 `github_trigger_apk` |

```text
本机仓库 (moe_social)
  └─ make build-linux / Agent 任务
        └─ 上传 api、rpc 二进制 ──►  /root/gowork/backend/
                                        └─ docker compose up
GitHub tag ──► Actions 打 APK（与 VPS 无关）
```

## 架构

```text
docs/dev/tools/deploy-ops.html  ──HTTP──►  Deploy Agent (:9100)
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
              本机 go build      云 SSH docker      GitHub API
              (local)            (cloud)            (APK 可选)
```

- **local**：`backend_build_linux`、`env_inspect`；可选 Flutter（本机调试）。
- **cloud**：仅 `docker_*`、`remote-check`、`remote-config`；SSH 到 `targets.cloud.backend_dir`。
- Agent 按任务类型**自动**选 local/cloud，无需每次手选。

## 路径配置（SSOT）

| 配置项 | 本机 | 云 VPS |
|--------|------|--------|
| `workspace_root` | 仓库根（相对 `deploy/config.yaml` 的 `../..`） | — |
| `backend_dir` | 相对路径 `backend` | **绝对路径** `/root/gowork/backend` |
| `compose_file` | `docker-compose.binary.yml` | 同上（在 VPS backend 目录内） |
| 镜像/数据卷 | — | `/root/gowork/moe_images`（见 `docker-compose.binary.yml`） |

**不要**把云路径写成 `/root/gowork/moe_social/backend`，除非你整仓克隆到 VPS；当前面板目录是 `root > gowork > backend`。

## 云 Docker 检查说明

- 管理台「容器状态」= SSH 到 VPS 执行 `docker compose -f docker-compose.binary.yml ps`（工作目录为 `targets.cloud.backend_dir`）。
- 与 1Panel 容器列表等价：应看到 **moe-social-api**（:8888）、**moe-social-rpc**（:8080）。
- **改 config.yaml 后必须重启 Agent**，否则内存里仍是旧路径（日志里若出现 `moe_social/backend` 即未重启）。

正确 compose 路径：`/root/gowork/backend/docker-compose.binary.yml`

## 本机 Windows / macOS 兼容

Deploy Agent 在本机执行任务时，会按操作系统选择 shell 与路径写法：

| 问题 | 处理 |
|------|------|
| Windows 上 `cd 'C:\...' && flutter` 失败 | 改为 `cmd /d` + 双引号路径：`cd /d "C:\...\moe_social" & flutter pub get` |
| 日志乱码（``） | 子进程输出按 GBK 解码；同时 `chcp 65001` 尽量让 Flutter 输出 UTF-8 |
| Agent 子进程 PATH 过短 | Windows 用 PowerShell 拉取用户环境变量；macOS/Linux 用 login shell `env` |
| Flutter / Android SDK 找不到 | 合并 `PATH`，并尝试 `%LOCALAPPDATA%\Android\Sdk`、`~/flutter/bin` 等常见路径 |

**建议**：后端交叉编译（`backend_build_linux`）在 Windows/macOS 均可；**Flutter 日常开发**优先本机终端或 Mac；APK 发布走 GitHub Actions。改 Agent 代码后执行 `make deploy-agent-stop && make deploy-agent` 再重试任务。

## 快速开始

```bash
cp backend/deploy/config.example.yaml backend/deploy/config.yaml
# 编辑 token、targets.cloud.backend_dir、SSH 密钥或密码

cd backend
make deploy-agent-stop   # 端口占用时
make deploy-agent

# 浏览器（必须由 Agent 提供，勿 file:// 打开 HTML）
# http://127.0.0.1:9100/
# ⚙ 设置 → Token 验证 → 总览看云 VPS 卡片
```

## API 与任务类型

见原表：`docker_up` / `docker_ps`、`backend_build_linux`、`github_trigger_apk` 等。请求头：`X-Deploy-Token`。

### 云平台巡检

`GET /api/deploy/remote-check?target=cloud` — 检查 `/root/gowork/backend` 与 compose 是否存在。

## 安全建议

1. `listen` 保持 `127.0.0.1`。
2. 勿提交 `deploy/config.yaml`（含 token/SSH 密码）。
3. 推荐 `ssh-copy-id` + `identity_file`，少用明文 password。

## 相关文件

- 管理台：`docs/dev/tools/deploy-ops.html`
- 配置：`backend/deploy/config.yaml`（gitignore）
- 编排：`backend/docker-compose.binary.yml`
- 通用后端部署说明：`backend/DEPLOY.md`
