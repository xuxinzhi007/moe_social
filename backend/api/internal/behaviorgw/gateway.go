package behaviorgw

import (
	"backend/api/internal/gwutil"
	"context"

	behaviorv1 "backend/api/behavior/v1"
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
		out, err := g.local.TrackEvents(ctx, moeTrackToBehaviorV1(in))
		if err != nil {
			return nil, err
		}
		return &moe.TrackUserBehaviorEventsResp{Accepted: out.GetAccepted()}, nil
	}
	return nil, gwutil.ErrUnavailable
}

func moeTrackToBehaviorV1(in *moe.TrackUserBehaviorEventsReq) *behaviorv1.TrackUserBehaviorEventsRequest {
	if in == nil {
		return &behaviorv1.TrackUserBehaviorEventsRequest{}
	}
	events := make([]*behaviorv1.UserBehaviorEventItem, 0, len(in.GetEvents()))
	for _, ev := range in.GetEvents() {
		if ev == nil {
			continue
		}
		events = append(events, &behaviorv1.UserBehaviorEventItem{
			Event:      ev.GetEvent(),
			Screen:     ev.GetScreen(),
			ParamsJson: ev.GetParamsJson(),
			DurationMs: ev.GetDurationMs(),
			SessionId:  ev.GetSessionId(),
			ClientTs:   ev.GetClientTsMs(),
		})
	}
	return &behaviorv1.TrackUserBehaviorEventsRequest{
		UserId: in.GetUserId(),
		Events: events,
	}
}
