package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	emojibiz "backend/internal/biz/emoji"
)

// ListAvatarOutfits 装扮列表。
func (s *AppService) ListAvatarOutfits(ctx context.Context, f userbiz.ListAvatarOutfitsFilter) (userbiz.ListAvatarOutfitsResult, error) {
	return userbiz.ListAvatarOutfits(ctx, f)
}

// GetAvatarOutfit 单个装扮。
func (s *AppService) GetAvatarOutfit(ctx context.Context, outfitID string) (userbiz.AvatarOutfitItem, error) {
	return userbiz.GetAvatarOutfit(ctx, outfitID)
}

// PurchaseAvatarOutfit 购买装扮。
func (s *AppService) PurchaseAvatarOutfit(ctx context.Context, userID, outfitID string) (string, error) {
	return userbiz.PurchaseAvatarOutfit(ctx, userID, outfitID)
}

// ListEmojiPacks 表情包列表。
func (s *AppService) ListEmojiPacks(ctx context.Context, f emojibiz.ListEmojiPacksFilter) (emojibiz.ListEmojiPacksResult, error) {
	return emojibiz.ListEmojiPacks(ctx, f)
}

// GetEmojiPack 单个表情包。
func (s *AppService) GetEmojiPack(ctx context.Context, packID string) (emojibiz.EmojiPackItem, error) {
	return emojibiz.GetEmojiPack(ctx, packID)
}

// FavoriteEmojiPack 收藏表情包。
func (s *AppService) FavoriteEmojiPack(ctx context.Context, userID, packID string) error {
	return emojibiz.FavoriteEmojiPack(ctx, userID, packID)
}

// PurchaseEmojiPack 购买表情包。
func (s *AppService) PurchaseEmojiPack(ctx context.Context, userID, packID string) (string, error) {
	return emojibiz.PurchaseEmojiPack(ctx, userID, packID)
}

// ListUserEmojiPacks 用户表情包。
func (s *AppService) ListUserEmojiPacks(ctx context.Context, userID string) ([]emojibiz.EmojiPackItem, error) {
	return emojibiz.ListUserEmojiPacks(ctx, userID)
}
