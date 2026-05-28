// 生产 SSOT：Kratos 单进程 HTTP :8888 + gRPC :8080。
//
//	go run ./cmd/moe-social
//	make moe-social
//
// 配置 SSOT：config/config.yaml（-f）；API/RPC 结构片段由 runtime 段指向。
package main

import (
	"flag"
	"log"

	"backend/internal/platform/moesocial"
	"backend/utils"
)

var (
	configFile = flag.String("f", "config/config.yaml", "Unified config (SSOT)")
	apiConfig  = flag.String("f-api", "", "Optional override: API struct fragment YAML")
	rpcConfig  = flag.String("f-rpc", "", "Optional override: RPC struct fragment YAML")
	migrate    = flag.Bool("migrate", false, "run schema migrate before starting")
)

func main() {
	flag.Parse()
	if err := moesocial.Run(moesocial.Options{
		UnifiedConfigFile: *configFile,
		APIConfigFile:     *apiConfig,
		RPCConfigFile:     *rpcConfig,
		Migrate:           utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
