package arenabiz_test

import (
	"context"
	"errors"
	"math/rand"
	"testing"

	arenabiz "backend/internal/biz/arena"
	"backend/model"

	"gorm.io/gorm"
)

type memRepo struct {
	byUser map[string]*model.ArenaProfile
	nextID uint
}

func newMemRepo() *memRepo {
	return &memRepo{byUser: map[string]*model.ArenaProfile{}, nextID: 1}
}

func (r *memRepo) GetByUserID(_ context.Context, userID string) (*model.ArenaProfile, error) {
	p, ok := r.byUser[userID]
	if !ok {
		return nil, gorm.ErrRecordNotFound
	}
	cp := *p
	return &cp, nil
}

func (r *memRepo) Save(_ context.Context, p *model.ArenaProfile) error {
	if p == nil {
		return errors.New("nil profile")
	}
	if p.ID == 0 {
		p.ID = r.nextID
		r.nextID++
	}
	cp := *p
	r.byUser[p.UserID] = &cp
	return nil
}

func TestEnsureProfileDefaults(t *testing.T) {
	uc := arenabiz.NewUsecase(newMemRepo())
	st, err := uc.GetState(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	if st.StarCrystals != arenabiz.DefaultStarCrystals {
		t.Fatalf("crystals=%d", st.StarCrystals)
	}
	if st.TowerFloor != 1 {
		t.Fatalf("floor=%d", st.TowerFloor)
	}
	if len(st.FormationHeroIDs) != arenabiz.FormationSize {
		t.Fatalf("formation=%v", st.FormationHeroIDs)
	}
	if len(st.OwnedHeroes) != 3 {
		t.Fatalf("owned=%v", st.OwnedHeroes)
	}
}

func TestSummonDeductsAndTenGuarantee(t *testing.T) {
	repo := newMemRepo()
	uc := arenabiz.NewUsecaseWithRand(repo, rand.New(rand.NewSource(1)))
	res, err := uc.Summon(context.Background(), "u1", 10)
	if err != nil {
		t.Fatal(err)
	}
	if res.State.StarCrystals != arenabiz.DefaultStarCrystals-arenabiz.TenSummonCost {
		t.Fatalf("crystals=%d", res.State.StarCrystals)
	}
	if len(res.Pulls) != 10 {
		t.Fatalf("pulls=%d", len(res.Pulls))
	}
	hasSR := false
	for _, p := range res.Pulls {
		if p.HeroID != "yuebai" {
			hasSR = true
			break
		}
	}
	if !hasSR {
		t.Fatal("expected ten-pull SR+ guarantee")
	}
}

func TestClearTowerWin(t *testing.T) {
	uc := arenabiz.NewUsecase(newMemRepo())
	res, err := uc.ClearTower(context.Background(), "u1", true, "lanxing", nil)
	if err != nil {
		t.Fatal(err)
	}
	if res.CrystalReward != arenabiz.TowerClearReward {
		t.Fatalf("reward=%d", res.CrystalReward)
	}
	if res.State.TowerFloor != 2 {
		t.Fatalf("floor=%d", res.State.TowerFloor)
	}
	if res.State.StarCrystals != arenabiz.DefaultStarCrystals+arenabiz.TowerClearReward {
		t.Fatalf("crystals=%d", res.State.StarCrystals)
	}
	found := false
	for _, h := range res.State.OwnedHeroes {
		if h.HeroID == "lanxing" && h.Shards == arenabiz.TowerWinShardBonus {
			found = true
		}
	}
	if !found {
		t.Fatalf("owned=%v", res.State.OwnedHeroes)
	}
}

func TestHomeGiftAndDeckPersist(t *testing.T) {
	uc := arenabiz.NewUsecase(newMemRepo())
	st, err := uc.HomeGift(context.Background(), "u1", "lanxing")
	if err != nil {
		t.Fatal(err)
	}
	if st.StarCrystals != arenabiz.DefaultStarCrystals-arenabiz.HomeGiftCost {
		t.Fatalf("crystals=%d", st.StarCrystals)
	}
	if !st.BondBuffReady {
		t.Fatal("expected bond buff")
	}
	bondOK := false
	for _, h := range st.OwnedHeroes {
		if h.HeroID == "lanxing" && h.Bond == arenabiz.HomeGiftBondGain && h.Level == 42 {
			bondOK = true
		}
	}
	if !bondOK {
		t.Fatalf("owned=%v", st.OwnedHeroes)
	}

	stTrain, err := uc.HomeTrain(context.Background(), "u1")
	if err != nil {
		t.Fatal(err)
	}
	if !stTrain.RestBuffReady {
		t.Fatal("expected rest buff")
	}

	node := 1
	stMeta, err := uc.SaveMeta(context.Background(), "u1", &node, false)
	if err != nil {
		t.Fatal(err)
	}
	if stMeta.SelectedTowerNode != 1 {
		t.Fatalf("node=%d", stMeta.SelectedTowerNode)
	}

	stClear, err := uc.SaveMeta(context.Background(), "u1", nil, true)
	if err != nil {
		t.Fatal(err)
	}
	if stClear.RestBuffReady || stClear.BondBuffReady {
		t.Fatal("expected buffs cleared")
	}

	deck := []arenabiz.DeckCard{{
		Name: "测试牌", Cost: 2, Damage: 20, Targeting: "single_enemy",
	}}
	st2, err := uc.SaveDeck(context.Background(), "u1", deck)
	if err != nil {
		t.Fatal(err)
	}
	if len(st2.Deck) != 1 || st2.Deck[0].Name != "测试牌" {
		t.Fatalf("deck=%v", st2.Deck)
	}

	res, err := uc.ClearTower(context.Background(), "u1", true, "lanxing", append(deck, arenabiz.DeckCard{
		Name: "奖励牌", Cost: 1, Damage: 10, Targeting: "single_enemy",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if res.State.TowerFloor != 2 {
		t.Fatalf("floor=%d", res.State.TowerFloor)
	}
	if len(res.State.Deck) != 2 {
		t.Fatalf("deck after clear=%v", res.State.Deck)
	}
}

func TestSetFormationRejectsUnowned(t *testing.T) {
	uc := arenabiz.NewUsecase(newMemRepo())
	_, err := uc.SetFormation(context.Background(), "u1", []string{"lanxing", "tutu", "xueli"})
	if err == nil {
		t.Fatal("expected error for unowned hero")
	}
}

func TestSetSkinPersistsOwnedHero(t *testing.T) {
	uc := arenabiz.NewUsecase(newMemRepo())
	if _, err := uc.GetState(context.Background(), "u1"); err != nil {
		t.Fatal(err)
	}
	st, err := uc.SetSkin(context.Background(), "u1", "lanxing", "starlight")
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, h := range st.OwnedHeroes {
		if h.HeroID == "lanxing" {
			found = true
			if h.SkinID != "starlight" {
				t.Fatalf("skin=%s", h.SkinID)
			}
		}
	}
	if !found {
		t.Fatal("lanxing missing")
	}
}
