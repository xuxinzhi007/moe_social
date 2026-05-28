// Package checkinapp 签到域应用服务。
package checkinapp

import (
	"context"

	checkinv1 "backend/api/checkin/v1"
	checkinbiz "backend/internal/biz/checkin"
	checkindata "backend/internal/data/checkin"
	"backend/pkg/achievement"

	"gorm.io/gorm"
)

// AppService 签到应用层。
type AppService struct {
	store checkinbiz.CheckInStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: checkindata.NewStore(db)}
}

func (s *AppService) GetCheckInStatus(ctx context.Context, in *checkinv1.GetCheckInStatusRequest) (*checkinv1.GetCheckInStatusReply, error) {
	status, err := checkinbiz.GetStatus(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInStatusReply{Status: checkinv1.CheckInStatusFromMoe(status)}, nil
}

func (s *AppService) CheckIn(ctx context.Context, in *checkinv1.CheckInRequest) (*checkinv1.CheckInReply, error) {
	result, err := checkinbiz.CheckIn(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &checkinv1.CheckInReply{
		ExpGained:       int32(result.ExpGained),
		NewLevel:        int32(result.NewLevel),
		ConsecutiveDays: int32(result.ConsecutiveDays),
		LevelUp:         result.LevelUp,
		SpecialReward:   result.SpecialReward,
		NewAchievements: checkinv1.AchievementUnlocksFromMoe(achievement.UnlocksToProto(result.AchUnlocks)),
	}, nil
}

func (s *AppService) GetCheckInHistory(ctx context.Context, in *checkinv1.GetCheckInHistoryRequest) (*checkinv1.GetCheckInHistoryReply, error) {
	records, total, err := checkinbiz.ListHistory(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInHistoryReply{
		Records: checkinv1.CheckInRecordsFromMoe(records),
		Total:   total,
	}, nil
}

func (s *AppService) GetExpLogs(ctx context.Context, in *checkinv1.GetExpLogsRequest) (*checkinv1.GetExpLogsReply, error) {
	logs, total, err := checkinbiz.ListExpLogs(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetExpLogsReply{
		Logs:  checkinv1.ExpLogRecordsFromMoe(logs),
		Total: total,
	}, nil
}

func (s *AppService) GetUserLevel(ctx context.Context, in *checkinv1.GetUserLevelRequest) (*checkinv1.GetUserLevelReply, error) {
	info, err := checkinbiz.GetUserLevel(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetUserLevelReply{LevelInfo: checkinv1.UserLevelInfoFromMoe(info)}, nil
}
