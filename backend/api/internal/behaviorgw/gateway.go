package behaviorgw

import (
	"context"

	behaviorapp "backend/internal/service/behavior"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Behavior HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *behaviorapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *behaviorapp.AppService, legacy moe.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) TrackUserBehaviorEvents(ctx context.Context, in *moe.TrackUserBehaviorEventsReq, opts ...grpc.CallOption) (*moe.TrackUserBehaviorEventsResp, error) {
	if g != nil && g.local != nil {
		return g.local.TrackEvents(ctx, in)
	}
	return g.super.TrackUserBehaviorEvents(ctx, in, opts...)
}
