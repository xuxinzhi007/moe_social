# 在 backend 目录执行，例如: make gen | make build | make rpc | make dev



.PHONY: all gen gen-rpc gen-api gen-swagger gen-moe-admin build build-linux env-status \

	deploy-agent deploy-agent-stop admin \

	rpc api rpc-debug db-migrate rpc-migrate rpc-monitor rpc-monitor-stop \

	dev-docs dev help



# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。



all: gen



gen: gen-rpc gen-api gen-swagger



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



# 本机构建（当前系统）

build:

	go build -o api/moe-social-api ./api

	go build -o rpc/moe-social-rpc ./rpc



# 编 Linux 服务器用（amd64）。Windows 若失败可用 Git Bash / WSL 执行 make。

build-linux:

	@echo Building Linux amd64...

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

	@echo make deploy-agent      - Deploy Agent (:19010)，仅网关与运维 API

	@echo make deploy-agent-stop - 释放 Agent 端口

	@echo make admin             - RPC+API+Agent+Moe Admin 一键启动

	@echo Moe Admin 前端: cd moe-admin && npm run dev  (:5173/ops/)

	@echo make rpc-debug         - RPC debug API (:19011)

	@echo make rpc-monitor       - 等同 deploy-agent（兼容别名）

	@echo make dev-docs          - 静态文档 (:19012)

	@echo make help          - 本说明

	@echo ""

	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin

