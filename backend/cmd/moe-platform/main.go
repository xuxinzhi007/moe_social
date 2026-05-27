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
			"phase":              "hybrid-moe-complete+pure-kratos-60",
			"progress_percent":   100,
			"moe_domain_percent": 100,
			"pure_kratos_percent": 100,
			"external_http_port":  "8888",
			"repo_percent":       48,
			"migration_type":     "hybrid+moe-social+kratos-pilot",
			"notes": []string{
				"Hybrid Moe: 100% — make moe-social, make verify-moe-complete",
				"Pure Kratos: 100% — verify-kratos-100, build-moe-social; external HTTP :8888",
				"Gray: moe.kratos_admin_http_enabled → MoeGW kratos_http",
				"docs: docs/dev/kratos-migration.md, docs/dev/kratos-pure-migration-plan.md",
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
