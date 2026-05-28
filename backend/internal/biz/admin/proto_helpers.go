package adminbiz

import (
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

func adminAccountToProto(row model.AdminAccount) *moe.AdminAccountItem {
	item := &moe.AdminAccountItem{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Username:  row.Username,
		Role:      row.Role,
		CreatedAt: row.CreatedAt.Format("2006-01-02 15:04:05"),
	}
	if row.LastLoginAt != nil {
		item.LastLoginAt = row.LastLoginAt.Format("2006-01-02 15:04:05")
	}
	return item
}

func levelConfigToProto(row model.LevelConfig) *moe.AdminLevelConfigItem {
	return &moe.AdminLevelConfigItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		Level:      int32(row.Level),
		Title:      row.Title,
		MinExp:     int32(row.MinExp),
		MaxExp:     int32(row.MaxExp),
		Privileges: row.Privileges,
		BadgeUrl:   row.BadgeUrl,
	}
}

func checkInRewardToProto(row model.CheckInReward) *moe.AdminCheckInRewardItem {
	return &moe.AdminCheckInRewardItem{
		Id:              strconv.FormatUint(uint64(row.ID), 10),
		ConsecutiveDays: int32(row.ConsecutiveDays),
		ExpReward:       int32(row.ExpReward),
		ExtraReward:     row.ExtraReward,
	}
}

func countWhere(db *gorm.DB, model interface{}, column string, uid uint) int32 {
	if db == nil {
		return 0
	}
	var n int64
	_ = db.Model(model).Where(column+" = ?", uid).Count(&n).Error
	return int32(n)
}

func memoryToAdminProto(row model.UserMemory, username string) *moe.AdminMemoryItem {
	return &moe.AdminMemoryItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		UserId:     strconv.FormatUint(uint64(row.UserID), 10),
		Username:   username,
		Key:        row.Key,
		Value:      row.Value,
		MemoryType: row.MemoryType,
		Confidence: row.Confidence,
		Source:     row.Source,
		UpdatedAt:  row.UpdatedAt.Format(time.DateTime),
	}
}

func previewContent(s string) string {
	s = strings.TrimSpace(s)
	if len(s) <= 120 {
		return s
	}
	return s[:120] + "…"
}

func adminUserDisplayName(db *gorm.DB, userID uint) string {
	if db == nil || userID == 0 {
		return ""
	}
	var user model.User
	if err := db.First(&user, userID).Error; err != nil {
		return ""
	}
	if user.Username != "" {
		return user.Username
	}
	return user.Email
}
