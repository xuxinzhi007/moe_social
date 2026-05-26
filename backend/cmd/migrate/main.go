// 独立 schema 迁移：只连库、跑 AutoMigrate、退出，不启动 RPC/API。
//
// 用法（在 backend/ 目录）:
//
//	go run ./cmd/migrate
//	go run ./cmd/migrate -models users,moe_agent_runtimes
//	go run ./cmd/migrate -force
//
// 若习惯迁移后直接启动 RPC，可在 rpc/ 目录: go run super.go -migrate
package main

import (
	"flag"
	"log"
	"os"

	"backend/utils"
)

var (
	models = flag.String("models", "", "comma-separated migrate keys (empty=all), e.g. users,moe_bot_episodes")
	force  = flag.Bool("force", false, "ignore schema hash cache and re-run AutoMigrate on selected tables")
)

func main() {
	flag.Parse()

	if err := utils.InitConfig(); err != nil {
		log.Fatalf("config: %v", err)
	}

	opts := utils.MigrateOptions{
		Enabled: true,
		Models:  utils.ParseMigrateModelKeys(*models),
		Force:   *force,
	}
	if err := utils.InitDBWithMigrate(opts); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	log.Println("migrate finished; start RPC with: cd rpc && go run super.go")
	os.Exit(0)
}
