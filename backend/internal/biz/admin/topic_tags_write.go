package adminbiz

import (
	"context"

	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

// BootstrapTopicTags 空表时写入官方推荐话题标签。
func BootstrapTopicTags(ctx context.Context, st AdminStore) (int32, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.TopicTag{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if count > 0 {
		return 0, nil
	}
	created := utils.SeedDefaultTopicTags(db.WithContext(ctx))
	if err := db.WithContext(ctx).Model(&model.TopicTag{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if created == 0 {
		return int32(count), nil
	}
	return created, nil
}
