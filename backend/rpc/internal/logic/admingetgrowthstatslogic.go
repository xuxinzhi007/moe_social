package logic

import (
	"context"
	"time"

	"backend/model"
	"backend/rpc/internal/achievement"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetGrowthStatsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetGrowthStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetGrowthStatsLogic {
	return &AdminGetGrowthStatsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetGrowthStatsLogic) AdminGetGrowthStats(_ *super.AdminGetGrowthStatsReq) (*super.AdminGetGrowthStatsResp, error) {
	db := l.svcCtx.DB
	stats := &super.AdminGrowthStats{}

	count := func(model any, dest *int32) error {
		var n int64
		if err := db.Model(model).Count(&n).Error; err != nil {
			return err
		}
		*dest = int32(n)
		return nil
	}

	if err := count(&model.AchievementDefinition{}, &stats.AchievementDefinitions); err != nil {
		l.Errorf("[admin] growth stats achievements: %v", err)
		return nil, errorx.Internal("查询成长统计失败")
	}
	var unlocked int64
	if err := db.Model(&model.UserAchievementProgress{}).Where("unlocked_at IS NOT NULL").Count(&unlocked).Error; err != nil {
		l.Errorf("[admin] growth stats unlocked: %v", err)
		return nil, errorx.Internal("查询成长统计失败")
	}
	stats.UnlockedProgressRecords = int32(unlocked)

	if err := count(&model.LevelConfig{}, &stats.LevelConfigs); err != nil {
		return nil, errorx.Internal("查询成长统计失败")
	}
	if err := count(&model.CheckInReward{}, &stats.CheckInRewards); err != nil {
		return nil, errorx.Internal("查询成长统计失败")
	}
	if err := count(&model.UserLevel{}, &stats.UserLevels); err != nil {
		return nil, errorx.Internal("查询成长统计失败")
	}
	if err := count(&model.UserCheckIn{}, &stats.TotalCheckIns); err != nil {
		return nil, errorx.Internal("查询成长统计失败")
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	var todayCount int64
	if err := db.Model(&model.UserCheckIn{}).
		Where("check_in_date >= ? AND check_in_date < ?", dayStart, dayEnd).
		Count(&todayCount).Error; err != nil {
		l.Errorf("[admin] growth stats today checkins: %v", err)
		return nil, errorx.Internal("查询成长统计失败")
	}
	stats.CheckInsToday = int32(todayCount)

	return &super.AdminGetGrowthStatsResp{Stats: stats}, nil
}
