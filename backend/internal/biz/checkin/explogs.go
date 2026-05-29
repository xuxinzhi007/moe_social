package checkinbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	checkinv1 "backend/api/checkin/v1"

	"gorm.io/gorm"
)

// ListExpLogs 经验日志分页。
func ListExpLogs(ctx context.Context, store CheckInStore, userIDRaw string, page, pageSize int32) ([]*checkinv1.ExpLogRecord, int32, error) {
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

	total, err := store.CountExpLogs(ctx, uint(userID))
	if err != nil {
		return nil, 0, err
	}
	rows, err := store.ListExpLogs(ctx, uint(userID), page, pageSize)
	if err != nil {
		return nil, 0, err
	}
	out := make([]*checkinv1.ExpLogRecord, 0, len(rows))
	for _, log := range rows {
		out = append(out, &checkinv1.ExpLogRecord{
			Id:          fmt.Sprintf("%d", log.ID),
			ExpChange:   int32(log.ExpChange),
			Source:      log.Source,
			Description: log.Description,
			CreatedAt:   log.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out, int32(total), nil
}
