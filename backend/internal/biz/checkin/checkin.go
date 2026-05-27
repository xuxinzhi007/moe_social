package checkinbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/achievement"
	"backend/pkg/level"

	"gorm.io/gorm"
)

// CheckInResult 签到结果。
type CheckInResult struct {
	ExpGained       int
	NewLevel        int
	ConsecutiveDays int
	LevelUp         bool
	SpecialReward   string
	AchUnlocks      []achievement.UnlockResult
}

// CheckIn 用户签到。
func CheckIn(ctx context.Context, db *gorm.DB, userIDRaw string) (CheckInResult, error) {
	if db == nil {
		return CheckInResult{}, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return CheckInResult{}, ErrInvalidUserID
	}

	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return CheckInResult{}, tx.Error
	}

	var user model.User
	if err := tx.Where("id = ?", userID).First(&user).Error; err != nil {
		tx.Rollback()
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CheckInResult{}, ErrUserNotFound
		}
		return CheckInResult{}, err
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	var todayCheckIn model.UserCheckIn
	if err := tx.Where("user_id = ? AND check_in_date >= ? AND check_in_date < ?",
		userID, dayStart, dayEnd).First(&todayCheckIn).Error; err == nil {
		tx.Rollback()
		return CheckInResult{}, ErrAlreadyCheckedIn
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
		return CheckInResult{}, err
	}

	expRes, err := level.AddExperience(tx, uint(userID), totalExp, "check_in",
		fmt.Sprintf("%d", checkInRecord.ID), fmt.Sprintf("每日签到获得%d经验", totalExp))
	if err != nil {
		tx.Rollback()
		return CheckInResult{}, err
	}
	if err := tx.Commit().Error; err != nil {
		return CheckInResult{}, err
	}

	unlocks, achErr := achievement.ApplyEventAfterCommit(db, uint(userID), achievement.Event{Type: achievement.EventCheckIn})
	if achErr != nil {
		unlocks = nil
	}

	specialReward := ""
	if extraExp > 0 {
		specialReward = fmt.Sprintf("连续签到%d天获得额外%d经验", consecutiveDays, extraExp)
	}
	return CheckInResult{
		ExpGained: totalExp, NewLevel: expRes.NewLevel, ConsecutiveDays: consecutiveDays,
		LevelUp: expRes.LevelUp, SpecialReward: specialReward, AchUnlocks: unlocks,
	}, nil
}
