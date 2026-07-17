package lifebiz

import (
	"math"
	"testing"

	"backend/model"
)

func TestFindNearbyFriend(t *testing.T) {
	t.Run("找到最近朋友", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, PositionX: 100, PositionY: 100}
		friend := &model.LifeEntity{ID: 2, PositionX: 150, PositionY: 100}
		entities := map[uint]*model.LifeEntity{1: e, 2: friend}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelFriend},
		}
		id, dist := FindNearbyFriend(e, entities, rels)
		if id != 2 {
			t.Errorf("friend id=%d, want 2", id)
		}
		if math.Abs(dist-50) > 0.1 {
			t.Errorf("dist=%.1f, want ~50", dist)
		}
	})

	t.Run("无朋友返回0", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1}
		id, _ := FindNearbyFriend(e, map[uint]*model.LifeEntity{1: e}, nil)
		if id != 0 {
			t.Errorf("no friends should return 0, got %d", id)
		}
	})

	t.Run("mate也算朋友", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, PositionX: 0, PositionY: 0}
		mate := &model.LifeEntity{ID: 3, PositionX: 10, PositionY: 0}
		entities := map[uint]*model.LifeEntity{1: e, 3: mate}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 3, RelationType: RelMate},
		}
		id, _ := FindNearbyFriend(e, entities, rels)
		if id != 3 {
			t.Errorf("mate should count as friend, got id=%d", id)
		}
	})
}

func TestFindNearbyRival(t *testing.T) {
	t.Run("找到对手", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, PositionX: 100, PositionY: 100}
		rival := &model.LifeEntity{ID: 2, PositionX: 120, PositionY: 100}
		entities := map[uint]*model.LifeEntity{1: e, 2: rival}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelRival},
		}
		id, dist := FindNearbyRival(e, entities, rels)
		if id != 2 {
			t.Errorf("rival id=%d, want 2", id)
		}
		if math.Abs(dist-20) > 0.1 {
			t.Errorf("dist=%.1f, want ~20", dist)
		}
	})

	t.Run("无对手返回0", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelFriend},
		}
		id, _ := FindNearbyRival(e, map[uint]*model.LifeEntity{1: e}, rels)
		if id != 0 {
			t.Errorf("no rivals should return 0, got %d", id)
		}
	})
}

func TestHasMateRelationship(t *testing.T) {
	tests := []struct {
		name string
		rels []*model.LifeRelationship
		want bool
	}{
		{"有mate", []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelMate},
		}, true},
		{"无mate", []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelFriend},
		}, false},
		{"空关系", nil, false},
		{"mate反向", []*model.LifeRelationship{
			{EntityID: 3, TargetID: 1, RelationType: RelMate},
		}, true},
	}

	e := &model.LifeEntity{ID: 1}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := HasMateRelationship(e, tc.rels)
			if got != tc.want {
				t.Errorf("HasMateRelationship()=%v, want %v", got, tc.want)
			}
		})
	}
}

func TestUpdateRelationships(t *testing.T) {
	t.Run("死亡实体关系清理", func(t *testing.T) {
		// entity 1 存活，entity 2 不在 map 中（已死亡）
		entities := map[uint]*model.LifeEntity{
			1: {ID: 1, PositionX: 100, PositionY: 100, GrowthStage: StageAdult},
		}
		existingRels := []*model.LifeRelationship{
			{ID: 10, WorldID: "w", EntityID: 1, TargetID: 2, RelationType: RelFriend, Affinity: 20},
		}
		ss := NewSocialSystem()
		_, _, deletedIDs, _ := ss.UpdateRelationships("w", entities, existingRels)
		found := false
		for _, id := range deletedIDs {
			if id == 10 {
				found = true
			}
		}
		if !found {
			t.Error("relationship with dead entity should be deleted")
		}
	})

	t.Run("远距离关系衰减", func(t *testing.T) {
		// 两个实体距离很远（>100），不满足近距离条件
		e1 := &model.LifeEntity{ID: 1, PositionX: 0, PositionY: 0, GrowthStage: StageAdult}
		e2 := &model.LifeEntity{ID: 2, PositionX: 500, PositionY: 500, GrowthStage: StageAdult}
		entities := map[uint]*model.LifeEntity{1: e1, 2: e2}
		existingRels := []*model.LifeRelationship{
			{ID: 10, WorldID: "w", EntityID: 1, TargetID: 2, RelationType: RelFriend, Affinity: 5},
		}
		ss := NewSocialSystem()
		_, updatedRels, deletedIDs, _ := ss.UpdateRelationships("w", entities, existingRels)

		// 远距离 friend affinity 减少 0.3 → 5-0.3=4.7
		if len(updatedRels) == 0 && len(deletedIDs) == 0 {
			t.Error("distant friendship should decay (updated or deleted)")
		}
		if len(updatedRels) > 0 {
			for _, r := range updatedRels {
				if r.Affinity >= 5 {
					t.Errorf("affinity should decrease, got %.2f", r.Affinity)
				}
			}
		}
	})
}
