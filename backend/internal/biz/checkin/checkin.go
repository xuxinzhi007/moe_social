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
func CheckIn(ctx context.Context, store CheckInStore, userIDRaw string) (CheckInResult, error) {
	if store == nil {
		return CheckInResult{}, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return CheckInResult{}, ErrInvalidUserID
	}

	tx, err := store.Begin(ctx)
	if err != nil {
		return CheckInResult{}, err
	}

	user, err := tx.GetUser(uint(userID))
	if err != nil {
		_ = tx.Rollback()
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CheckInResult{}, ErrUserNotFound
		}
		return CheckInResult{}, err
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	if _, ok, err := tx.FindTodayCheckIn(uint(userID), dayStart, dayEnd); err != nil {
		_ = tx.Rollback()
		return CheckInResult{}, err
	} else if ok {
		_ = tx.Rollback()
		return CheckInResult{}, ErrAlreadyCheckedIn
	}

	consecutiveDays := 1
	if last, ok, err := tx.FindLastCheckIn(uint(userID)); err != nil {
		_ = tx.Rollback()
		return CheckInResult{}, err
	} else if ok {
		yesterday := achievement.ShanghaiYesterdayString(now)
		if achievement.ShanghaiDayStringFrom(last.CheckInDate) == yesterday {
			consecutiveDays = last.ConsecutiveDays + 1
		}
	}

	baseExp := 10
	extraExp := 0
	if reward, ok, err := tx.FindCheckInReward(consecutiveDays); err != nil {
		_ = tx.Rollback()
		return CheckInResult{}, err
	} else if ok {
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
	if err := tx.CreateCheckIn(&checkInRecord); err != nil {
		_ = tx.Rollback()
		return CheckInResult{}, err
	}

	expRes, err := level.AddExperience(tx.DB(), uint(userID), totalExp, "check_in",
		fmt.Sprintf("%d", checkInRecord.ID), fmt.Sprintf("每日签到获得%d经验", totalExp))
	if err != nil {
		_ = tx.Rollback()
		return CheckInResult{}, err
	}
	if err := tx.Commit(); err != nil {
		return CheckInResult{}, err
	}

	unlocks, achErr := achievement.ApplyEventAfterCommit(store.Raw(), uint(userID), achievement.Event{Type: achievement.EventCheckIn})
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
