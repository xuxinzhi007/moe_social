package checkinwg

import (
	"backend/api/internal/gwutil"
	"context"

	checkinv1 "backend/api/checkin/v1"
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
		out, err := g.local.GetCheckInStatus(ctx, checkinv1.GetCheckInStatusRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return checkinv1.GetCheckInStatusReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CheckIn(ctx context.Context, in *moe.CheckInReq, opts ...grpc.CallOption) (*moe.CheckInResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CheckIn(ctx, checkinv1.CheckInRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return checkinv1.CheckInReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetCheckInHistory(ctx context.Context, in *moe.GetCheckInHistoryReq, opts ...grpc.CallOption) (*moe.GetCheckInHistoryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetCheckInHistory(ctx, checkinv1.GetCheckInHistoryRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return checkinv1.GetCheckInHistoryReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetExpLogs(ctx context.Context, in *moe.GetExpLogsReq, opts ...grpc.CallOption) (*moe.GetExpLogsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetExpLogs(ctx, checkinv1.GetExpLogsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return checkinv1.GetExpLogsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserLevel(ctx context.Context, in *moe.GetUserLevelReq, opts ...grpc.CallOption) (*moe.GetUserLevelResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserLevel(ctx, checkinv1.GetUserLevelRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return checkinv1.GetUserLevelReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
