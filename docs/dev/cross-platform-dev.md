# 跨平台开发（macOS / Windows / Linux）

> 结论：**Mac 与 Windows 均支持**日常后端、Deploy Agent、Moe Admin；不是 Windows 专属项目。

## 一键对照

| 能力 | macOS | Windows | 说明 |
|------|:-----:|:-------:|------|
| `make rpc` / `make api` / `make dev` | ✅ | ✅ | Go 跨平台 |
| `make deploy-agent` | ✅ | ✅ | 首次缺配置时 Go 自动从 example 生成 |
| `make deploy-config-init` | ✅ | ✅ | Makefile 已分 OS 写法 |
| `make deploy-agent-stop` | ✅ `lsof` | ✅ PowerShell | |
| `make admin` | ✅ `start-admin.sh` | ✅ `start-admin.ps1` | |
| `cd moe-admin && npm run dev` | ✅ | ✅ | Vite |
| Deploy 本机构建 / Flutter 任务 | ✅ `zsh -l` | ✅ Git Bash 或 cmd | 见 `deploy-platform.md` |
| `make build-linux` | ✅ | ✅（建议 Git Bash） | 交叉编 Linux |
| `make gen` / `gen-api` / `gen-rpc` | ✅ | ✅ | 需安装 goctl |
| `make gen-swagger` | ✅ | ⚠️ | 依赖 `command -v`（Mac/Linux 原生；Win 用 Git Bash） |
| `make dev-docs` | ✅ `python3` | ✅ `python`/`py` | 需 Python |
| Flutter `flutter run` / `build macos` | ✅ | ✅ | 各平台目录已有 |

## Mac 推荐流程

```bash
# 1. 依赖：Go、Node、make（Xcode CLT 自带）、python3（可选）
cd backend
make deploy-config-init    # 或首次 make deploy-agent 自动创建 config.yaml
# 编辑 deploy/config.yaml：token、api_base_url 等

# 2. 业务
make rpc-migrate           # 首次
make dev                   # 或分开 make rpc / make api

# 3. 管理台（另开终端）
cd moe-admin && npm ci && npm run dev
# http://127.0.0.1:5173/ops/login

# 4. 运维（按需）
make deploy-agent
make rpc-debug             # RPC 监控需要

# 一键：make admin  或  ./scripts/start-admin.sh
# 停止：./scripts/stop-admin.sh
```

`config.yaml` **不进 Git**，Mac 新克隆后需从 `config.example.yaml` 复制或 `make deploy-config-init`，再填入本机 token（可从 Windows 用密码管理器同步，见 `deploy-platform.md`）。

## Windows 注意点

- `make admin` / `deploy-agent-stop` 走 `.ps1`，无需 bash。
- 在 **cmd** 里跑 `make` 时，`gen-swagger`、`deploy-config-init`（旧版）可能失败 → 用 **Git Bash** 或 WSL，或直接用 `go run` / 手动 `copy` 配置。
- Deploy Agent 本机任务：`windows_shell: auto` 优先 Git Bash；无 Git 时用 cmd + `local_path_extra` 补 Go/Flutter PATH。

## 仅 Windows 的脚本（与 Moe Admin 无关）

- `tool/setup_sqlite3_amalgamation.ps1`
- `website/official/scripts/generate_wechat_icons.ps1`（另有 `gen_wechat_icons.py 可跨平台）

## 相关文档

- [ports.md](./ports.md) — 端口
- [deploy-platform.md](./deploy-platform.md) — Win/Mac Agent 与配置
- [moe-admin.md](./moe-admin.md) — 管理台启动
