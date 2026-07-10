package lifebiz

import (
	"context"

	"backend/model"
)

// ItemSystem 道具系统，管理道具定义与内存缓存。
type ItemSystem struct {
	store Store
	items map[uint]*model.LifeItem // 内存缓存
}

// NewItemSystem 创建道具系统实例
func NewItemSystem(store Store) *ItemSystem {
	return &ItemSystem{
		store: store,
		items: make(map[uint]*model.LifeItem),
	}
}

// SeedItems 初始化种子道具到数据库和内存缓存
func (s *ItemSystem) SeedItems(ctx context.Context) error {
	seeds := []*model.LifeItem{
		{Name: "普通食物", Icon: "🍖", Description: "恢复 20 点饱食度", ItemType: "food", EffectKey: "hunger", EffectValue: 20, DurationTicks: 0},
		{Name: "高级食物", Icon: "🥩", Description: "恢复 40 点饱食度", ItemType: "food", EffectKey: "hunger", EffectValue: 40, DurationTicks: 0},
		{Name: "精力药剂", Icon: "⚡", Description: "恢复 30 点精力", ItemType: "medicine", EffectKey: "energy", EffectValue: 30, DurationTicks: 0},
		{Name: "快乐玩具", Icon: "🎾", Description: "提升 25 点心情，持续 12 tick", ItemType: "toy", EffectKey: "mood", EffectValue: 5, DurationTicks: 12},
		{Name: "经验书", Icon: "📖", Description: "获得 50 经验值", ItemType: "food", EffectKey: "experience", EffectValue: 50, DurationTicks: 0},
		{Name: "治愈草药", Icon: "🌿", Description: "恢复所有属性 15 点，持续 6 tick", ItemType: "medicine", EffectKey: "all", EffectValue: 5, DurationTicks: 6},
	}
	if err := s.store.SeedItems(ctx, seeds); err != nil {
		return err
	}
	// 加载到缓存
	items, err := s.store.ListItems(ctx)
	if err != nil {
		return err
	}
	for _, item := range items {
		s.items[item.ID] = item
	}
	return nil
}

// GetItemDefinition 查询道具定义
func (s *ItemSystem) GetItemDefinition(id uint) (*model.LifeItem, bool) {
	item, ok := s.items[id]
	return item, ok
}

// ListAllItems 列出所有道具
func (s *ItemSystem) ListAllItems() []*model.LifeItem {
	result := make([]*model.LifeItem, 0, len(s.items))
	for _, item := range s.items {
		result = append(result, item)
	}
	return result
}
