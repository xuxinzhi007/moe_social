# 在 backend 目录执行，例如: make gen | make build | make rpc | make dev



.PHONY: all gen gen-legacy-goctl gen-moe-proto gen-moe-conf gen-moekratospilot-get gen-rpc gen-api gen-swagger gen-moe-admin api-moe-proto verify-moe-migration verify-moe-grpc verify-moe-gateway verify-moe-complete verify-domain-vip verify-domain-user verify-domain-misc verify-platform verify-full-site-50 verify-kratos-pilot verify-kratos-50 verify-kratos-60 verify-kratos-80 verify-kratos-100 verify-kratos-pure-50 verify-kratos-pure-80 verify-kratos-pure-90 verify-kratos-pure-100 verify-kratos-rollout-pk0 moe-social-dev verify-kratos-rollout-pk1 verify-kratos-rollout-pk2 verify-kratos-rollout-pk12 verify-kratos-rollout-pk3 verify-kratos-rollout-pk4 verify-kratos-rollout-pk6 verify-kratos-rollout-pk7 verify-kratos-rollout-pk11 verify-kratos-rollout-pk34 verify-kratos-rollout-pk8 verify-kratos-rollout-85 verify-kratos-rollout-70 verify-kratos-rollout-regression verify-kratos-rollout-regression-full moe-social moe-social-stop moe-platform moe-kratos migrate-moe build build-moe-social build build-linux env-status \

	deploy-agent deploy-agent-stop moe-social-stop admin \

	rpc api rpc-debug db-migrate rpc-migrate rpc-monitor rpc-monitor-stop \

	dev-docs dev help



# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。



all: gen



# 生成：域 proto + RPC + Kratos 路由注册（PK-8 默认不含 goctl gen-api）
gen: gen-moe-proto gen-moe-conf gen-rpc gen-moekratospilot-get

# 紧急/兼容：goctl api + swagger（需 MOE_ALLOW_GOCTL_API=1）
gen-legacy-goctl: gen-api gen-swagger

gen-moe-proto:
	bash scripts/gen-moe-proto.sh

gen-moe-conf:
	bash scripts/gen-moe-conf.sh

# PK-10b：从 routes.go 生成 routes_native_gen.go + routes_bridge_gen.go（swagger bridge）
gen-moekratospilot-get:
	cd scripts/gen-moekratospilot-get && go run ./

# --client=false：避免与 pb 包名冲突、生成坏 client

gen-rpc: fs8-assemble-super-proto

	goctl rpc protoc rpc/moe.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false
	@rm -f rpc/pb/super/super.pb.go rpc/pb/super/super_grpc.pb.go rpc/pb/super/common.pb.go rpc/pb/super/moe.pb.go rpc/pb/super/moe_grpc.pb.go
	bash scripts/fs9b-gen-pb-super-shim.sh
	bash scripts/fs9-fix-rpc-server-import.sh
	bash scripts/prune-rpc-logic-shells.sh

fs8-assemble-super-proto:
	python3 scripts/fs8-assemble-super-proto.py

# 仅从单体 moe.proto 重新切分（覆盖 defs 手工编辑，慎用）
fs8-split-super-proto:
	python3 scripts/fs8-split-super-proto.py
	python3 scripts/fs8-assemble-super-proto.py



gen-api:
	bash scripts/gen-api-guard.sh
	cd api && goctl api go -api moe.api -dir ./
	bash scripts/prune-api-logic-shells.sh
	$(MAKE) gen-moekratospilot-get



gen-swagger:

	@command -v goctl-swagger >/dev/null 2>&1 || (echo "goctl-swagger 未安装，请先执行: go install github.com/zeromicro/goctl-swagger@latest" && exit 1)

	cd api && goctl api plugin -plugin goctl-swagger="swagger -filename ../rest.swagger.json" -api moe.api -dir ./



# Moe 管理台相关：gen + 删除与 moe_admin_logic.go 冲突的空壳 + 编译（见 scripts/gen-moe-admin.sh）
gen-moe-admin:

	bash scripts/gen-moe-admin.sh

# Moe 域 proto（Kratos 混合迁移 SSOT；可选生成，逻辑层不强制依赖 pb）
api-moe-proto:

	bash scripts/gen-moe-proto.sh

# 验收门禁（目录 scripts/verify/，说明 scripts/README.md）
verify:

	bash scripts/verify/kratos-pure-100.sh

verify-kratos-pure-100: verify

verify-kratos-regression:

	bash scripts/verify/kratos-regression.sh

verify-kratos-regression-full:

	bash scripts/verify/kratos-regression-full.sh

verify-kratos-100: verify-kratos-regression-full

verify-moe-migration:

	bash scripts/verify/domain/verify-moe-migration.sh

verify-moe-grpc:

	bash scripts/verify/domain/verify-moe-grpc.sh

verify-moe-gateway:

	bash scripts/verify/domain/verify-moe-gateway.sh

verify-moe-complete:

	bash scripts/verify/domain/verify-moe-complete.sh

verify-domain-vip:

	bash scripts/verify/domain/verify-domain-vip.sh

verify-domain-user:

	bash scripts/verify/domain/verify-domain-user.sh

verify-domain-misc:

	bash scripts/verify/domain/verify-domain-misc.sh

verify-platform:

	bash scripts/verify/domain/verify-platform.sh

verify-full-site-50:

	bash scripts/verify/domain/verify-full-site-50.sh

verify-sprint-regression:

	bash scripts/verify/sprint/regression.sh

verify-sprint-f100-structure:

	bash scripts/verify/sprint/f100-structure.sh

verify-sprint-f102-admin-memory:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f102-admin-memory.ps1
else
	bash scripts/verify/sprint/f102-admin-memory.sh
endif

verify-sprint-f104-admin-insights:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f104-admin-insights.ps1
else
	@test -f internal/biz/admin/insights_ops.go
	@grep -q 'AdminGW.AdminListAiChatSessions' api/internal/logic/admin/admin_insights_logic.go
	@go build ./api ./rpc
endif

verify-sprint-f107-chat-read:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f107-chat-read.ps1
else
	@test -f internal/biz/chat/private_message_read.go
	@grep -q 'ChatGW.ListPrivateMessages' api/internal/logic/privatemsg/listprivatemessageslogic.go
	@grep -q 'ChatGW.ListPrivateConversations' api/internal/logic/privatemsg/listprivateconversationslogic.go
	@grep -q 'UserGW.GetUser' api/internal/logic/voice/voicecalllogic.go
	@go build ./api ./rpc
endif

verify-sprint-f109-user-tail:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f109-user-tail.ps1
else
	@! grep -r 'SuperRpcClient' api/internal/logic/user/ 2>/dev/null || true
	@test -f internal/biz/user/profile.go
	@test -f internal/biz/llm/memory_read.go
	@grep -q 'UserGW.GetUsers' api/internal/logic/user/getuserslogic.go
	@go test ./internal/biz/user/... ./internal/biz/llm/... -count=1
	@go build ./api ./rpc
endif

verify-gen-hygiene:
	bash scripts/verify-gen-hygiene.sh

verify-sprint-fs10-admin-rpc:
	bash scripts/verify/sprint/fs10-admin-rpc.sh
	@grep -q 'newAdminApp' rpc/internal/logic/adminlistmemorieslogic.go
	@grep -q 'newAdminApp' rpc/internal/logic/admindashboardlogic.go

verify-sprint-fs10:
	bash scripts/verify/sprint/fs10.sh
	@grep -q 'newLLMApp' rpc/internal/logic/upsertusermemoryembeddinglogic.go
	@grep -q 'newVipAdminApp' rpc/internal/logic/adminupdatevipplanlogic.go
	@go build ./api ./rpc

# FS-8：仅从单体 moe.api 重新切分 defs（会覆盖 defs 手工编辑，慎用）
fs8-split-api:
	python3 scripts/fs8-split-super-api.py

verify-sprint-fs8:
	bash scripts/verify/sprint/fs8.sh

verify-sprint-fs8b:
	bash scripts/verify/sprint/fs8b.sh

verify-sprint-fs9:
	bash scripts/verify/fs9.sh

verify-sprint-fs9b:
	bash scripts/verify/fs9b.sh

verify-sprint-f113-rpc-notify:
	@grep -q 'notifybiz.CreateInbox' rpc/internal/logic/createnotificationlogic.go
	@go build ./api ./rpc

verify-sprint-f112:
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f112.ps1
else
	@test -f internal/biz/admin/auth.go
	@test -f internal/biz/ai/user_config.go
	@grep -q 'g.local.AdminLogin' api/internal/admingw/gateway_public.go
	@grep -q 'g.local.GetAiUserConfig' api/internal/llmgw/gateway.go
	@grep -q 'ResolveVoiceUserDisplay' api/internal/logic/voice/voicecalllogic.go
	@bash scripts/verify-gw-local-first.sh
	@go test ./internal/biz/admin/... ./internal/biz/ai/... -count=1
	@go build ./api ./rpc
endif

verify-sprint-f111:
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f111.ps1
else
	@test -f internal/biz/admin/audit_write.go
	@test -f internal/biz/user/avatar.go
	@test -f api/internal/admingw/gateway_audit.go
	@grep -q 'AdminGW.RecordAdminAuditLog' api/internal/common/admin_audit_writer.go
	@! grep -q 'SuperRpcClient' api/internal/common/admin_audit_writer.go
	@grep -q 'g.local.GetUserAvatar' api/internal/usergw/gateway_f110.go
	@grep -q 'g.local.ExecuteTool' api/internal/moeadmingw/gateway_tools.go
	@grep -q 'userbiz.GetUserAvatar' rpc/internal/logic/getuseravatarlogic.go
	@go test ./internal/biz/user/... ./internal/biz/admin/... -count=1
	@go build ./api ./rpc
endif

verify-sprint-f110:
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f110.ps1
else
	@! grep -r 'SuperRpcClient' api/internal/logic/ 2>/dev/null || (echo "F110: SuperRpcClient still in api/internal/logic" && exit 1)
	@test -f api/internal/usergw/gateway_f110.go
	@test -f api/internal/admingw/gateway_public.go
	@test -f api/internal/moeadmingw/gateway_tools.go
	@grep -q 'UpsertAiUserConfig' api/internal/llmgw/gateway.go
	@grep -q 'UserGW.GetUserAvatar' api/internal/logic/avatar/getuseravatarlogic.go
	@grep -q 'AdminGW.AdminLogin' api/internal/logic/admin_public/adminloginlogic.go
	@grep -q 'MoeGW.MoeExecuteTool' api/internal/logic/moe/executemoetoollogic.go
	@grep -q 'UserGW.CreateNotification' api/internal/logic/chat/private_chat_delivery.go
	@go build ./api ./rpc
endif

verify-sprint-f108-admin-tail:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f108-admin-tail.ps1
else
	@! grep -r 'SuperRpcClient' api/internal/logic/admin/ 2>/dev/null || true
	@test -f internal/biz/admin/moderation_lists.go
	@grep -q 'AdminGW.AdminListFollows' api/internal/logic/admin/adminlistfollowslogic.go
	@go build ./api ./rpc
endif

verify-sprint-f100-final:

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-sprint-f100-final.ps1
else
	@test -f internal/biz/admin/insights_ops.go
	@test -f api/internal/aigw/gateway.go
	@test -f api/internal/chatgw/gateway.go
	@test -f api/admin/v1/admin_insights.proto
	@test -f api/ai/v1/ai_resources.proto
	@test -f api/llm/v1/llm_chat.proto
	@test -f api/chat/v1/private_message.proto
	@grep -q 'AdminGW.AdminListAiChatSessions' api/internal/logic/admin/admin_insights_logic.go
	@grep -q 'AIGW' api/internal/logic/ai/resource_logic.go
	@grep -q 'DEPRECATED' api/moe.api rpc/moe.proto
	@go build ./api ./rpc
endif

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

	cd scripts/fs9b-rewrite-imports && go run ./

# 兼容旧文档中的 target 名
verify-kratos-rollout-regression: verify-kratos-regression

verify-kratos-rollout-regression-full: verify-kratos-regression-full

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

	@echo --- Kratos 迁移 ---

	@echo make moe-social          - 纯 Kratos 单进程 (:8888 HTTP + :8080 gRPC)，-f config/config.yaml
	@echo make moe-social-dev      - 同上 + deploy-agent (:19010) + RPC debug (:19011)

	@echo make moe-social-stop     - 释放开发端口（叠跑/Ctrl+C 残留时用）

	@echo make moe-kratos            - 纯 Kratos 试点 (:19031+:19032，并行)

	@echo make verify-kratos-rollout-pk12 - PK-1+PK-2 纯 Kratos 契约与灰度验收
	@echo make verify-kratos-rollout-pk0  - 纯 Kratos PK-0 基线
	@echo make verify-kratos-rollout-pk1  - PK-1 域 proto 纪律
	@echo make verify-kratos-rollout-pk2  - PK-2 Moe/VIP kratos_http 灰度
	@echo make verify                - 纯 Kratos 100%% 门禁（推荐）
	@echo make verify-kratos-regression - PK/Kratos PR 轻量回归
	@echo make verify-kratos-regression-full - 发版：Kratos + F 全量
	@echo make build-moe-social      - 生产单二进制（:8888+:8080）

	@echo make moe-platform          - 迁移观测 (:19020)

	@echo make help          - 本说明

	@echo ""

	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin

