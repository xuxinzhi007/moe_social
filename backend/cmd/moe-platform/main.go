// 迁移观测进程：Kratos HTTP 健康检查 + 迁移进度（Phase 3 Sprint 3，非生产入口）。
//
//	go run ./cmd/moe-platform
//	curl -s http://127.0.0.1:19020/health
//	curl -s http://127.0.0.1:19020/migration
package main

import (
	"encoding/json"
	"log"
	"os"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/transport/http"
)

func main() {
	addr := os.Getenv("MOE_PLATFORM_ADDR")
	if addr == "" {
		addr = ":19020"
	}

	httpSrv := http.NewServer(http.Address(addr))
	r := httpSrv.Route("/")
	r.GET("/health", func(ctx http.Context) error {
		return ctx.JSON(200, map[string]string{"status": "ok", "service": "moe-platform"})
	})
	r.GET("/migration", func(ctx http.Context) error {
		payload := map[string]any{
			"phase":            "moe-complete",
			"progress_percent": 100,
			"moe_domain_percent": 100,
			"repo_percent": 30,
			"migration_type":   "hybrid+moe-social",
			"notes": []string{
				"Moe domain: 100% (biz/service/data + MoeGW + moegrpc)",
				"Run: make moe-social (single process)",
				"Legacy super.api still serves non-Moe domains",
				"docs: docs/dev/kratos-migration.md",
			},
		}
		b, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		ctx.Response().Header().Set("Content-Type", "application/json")
		_, err = ctx.Response().Write(b)
		return err
	})

	app := kratos.New(
		kratos.Name("moe-platform"),
		kratos.Server(httpSrv),
	)
	log.Printf("moe-platform (kratos) listening on %s", addr)
	if err := app.Run(); err != nil {
		log.Fatal(err)
	}
}
