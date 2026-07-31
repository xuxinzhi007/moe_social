package moewiring

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// companionBoundEntitySource 从 companion_profiles 读取已绑定的 life_entity_id。
type companionBoundEntitySource struct {
	db *gorm.DB
}

func (s *companionBoundEntitySource) BoundEntityIDs(ctx context.Context) (map[uint]struct{}, error) {
	if s == nil || s.db == nil {
		return nil, nil
	}
	var ids []int
	err := s.db.WithContext(ctx).
		Model(&model.CompanionProfile{}).
		Where("life_entity_id > 0").
		Distinct().
		Pluck("life_entity_id", &ids).Error
	if err != nil {
		return nil, err
	}
	out := make(map[uint]struct{}, len(ids))
	for _, id := range ids {
		if id > 0 {
			out[uint(id)] = struct{}{}
		}
	}
	return out, nil
}
