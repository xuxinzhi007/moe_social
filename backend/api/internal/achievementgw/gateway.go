package achievementgw

import (
	"backend/api/internal/gwutil"
	"context"

	achievementv1 "backend/api/achievement/v1"
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
		out, err := g.local.GetUserAchievements(ctx, achievementv1.GetUserAchievementsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return achievementv1.GetUserAchievementsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserUnlockedAchievements(ctx context.Context, in *moe.GetUserUnlockedAchievementsReq, opts ...grpc.CallOption) (*moe.GetUserUnlockedAchievementsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserUnlockedAchievements(ctx, achievementv1.GetUserUnlockedAchievementsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return achievementv1.GetUserUnlockedAchievementsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserAchievementSummary(ctx context.Context, in *moe.GetUserAchievementSummaryReq, opts ...grpc.CallOption) (*moe.GetUserAchievementSummaryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserAchievementSummary(ctx, achievementv1.GetUserAchievementSummaryRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return achievementv1.GetUserAchievementSummaryReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) EnsureUserAchievements(ctx context.Context, in *moe.EnsureUserAchievementsReq, opts ...grpc.CallOption) (*moe.EnsureUserAchievementsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.EnsureUserAchievements(ctx, achievementv1.EnsureUserAchievementsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return achievementv1.EnsureUserAchievementsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
