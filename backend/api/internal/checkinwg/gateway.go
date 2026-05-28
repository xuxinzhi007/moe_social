package checkinwg

import (
	"backend/api/internal/gwutil"
	"context"

	checkinapp "backend/internal/service/checkin"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway CheckIn HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *checkinapp.AppService
}

// New 构造网关。
func New(local *checkinapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) GetCheckInStatus(ctx context.Context, in *moe.GetCheckInStatusReq, opts ...grpc.CallOption) (*moe.GetCheckInStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetCheckInStatus(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CheckIn(ctx context.Context, in *moe.CheckInReq, opts ...grpc.CallOption) (*moe.CheckInResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckIn(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetCheckInHistory(ctx context.Context, in *moe.GetCheckInHistoryReq, opts ...grpc.CallOption) (*moe.GetCheckInHistoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetCheckInHistory(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetExpLogs(ctx context.Context, in *moe.GetExpLogsReq, opts ...grpc.CallOption) (*moe.GetExpLogsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetExpLogs(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserLevel(ctx context.Context, in *moe.GetUserLevelReq, opts ...grpc.CallOption) (*moe.GetUserLevelResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserLevel(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
