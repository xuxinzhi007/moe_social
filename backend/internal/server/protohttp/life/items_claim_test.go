package lifehttp

import (
	"testing"

	"backend/model"
)

func TestPickDailyClaimItemsByType(t *testing.T) {
	all := []*model.LifeItem{
		{ID: 2, Name: "高级食物", ItemType: "food"},
		{ID: 1, Name: "普通食物", ItemType: "food"},
		{ID: 4, Name: "快乐玩具", ItemType: "toy"},
		{ID: 3, Name: "精力药剂", ItemType: "medicine"},
		{ID: 5, Name: "经验书", ItemType: "food"},
	}
	got := pickDailyClaimItems(all)
	if len(got) != 3 {
		t.Fatalf("len=%d, want 3", len(got))
	}
	if got[0].ItemType != "food" || got[0].ID != 1 {
		t.Fatalf("food=%v, want id=1", got[0])
	}
	if got[1].ItemType != "medicine" || got[1].ID != 3 {
		t.Fatalf("medicine=%v, want id=3", got[1])
	}
	if got[2].ItemType != "toy" || got[2].ID != 4 {
		t.Fatalf("toy=%v, want id=4", got[2])
	}
}

func TestPickDailyClaimItemsFallback(t *testing.T) {
	all := []*model.LifeItem{
		{ID: 10, Name: "特殊", ItemType: "special"},
		{ID: 11, Name: "特殊2", ItemType: "special"},
	}
	got := pickDailyClaimItems(all)
	if len(got) != 2 {
		t.Fatalf("len=%d, want 2", len(got))
	}
}

func TestPickDailyClaimItemsEmpty(t *testing.T) {
	if got := pickDailyClaimItems(nil); got != nil {
		t.Fatalf("want nil, got %v", got)
	}
}
