// Package checkinapp 签到域应用服务。
package checkinapp

import (
	"context"

	checkinbiz "backend/internal/biz/checkin"
	"backend/pkg/achievement"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AppService 签到应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) GetCheckInStatus(ctx context.Context, in *moe.GetCheckInStatusReq) (*moe.GetCheckInStatusResp, error) {
	status, err := checkinbiz.GetStatus(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetCheckInStatusResp{Status: status}, nil
}

func (s *AppService) CheckIn(ctx context.Context, in *moe.CheckInReq) (*moe.CheckInResp, error) {
	result, err := checkinbiz.CheckIn(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.CheckInResp{
		ExpGained: int32(result.ExpGained), NewLevel: int32(result.NewLevel),
		ConsecutiveDays: int32(result.ConsecutiveDays), LevelUp: result.LevelUp,
		SpecialReward: result.SpecialReward, NewAchievements: achievement.UnlocksToProto(result.AchUnlocks),
	}, nil
}

func (s *AppService) GetCheckInHistory(ctx context.Context, in *moe.GetCheckInHistoryReq) (*moe.GetCheckInHistoryResp, error) {
	records, total, err := checkinbiz.ListHistory(ctx, s.db, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &moe.GetCheckInHistoryResp{Records: records, Total: total}, nil
}

func (s *AppService) GetExpLogs(ctx context.Context, in *moe.GetExpLogsReq) (*moe.GetExpLogsResp, error) {
	logs, total, err := checkinbiz.ListExpLogs(ctx, s.db, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &moe.GetExpLogsResp{Logs: logs, Total: total}, nil
}

func (s *AppService) GetUserLevel(ctx context.Context, in *moe.GetUserLevelReq) (*moe.GetUserLevelResp, error) {
	info, err := checkinbiz.GetUserLevel(ctx, s.db, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetUserLevelResp{LevelInfo: info}, nil
}
