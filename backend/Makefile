# 在 backend 目录执行，例如: make gen | make build | make rpc | make dev



.PHONY: all gen gen-all gen-legacy-goctl gen-moe-proto gen-moe-conf gen-http-routes gen-moekratospilot-get gen-rpc gen-api gen-swagger gen-moe-admin api-moe-proto check fs8-split-api fs8-split-super-proto fs9b-rewrite-imports moe-social moe-social-dev moe-social-stop moe-platform moe-kratos migrate-moe build build-moe-social build build-linux env-status \

	deploy-agent deploy-agent-stop moe-social-stop admin \

	rpc api rpc-debug db-migrate rpc-migrate rpc-monitor rpc-monitor-stop \

	dev-docs dev help



# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。



all: gen



# 日常安全生成：不跑 goctl api/rpc，不覆盖 api/internal/logic 与 rpc/internal/logic
gen: gen-moe-proto gen-moe-conf gen-http-routes

# 域 proto + conf + goctl API + RPC + Kratos 路由（改 .api / moe.proto 后用）
gen-all: gen-moe-proto gen-moe-conf gen-api gen-rpc gen-http-routes

# goctl api + swagger（改 api/defs 后）
gen-legacy-goctl: gen-api gen-swagger

gen-moe-proto:
	bash scripts/gen/moe-proto.sh

gen-moe-conf:
	bash scripts/gen/moe-conf.sh

# 从 api/internal/handler/routes.go → api/moehttp/routes_*_gen.go
gen-http-routes:
	bash scripts/gen/stale-api-hint.sh
	cd scripts/gen/http-routes && go run .

# 兼容旧文档 target 名
gen-moekratospilot-get: gen-http-routes

# --client=false：避免与 pb 包名冲突、生成坏 client
gen-rpc: fs8-assemble-super-proto
	goctl rpc protoc rpc/moe.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false
	@rm -f rpc/pb/super/super.pb.go rpc/pb/super/super_grpc.pb.go rpc/pb/super/common.pb.go rpc/pb/super/moe.pb.go rpc/pb/super/moe_grpc.pb.go
	bash scripts/gen/fs9b-pb-shim.sh
	bash scripts/gen/fs9-fix-rpc-import.sh
	bash scripts/gen/prune-rpc-logic-shells.sh

fs8-assemble-super-proto:
	python3 scripts/gen/fs8-assemble-rpc-proto.py

# 仅从单体 moe.proto 重新切分（覆盖 defs 手工编辑，慎用）
fs8-split-super-proto:
	python3 scripts/fs8-split-super-proto.py
	python3 scripts/gen/fs8-assemble-rpc-proto.py

gen-api:
	bash scripts/gen/api-guard.sh
	cd api && goctl api go -api moe.api -dir ./
	bash scripts/gen/prune-api-logic-shells.sh
	bash scripts/gen/prune-api-logic-retired.sh
	bash scripts/gen/tag-hybrid-routes.sh
	bash scripts/gen/post-gen-check.sh
	$(MAKE) gen-http-routes



gen-swagger:

	@command -v goctl-swagger >/dev/null 2>&1 || (echo "goctl-swagger 未安装，请先执行: go install github.com/zeromicro/goctl-swagger@latest" && exit 1)

	cd api && goctl api plugin -plugin goctl-swagger="swagger -filename ../rest.swagger.json" -api moe.api -dir ./



# Moe 管理台：gen + 删空壳 + 编译（见 scripts/gen/moe-admin.sh）
gen-moe-admin:
	bash scripts/gen/moe-admin.sh

api-moe-proto:
	bash scripts/gen/moe-proto.sh

# FS-8：仅从单体 moe.api 重新切分 defs（会覆盖 defs 手工编辑，慎用）
fs8-split-api:
	python3 scripts/gen/fs8-split-api.py

# 日常检查：编译生产入口 + 核心包单测
check:
	go build -o /dev/null ./cmd/moe-social
	go test ./internal/platform/moesocial/... ./api/moehttp/... ./internal/platform/kratosprogress/... -count=1

# P3-W4：列出无 handler 引用的 logic 文件（Windows/Linux 均可）
audit-logic-orphans:
	go run ./scripts/tools/logic-orphan-audit

moe-social:

	go run ./cmd/moe-social

# 开发：附带 deploy-agent (:19010) + RPC debug (:19011)
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

	go run ./cmd/moe-platform

fs9b-rewrite-imports:
	cd scripts/tools/fs9b-rewrite-imports && go run ./

moe-kratos:
	@echo "DEPRECATED: use make moe-social (Kratos HTTP :8888 + gRPC :8080)."
	@echo "  Pilot :1903x removed (moe.pilot_process_deprecated=true). Exiting."
	@exit 1



# 本机构建（当前系统）

build-moe-social:

	@mkdir -p bin
	go build -o bin/moe-social ./cmd/moe-social

build: build-moe-social

	go build -o api/moe-social-api ./api

	go build -o rpc/moe-social-rpc ./rpc



# 编 Linux 服务器用（amd64）。Windows 若失败可用 Git Bash / WSL 执行 make。

build-linux:

	@echo Building Linux amd64...

	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/moe-social ./cmd/moe-social

	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o api/moe-social-api ./api

	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rpc/moe-social-rpc ./rpc

	@echo Done.



# 看一眼本机 GOOS / GOARCH（排查用）

env-status:

	@echo GOOS=$$(go env GOOS) GOARCH=$$(go env GOARCH) CGO_ENABLED=$$(go env CGO_ENABLED)



# ===== 后端业务（go run super.go 只跑业务，不含监控）=====



rpc:

	go run ./rpc/super.go -f rpc/etc/moe.yaml



api:

	go run ./api/super.go -f api/etc/moe.yaml



db-migrate:

	go run ./cmd/migrate

# 新机器 / Moe 功能：仅迁移 Bot、试跑日志、AI 聊天等表
migrate-moe:

	go run ./cmd/migrate -models moe_agent_runtimes,moe_bot_episodes,moe_tool_calls,moe_agent_run_logs,ai_chat_sessions,ai_chat_messages



# 兼容旧命令：等价于 db-migrate（不再启动 RPC 进程）
rpc-migrate: db-migrate



# RPC 进程内 debug API（:19011），Agent 将 /debug/* 转发到此

rpc-debug:

	go run ./rpc/super.go -f rpc/etc/moe.yaml -debug



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

	go run ./cmd/dev



help:

	@echo make gen           - 生成 RPC + API 代码

	@echo make gen-rpc       - 仅 RPC 代码生成

	@echo make gen-api       - 仅 API 代码生成

	@echo make gen-swagger   - 仅生成 Swagger JSON（backend/rest.swagger.json）

	@echo make build         - 本机打包 api + rpc

	@echo make build-linux   - 交叉编 Linux 包（不改全局 go 配置）

	@echo make env-status    - 打印 GOOS/GOARCH

	@echo ""

	@echo --- 后端业务 ---

	@echo make rpc           - 仅 RPC (:8080)，等同 go run super.go

	@echo make api           - 仅 API (:8888)

	@echo make db-migrate    - 仅 schema 迁移（推荐，跑完即退出）

	@echo make rpc-migrate   - 同 db-migrate（兼容旧命令）

	@echo make dev           - RPC + API 联调，Ctrl+C 全停

	@echo ""

	@echo --- 开发工具（独立进程）---

	@echo make deploy-agent      - 仅 Deploy Agent (:19010)；make dev / moe-social 默认已带

	@echo make deploy-agent-stop - 释放 Agent 端口

	@echo make admin             - RPC+API+Agent+Moe Admin 一键启动

	@echo Moe Admin 前端: cd moe-admin && npm run dev  (:5173/ops/)

	@echo make rpc-debug         - RPC debug API (:19011)

	@echo make rpc-monitor       - 等同 deploy-agent（兼容别名）

	@echo make dev-docs          - 静态文档 (:19012)

	@echo ""

	@echo --- Kratos 运行时 ---

	@echo make moe-social          - 单进程 Kratos (:8888 HTTP + :8080 gRPC)，-f config/config.yaml
	@echo make moe-social-dev      - 同上 + deploy-agent (:19010) + RPC debug (:19011)
	@echo make moe-social-stop     - 释放开发端口
	@echo make check               - 编译 cmd/moe-social + 核心包单测
	@echo make gen                 - 安全：proto + conf + HTTP 路由（不碰 logic）
	@echo make gen-api             - 改 api/defs 后（goctl handler/types/routes）
	@echo make gen-rpc             - 改 rpc 契约后
	@echo make gen-all             - gen-api + gen-rpc + proto + 路由
	@echo make gen-http-routes     - routes.go → api/moehttp
	@echo make build-moe-social    - 生产单二进制

	@echo make moe-platform          - 迁移观测 (:19020)

	@echo make help          - 本说明

	@echo ""

	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin

