package checkinbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/pkg/achievement"
	"backend/pkg/level"

	"gorm.io/gorm"
)

// DailyExpAction 每日一次的经验来源。
type DailyExpAction string

const (
	DailyExpActionPost   DailyExpAction = "daily_post"
	DailyExpActionBrowse DailyExpAction = "daily_browse"

	dailyPostExpAmount   = 5
	dailyBrowseExpAmount = 3
)

// DailyExpResult 每日经验发放结果。
type DailyExpResult struct {
	Granted        bool
	AlreadyGranted bool
	ExpGained      int
	LevelUp        bool
	NewLevel       int
}

// GrantDailyExpOnce 按自然日发放一次经验；重复调用同一天返回 AlreadyGranted。
func GrantDailyExpOnce(ctx context.Context, store CheckInStore, userIDRaw string, action DailyExpAction) (DailyExpResult, error) {
	if store == nil {
		return DailyExpResult{}, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return DailyExpResult{}, ErrInvalidUserID
	}
	if err := store.UserExists(ctx, uint(userID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return DailyExpResult{}, ErrUserNotFound
		}
		return DailyExpResult{}, err
	}

	source, amount, desc := dailyExpMeta(action)
	if amount <= 0 {
		return DailyExpResult{}, fmt.Errorf("unsupported daily exp action: %s", action)
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	has, err := store.HasExpLogToday(ctx, uint(userID), source, dayStart, dayEnd)
	if err != nil {
		return DailyExpResult{}, err
	}
	if has {
		return DailyExpResult{AlreadyGranted: true}, nil
	}

	tx, err := store.Begin(ctx)
	if err != nil {
		return DailyExpResult{}, err
	}
	has, err = tx.HasExpLogToday(uint(userID), source, dayStart, dayEnd)
	if err != nil {
		_ = tx.Rollback()
		return DailyExpResult{}, err
	}
	if has {
		_ = tx.Rollback()
		return DailyExpResult{AlreadyGranted: true}, nil
	}

	user, err := tx.GetUser(uint(userID))
	if err != nil {
		_ = tx.Rollback()
		return DailyExpResult{}, err
	}

	delta := amount
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(now) {
		delta = int(float64(delta) * 1.5)
	}

	expRes, err := level.AddExperience(tx.DB(), uint(userID), delta, source,
		achievement.ShanghaiDayString(now), desc)
	if err != nil {
		_ = tx.Rollback()
		return DailyExpResult{}, err
	}
	if err := tx.Commit(); err != nil {
		return DailyExpResult{}, err
	}

	return DailyExpResult{
		Granted:   true,
		ExpGained: delta,
		LevelUp:   expRes.LevelUp,
		NewLevel:  expRes.NewLevel,
	}, nil
}

func dailyExpMeta(action DailyExpAction) (source string, amount int, desc string) {
	switch action {
	case DailyExpActionPost:
		return string(DailyExpActionPost), dailyPostExpAmount, fmt.Sprintf("每日发帖奖励%d经验", dailyPostExpAmount)
	case DailyExpActionBrowse:
		return string(DailyExpActionBrowse), dailyBrowseExpAmount, fmt.Sprintf("每日浏览动态奖励%d经验", dailyBrowseExpAmount)
	default:
		return "", 0, ""
	}
}
