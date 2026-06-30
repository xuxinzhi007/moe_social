# 在 backend 目录执行，例如: make gen | make build | make moe-social



.PHONY: all gen gen-all gen-legacy-goctl gen-moe-proto gen-moe-conf gen-proto-route-count gen-moekratospilot-get gen-rpc gen-api gen-swagger gen-moe-admin api-moe-proto check fs8-split-api fs8-split-super-proto fs9b-rewrite-imports moe-social moe-social-dev moe-social-stop moe-platform moe-kratos migrate-moe build build-moe-social build build-linux env-status grpc-smoke split-deploy-smoke remove-hybrid-gozero \

	deploy-agent deploy-agent-stop moe-social-stop admin \

	rpc api rpc-debug db-migrate rpc-migrate rpc-monitor rpc-monitor-stop \

	dev-docs dev help



# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。



all: gen

# 安装 proto 代码生成工具（对齐 Kratos 官方：含 protoc-gen-go-http）
.PHONY: init-proto-tools
init-proto-tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@latest
	go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest

# 日常安全生成：域 proto + conf + proto HTTP 路由计数
gen: gen-moe-proto gen-moe-conf gen-proto-route-count

# 日常生成：仅 proto + conf + OpenAPI + 路由计数
gen-all: gen

gen-legacy-goctl gen-api:
	@echo "RETIRED: goctl 已移除。请改 api/<domain>/v1/*.proto 后执行 make gen"
	@exit 1

gen-moe-proto:
	bash scripts/gen/moe-proto.sh

gen-moe-conf:
	bash scripts/gen/moe-conf.sh

# 从 api/**/v1/*_http.pb.go 统计 → internal/server/routestats/proto_routes_gen.go
gen-proto-route-count:
	cd scripts/gen/proto-route-count && go run .

# 兼容旧文档 target 名
gen-moekratospilot-get: gen-proto-route-count
gen-http-routes: gen-proto-route-count

# P5/D4 Phase-4：backend/rpc/ 已删除；域契约见 api/*/v1/*.proto
gen-rpc:
	@echo "RETIRED: backend/rpc removed. Domain HTTP: api/*/v1 + make gen."
	@exit 1

# DEPRECATED (P5 完成)：go-zero / Super logic 已删除；配套脚本在 scripts/archive/fs8-rollback/
gen-rpc-legacy:
	@echo "DEPRECATED: gen-rpc-legacy disabled. Rollback scripts: scripts/archive/fs8-rollback/"
	@exit 1

fs8-assemble-super-proto:
	@echo "RETIRED: backend/rpc removed. Use api/<domain>/v1/*.proto + make gen."
	@exit 1

# DEPRECATED (P5 完成)：脚本已迁至 scripts/archive/fs8-rollback/
fs8-split-super-proto:
	@echo "DEPRECATED: scripts moved to scripts/archive/fs8-rollback/. Restore from git if disaster recovery needed."
	@exit 1

gen-swagger:
	bash scripts/gen/openapi.sh



# Moe 管理台：gen + 删空壳 + 编译（见 scripts/gen/moe-admin.sh）
gen-moe-admin:
	bash scripts/gen/moe-admin.sh

api-moe-proto:
	bash scripts/gen/moe-proto.sh

# DEPRECATED (P6 完成)：脚本已迁至 scripts/archive/fs8-rollback/
fs8-split-api:
	@echo "DEPRECATED: scripts moved to scripts/archive/fs8-rollback/. Restore from git if disaster recovery needed."
	@exit 1

# 日常检查：编译生产入口 + 核心包单测
check:
	go build -o /dev/null ./cmd/moe-social
	go test ./internal/platform/moesocial/... ./internal/server/routestats/... ./internal/platform/kratosprogress/... -count=1

# P4 域 gRPC 冒烟（已退役）
grpc-smoke:
	@echo "RETIRED: backend/rpc removed; use HTTP :8888 + openapi.yaml"
	@exit 1

# P5 分体联调（已退役）
split-deploy-smoke:
	@echo "RETIRED: single-process HTTP-only; use make moe-social"
	@exit 1

# DEPRECATED (P5-E 已执行 2026-05-29)：脚本在 scripts/archive/p5/p5e-remove-hybrid-gozero.py
remove-hybrid-gozero:
	@echo "DEPRECATED: P5-E already applied. Script archived at scripts/archive/p5/p5e-remove-hybrid-gozero.py"
	@exit 1

# 已退役：goctl logic 审计工具随 api/internal 删除
audit-logic-orphans:
	@echo "RETIRED: goctl logic removed; contract SSOT is api/<domain>/v1/*.proto"
	@exit 1

moe-social:

	go run ./cmd/moe-social

# 开发：moe-social + deploy-agent (:19010)
moe-social-dev:

	go run ./cmd/moe-social-stack

# 释放 8080/8888/19010/19011/19012（Ctrl+C 未完全退出时用）
moe-social-stop:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File deploy/scripts/stop-moe-social.ps1
else
	@bash deploy/scripts/stop-moe-social.sh
endif

moe-platform:
	@echo "DEPRECATED: cmd/moe-platform removed; use make moe-social"
	@exit 1

# DEPRECATED：已迁至 scripts/archive/fs8-rollback/fs9b-rewrite-imports/
fs9b-rewrite-imports:
	@echo "DEPRECATED: scripts/archive/fs8-rollback/fs9b-rewrite-imports/"
	@exit 1

moe-kratos:
	@echo "DEPRECATED: use make moe-social (Kratos HTTP :8888)."
	@echo "  Pilot :1903x removed (moe.pilot_process_deprecated=true). Exiting."
	@exit 1



# 本机构建（当前系统）

build-moe-social:

	@mkdir -p bin
	go build -o bin/moe-social ./cmd/moe-social

build: build-moe-social



# 编 Linux 服务器用（amd64）。Windows 若失败可用 Git Bash / WSL 执行 make。

build-linux:

	@echo Building Linux amd64...

	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/moe-social ./cmd/moe-social

	@echo Done.



# 看一眼本机 GOOS / GOARCH（排查用）

env-status:

	@echo GOOS=$$(go env GOOS) GOARCH=$$(go env GOARCH) CGO_ENABLED=$$(go env CGO_ENABLED)



# ===== 后端业务（make moe-social / go run ./cmd/moe-social）=====



rpc:
	@echo "standalone rpc removed; use: make moe-social"

api:
	@echo "standalone api removed; use: make moe-social"



db-migrate:

	go run ./cmd/migrate

# 新机器 / Moe 功能：仅迁移 Bot、试跑日志、AI 聊天等表
migrate-moe:

	go run ./cmd/migrate -models moe_agent_runtimes,moe_bot_episodes,moe_tool_calls,moe_agent_run_logs,ai_chat_sessions,ai_chat_messages



# 兼容旧命令：等价于 db-migrate（不再启动 RPC 进程）
rpc-migrate: db-migrate



# RPC debug 已随 backend/rpc 删除
rpc-debug:
	@echo "RETIRED: rpc-debug removed with backend/rpc; use make moe-social"
	@exit 1



# ===== 开发工具（独立进程，类似 deploy-agent）=====



# 首次生成 deploy/config.yaml（已存在则跳过，不会覆盖）

deploy-config-init:

ifeq ($(OS),Windows_NT)
	@if not exist deploy\config.yaml (copy deploy\config.example.yaml deploy\config.yaml && echo created deploy/config.yaml — please edit token) else (echo deploy/config.yaml already exists (not overwritten))
else
	@if [ ! -f deploy/config.yaml ]; then cp deploy/config.example.yaml deploy/config.yaml && echo "created deploy/config.yaml — please edit token"; else echo "deploy/config.yaml already exists (not overwritten)"; fi
endif



# Deploy Agent（:19010）：Deploy API、admin 代理、RPC debug、docs/dev；不构建/不打开 Moe Admin
# 管理台：cd moe-admin && npm run dev → :5173/ops/

deploy-agent:

	go run ./cmd/deploy-agent -f deploy/config.yaml

admin:
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File ../scripts/start-admin.ps1
else
	@chmod +x ../scripts/start-admin.sh ../scripts/stop-admin.sh 2>/dev/null || true
	@../scripts/start-admin.sh
endif

deploy-agent-stop:

ifeq ($(OS),Windows_NT)

	-@powershell -NoProfile -ExecutionPolicy Bypass -File deploy/scripts/stop-agent.ps1

else

	-@command -v lsof >/dev/null 2>&1 && lsof -ti :19010 | xargs kill 2>/dev/null || true

endif

	@echo port 19010 cleared



# 已合并到 deploy-agent（:19010/#rpc）；保留别名

rpc-monitor:

	@echo "[rpc-monitor] 已合并到 deploy-agent，启动统一工具台…"

	go run ./cmd/deploy-agent -f deploy/config.yaml



rpc-monitor-stop:

ifeq ($(OS),Windows_NT)

	-@powershell -NoProfile -ExecutionPolicy Bypass -File deploy/scripts/stop-agent.ps1

else

	-@command -v lsof >/dev/null 2>&1 && lsof -ti :19010 | xargs kill 2>/dev/null || true

endif

	@echo port 19010 cleared



# 文档静态站（Moe 专属 :19012，见 docs/dev/ports.md）

dev-docs:

	cd ../docs && python -m http.server 19012



# 本地联调：仅 RPC + API，Ctrl+C 全部退出（监控/文档请另开终端 make rpc-monitor / make dev-docs）

dev:
	@echo "RETIRED: 旧双进程 dev 已移除。请使用: make moe-social 或 make moe-social-dev"
	@exit 1



help:
	@echo make gen              - proto + conf + HTTP 路由计数
	@echo make gen-swagger      - 生成 openapi.yaml（与 make gen 同源）
	@echo make build            - 本机编译 bin/moe-social
	@echo make build-linux      - 交叉编译 Linux bin/moe-social
	@echo make check            - 编译 + 核心包单测
	@echo ""
	@echo --- 生产 / 开发 ---
	@echo make moe-social         - Kratos HTTP :8888（生产入口）
	@echo make moe-social-dev     - 同上 + deploy-agent :19010
	@echo make moe-social-stop    - 释放开发端口
	@echo make db-migrate         - 数据库 schema 迁移
	@echo make deploy-agent       - 部署调试代理 :19010
	@echo ""
	@echo 契约 SSOT: api/<domain>/v1/*.proto  Apifox: backend/openapi.yaml
	@echo 布局说明: LAYOUT.md  迁移状态: docs/dev/kratos-migration-status.md

