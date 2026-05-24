package logic

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/achievement"
	"backend/rpc/internal/level"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckInLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckInLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckInLogic {
	return &CheckInLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 签到等级相关服务
func (l *CheckInLogic) CheckIn(in *super.CheckInReq) (*super.CheckInResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	var user model.User
	if err := tx.Where("id = ?", userID).First(&user).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("用户不存在")
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	var todayCheckIn model.UserCheckIn
	if err := tx.Where("user_id = ? AND check_in_date >= ? AND check_in_date < ?",
		userID, dayStart, dayEnd).First(&todayCheckIn).Error; err == nil {
		tx.Rollback()
		return nil, fmt.Errorf("今日已签到")
	}

	var lastCheckIn model.UserCheckIn
	consecutiveDays := 1
	if err := tx.Where("user_id = ?", userID).Order("check_in_date DESC").
		First(&lastCheckIn).Error; err == nil {
		yesterday := achievement.ShanghaiYesterdayString(now)
		if achievement.ShanghaiDayStringFrom(lastCheckIn.CheckInDate) == yesterday {
			consecutiveDays = lastCheckIn.ConsecutiveDays + 1
		}
	}

	baseExp := 10
	var reward model.CheckInReward
	extraExp := 0
	if err := tx.Where("consecutive_days <= ?", consecutiveDays).
		Order("consecutive_days DESC").First(&reward).Error; err == nil {
		extraExp = reward.ExpReward
	}

	totalExp := baseExp + extraExp
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
		totalExp = int(float64(totalExp) * 1.5)
	}

	checkInRecord := model.UserCheckIn{
		UserID:          uint(userID),
		CheckInDate:     achievement.StorageDateForShanghaiDay(now),
		ConsecutiveDays: consecutiveDays,
		ExpReward:       totalExp,
		IsSpecialReward: extraExp > 0,
	}
	if extraExp > 0 {
		checkInRecord.SpecialRewardDesc = fmt.Sprintf("连续签到%d天额外奖励", consecutiveDays)
	}
	if err := tx.Create(&checkInRecord).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建签到记录失败: %v", err)
	}

	expRes, err := level.AddExperience(tx, uint(userID), totalExp, "check_in",
		fmt.Sprintf("%d", checkInRecord.ID), fmt.Sprintf("每日签到获得%d经验", totalExp))
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	var achUnlocks []achievement.UnlockResult
	unlocks, achErr := achievement.ApplyEventAfterCommit(l.svcCtx.DB, uint(userID), achievement.Event{Type: achievement.EventCheckIn})
	if achErr != nil {
		l.Errorf("成就处理失败（签到仍会成功）: %v", achErr)
	} else {
		achUnlocks = unlocks
	}

	specialReward := ""
	if extraExp > 0 {
		specialReward = fmt.Sprintf("连续签到%d天获得额外%d经验", consecutiveDays, extraExp)
	}

	return &super.CheckInResp{
		ExpGained:       int32(totalExp),
		NewLevel:        int32(expRes.NewLevel),
		ConsecutiveDays: int32(consecutiveDays),
		LevelUp:         expRes.LevelUp,
		SpecialReward:   specialReward,
		NewAchievements: achievement.UnlocksToProto(achUnlocks),
	}, nil
}
