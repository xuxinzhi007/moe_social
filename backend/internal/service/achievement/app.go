// Package achievementapp 成就域应用服务。
package achievementapp

import (
	"context"

	achievementbiz "backend/internal/biz/achievement"
	achievementdata "backend/internal/data/achievement"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AppService 成就应用层。
type AppService struct {
	store achievementbiz.Store
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: achievementdata.NewStore(db)}
}

func (s *AppService) GetUserAchievements(ctx context.Context, in *moe.GetUserAchievementsReq) (*moe.GetUserAchievementsResp, error) {
	badges, err := achievementbiz.ListBadges(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetUserAchievementsResp{Badges: badges}, nil
}

func (s *AppService) GetUserUnlockedAchievements(ctx context.Context, in *moe.GetUserUnlockedAchievementsReq) (*moe.GetUserUnlockedAchievementsResp, error) {
	badges, err := achievementbiz.ListUnlockedBadges(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetUserUnlockedAchievementsResp{Badges: badges}, nil
}

func (s *AppService) GetUserAchievementSummary(ctx context.Context, in *moe.GetUserAchievementSummaryReq) (*moe.GetUserAchievementSummaryResp, error) {
	summary, err := achievementbiz.GetSummary(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetUserAchievementSummaryResp{Summary: summary}, nil
}

func (s *AppService) EnsureUserAchievements(ctx context.Context, in *moe.EnsureUserAchievementsReq) (*moe.EnsureUserAchievementsResp, error) {
	unlocks, err := achievementbiz.EnsureInitialized(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.EnsureUserAchievementsResp{NewAchievements: unlocks}, nil
}
