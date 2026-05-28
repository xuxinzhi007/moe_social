package achievementgw

import (
	"backend/api/internal/gwutil"
	"context"

	achievementapp "backend/internal/service/achievement"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Achievement HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *achievementapp.AppService
}

// New 构造网关。
func New(local *achievementapp.AppService) *Gateway {
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

func (g *Gateway) GetUserAchievements(ctx context.Context, in *moe.GetUserAchievementsReq, opts ...grpc.CallOption) (*moe.GetUserAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAchievements(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserUnlockedAchievements(ctx context.Context, in *moe.GetUserUnlockedAchievementsReq, opts ...grpc.CallOption) (*moe.GetUserUnlockedAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserUnlockedAchievements(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserAchievementSummary(ctx context.Context, in *moe.GetUserAchievementSummaryReq, opts ...grpc.CallOption) (*moe.GetUserAchievementSummaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAchievementSummary(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) EnsureUserAchievements(ctx context.Context, in *moe.EnsureUserAchievementsReq, opts ...grpc.CallOption) (*moe.EnsureUserAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.EnsureUserAchievements(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
