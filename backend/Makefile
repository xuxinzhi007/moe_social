# 在 backend 目录执行，例如: make gen | make build | make moe-social

.PHONY: all gen gen-moe-proto gen-moe-conf gen-proto-route-count gen-swagger gen-moe-admin \
	api-one init-proto-tools check temp-mail-password \
	moe-social moe-social-dev moe-social-stop \
	build build-moe-social build-linux env-status \
	db-migrate migrate-moe \
	deploy-config-init deploy-agent deploy-agent-stop admin \
	dev-docs help

all: gen

# 安装 proto 代码生成工具（对齐 Kratos 官方：含 protoc-gen-go-http）
init-proto-tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@latest
	go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest

# 日常安全生成：域 proto + conf + 路由计数
# 注：gen-moe-proto 末尾会调用 openapi.sh，因此 openapi.yaml 会一并更新
gen: gen-moe-proto gen-moe-conf gen-proto-route-count

gen-moe-proto:
	bash scripts/gen/moe-proto.sh

gen-moe-conf:
	bash scripts/gen/moe-conf.sh

# 从 api/**/v1/*_http.pb.go 统计 → internal/server/routestats/proto_routes_gen.go
gen-proto-route-count:
	cd scripts/gen/proto-route-count && go run .

# 仅重生 openapi.yaml（make gen 已包含；单独调试时用）
gen-swagger:
	bash scripts/gen/openapi.sh

# Moe 管理台：gen + 删空壳 + 编译（见 scripts/gen/moe-admin.sh）
gen-moe-admin:
	bash scripts/gen/moe-admin.sh

# 单模块 proto 生成：make api-one PROTO=api/<module>/v1/<module>.proto
api-one:
	@if [ -z "$(PROTO)" ]; then echo "Usage: make api-one PROTO=api/<module>/v1/<module>.proto"; exit 1; fi
	protoc \
		--proto_path=. \
		--proto_path=./third_party \
		--go_out=. --go_opt=module=backend \
		--go-grpc_out=. --go-grpc_opt=module=backend \
		--go-http_out=. --go-http_opt=module=backend \
		$(PROTO)

# 日常检查：编译生产入口 + 核心包单测
check:
	go build -o /dev/null ./cmd/moe-social
	go test ./internal/platform/moesocial/... ./internal/server/routestats/... -count=1

# 计算临时邮箱对应的 mail.tm 内部密码
# 用法：make temp-mail-password EMAIL=foo@web-library.net
temp-mail-password:
ifeq ($(OS),Windows_NT)
	@if "$(EMAIL)"=="" (echo Usage: make temp-mail-password EMAIL=foo@web-library.net && exit /b 1)
	go run ./cmd/temp-mail-password --email "$(EMAIL)"
else
	@if [ -z "$(EMAIL)" ]; then echo "Usage: make temp-mail-password EMAIL=foo@web-library.net"; exit 1; fi
	go run ./cmd/temp-mail-password --email "$(EMAIL)"
endif

moe-social:
	go run ./cmd/moe-social

# 开发：moe-social（默认不带 deploy-agent）
moe-social-dev:
	go run ./cmd/moe-social-stack -agent=false

# 释放 8080/8888/19010/19011/19012（Ctrl+C 未完全退出时用）
moe-social-stop:
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File deploy/scripts/stop-moe-social.ps1
else
	@bash deploy/scripts/stop-moe-social.sh
endif

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

db-migrate:
	go run ./cmd/migrate

# 新机器 / Moe 功能：仅迁移 Bot、试跑日志、AI 聊天等表
migrate-moe:
	go run ./cmd/migrate -models moe_agent_runtimes,moe_bot_episodes,moe_tool_calls,moe_agent_run_logs,ai_chat_sessions,ai_chat_messages

# 首次生成 deploy/config.yaml（已存在则跳过，不会覆盖）
deploy-config-init:
ifeq ($(OS),Windows_NT)
	@if not exist deploy\config.yaml (copy deploy\config.example.yaml deploy\config.yaml && echo created deploy/config.yaml — please edit token) else (echo deploy/config.yaml already exists (not overwritten))
else
	@if [ ! -f deploy/config.yaml ]; then cp deploy/config.example.yaml deploy/config.yaml && echo "created deploy/config.yaml — please edit token"; else echo "deploy/config.yaml already exists (not overwritten)"; fi
endif

# Deploy Agent（:19010）：Deploy API、admin 代理、docs/dev；不构建/不打开 Moe Admin
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

# 文档静态站（Moe 专属 :19012，见 docs/dev/ports.md）
dev-docs:
	cd ../docs && python -m http.server 19012

help:
	@echo make gen              - proto + conf + HTTP 路由计数（含 openapi.yaml）
	@echo make gen-swagger      - 仅重生 openapi.yaml
	@echo make api-one          - 单模块 proto 生成 'PROTO=api/<mod>/v1/<mod>.proto'
	@echo make build            - 本机编译 bin/moe-social
	@echo make build-linux      - 交叉编译 Linux bin/moe-social
	@echo make check            - 编译 + 核心包单测
	@echo ""
	@echo --- 生产 / 开发 ---
	@echo make moe-social         - Kratos HTTP :8888（生产入口）
	@echo make moe-social-dev     - 同上（默认不带 deploy-agent）
	@echo make moe-social-stop    - 释放开发端口
	@echo make db-migrate         - 数据库 schema 迁移
	@echo make migrate-moe        - 仅迁移 Moe/AI 相关表
	@echo make deploy-agent       - 部署调试代理 :19010
	@echo make admin              - 启动管理台
	@echo make temp-mail-password - 计算临时邮箱内部密码 EMAIL=...
	@echo ""
	@echo 契约 SSOT: 'api/<domain>/v1/*.proto'  Apifox: backend/openapi.yaml
	@echo 布局说明: LAYOUT.md  架构: docs/dev/kratos-migration.md
