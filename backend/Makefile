# 在 backend 目录执行，例如: make gen | make build | make build-linux
# gen-rpc 须在 backend 根目录跑（pb 路径依赖 --go_opt=module=backend）

.PHONY: all gen gen-rpc gen-api build build-linux env-status help

# 交叉编译用「命令前面临时变量」，不用 go env -w，避免本机 go run 编错平台。

all: gen

gen: gen-rpc gen-api

# --client=false：避免与 pb 包名冲突、生成坏 client
gen-rpc:
	goctl rpc protoc rpc/super.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false

gen-api:
	cd api && goctl api go -api super.api -dir ./

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

help:
	@echo make gen           - 生成 RPC + API 代码
	@echo make gen-rpc       - 仅 RPC 代码生成
	@echo make gen-api       - 仅 API 代码生成
	@echo make build         - 本机打包 api + rpc
	@echo make build-linux   - 交叉编 Linux 包（不改全局 go 配置）
	@echo make env-status    - 打印 GOOS/GOARCH
	@echo make help          - 本说明
	@echo ""
	@echo 若本机 go run 曾异常，可试: go env -u GOOS  或  go env -w GOOS=darwin
	@echo ""
	@echo RPC: 在 rpc 目录执行 go run super.go ；改表时加 -migrate
