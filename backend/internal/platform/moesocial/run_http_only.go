package moesocial

import (
	"context"
	"fmt"
	"log"

	"backend/internal/platform/bootstrap"
	apirun "backend/internal/platform/wiring"
	"backend/utils"

	"github.com/go-kratos/kratos/v2"
)

// runHTTPOnly 单进程纯 Kratos HTTP（:8888），不监听 gRPC。
func runHTTPOnly(opts Options) error {
	opts.NormalizeOptions()
	if err := utils.InitConfig(); err != nil {
		return fmt.Errorf("config: %w", err)
	}
	if opts.Migrate.Enabled {
		if err := utils.InitDBWithMigrate(opts.Migrate); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}

	apiOpts := apirun.Options{ConfigFile: opts.APIConfigFile, WireOnly: true}
	apiRes, err := apirun.StartWithResult(apiOpts)
	if err != nil {
		return fmt.Errorf("wire: %w", err)
	}
	bootstrap.AfterWire(context.Background(), apiRes.Svc)

	port := externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile)
	httpSrv, err := newKratosPureHTTPServer(apiRes, "0.0.0.0", port)
	if err != nil {
		return fmt.Errorf("kratos http: %w", err)
	}

	app := kratos.New(
		kratos.Name("moe-social"),
		kratos.Server(httpSrv),
	)
	logHTTPOnlyStartup(port)
	return app.Run()
}

func logHTTPOnlyStartup(port int) {
	log.Printf("moe-social 已就绪 · Kratos HTTP-only · 端口 %d（listening 日志见下方）", port)
}
