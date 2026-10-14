package lifebiz

import (
	"testing"

	"backend/model"
)

func TestWeightsFor(t *testing.T) {
	if got := weightsFor(""); got != personalityDefaults {
		t.Errorf("empty personality should fall back to defaults, got %+v", got)
	}
	if got := weightsFor("unknown"); got != personalityDefaults {
		t.Errorf("unknown personality should fall back to defaults, got %+v", got)
	}
	if got := weightsFor(PersonalitySleepy); got.SleepEnergyBelow != 24 {
		t.Errorf("sleepy SleepEnergyBelow=%v, want 24", got.SleepEnergyBelow)
	}
}

func TestDecideActionPersonalitySleepy(t *testing.T) {
	// energy=20：默认阈值 15 不睡，sleepy 阈值 24 必睡。
	slp := &model.LifeEntity{Energy: 20, Hunger: 50, Mood: 50, Personality: PersonalitySleepy}
	if got := decideAction(slp); got != ActionSleeping {
		t.Errorf("sleepy got %v, want sleeping", got)
	}

	def := &model.LifeEntity{Energy: 20, Hunger: 50, Mood: 50}
	for i := 0; i < 100; i++ {
		if got := decideAction(def); got == ActionSleeping {
			t.Fatalf("default personality should not sleep at energy=20")
		}
	}
}

func TestDecideActionWithRelationsPersonalitySocial(t *testing.T) {
	// friend dist=250：默认上限 200 不接近，social 上限 280 接近。
	newScene := func(personality string) (*model.LifeEntity, map[uint]*model.LifeEntity, []*model.LifeRelationship) {
		e := &model.LifeEntity{ID: 1, Energy: 80, Hunger: 80, Mood: 80, PositionX: 100, PositionY: 100, Personality: personality}
		friend := &model.LifeEntity{ID: 2, Energy: 80, Hunger: 80, Mood: 80, PositionX: 350, PositionY: 100}
		entities := map[uint]*model.LifeEntity{1: e, 2: friend}
		rels := []*model.LifeRelationship{{EntityID: 1, TargetID: 2, RelationType: RelFriend}}
		return e, entities, rels
	}

	t.Run("默认不接近", func(t *testing.T) {
		e, entities, rels := newScene("")
		for i := 0; i < 100; i++ {
			if got := decideActionWithRelations(e, entities, rels); got == ActionTalking {
				t.Fatalf("default personality should not approach friend at dist=250")
			}
		}
	})

	t.Run("social接近", func(t *testing.T) {
		e, entities, rels := newScene(PersonalitySocial)
		if got := decideActionWithRelations(e, entities, rels); got != ActionTalking {
			t.Errorf("social got %v, want talking", got)
		}
	})
}

func TestDecideActionPersonalityDiligent(t *testing.T) {
	// 统计分支：diligent 走动概率 0.32 应显著高于默认 0.18。
	walks := func(personality string) int {
		e := &model.LifeEntity{Energy: 80, Hunger: 80, Mood: 80, Personality: personality}
		n := 0
		for i := 0; i < 2000; i++ {
			if decideAction(e) == ActionWalking {
				n++
			}
		}
		return n
	}
	def := walks("")
	dil := walks(PersonalityDiligent)
	if dil <= def {
		t.Errorf("diligent walks=%d, default walks=%d; want diligent > default", dil, def)
	}
}

func TestCreateSeedEntitiesFlagshipHero(t *testing.T) {
	entities := createSeedEntities("w-test")
	if len(entities) == 0 {
		t.Fatal("seed entities should not be empty")
	}
	hero := entities[0]
	if hero.Name != "小星" || hero.Emoji != "⭐" {
		t.Errorf("first seed should be flagship hero 小星⭐, got %s %s", hero.Name, hero.Emoji)
	}
	if hero.Personality != PersonalityDiligent {
		t.Errorf("hero personality=%q, want %q", hero.Personality, PersonalityDiligent)
	}
	for _, e := range entities[1:] {
		if e.Personality != "" {
			t.Errorf("NPC %s personality=%q, want empty (default behavior)", e.Name, e.Personality)
		}
	}
}
