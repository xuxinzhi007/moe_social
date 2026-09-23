package moesocial

import (
	"context"
	"fmt"
	"log"

	"backend/internal/platform/bootstrap"
	apirun "backend/internal/platform/wiring"
	"backend/pkg/conf"
	"backend/utils"

	"github.com/go-kratos/kratos/v2"
)

// runHTTPOnly starts the pure Kratos HTTP process on the external port.
func runHTTPOnly(opts Options) error {
	opts.NormalizeOptions()
	if _, err := conf.Load(); err != nil {
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
	backgroundCtx, cancelBackground := context.WithCancel(context.Background())
	deps := bootstrap.DepsFromServiceContext(apiRes.Svc)
	defer func() {
		cancelBackground()
		if deps.CompanionApp != nil {
			deps.CompanionApp.Stop()
		}
	}()
	bootstrap.AfterWire(backgroundCtx, deps)

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
	log.Printf("moe-social ready: Kratos HTTP-only on port %d", port)
}
