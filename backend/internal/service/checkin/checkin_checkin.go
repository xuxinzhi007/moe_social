package checkinapp

import (
	"context"
	checkinv1 "backend/api/checkin/v1"
	checkinbiz "backend/internal/biz/checkin"
)

func (s *AppService) GetCheckInStatus(ctx context.Context, in *checkinv1.GetCheckInStatusRequest) (*checkinv1.GetCheckInStatusReply, error) {
	status, err := checkinbiz.GetStatus(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInStatusReply{Status: status}, nil
}

func (s *AppService) CheckIn(ctx context.Context, in *checkinv1.CheckInRequest) (*checkinv1.CheckInReply, error) {
	result, err := checkinbiz.CheckIn(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	newAchievements := make([]*checkinv1.AchievementUnlock, 0, len(result.AchUnlocks))
	for _, u := range result.AchUnlocks {
		newAchievements = append(newAchievements, &checkinv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return &checkinv1.CheckInReply{
		ExpGained:       int32(result.ExpGained),
		NewLevel:        int32(result.NewLevel),
		ConsecutiveDays: int32(result.ConsecutiveDays),
		LevelUp:         result.LevelUp,
		SpecialReward:   result.SpecialReward,
		NewAchievements: newAchievements,
	}, nil
}

func (s *AppService) GetCheckInHistory(ctx context.Context, in *checkinv1.GetCheckInHistoryRequest) (*checkinv1.GetCheckInHistoryReply, error) {
	records, total, err := checkinbiz.ListHistory(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInHistoryReply{
		Records: records,
		Total:   total,
	}, nil
}
