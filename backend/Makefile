# 在 backend 目录执行: make gen
# RPC 必须在模块根目录生成：super.proto 的 go_package 含完整路径 backend/rpc/pb/super，
# 若在 rpc 目录使用 --go_out=./pb，会把路径叠成 rpc/pb/backend/rpc/pb/super（错误）。
# 使用 --go_opt=module=backend 后，pb 落在唯一正确目录: rpc/pb/super/

.PHONY: all gen gen-rpc gen-api build build-linux help

all: gen

gen: gen-rpc gen-api

# --client=false：避免 goctl 在 rpc/super 再生成一份 client（包名 super 与 pb 包冲突，会写成 super_super. 且无法编译）
gen-rpc:
	goctl rpc protoc rpc/super.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false

gen-api:
	cd api && goctl api go -api super.api -dir ./

# 构建二进制文件（本地）
build:
	go build -o api/moe-social-api ./api
	go build -o rpc/moe-social-rpc ./rpc

# 构建 Linux 二进制文件（用于服务器）
build-linux:
	@echo 构建 Linux 二进制文件...
	@go env -w CGO_ENABLED=0
	@go env -w GOOS=linux
	@go env -w GOARCH=amd64
	@go build -o api/moe-social-api ./api
	@go build -o rpc/moe-social-rpc ./rpc
	@go env -w GOOS=windows
	@echo 交叉编译完成，已恢复 GOOS 为 windows

help:
	@echo Targets:
	@echo   make gen           - RPC + API 代码生成
	@echo   make gen-rpc       - 仅 RPC 代码生成
	@echo   make gen-api       - 仅 API 代码生成
	@echo   make build         - 构建本地二进制文件
	@echo   make build-linux   - 构建 Linux 二进制文件（用于服务器）
	@echo   make help          - 显示帮助信息
