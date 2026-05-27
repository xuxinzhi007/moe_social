# 在 backend 目录执行，例如: make gen | make build | make rpc | make dev



.PHONY: all gen gen-moe-proto gen-moe-conf gen-rpc gen-api gen-swagger gen-moe-admin api-moe-proto verify-moe-migration verify-moe-grpc verify-moe-gateway verify-moe-complete verify-domain-vip verify-domain-user verify-domain-misc verify-platform verify-full-site-50 verify-kratos-pilot verify-kratos-50 verify-kratos-60 verify-kratos-80 verify-kratos-100 moe-social moe-platform moe-kratos migrate-moe build build-moe-social build build-linux env-status \

	deploy-agent deploy-agent-stop admin \

	rpc api rpc-debug db-migrate rpc-migrate rpc-monitor rpc-monitor-stop \

	dev-docs dev help



# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。



all: gen



# 生成：api/**/v1 proto（Kratos 风格目录）+ legacy goctl（super.api / super.proto）
gen: gen-moe-proto gen-moe-conf gen-rpc gen-api gen-swagger

gen-moe-proto:
	bash scripts/gen-moe-proto.sh

gen-moe-conf:
	bash scripts/gen-moe-conf.sh



# --client=false：避免与 pb 包名冲突、生成坏 client

gen-rpc:

	goctl rpc protoc rpc/super.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false



gen-api:

	cd api && goctl api go -api super.api -dir ./



gen-swagger:

	@command -v goctl-swagger >/dev/null 2>&1 || (echo "goctl-swagger 未安装，请先执行: go install github.com/zeromicro/goctl-swagger@latest" && exit 1)

	cd api && goctl api plugin -plugin goctl-swagger="swagger -filename ../rest.swagger.json" -api super.api -dir ./



# Moe 管理台相关：gen + 删除与 moe_admin_logic.go 冲突的空壳 + 编译（见 scripts/gen-moe-admin.sh）
gen-moe-admin:

	bash scripts/gen-moe-admin.sh

# Moe 域 proto（Kratos 混合迁移 SSOT；可选生成，逻辑层不强制依赖 pb）
api-moe-proto:

	bash scripts/gen-moe-proto.sh

# Kratos 混合迁移验收（编译 + 单测 + RPC 注册检查）
verify-moe-migration:

	bash scripts/verify-moe-migration.sh

verify-moe-grpc:

	bash scripts/verify-moe-grpc.sh

verify-moe-gateway:

	bash scripts/verify-moe-gateway.sh

verify-moe-complete:

	bash scripts/verify-moe-complete.sh

verify-domain-vip:

	bash scripts/verify-domain-vip.sh

verify-domain-user:

	bash scripts/verify-domain-user.sh

verify-domain-misc:

	bash scripts/verify-domain-misc.sh

verify-platform:

	bash scripts/verify-platform.sh

verify-full-site-50:

	bash scripts/verify-full-site-50.sh

moe-social:

	go run ./cmd/moe-social-stack -f-api api/etc/super.yaml -f-rpc rpc/etc/super.yaml

moe-platform:

	go run ./cmd/moe-platform

verify-kratos-pilot:

	bash scripts/verify-kratos-pilot.sh

verify-kratos-50:

	bash scripts/verify-kratos-50.sh

verify-kratos-60:

	bash scripts/verify-kratos-60.sh

verify-kratos-80:

	bash scripts/verify-kratos-80.sh

verify-kratos-100:

	bash scripts/verify-kratos-100.sh

moe-kratos:

	go run ./cmd/moe-kratos



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

	go run ./rpc/super.go -f rpc/etc/super.yaml



api:

	go run ./api/super.go -f api/etc/super.yaml



db-migrate:

	go run ./cmd/migrate

# 新机器 / Moe 功能：仅迁移 Bot、试跑日志、AI 聊天等表
migrate-moe:

	go run ./cmd/migrate -models moe_agent_runtimes,moe_bot_episodes,moe_tool_calls,moe_agent_run_logs,ai_chat_sessions,ai_chat_messages



# 兼容旧命令：等价于 db-migrate（不再启动 RPC 进程）
rpc-migrate: db-migrate



# RPC 进程内 debug API（:19011），Agent 将 /debug/* 转发到此

rpc-debug:

	go run ./rpc/super.go -f rpc/etc/super.yaml -debug



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

	@echo --- Kratos 迁移 ---

	@echo make moe-social          - Hybrid 单进程 (:8888+:8080) + deploy-agent (:19010)

	@echo make moe-kratos            - 纯 Kratos 试点 (:19031+:19032，并行)

	@echo make verify-kratos-100     - 纯 Kratos 100%% + Hybrid 回归（推荐）
	@echo make verify-kratos-80      - 纯 Kratos 80%% 验收（Phase 0-4）
	@echo make build-moe-social      - 生产推荐单二进制（:8888+:8080）
	@echo make verify-kratos-60      - 纯 Kratos 60%% 验收（Phase 0-3）
	@echo make verify-kratos-50      - 纯 Kratos 50%% 验收（Phase 0-2）
	@echo make verify-kratos-pilot   - 同 verify-kratos-50 子集（兼容）

	@echo make moe-platform          - 迁移观测 (:19020)

	@echo make help          - 本说明

	@echo ""

	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin

