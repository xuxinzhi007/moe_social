package arenabiz_test

import (
	"context"
	"math/rand"
	"testing"

	arenabiz "backend/internal/biz/arena"
	lifebiz "backend/internal/biz/life"
	"backend/model"
)

// 旗舰英雄小星全服默认拥有：老存档缺失时幂等补发，已拥有时不重复。
func TestFlagshipHeroGrantedUniversally(t *testing.T) {
	repo := newMemRepo()
	repo.byUser["u1"] = &model.ArenaProfile{
		ID:              1,
		UserID:          "u1",
		StarCrystals:    100,
		TowerFloor:      1,
		OwnedHeroesJSON: `[{"hero_id":"lanxing","bond":7}]`,
		FormationJSON:   `["lanxing"]`,
		DeckJSON:        "[]",
		ProgressJSON:    "{}",
	}
	repo.nextID = 2
	uc := arenabiz.NewUsecase(repo)

	st, err := uc.GetState(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	grants := 0
	for _, h := range st.OwnedHeroes {
		if h.HeroID == lifebiz.HeroSlugXiaoxing {
			grants++
		}
	}
	if grants != 1 {
		t.Fatalf("owned=%v, want exactly one flagship hero grant", st.OwnedHeroes)
	}

	// 第二次读取不重复补发。
	st, err = uc.GetState(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	grants = 0
	for _, h := range st.OwnedHeroes {
		if h.HeroID == lifebiz.HeroSlugXiaoxing {
			grants++
		}
	}
	if grants != 1 {
		t.Fatalf("owned=%v, want idempotent flagship grant", st.OwnedHeroes)
	}
}

// 旗舰英雄不进召唤池：大量抽卡永不出现 xiaoxing。
func TestFlagshipHeroExcludedFromSummonPool(t *testing.T) {
	repo := newMemRepo()
	uc := arenabiz.NewUsecaseWithRand(repo, rand.New(rand.NewSource(7)))
	for round := 0; round < 20; round++ {
		if profile := repo.byUser["u1"]; profile != nil {
			profile.StarCrystals = 100000
		}
		res, err := uc.Summon(context.Background(), "u1", 10)
		if err != nil {
			t.Fatal(err)
		}
		for _, pull := range res.Pulls {
			if pull.HeroID == lifebiz.HeroSlugXiaoxing {
				t.Fatalf("summon pool yielded grant-only hero: %+v", pull)
			}
		}
	}
}
