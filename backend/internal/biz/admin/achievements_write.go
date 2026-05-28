package adminbiz

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

var (
	ErrInvalidAchievementID = errors.New("invalid achievement_id")
	ErrAchievementNotFound  = errors.New("achievement not found")
)

// UpdateAchievementInput Admin 成就部分更新。
type UpdateAchievementInput struct {
	ID                string
	Name              string
	Description       string
	Enabled           bool
	ExpReward         int32
	SortOrder         int32
	UpdateName        bool
	UpdateDescription bool
	UpdateEnabled     bool
	UpdateExpReward   bool
	UpdateSortOrder   bool
}

// UpdateAchievement 更新成就定义。
func UpdateAchievement(ctx context.Context, db *gorm.DB, in UpdateAchievementInput) (*moe.AdminAchievementItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id := strings.TrimSpace(in.ID)
	if id == "" {
		return nil, ErrInvalidAchievementID
	}

	var row model.AchievementDefinition
	if err := db.WithContext(ctx).First(&row, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAchievementNotFound
		}
		return nil, err
	}

	updates := map[string]interface{}{}
	if in.UpdateName {
		updates["name"] = strings.TrimSpace(in.Name)
	}
	if in.UpdateDescription {
		updates["description"] = strings.TrimSpace(in.Description)
	}
	if in.UpdateEnabled {
		updates["enabled"] = in.Enabled
	}
	if in.UpdateExpReward {
		updates["exp_reward"] = int(in.ExpReward)
	}
	if in.UpdateSortOrder {
		updates["sort_order"] = int(in.SortOrder)
	}
	if len(updates) == 0 {
		item := achievementItemToProto(row)
		return item, nil
	}
	if err := db.WithContext(ctx).Model(&row).Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := db.WithContext(ctx).First(&row, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return achievementItemToProto(row), nil
}

// BootstrapAchievements 空表时导入默认成就定义。
func BootstrapAchievements(ctx context.Context, db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	_ = ctx
	created, err := utils.BootstrapAchievementDefinitions(db)
	if err != nil {
		return 0, err
	}
	return created, nil
}
