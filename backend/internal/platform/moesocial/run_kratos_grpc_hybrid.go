//go:build hybrid

package moesocial

import (
	"context"
	"fmt"
	"log"

	apirun "backend/api/runserver"
	"backend/internal/platform/moewiring"

	"github.com/zeromicro/go-zero/rest"
)

func buildHTTPServerHybridLegacy(opts Options, rpcMonitor interface{ Stop() }) (interface {
	Start(context.Context) error
	Stop(context.Context) error
}, string, error) {
	apiOpts := apirun.Options{ConfigFile: opts.APIConfigFile}
	if moewiring.KratosHTTPFrontEnabled() {
		internalPort := moewiring.KratosInternalHTTPPort()
		apiOpts.InternalHTTPPort = internalPort
		apiOpts.InternalHTTPHost = "127.0.0.1"
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			return nil, "", fmt.Errorf("api start: %w", err)
		}
		front, err := newKratosFrontServer(apiRes, "0.0.0.0", externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile))
		if err != nil {
			stopLegacyAPIServer(apiRes)
			stopRPCMonitor(rpcMonitor)
			return nil, "", fmt.Errorf("kratos front: %w", err)
		}
		addr := fmt.Sprintf("0.0.0.0:%d", externalHTTPPort(opts.UnifiedConfigFile, opts.APIConfigFile))
		log.Printf("moe-social: PK-4 enabled — Kratos HTTP %s, go-zero 127.0.0.1:%d (fallback)", addr, internalPort)
		return front, addr, nil
	}
	if moewiring.KratosHybridHTTPFallback() {
		apiSrv, err := apirun.Start(apiOpts)
		if err != nil {
			stopRPCMonitor(rpcMonitor)
			return nil, "", fmt.Errorf("api start: %w", err)
		}
		srv, ok := apiSrv.(*rest.Server)
		if !ok {
			stopRPCMonitor(rpcMonitor)
			return nil, "", fmt.Errorf("hybrid api: expected *rest.Server")
		}
		addr := apiListenAddr(opts.APIConfigFile)
		log.Printf("moe-social: PK-8 hybrid fallback — go-zero HTTP %s", addr)
		return wrapREST(srv), addr, nil
	}
	stopRPCMonitor(rpcMonitor)
	return nil, "", fmt.Errorf("legacy HTTP: no mode enabled")
}
