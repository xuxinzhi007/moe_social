package petapp

import (
	"context"

	petbiz "backend/internal/biz/pet"
	"backend/model"
)

// AppService 养成应用服务。
type AppService struct {
	uc *petbiz.Usecase
}

// New 创建服务。
func New(uc *petbiz.Usecase) *AppService {
	return &AppService{uc: uc}
}

func (a *AppService) Get(ctx context.Context, userID string) (*model.PetProfile, error) {
	return a.uc.EnsureProfile(ctx, userID)
}

func (a *AppService) Feed(ctx context.Context, userID, itemID string) (*model.PetProfile, error) {
	return a.uc.Feed(ctx, userID, itemID)
}

func (a *AppService) Pet(ctx context.Context, userID string) (*model.PetProfile, error) {
	return a.uc.Pet(ctx, userID)
}

func (a *AppService) Dress(ctx context.Context, userID, hat, top, bottom, shoes, outfitJSON string) (*model.PetProfile, error) {
	return a.uc.Dress(ctx, userID, hat, top, bottom, shoes, outfitJSON)
}

func (a *AppService) SetScene(ctx context.Context, userID, scene string) (*model.PetProfile, error) {
	return a.uc.SetScene(ctx, userID, scene)
}

func (a *AppService) PlaceFurniture(ctx context.Context, userID string, slots []petbiz.FurnitureSlot) (*model.PetProfile, error) {
	return a.uc.PlaceFurniture(ctx, userID, slots)
}

func (a *AppService) SaveRoomBoundaries(ctx context.Context, userID string, boundaries []petbiz.RoomBoundary) (*model.PetProfile, error) {
	return a.uc.SaveRoomBoundaries(ctx, userID, boundaries)
}

func (a *AppService) Study(ctx context.Context, userID, subject string) (*model.PetProfile, string, error) {
	return a.uc.Study(ctx, userID, subject)
}

func (a *AppService) Work(ctx context.Context, userID string) (*model.PetProfile, string, error) {
	return a.uc.Work(ctx, userID)
}

func (a *AppService) AgeUp(ctx context.Context, userID string) (*model.PetProfile, error) {
	return a.uc.AgeUp(ctx, userID)
}

func (a *AppService) AddFriend(ctx context.Context, userID, friendID string) error {
	return a.uc.AddFriend(ctx, userID, friendID)
}

func (a *AppService) Marry(ctx context.Context, userID, spouseID string) (*model.PetProfile, error) {
	return a.uc.Marry(ctx, userID, spouseID)
}

func (a *AppService) HaveBaby(ctx context.Context, userID string) (*model.PetProfile, error) {
	return a.uc.HaveBaby(ctx, userID)
}

func (a *AppService) Adventure(ctx context.Context, userID string) (*model.PetProfile, string, bool, error) {
	return a.uc.Adventure(ctx, userID)
}

func (a *AppService) BuySoft(ctx context.Context, userID, itemID string) (*model.PetProfile, error) {
	return a.uc.BuySoft(ctx, userID, itemID)
}
