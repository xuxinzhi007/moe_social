package behaviorgw

import (
	"backend/api/internal/gwutil"
	"context"

	behaviorapp "backend/internal/service/behavior"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Behavior HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *behaviorapp.AppService
}

// New 构造网关。
func New(local *behaviorapp.AppService) *Gateway {
	return &Gateway{local: local}
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) TrackUserBehaviorEvents(ctx context.Context, in *moe.TrackUserBehaviorEventsReq, opts ...grpc.CallOption) (*moe.TrackUserBehaviorEventsResp, error) {
	if g != nil && g.local != nil {
		return g.local.TrackEvents(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
