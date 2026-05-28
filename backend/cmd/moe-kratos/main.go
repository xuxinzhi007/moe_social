// 纯 Kratos 试点进程（Phase 0，PK-10 已弃用）：生产请用 make moe-social（:8888 纯 Kratos）。
//
//	go run ./cmd/moe-kratos   # 仅本地对照；默认打印弃用提示
//
// 连接已运行的 legacy Super（完整 Moe 能力）：
//
//	go run ./cmd/moe-kratos -super-rpc 127.0.0.1:8080
package main

import (
	"flag"
	"log"

	"backend/internal/platform/moekratos"
	"backend/internal/platform/moewiring"
	"backend/utils"
)

var (
	grpcAddr = flag.String("grpc", ":19031", "Kratos gRPC listen address")
	httpAddr = flag.String("http", ":19032", "Kratos HTTP listen address")
	superRPC = flag.String("super-rpc", "", "optional legacy Super gRPC host:port (e.g. 127.0.0.1:8080)")
	migrate  = flag.Bool("migrate", false, "run schema migrate before starting")
)

func main() {
	flag.Parse()
	if moewiring.PilotProcessDeprecated() {
		log.Print("moe-kratos: DEPRECATED — production uses `make moe-social` (Kratos HTTP :8888).")
		log.Print("  · Set moe.pilot_process_deprecated=false to silence; see docs/dev/kratos-directory-layout.md")
	}
	if err := moekratos.Run(moekratos.Options{
		GRPCAddr: *grpcAddr,
		HTTPAddr: *httpAddr,
		SuperRPC: *superRPC,
		Migrate:  utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
