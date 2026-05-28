package moesocial

import (
	"context"
	"fmt"
	"log"
	"time"

	apirun "backend/api/runserver"
	"backend/devports"
	"backend/internal/platform/moewiring"
	rpcrun "backend/rpc/runserver"

	"github.com/go-kratos/kratos/v2"
)

func runWithKratosGRPC(opts Options) error {
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

	if err := waitRPCListen(opts.RPCConfigFile, 15*time.Second); err != nil {
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
		port := externalHTTPPort(opts.APIConfigFile)
		pure, err := newKratosPureHTTPServer(apiRes, "0.0.0.0", port)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("kratos pure http: %w", err)
		}
		addr := fmt.Sprintf("0.0.0.0:%d", port)
		log.Printf("moe-social: pure Kratos HTTP %s (no go-zero rest)", addr)
		return pure, addr, nil
	}
	if moewiring.KratosHTTPFrontEnabled() {
		internalPort := moewiring.KratosInternalHTTPPort()
		apiOpts.InternalHTTPPort = internalPort
		apiOpts.InternalHTTPHost = "127.0.0.1"
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("api start: %w", err)
		}
		front, err := newKratosFrontServer(apiRes, "0.0.0.0", externalHTTPPort(opts.APIConfigFile))
		if err != nil {
			if apiRes.Server != nil {
				apiRes.Server.Stop()
			}
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("kratos front: %w", err)
		}
		addr := fmt.Sprintf("0.0.0.0:%d", externalHTTPPort(opts.APIConfigFile))
		log.Printf("moe-social: PK-4 enabled — Kratos HTTP %s, go-zero 127.0.0.1:%d (fallback)", addr, internalPort)
		return front, addr, nil
	}
	if moewiring.KratosHybridHTTPFallback() {
		apiSrv, err := apirun.Start(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			return nil, "", fmt.Errorf("api start: %w", err)
		}
		addr := apiListenAddr(opts.APIConfigFile)
		log.Printf("moe-social: PK-8 hybrid fallback — go-zero HTTP %s", addr)
		return wrapREST(apiSrv), addr, nil
	}
	if rpcMonitor != nil {
		rpcMonitor.Stop()
	}
	return nil, "", fmt.Errorf("PK-8: go-zero HTTP retired; set moe.kratos_pure_enabled=true or moe.kratos_hybrid_http_fallback=true")
}

func logStartup(rpcAddr, apiAddr string, nativeGRPC bool) {
	log.Printf("moe-social: 单进程已就绪 — gRPC %s + HTTP %s", rpcAddr, apiAddr)
	log.Printf("moe-social: 对外请使用 HTTP %s（Flutter / moe-admin / 第三方 REST 不变）", apiAddr)
	if moewiring.KratosPureEnabled() {
		log.Print("  · PK-9: 纯 Kratos 生产（transport/http + transport/grpc）")
	} else if moewiring.KratosHTTPFrontEnabled() {
		log.Print("  · PK-4: Kratos HTTP :8888（未匹配路由回退 go-zero 内网）")
	} else if moewiring.KratosHybridHTTPFallback() {
		log.Print("  · PK-8 hybrid fallback: go-zero HTTP（紧急回滚）")
	}
	if nativeGRPC {
		log.Print("  · PK-11: Super gRPC 使用 kratos/transport/grpc（非 zrpc）")
	} else if moewiring.KratosGRPCManaged() {
		log.Print("  · gRPC :8080 由 kratos.App 管理（zrpc）")
	}
}
