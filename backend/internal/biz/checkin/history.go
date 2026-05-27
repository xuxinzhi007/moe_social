package checkinbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ListHistory 签到历史分页。
func ListHistory(ctx context.Context, db *gorm.DB, userIDRaw string, page, pageSize int32) ([]*super.CheckInRecord, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, 0, ErrInvalidUserID
	}
	if err := db.WithContext(ctx).Where("id = ?", userID).First(&model.User{}).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, 0, ErrUserNotFound
		}
		return nil, 0, err
	}
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	var total int64
	if err := db.WithContext(ctx).Model(&model.UserCheckIn{}).
		Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.UserCheckIn
	offset := int((page - 1) * pageSize)
	if err := db.WithContext(ctx).Where("user_id = ?", userID).
		Order("check_in_date DESC").Limit(int(pageSize)).Offset(offset).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	out := make([]*super.CheckInRecord, 0, len(rows))
	for _, record := range rows {
		out = append(out, &super.CheckInRecord{
			CheckInDate:       record.CheckInDate.Format("2006-01-02"),
			ConsecutiveDays:   int32(record.ConsecutiveDays),
			ExpReward:         int32(record.ExpReward),
			IsSpecialReward:   record.IsSpecialReward,
			SpecialRewardDesc: record.SpecialRewardDesc,
		})
	}
	return out, int32(total), nil
}
