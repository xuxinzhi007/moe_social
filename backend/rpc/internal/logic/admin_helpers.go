package logic

import (
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

const adminSystemNotificationType = 4

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

func achievementToProto(row model.AchievementDefinition) *super.AdminAchievementItem {
	return &super.AdminAchievementItem{
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

func levelConfigToProto(row model.LevelConfig) *super.AdminLevelConfigItem {
	return &super.AdminLevelConfigItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		Level:      int32(row.Level),
		Title:      row.Title,
		MinExp:     int32(row.MinExp),
		MaxExp:     int32(row.MaxExp),
		Privileges: row.Privileges,
		BadgeUrl:   row.BadgeUrl,
	}
}

func checkInRewardToProto(row model.CheckInReward) *super.AdminCheckInRewardItem {
	return &super.AdminCheckInRewardItem{
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

func announcementToProto(row model.AdminAnnouncement) *super.AdminAnnouncementItem {
	item := &super.AdminAnnouncementItem{
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

func adminAccountToProto(row model.AdminAccount) *super.AdminAccountItem {
	item := &super.AdminAccountItem{
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

func adminMenuToProto(row model.AdminMenu) *super.AdminMenuItem {
	return &super.AdminMenuItem{
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

func adminAuditLogToProto(row model.AdminAuditLog) *super.AdminAuditLogItem {
	return &super.AdminAuditLogItem{
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
	title = strings.TrimSpace(title)
	content = strings.TrimSpace(content)
	if title != "" && content != "" {
		return title + ": " + content
	}
	if title != "" {
		return title
	}
	return content
}
