package bootstrap

import (
	"backend/internal/adapter/rpcsuper"
	"backend/internal/platform/moewiring"
	"backend/pkg/moe/port"
	"backend/rpc/internal/svc"
)

type toolBridge struct {
	port.MoeToolPort
}

func newAppBridge(svcCtx *svc.ServiceContext) rpcsuper.Bridge {
	if svcCtx == nil {
		return nil
	}
	p := moewiring.NewAppAdapter(svcCtx.PostApp, svcCtx.LLMApp)
	if p == nil {
		return nil
	}
	return toolBridge{p}
}
