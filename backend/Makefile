# 在 backend 目录执行，例如: make gen | make build | make moe-social

.PHONY: all gen gen-moe-proto gen-swagger gen-moe-admin check-gen \
	api-one init-proto-tools check check-format vet test test-race temp-mail-password \
	moe-social moe-social-dev moe-social-stop \
	build build-moe-social build-linux env-status \
	db-migrate migrate-moe \
	deploy-config-init deploy-agent deploy-agent-stop admin \
	dev-docs help

# Serialize invocations involving generation, including make -j gen check-gen.
ifneq ($(filter all gen gen-moe-proto gen-swagger gen-moe-admin api-one init-proto-tools check-gen,$(or $(MAKECMDGOALS),all)),)
.NOTPARALLEL:
endif

all: gen

# Explicit installation only; versions are shared with the generation preflight.
init-proto-tools:
	bash scripts/gen/proto-tools.sh install

# One ordered pipeline: domain proto pb/grpc/http, then openapi.yaml.
gen: gen-moe-proto

gen-moe-proto:
	bash scripts/gen/moe-proto.sh

check-gen:
	bash scripts/gen/check-gen.sh

# 仅重生 openapi.yaml（make gen 已包含；单独调试时用）
gen-swagger:
	bash scripts/gen/openapi.sh

# Moe 管理台：gen + 编译（见 scripts/gen/moe-admin.sh）
gen-moe-admin: gen
	bash scripts/gen/moe-admin.sh --skip-gen

# 单模块 proto 生成：make api-one PROTO=api/<module>/v1/<module>.proto
api-one:
	bash scripts/gen/moe-proto.sh --proto "$(PROTO)"

# 全仓单测。CGO_ENABLED=1 是必须的，不是可选优化：
# gorm 的 sqlite 驱动依赖 cgo，关掉它 gorm.Open 直接报错，各处 helper 一律 t.Skip，
# go test ./... 照样报 ok —— 实测两个包各有失败用例被这样藏了很久（§25.4）。
# utils/cgo_canary_test.go 是配套的哨兵：CGO_ENABLED=0 时它会编译进来并直接失败。
test:
	CGO_ENABLED=1 go test ./... -count=1

test-race:
	CGO_ENABLED=1 go test -race ./... -count=1

check-format:
	bash scripts/check-go-format.sh

vet:
	CGO_ENABLED=1 go vet ./...

# 日常检查：格式、静态分析、生产入口编译与全仓单测。
check:
	$(MAKE) check-format
	$(MAKE) vet
	CGO_ENABLED=1 go build -o /dev/null ./cmd/moe-social
	$(MAKE) test

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
	@echo make gen              - 固定工具链生成 proto pb/grpc/http + openapi.yaml
	@echo make check-gen        - 临时生成并只读比较当前工作树产物
	@echo make gen-swagger      - 仅重生 openapi.yaml
	@echo make api-one          - 单模块 proto 生成 'PROTO=api/<mod>/v1/<mod>.proto'
	@echo make build            - 本机编译 bin/moe-social
	@echo make build-linux      - 交叉编译 Linux bin/moe-social
	@echo make check            - 格式门禁 + vet + 编译生产入口 + 全仓单测
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
