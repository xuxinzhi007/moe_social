package moeadmingw

import (
	"context"

	moebiz "backend/internal/biz/moe"
	"backend/rpc/pb/super"
)

func (g *Gateway) MoeExecuteTool(ctx context.Context, in *super.MoeExecuteToolReq) (*super.MoeExecuteToolResp, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		res, err := g.local.ExecuteTool(ctx, moebiz.ExecuteToolInput{
			Tool:           in.GetTool(),
			ArgumentsJSON:  in.GetArgumentsJson(),
			ActorUserID:    uint(in.GetActorUserId()),
			AgentKey:       in.GetAgentKey(),
			Source:         in.GetSource(),
			IdempotencyKey: in.GetIdempotencyKey(),
		})
		if err != nil {
			return nil, err
		}
		return &super.MoeExecuteToolResp{Ok: res.OK, Result: res.Result, Error: res.Error}, nil
	}
	if g.super != nil {
		return g.super.MoeExecuteTool(ctx, in)
	}
	return nil, errNoBackend
}
