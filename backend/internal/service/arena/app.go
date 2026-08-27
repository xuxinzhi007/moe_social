package arenaapp

import (
	"context"

	arenabiz "backend/internal/biz/arena"
)

// AppService 星辉远征应用服务。
type AppService struct {
	uc *arenabiz.Usecase
}

// New 创建服务。
func New(uc *arenabiz.Usecase) *AppService {
	return &AppService{uc: uc}
}

func (a *AppService) GetState(ctx context.Context, userID string) (*arenabiz.State, error) {
	return a.uc.GetState(ctx, userID)
}

func (a *AppService) SetFormation(ctx context.Context, userID string, heroIDs []string) (*arenabiz.State, error) {
	return a.uc.SetFormation(ctx, userID, heroIDs)
}

func (a *AppService) Summon(ctx context.Context, userID string, count int) (*arenabiz.SummonResult, error) {
	return a.uc.Summon(ctx, userID, count)
}

func (a *AppService) HomeGift(ctx context.Context, userID, heroID string) (*arenabiz.State, error) {
	return a.uc.HomeGift(ctx, userID, heroID)
}

func (a *AppService) HomeTrain(ctx context.Context, userID string) (*arenabiz.State, error) {
	return a.uc.HomeTrain(ctx, userID)
}

func (a *AppService) SaveMeta(ctx context.Context, userID string, selectedTowerNode *int, clearBuffs bool) (*arenabiz.State, error) {
	return a.uc.SaveMeta(ctx, userID, selectedTowerNode, clearBuffs)
}

func (a *AppService) SetSkin(ctx context.Context, userID, heroID, skinID string) (*arenabiz.State, error) {
	return a.uc.SetSkin(ctx, userID, heroID, skinID)
}

func (a *AppService) SaveDeck(ctx context.Context, userID string, deck []arenabiz.DeckCard) (*arenabiz.State, error) {
	return a.uc.SaveDeck(ctx, userID, deck)
}

func (a *AppService) ClearTower(ctx context.Context, userID string, won bool, bonusHeroID string, deck []arenabiz.DeckCard) (*arenabiz.ClearTowerResult, error) {
	return a.uc.ClearTower(ctx, userID, won, bonusHeroID, deck)
}
