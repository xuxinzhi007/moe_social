//go:build hybrid

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
	"github.com/zeromicro/go-zero/rest"
)

func runWithZRPC(opts Options) error {
	rpcSrv, _, rpcMonitor, err := rpcrun.Start(rpcrun.Options{
		ConfigFile:    opts.RPCConfigFile,
		Migrate:       opts.Migrate,
		EnableMonitor: opts.EnableRPCMonitor,
	})
	if err != nil {
		return fmt.Errorf("rpc start: %w", err)
	}

	rpcManaged := moewiring.KratosGRPCManaged()
	go func() { rpcSrv.Start() }()

	if err := waitRPCListen(opts.UnifiedConfigFile, opts.RPCConfigFile, 15*time.Second); err != nil {
		rpcSrv.Stop()
		return err
	}

	if rpcMonitor != nil {
		log.Printf("moe-social: RPC debug API %s/debug/live (经 deploy-agent /debug/* 访问)", devports.RpcDebugUpstream())
	}

	apiOpts := apirun.Options{ConfigFile: opts.APIConfigFile}
	var httpSrv interface {
		Start(context.Context) error
		Stop(context.Context) error
	}
	var apiAddr string

	if moewiring.KratosPureHTTPWithoutLegacy() {
		apiOpts.WireOnly = true
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("api wire: %w", err)
		}
		port := externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile)
		pure, err := newKratosPureHTTPServer(apiRes, "0.0.0.0", port)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("kratos pure http: %w", err)
		}
		httpSrv = pure
		apiAddr = fmt.Sprintf("0.0.0.0:%d", port)
		log.Printf("moe-social: pure Kratos HTTP %s (no go-zero rest)", apiAddr)
	} else if moewiring.KratosHTTPFrontEnabled() {
		internalPort := moewiring.KratosInternalHTTPPort()
		apiOpts.InternalHTTPPort = internalPort
		apiOpts.InternalHTTPHost = "127.0.0.1"
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("api start: %w", err)
		}
		front, err := newKratosFrontServer(apiRes, "0.0.0.0", externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile))
		if err != nil {
			stopLegacyAPIServer(apiRes)
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("kratos front: %w", err)
		}
		httpSrv = front
		apiAddr = fmt.Sprintf("0.0.0.0:%d", externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile))
		log.Printf("moe-social: PK-4 enabled — Kratos HTTP %s, go-zero 127.0.0.1:%d (fallback)", apiAddr, internalPort)
	} else if moewiring.KratosHybridHTTPFallback() {
		apiSrv, err := apirun.Start(apiOpts)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("api start: %w", err)
		}
		srv, ok := apiSrv.(*rest.Server)
		if !ok {
			stopRPCMonitor(rpcMonitor)
			rpcSrv.Stop()
			return fmt.Errorf("hybrid api: expected *rest.Server")
		}
		httpSrv = wrapREST(srv)
		apiAddr = apiListenAddr(opts.APIConfigFile)
		log.Printf("moe-social: PK-8 hybrid fallback — go-zero HTTP %s", apiAddr)
	} else {
		stopRPCMonitor(rpcMonitor)
		rpcSrv.Stop()
		return fmt.Errorf("PK-8: go-zero HTTP retired; set moe.kratos_pure_enabled=true or moe.kratos_hybrid_http_fallback=true")
	}

	kratosOpts := []kratos.Option{
		kratos.Name("moe-social"),
		kratos.AfterStop(func(context.Context) error {
			stopRPCMonitor(rpcMonitor)
			if !rpcManaged {
				rpcSrv.Stop()
			}
			return nil
		}),
	}
	if rpcManaged {
		kratosOpts = append(kratosOpts, kratos.Server(httpSrv, wrapZRPC(rpcSrv)))
	} else {
		kratosOpts = append(kratosOpts, kratos.Server(httpSrv))
	}
	app := kratos.New(kratosOpts...)
	rpcAddr, _ := rpcListenAddr(opts.UnifiedConfigFile, opts.RPCConfigFile)
	logStartup(rpcAddr, apiAddr, false)
	return app.Run()
}

func stopLegacyAPIServer(res *apirun.StartResult) {
	if res == nil || res.Server == nil {
		return
	}
	if s, ok := res.Server.(*rest.Server); ok && s != nil {
		s.Stop()
	}
}

func stopRPCMonitor(mon interface{ Stop() }) {
	if mon != nil {
		mon.Stop()
	}
}
