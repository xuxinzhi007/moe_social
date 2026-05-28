// Package achievementapp 成就域应用服务。
package achievementapp

import (
	"context"

	achievementv1 "backend/api/achievement/v1"
	achievementbiz "backend/internal/biz/achievement"
	achievementdata "backend/internal/data/achievement"

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

func (s *AppService) GetUserAchievements(ctx context.Context, in *achievementv1.GetUserAchievementsRequest) (*achievementv1.GetUserAchievementsReply, error) {
	badges, err := achievementbiz.ListBadges(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &achievementv1.GetUserAchievementsReply{Badges: achievementv1.BadgesFromMoe(badges)}, nil
}

func (s *AppService) GetUserUnlockedAchievements(ctx context.Context, in *achievementv1.GetUserUnlockedAchievementsRequest) (*achievementv1.GetUserUnlockedAchievementsReply, error) {
	badges, err := achievementbiz.ListUnlockedBadges(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &achievementv1.GetUserUnlockedAchievementsReply{Badges: achievementv1.BadgesFromMoe(badges)}, nil
}

func (s *AppService) GetUserAchievementSummary(ctx context.Context, in *achievementv1.GetUserAchievementSummaryRequest) (*achievementv1.GetUserAchievementSummaryReply, error) {
	summary, err := achievementbiz.GetSummary(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	if summary == nil {
		return &achievementv1.GetUserAchievementSummaryReply{}, nil
	}
	return &achievementv1.GetUserAchievementSummaryReply{
		Summary: &achievementv1.AchievementSummary{
			TotalBadges:            summary.GetTotalBadges(),
			UnlockedBadges:         summary.GetUnlockedBadges(),
			CompletionPercentage:   summary.GetCompletionPercentage(),
		},
	}, nil
}

func (s *AppService) EnsureUserAchievements(ctx context.Context, in *achievementv1.EnsureUserAchievementsRequest) (*achievementv1.EnsureUserAchievementsReply, error) {
	unlocks, err := achievementbiz.EnsureInitialized(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &achievementv1.EnsureUserAchievementsReply{NewAchievements: achievementv1.UnlocksFromMoe(unlocks)}, nil
}
