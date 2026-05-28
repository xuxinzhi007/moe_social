package checkinbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/achievement"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// GetStatus 返回用户签到状态。
func GetStatus(ctx context.Context, db *gorm.DB, userIDRaw string) (*moe.CheckInStatus, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, ErrInvalidUserID
	}

	var user model.User
	if err := db.WithContext(ctx).Where("id = ?", userID).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	var todayCheckIn model.UserCheckIn
	hasCheckedToday := db.WithContext(ctx).Where("user_id = ? AND check_in_date >= ? AND check_in_date < ?",
		userID, dayStart, dayEnd).First(&todayCheckIn).Error == nil

	var lastCheckIn model.UserCheckIn
	consecutiveDays := 0
	if err := db.WithContext(ctx).Where("user_id = ?", userID).Order("check_in_date DESC").
		First(&lastCheckIn).Error; err == nil {
		if hasCheckedToday {
			consecutiveDays = lastCheckIn.ConsecutiveDays
		} else {
			yesterday := achievement.ShanghaiYesterdayString(now)
			if achievement.ShanghaiDayStringFrom(lastCheckIn.CheckInDate) == yesterday {
				consecutiveDays = lastCheckIn.ConsecutiveDays
			}
		}
	}

	todayReward := 0
	nextDayReward := 0
	if !hasCheckedToday {
		todayReward = calcCheckInReward(db.WithContext(ctx), user, consecutiveDays+1)
	}
	nextFuture := consecutiveDays + 1
	if hasCheckedToday {
		nextFuture = consecutiveDays + 1
	} else {
		nextFuture = consecutiveDays + 2
	}
	nextDayReward = calcCheckInReward(db.WithContext(ctx), user, nextFuture)

	return &moe.CheckInStatus{
		HasCheckedToday: hasCheckedToday,
		ConsecutiveDays: int32(consecutiveDays),
		TodayReward:     int32(todayReward),
		NextDayReward:   int32(nextDayReward),
		CanCheckIn:      !hasCheckedToday,
	}, nil
}

func calcCheckInReward(db *gorm.DB, user model.User, consecutiveDays int) int {
	baseExp := 10
	var reward model.CheckInReward
	extraExp := 0
	if err := db.Where("consecutive_days <= ?", consecutiveDays).
		Order("consecutive_days DESC").First(&reward).Error; err == nil {
		extraExp = reward.ExpReward
	}
	total := baseExp + extraExp
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
		total = int(float64(total) * 1.5)
	}
	return total
}
