// 纯 Kratos 试点进程（Phase 0）：与 Hybrid 并行，不替代 make moe-social。
//
//	go run ./cmd/moe-kratos
//	curl -s http://127.0.0.1:19032/health
//	curl -s http://127.0.0.1:19032/kratos/v1/moe/runtimes
//
// 连接已运行的 legacy Super（完整 Moe 能力）：
//
//	go run ./cmd/moe-kratos -super-rpc 127.0.0.1:8080
package main

import (
	"flag"
	"log"

	"backend/internal/platform/moekratos"
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
	if err := moekratos.Run(moekratos.Options{
		GRPCAddr: *grpcAddr,
		HTTPAddr: *httpAddr,
		SuperRPC: *superRPC,
		Migrate:  utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
