package achievementgw

import (
	"context"

	achievementapp "backend/internal/service/achievement"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Achievement HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *achievementapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *achievementapp.AppService, legacy moe.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

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

func (g *Gateway) GetUserAchievements(ctx context.Context, in *moe.GetUserAchievementsReq, opts ...grpc.CallOption) (*moe.GetUserAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAchievements(ctx, in)
	}
	return g.super.GetUserAchievements(ctx, in, opts...)
}

func (g *Gateway) GetUserUnlockedAchievements(ctx context.Context, in *moe.GetUserUnlockedAchievementsReq, opts ...grpc.CallOption) (*moe.GetUserUnlockedAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserUnlockedAchievements(ctx, in)
	}
	return g.super.GetUserUnlockedAchievements(ctx, in, opts...)
}

func (g *Gateway) GetUserAchievementSummary(ctx context.Context, in *moe.GetUserAchievementSummaryReq, opts ...grpc.CallOption) (*moe.GetUserAchievementSummaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAchievementSummary(ctx, in)
	}
	return g.super.GetUserAchievementSummary(ctx, in, opts...)
}

func (g *Gateway) EnsureUserAchievements(ctx context.Context, in *moe.EnsureUserAchievementsReq, opts ...grpc.CallOption) (*moe.EnsureUserAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.EnsureUserAchievements(ctx, in)
	}
	return g.super.EnsureUserAchievements(ctx, in, opts...)
}
