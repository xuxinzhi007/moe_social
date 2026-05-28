package adminbiz

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AchievementPage Admin 成就列表筛选。
type AchievementPage struct {
	Page     int32
	PageSize int32
	Keyword  string
	Category string
}

// ListAchievements Admin 成就定义列表。
func ListAchievements(ctx context.Context, db *gorm.DB, in AchievementPage) ([]*moe.AdminAchievementItem, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := adminListPageParams(in.Page, in.PageSize)

	q := db.WithContext(ctx).Model(&model.AchievementDefinition{})
	if kw := strings.TrimSpace(in.Keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ? OR id LIKE ?", like, like, like)
	}
	if cat := strings.TrimSpace(in.Category); cat != "" {
		q = q.Where("category = ?", cat)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []model.AchievementDefinition
	offset := int((page - 1) * pageSize)
	if err := q.Order("sort_order ASC, id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, 0, err
	}

	items := make([]*moe.AdminAchievementItem, len(rows))
	for i, row := range rows {
		items[i] = achievementItemToProto(row)
	}
	return items, int32(total), nil
}

func adminListPageParams(page, pageSize int32) (int32, int32) {
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

func achievementItemToProto(row model.AchievementDefinition) *moe.AdminAchievementItem {
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

func menuItemToProto(row model.AdminMenu) *moe.AdminMenuItem {
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
