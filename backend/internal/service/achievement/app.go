// Package achievementapp 成就域应用服务。
package achievementapp

import (
	"context"

	achievementbiz "backend/internal/biz/achievement"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService 成就应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) GetUserAchievements(ctx context.Context, in *super.GetUserAchievementsReq) (*super.GetUserAchievementsResp, error) {
	badges, err := achievementbiz.ListBadges(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &super.GetUserAchievementsResp{Badges: badges}, nil
}

func (s *AppService) GetUserUnlockedAchievements(ctx context.Context, in *super.GetUserUnlockedAchievementsReq) (*super.GetUserUnlockedAchievementsResp, error) {
	badges, err := achievementbiz.ListUnlockedBadges(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &super.GetUserUnlockedAchievementsResp{Badges: badges}, nil
}

func (s *AppService) GetUserAchievementSummary(ctx context.Context, in *super.GetUserAchievementSummaryReq) (*super.GetUserAchievementSummaryResp, error) {
	summary, err := achievementbiz.GetSummary(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &super.GetUserAchievementSummaryResp{Summary: summary}, nil
}

func (s *AppService) EnsureUserAchievements(ctx context.Context, in *super.EnsureUserAchievementsReq) (*super.EnsureUserAchievementsResp, error) {
	unlocks, err := achievementbiz.EnsureInitialized(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &super.EnsureUserAchievementsResp{NewAchievements: unlocks}, nil
}
