package moesocial

import (
	"context"
	"fmt"
	"log"
	"time"

	apirun "backend/internal/platform/wiring"
	"backend/devports"
	"backend/internal/platform/moewiring"
	rpcrun "backend/rpc/runserver"

	"github.com/go-kratos/kratos/v2"
)

func runWithKratosGRPC(opts Options) error {
	opts.NormalizeOptions()
	kratosRPC, rpcMonitor, err := rpcrun.StartKratos(rpcrun.Options{
		ConfigFile:    opts.RPCConfigFile,
		Migrate:       opts.Migrate,
		EnableMonitor: opts.EnableRPCMonitor,
	})
	if err != nil {
		return fmt.Errorf("kratos grpc start: %w", err)
	}

	go func() {
		if err := kratosRPC.Server.Start(context.Background()); err != nil {
			log.Printf("moe-social: kratos grpc stopped: %v", err)
		}
	}()

	if err := waitRPCListen(opts.UnifiedConfigFile, opts.RPCConfigFile, 15*time.Second); err != nil {
		_ = kratosRPC.Server.Stop(context.Background())
		return err
	}

	if rpcMonitor != nil {
		log.Printf("moe-social: RPC debug API %s/debug/live (经 deploy-agent /debug/* 访问)", devports.RpcDebugUpstream())
	}

	httpSrv, apiAddr, err := buildHTTPServer(opts, rpcMonitor)
	if err != nil {
		_ = kratosRPC.Server.Stop(context.Background())
		return err
	}

	app := kratos.New(
		kratos.Name("moe-social"),
		kratos.Server(httpSrv, kratosRPC.Server),
		kratos.AfterStop(func(context.Context) error {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return kratosRPC.Server.Stop(context.Background())
		}),
	)
	logStartup(kratosRPC.Addr, apiAddr, true)
	return app.Run()
}

func buildHTTPServer(opts Options, rpcMonitor interface{ Stop() }) (interface {
	Start(context.Context) error
	Stop(context.Context) error
}, string, error) {
	apiOpts := apirun.Options{ConfigFile: opts.APIConfigFile}

	if moewiring.KratosPureHTTPWithoutLegacy() {
		apiOpts.WireOnly = true
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("api wire: %w", err)
		}
		port := externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile)
		pure, err := newKratosPureHTTPServer(apiRes, "0.0.0.0", port)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("kratos pure http: %w", err)
		}
		addr := fmt.Sprintf("0.0.0.0:%d", port)
		return pure, addr, nil
	}
	if moewiring.KratosHTTPFrontEnabled() || moewiring.KratosHybridHTTPFallback() {
		return buildHTTPServerHybridLegacy(opts, rpcMonitor)
	}
	if rpcMonitor != nil {
		rpcMonitor.Stop()
	}
	return nil, "", fmt.Errorf("PK-8: go-zero HTTP retired; set moe.kratos_pure_enabled=true or moe.kratos_hybrid_http_fallback=true")
}

func logStartup(rpcAddr, apiAddr string, nativeGRPC bool) {
	log.Print("════════════════════════════════════════")
	log.Print("moe-social 已就绪")
	log.Printf("  HTTP (对外 REST): %s", apiAddr)
	log.Printf("  gRPC (内部 RPC):  %s", rpcAddr)
	switch {
	case moewiring.KratosPureEnabled():
		log.Print("  模式: 纯 Kratos HTTP + gRPC")
	case moewiring.KratosHTTPFrontEnabled():
		log.Print("  模式: Kratos HTTP 前置（未匹配路由回退 legacy）")
	case moewiring.KratosHybridHTTPFallback():
		log.Print("  模式: hybrid fallback（紧急回滚）")
	}
	if nativeGRPC {
		log.Print("  gRPC 传输: kratos/transport/grpc")
	} else if moewiring.KratosGRPCManaged() {
		log.Print("  gRPC 传输: kratos.App 托管")
	}
	log.Print("════════════════════════════════════════")
}
