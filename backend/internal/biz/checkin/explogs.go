package checkinbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ListExpLogs 经验日志分页。
func ListExpLogs(ctx context.Context, db *gorm.DB, userIDRaw string, page, pageSize int32) ([]*super.ExpLogRecord, int32, error) {
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
	if err := db.WithContext(ctx).Model(&model.ExpLog{}).
		Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.ExpLog
	offset := int((page - 1) * pageSize)
	if err := db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").Limit(int(pageSize)).Offset(offset).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	out := make([]*super.ExpLogRecord, 0, len(rows))
	for _, log := range rows {
		out = append(out, &super.ExpLogRecord{
			Id:          fmt.Sprintf("%d", log.ID),
			ExpChange:   int32(log.ExpChange),
			Source:      log.Source,
			Description: log.Description,
			CreatedAt:   log.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out, int32(total), nil
}
