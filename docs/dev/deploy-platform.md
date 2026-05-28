# Moe 部署平台（Deploy Agent + 管理台）

在**本机**开发、交叉编译后端二进制；在**云 VPS** 的 `/root/gowork/backend` 用 Docker 跑 API/RPC；**Flutter APK** 由 GitHub tag 触发 Actions，不在 VPS 上编前端。

## 实际分工（合并后）

| 环节 | 在哪里做 | 管理台 / 命令 |
|------|----------|----------------|
| 日常开发、联调 | 本机 Windows/Mac | Flutter / `go run`（本地测） |
| 后端 Linux 二进制 | 本机 Agent | `backend_build_linux` → 产物在 `backend/api`、`backend/rpc` |
| 上传到云 | Agent `backend_upload_binaries`（SFTP） | 本机 `api`/`rpc` 二进制 → VPS `backend_dir`；默认上传后 `docker compose restart` |
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
docs/dev/tools/deploy-ops.html  ──HTTP──►  Deploy Agent (:19010)
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

## 上传二进制（`backend_upload_binaries`）

在 **Windows / macOS** 上运行的 Deploy Agent 均支持（纯 Go SFTP，不依赖系统 `scp`）：

1. 先 `backend_build_linux` 生成本地 `backend/api/moe-social-api`、`backend/rpc/moe-social-rpc`。
2. 再 `backend_upload_binaries`（目标 **cloud**），**默认完整流程**（解决容器占用二进制）：
   - **停止** `api` / `rpc`：`docker compose stop api rpc`
   - **SFTP 上传** 到 `backend/api/`、`backend/rpc/`（与本地路径一致）
   - **启动** `docker compose up -d`（加载新二进制）
   - 若 **上传中途失败** 且曾执行过 stop，Agent 会自动 **【恢复】docker compose up -d**，避免服务一直停着（磁盘上多为旧二进制）
   - 参数：`stop_before=false` 仅跳过停止；`restart=false` 仅上传不启动（失败时也不会自动恢复）
3. 一般不必再单独点「③ 云 Docker Up」，除非首次部署或改了 compose。

### 一键发布（`backend_release_pipeline`）

管理台 **发布流水线** 旁 **「一键发布」** 串联：

1. 本机编 Linux  
2. 上传（停 → 并行 SFTP 传 api+rpc → 启；失败自动恢复）  
3. 检查 `moe-social-api` / `moe-social-rpc`：非 running、重启中、已退出时自动 `docker logs --tail 150`

api 与 rpc **并行上传**（各一条 SFTP 连接，Go 协程），缩短总耗时；进度条显示两个文件百分比。

前置：本机已能 `ssh user@vps`（`identity_file` 或 `password`，与现有云任务相同）。

## 本机 Windows / macOS 兼容

Deploy Agent 在本机执行任务时，会按操作系统选择 shell 与路径写法。

### Windows：Git Bash 终端 vs 系统终端

若 **PowerShell/CMD 里 `go`/`flutter` 不可用**，但 **Git 安装目录里的 Git Bash 可以**，在 `deploy/config.yaml` 设置：

```yaml
windows_shell: auto   # 默认：检测到 Git 则自动用 Git Bash
# windows_shell: git-bash
# windows_shell: cmd
```

或环境变量 `MOE_DEPLOY_WINDOWS_SHELL=git-bash`。Agent 会用 Git Bash 的 login 环境（`~/.bashrc` PATH）执行本机编包、Flutter 等，与你在 Git Bash 里手动执行一致。管理台总览显示 **本机 Shell**；任务执行时总览底部 **实时日志** 约每 0.6s 刷新。

### Windows 本机编 Linux：不用 make 配方

`backend/Makefile` 里 `build-linux` 写的是 Unix 一行环境变量：

```makefile
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build ...
```

这在 **Git Bash / Mac 终端**里没问题；**Windows cmd** 和不少 **make 调用的子 shell** 不支持这种写法，所以 Agent 的 `backend_build_linux` **不再调用 `make build-linux`**，而是直接：

```text
go build -o api/moe-social-api ./api   （进程环境变量 GOOS=linux GOARCH=amd64）
go build -o rpc/moe-social-rpc ./rpc
```

勿把 `api/...` 当成路径：在 Windows 上会生成名为 `...` 的目录并导致 `git add` 失败。

与你在 Git Bash 里手动交叉编译效果相同，且不依赖 shell 语法。终端里仍可用 `make build-linux`（建议在 Git Bash 下执行）。

若日志出现 `creating work dir: GetFileAttributesEx C:\tmp`，是 Git Bash 把 `TMPDIR` 指到了不存在的 `C:\tmp`；Agent 会自动改成本机真实 `%TEMP%`（重启 Agent 后生效）。

上传任务会在管理台显示 **进度条**（约每 2% 刷新）；大文件先写到远程 `*.uploading` 再替换，减轻「文件被占用」导致的 SFTP 失败。

### PATH 能有多「完整」？

| 环境 | PATH 来源 | 说明 |
|------|-----------|------|
| Mac 本机 | `zsh -l -c env` | 与终端登录环境接近，一般够用 |
| Win + Git Bash | `bash -l -c env` | 与 Git Bash 终端一致，**推荐** |
| Win + cmd（无 Git） | PowerShell 拉 env + 常见 flutter/sdk 猜测 | 不如 Git Bash；需自装 Go 到系统 PATH 或配 `local_path_extra` |

**没装 Git for Windows 时**：`windows_shell: auto` 会退回 **cmd**，若系统 PATH 没有 `go`，编包会失败——可 (1) 安装 Git 用 Bash，(2) 把 Go 加入系统环境变量，或 (3) 在 `config.yaml` 写 `local_path_extra: "C:\\Go\\bin;..."` 显式补 PATH。

```yaml
local_path_extra: "C:\\Program Files\\Go\\bin;C:\\src\\flutter\\bin"   # Windows 分号
# Mac: local_path_extra: "/opt/homebrew/bin:/path/to/flutter/bin"
```

| 问题 | 处理 |
|------|------|
| Windows 上 `cd 'C:\...' && flutter` 失败 | Git Bash：`cd '/c/...' &&`；cmd：`cd /d "..." &` |
| 日志乱码（cmd 下） | cmd 输出 GBK 解码；Git Bash 下为 UTF-8 直通 |
| Agent 子进程 PATH 过短 | Git Bash / macOS login shell 拉完整 `env` |
| Flutter / Android SDK 找不到 | 合并 `PATH`，并尝试常见 SDK 路径 |

**建议**：后端交叉编译（`backend_build_linux`）在 Windows/macOS 均可；**Flutter 日常开发**优先本机终端或 Mac；APK 发布走 GitHub Actions。改 Agent 代码后执行 `make deploy-agent-stop && make deploy-agent` 再重试任务。

## 多机配置（Win / Mac）与 git pull

`backend/deploy/config.yaml` 和 `config.local.yaml` **在 .gitignore 里**，`git pull` **不会**覆盖你本机已有配置，也 **不会** 把 Windows 上的 config 自动同步到 Mac。

| 文件 | 是否进 Git | 作用 |
|------|------------|------|
| `config.example.yaml` | ✅ | 模板；拉代码后会更新，供你对照新字段 |
| `config.yaml` | ❌ | 每台机器一份，首次 `make deploy-agent` 可从 example **复制生成**（仅当文件不存在） |
| `config.local.yaml` | ❌ | 可选；与 `config.yaml` **合并**，适合只拷贝 token/SSH 等私密小段 |

**Mac 上新克隆后：**

```bash
cd backend
make deploy-config-init   # 没有 config.yaml 才从 example 复制
# 手动把 Windows 上的 token、cloud.host、SSH 等填进 config.yaml
# 或：复制 config.local.example.yaml → config.local.yaml，填私密项后 Win/Mac 各放一份（U 盘/密码管理器同步）
make deploy-agent
```

`make deploy-agent` **只启动 Agent**，不会双向同步 config。改 `config.example.yaml` 后需自己把新字段合并进本机 `config.yaml`。

## 快速开始

```bash
cp backend/deploy/config.example.yaml backend/deploy/config.yaml
# 编辑 token、targets.cloud.backend_dir、SSH 密钥或密码

cd backend
make deploy-agent-stop   # 端口占用时
make deploy-agent

# 浏览器（必须由 Agent 提供，勿 file:// 打开 HTML）
# http://127.0.0.1:19010/
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

## 运维台对配置文件的管理范围

| 能力 | 管理/检查的文件 | 说明 |
|------|-----------------|------|
| **② 上传二进制** | 仅 `api/moe-social-api`、`rpc/moe-social-rpc` | **不会**上传 `api/etc/` |
| **远程 Docker 配置** | compose、`config/config.yaml`、`api/etc/super.yaml` | 读/写白名单，保存前自动 `.bak` |
| **云平台路径巡检** | compose + 运行中容器 | `MOE_SUPER_RPC_ENDPOINT=rpc:8080` 或 `config` 里 `api.super_rpc_endpoints` |
| **容器健康检查** | 无文件 | 只看 `moe-social-api` / `moe-social-rpc` 状态与日志 |

上传后若只改二进制、未同步 `api/etc`，仍可能 API→RPC 连 `127.0.0.1:8080`；发布前点一次 **检查 backend_dir**。

## App 报 500：`dial tcp 127.0.0.1:8080: connection refused`

说明 **手机已连上 VPS 的 API（8888）**，但 **API 容器内连不上 RPC**（不是 Flutter 配错）。

| 层级 | 地址 | 含义 |
|------|------|------|
| Flutter → API | `47.106.175.49:8888` | `lib/utils/config.dart` 的 `isProduction` |
| API → RPC | 容器内应 `rpc:8080` | compose 环境变量 `MOE_SUPER_RPC_ENDPOINT`；本机 `go run` 用 `super.yaml` 的 `127.0.0.1:8080` |

处理：

1. 管理台 **④ 容器状态**：`moe-social-api`、`moe-social-rpc` 均为 Up。
2. VPS 上 `docker-compose.binary.yml` 的 `api.environment` 含 `MOE_SUPER_RPC_ENDPOINT: rpc:8080`，然后 `docker compose restart api`。
3. 仅上传二进制不会改 compose；需在 VPS `git pull` 或运维台编辑 compose 后重启。

## 相关文件

- 管理台：`docs/dev/tools/deploy-ops.html`
- 配置：`backend/deploy/config.yaml`（gitignore）
- 编排：`backend/docker-compose.binary.yml`
- 通用后端部署说明：`backend/DEPLOY.md`
