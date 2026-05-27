// 单进程入口：HTTP :8888 + gRPC :8080（Kratos 编排，Moe 迁移终态推荐开发方式）。
//
//	go run ./cmd/moe-social
//	或 make moe-social
//
// 等价于同进程内 make rpc + make api，但只起一个 OS 进程。
package main

import (
	"flag"
	"log"

	"backend/internal/platform/moesocial"
	"backend/utils"
)

var (
	apiConfig = flag.String("f-api", "api/etc/super.yaml", "API config (go-zero rest)")
	rpcConfig = flag.String("f-rpc", "rpc/etc/super.yaml", "RPC config (go-zero zrpc)")
	migrate   = flag.Bool("migrate", false, "run schema migrate before starting")
)

func main() {
	flag.Parse()
	if err := moesocial.Run(moesocial.Options{
		APIConfigFile: *apiConfig,
		RPCConfigFile: *rpcConfig,
		Migrate:       utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
