# 跨平台开发（macOS / Windows / Linux）

> 结论：**Mac 与 Windows 均支持**日常后端、Deploy Agent、Moe Admin；不是 Windows 专属项目。

## 一键对照

| 能力 | macOS | Windows | 说明 |
|------|:-----:|:-------:|------|
| `make moe-social` / `make moe-social-dev` | ✅ | ✅ | Go 跨平台；单进程 Kratos HTTP :8888 |
| `make db-migrate` / `make migrate-moe` | ✅ | ✅ | `go run ./cmd/migrate` |
| `make deploy-agent` | ✅ | ✅ | 首次缺配置时 Go 自动从 example 生成 |
| `make deploy-config-init` | ✅ | ✅ | Makefile 已分 OS 写法 |
| `make deploy-agent-stop` / `make moe-social-stop` | ✅ `lsof` | ✅ PowerShell | |
| `make admin` | ✅ `start-admin.sh` | ✅ `start-admin.ps1` | |
| `cd moe-admin && npm run dev` | ✅ | ✅ | Vite |
| Deploy 本机构建 / Flutter 任务 | ✅ `zsh -l` | ✅ Git Bash 或 cmd | 见 `deploy-platform.md` |
| `make build-linux` | ✅ | ✅（建议 Git Bash） | 交叉编 Linux |
| `make gen` / `make api-one` / `make gen-moe-admin` | ✅ | ⚠️ 需 bash | Kratos protoc 链，**不再需要 goctl**；先 `make init-proto-tools` |
| `make gen-swagger` | ✅ | ⚠️ | 输出 `backend/openapi.yaml`（OpenAPI 3.0.3）；详见 [openapi-apifox.md](./openapi-apifox.md) |
| `make dev-docs` | ✅ `python3` | ✅ `python`/`py` | 需 Python |
| Flutter `flutter run` / `build macos` | ✅ | ✅ | 各平台目录已有 |

## Mac 推荐流程

```bash
# 1. 依赖：Go、Node、make（Xcode CLT 自带）、python3（可选）
cd backend
make deploy-config-init    # 或首次 make deploy-agent 自动创建 config.yaml
# 编辑 deploy/config.yaml：token、api_base_url 等

# 2. 业务
make db-migrate            # 首次（= go run ./cmd/migrate）
make moe-social            # 单进程 Kratos HTTP :8888

# 3. 管理台（另开终端）
cd moe-admin && npm ci && npm run dev
# http://127.0.0.1:5173/ops/login

# 4. 运维（按需，make moe-social 不会自动拉起 Agent）
cd ../backend && make deploy-agent   # :19010

# 一键：make admin  或  ./scripts/start-admin.sh
# 停止：./scripts/stop-admin.sh
```

`backend/deploy/config.yaml` **不进 Git**（`.gitignore:38`），Mac 新克隆后需从 `deploy/config.example.yaml` 复制或 `make deploy-config-init`，再填入本机 token（可从 Windows 用密码管理器同步，见 `deploy-platform.md`）。

⚠️ 别和 `backend/config/config.yaml` 搞混——后者是业务配置 SSOT，**进 Git**，新克隆后已存在、无需生成。

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
