package checkinbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	checkinv1 "backend/api/checkin/v1"

	"gorm.io/gorm"
)

// ListHistory 签到历史分页。
func ListHistory(ctx context.Context, store CheckInStore, userIDRaw string, page, pageSize int32) ([]*checkinv1.CheckInRecord, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, 0, ErrInvalidUserID
	}
	if err := store.UserExists(ctx, uint(userID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, 0, ErrUserNotFound
		}
		return nil, 0, err
	}

	rows, total, err := store.ListCheckIns(ctx, uint(userID), page, pageSize)
	if err != nil {
		return nil, 0, err
	}
	out := make([]*checkinv1.CheckInRecord, 0, len(rows))
	for _, record := range rows {
		out = append(out, &checkinv1.CheckInRecord{
			CheckInDate:       record.CheckInDate.Format("2006-01-02"),
			ConsecutiveDays:   int32(record.ConsecutiveDays),
			ExpReward:         int32(record.ExpReward),
			IsSpecialReward:   record.IsSpecialReward,
			SpecialRewardDesc: record.SpecialRewardDesc,
		})
	}
	return out, int32(total), nil
}
