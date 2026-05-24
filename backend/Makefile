# 在 backend 目录执行，例如: make gen | make build | make rpc | make dev



.PHONY: all gen gen-rpc gen-api gen-swagger build build-linux env-status \

	deploy-agent deploy-agent-stop ops-console-install ops-console-dev ops-console-build \

	rpc api rpc-debug rpc-migrate rpc-monitor rpc-monitor-stop \

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



rpc-migrate:

	go run ./rpc/super.go -f rpc/etc/super.yaml -migrate



# RPC 进程内 debug API（:19011），Agent 将 /debug/* 转发到此

rpc-debug:

	go run ./rpc/super.go -f rpc/etc/super.yaml -debug



# ===== 开发工具（独立进程，类似 deploy-agent）=====



# 首次生成 deploy/config.yaml（已存在则跳过，不会覆盖）

deploy-config-init:

	@if [ ! -f deploy/config.yaml ]; then cp deploy/config.example.yaml deploy/config.yaml && echo "created deploy/config.yaml — please edit token"; else echo "deploy/config.yaml already exists (not overwritten)"; fi



# 开发者 / 运维统一工具台（Moe 专属 :19010，见 docs/dev/ports.md）
# 默认打开 React 运维台（/ops/）；无 dist 时自动构建；HTML 版仍可通过 /tools/deploy-ops.html

deploy-agent: ops-console-build-if-needed

	go run ./cmd/deploy-agent -f deploy/config.yaml



# 仅当 ops-console/dist 不存在时构建（避免每次 npm ci）
ops-console-build-if-needed:

ifeq ($(OS),Windows_NT)
	@if not exist "..\ops-console\dist\index.html" (\
		echo [deploy-agent] building React ops-console... && \
		cd ../ops-console && if not exist node_modules npm ci && npm run build\
	) else (echo [deploy-agent] using existing ops-console/dist)
else
	@if [ ! -f ../ops-console/dist/index.html ]; then \
		echo "[deploy-agent] building React ops-console..."; \
		cd ../ops-console && ( [ -d node_modules ] || npm ci ) && npm run build; \
	else \
		echo "[deploy-agent] using existing ops-console/dist"; \
	fi
endif



ops-console-install:

	cd ../ops-console && npm ci



ops-console-dev:

	cd ../ops-console && npm run dev



ops-console-build:

	cd ../ops-console && npm ci && npm run build



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

	@echo make rpc-migrate   - RPC + 数据库迁移

	@echo make dev           - RPC + API 联调，Ctrl+C 全停

	@echo ""

	@echo --- 开发工具（独立进程）---

	@echo make deploy-agent      - 统一工具台 (:19010)，自动打开 React /ops/

	@echo make deploy-agent-stop - 释放 Agent 端口

	@echo make ops-console-dev   - React 运维台开发 (:5173/ops/)

	@echo make ops-console-build - 构建 React 运维台 → Agent /ops/

	@echo make rpc-debug         - RPC debug API (:19011)

	@echo make rpc-monitor       - 等同 deploy-agent（兼容别名）

	@echo make dev-docs          - 静态文档 (:19012)

	@echo make help          - 本说明

	@echo ""

	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin

