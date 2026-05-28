package logic

import (
	"strconv"
	"time"

	notifybiz "backend/internal/biz/notify"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

const adminSystemNotificationType = notifybiz.AdminSystemNotificationType

func adminPageParams(page, pageSize int32) (int32, int32) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}
	return page, pageSize
}

func achievementToProto(row model.AchievementDefinition) *moe.AdminAchievementItem {
	return &moe.AdminAchievementItem{
		Id:            row.ID,
		Name:          row.Name,
		Description:   row.Description,
		Category:      row.Category,
		Rarity:        row.Rarity,
		ConditionText: row.ConditionText,
		RuleType:      row.RuleType,
		RequiredCount: int32(row.RequiredCount),
		RuleParams:    row.RuleParams,
		ExpReward:     int32(row.ExpReward),
		Enabled:       row.Enabled,
		SortOrder:     int32(row.SortOrder),
		CreatedAt:     row.CreatedAt.Format("2006-01-02 15:04:05"),
	}
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

func announcementToProto(row model.AdminAnnouncement) *moe.AdminAnnouncementItem {
	item := &moe.AdminAnnouncementItem{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Title:     row.Title,
		Content:   row.Content,
		Status:    row.Status,
		CreatedBy: strconv.FormatUint(uint64(row.CreatedBy), 10),
		CreatedAt: row.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt: row.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
	if row.PublishedAt != nil {
		item.PublishedAt = row.PublishedAt.Format("2006-01-02 15:04:05")
	}
	return item
}

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

func adminMenuToProto(row model.AdminMenu) *moe.AdminMenuItem {
	return &moe.AdminMenuItem{
		Id:           strconv.FormatUint(uint64(row.ID), 10),
		Key:          row.Key,
		Kind:         row.Kind,
		ParentKey:    row.ParentKey,
		Path:         row.Path,
		Label:        row.Label,
		Icon:         row.Icon,
		Caption:      row.Caption,
		Status:       row.Status,
		AppDomain:    row.AppDomain,
		SortOrder:    int32(row.SortOrder),
		DefaultOpen:  row.DefaultOpen,
		End:          row.End,
		ExternalHref: row.ExternalHref,
		Enabled:      row.Enabled,
	}
}

func adminAuditLogToProto(row model.AdminAuditLog) *moe.AdminAuditLogItem {
	return &moe.AdminAuditLogItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		AdminId:    strconv.FormatUint(uint64(row.AdminID), 10),
		AdminName:  row.AdminName,
		Action:     row.Action,
		Resource:   row.Resource,
		ResourceId: row.ResourceID,
		Detail:     row.Detail,
		Ip:         row.IP,
		CreatedAt:  row.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}

func formatOptionalTime(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format("2006-01-02 15:04:05")
}

func systemNotificationContent(title, content string) string {
	return notifybiz.SystemNotificationContent(title, content)
}
