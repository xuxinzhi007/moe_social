package moesocial

import (
	"context"
	"fmt"
)

func buildHTTPServerHybridLegacy(opts Options, rpcMonitor interface{ Stop() }) (interface {
	Start(context.Context) error
	Stop(context.Context) error
}, string, error) {
	_ = opts
	stopRPCMonitor(rpcMonitor)
	return nil, "", fmt.Errorf("legacy HTTP fallback removed; use make moe-social")
}

func stopRPCMonitor(mon interface{ Stop() }) {
	if mon != nil {
		mon.Stop()
	}
}
