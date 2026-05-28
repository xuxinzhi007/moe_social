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
func GetStatus(ctx context.Context, store CheckInStore, userIDRaw string) (*moe.CheckInStatus, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, ErrInvalidUserID
	}

	user, err := store.GetUser(ctx, uint(userID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	now := time.Now()
	dayStart, dayEnd := achievement.ShanghaiDayBounds(now)
	_, hasCheckedToday, err := store.FindTodayCheckIn(ctx, uint(userID), dayStart, dayEnd)
	if err != nil {
		return nil, err
	}

	consecutiveDays := 0
	if last, ok, err := store.FindLastCheckIn(ctx, uint(userID)); err != nil {
		return nil, err
	} else if ok {
		if hasCheckedToday {
			consecutiveDays = last.ConsecutiveDays
		} else {
			yesterday := achievement.ShanghaiYesterdayString(now)
			if achievement.ShanghaiDayStringFrom(last.CheckInDate) == yesterday {
				consecutiveDays = last.ConsecutiveDays
			}
		}
	}

	todayReward := 0
	nextDayReward := 0
	if !hasCheckedToday {
		todayReward = calcCheckInReward(ctx, store, user, consecutiveDays+1)
	}
	nextFuture := consecutiveDays + 1
	if hasCheckedToday {
		nextFuture = consecutiveDays + 1
	} else {
		nextFuture = consecutiveDays + 2
	}
	nextDayReward = calcCheckInReward(ctx, store, user, nextFuture)

	return &moe.CheckInStatus{
		HasCheckedToday: hasCheckedToday,
		ConsecutiveDays: int32(consecutiveDays),
		TodayReward:     int32(todayReward),
		NextDayReward:   int32(nextDayReward),
		CanCheckIn:      !hasCheckedToday,
	}, nil
}

func calcCheckInReward(ctx context.Context, store CheckInStore, user model.User, consecutiveDays int) int {
	baseExp := 10
	extraExp := 0
	if reward, ok, err := store.FindCheckInReward(ctx, consecutiveDays); err == nil && ok {
		extraExp = reward.ExpReward
	}
	total := baseExp + extraExp
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
		total = int(float64(total) * 1.5)
	}
	return total
}
