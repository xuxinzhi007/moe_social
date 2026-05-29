// 生产入口：单进程 Kratos HTTP :8888。
//
//	make moe-social
//	go run ./cmd/moe-social -f config/config.yaml
//
// 开发附加 deploy-agent 请用 cmd/moe-social-stack（make moe-social-dev）。
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
	migrate    = flag.Bool("migrate", false, "run schema migrate before starting")
)

func main() {
	flag.Parse()
	if err := moesocial.Run(moesocial.Options{
		UnifiedConfigFile: *configFile,
		APIConfigFile:     *apiConfig,
		Migrate:           utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
