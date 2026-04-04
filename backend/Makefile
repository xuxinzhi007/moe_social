# 在 backend 目录执行: make gen
# RPC 必须在模块根目录生成：super.proto 的 go_package 含完整路径 backend/rpc/pb/super，
# 若在 rpc 目录使用 --go_out=./pb，会把路径叠成 rpc/pb/backend/rpc/pb/super（错误）。
# 使用 --go_opt=module=backend 后，pb 落在唯一正确目录: rpc/pb/super/

.PHONY: all gen gen-rpc gen-api help

all: gen

gen: gen-rpc gen-api

# --client=false：避免 goctl 在 rpc/super 再生成一份 client（包名 super 与 pb 包冲突，会写成 super_super. 且无法编译）
gen-rpc:
	goctl rpc protoc rpc/super.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false

gen-api:
	cd api && goctl api go -api super.api -dir ./

help:
	@echo Targets:
	@echo   make gen       - RPC + API
	@echo   make gen-rpc   - 仅 RPC
	@echo   make gen-api   - 仅 API
	@echo   make help
