//go:build !hybrid

package moesocial

import (
	"context"
	"fmt"

	"backend/internal/platform/moewiring"
)

func buildHTTPServerHybridLegacy(opts Options, rpcMonitor interface{ Stop() }) (interface {
	Start(context.Context) error
	Stop(context.Context) error
}, string, error) {
	_ = opts
	stopRPCMonitor(rpcMonitor)
	if moewiring.KratosHTTPFrontEnabled() {
		return nil, "", fmt.Errorf("PK-4 kratos HTTP front requires -tags hybrid")
	}
	return nil, "", fmt.Errorf("PK-8 go-zero HTTP fallback requires -tags hybrid")
}

func stopRPCMonitor(mon interface{ Stop() }) {
	if mon != nil {
		mon.Stop()
	}
}
