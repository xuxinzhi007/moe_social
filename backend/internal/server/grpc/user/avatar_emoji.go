package usergrpc

import (
	"context"

	userv1 "backend/api/user/v1"
	emojibiz "backend/internal/biz/emoji"
	userbiz "backend/internal/biz/user"
)

func (s *Server) GetUserAvatar(ctx context.Context, in *userv1.GetUserAvatarReq) (*userv1.GetUserAvatarResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserAvatar(ctx, in)
}

func (s *Server) UpdateUserAvatar(ctx context.Context, in *userv1.UpdateUserAvatarReq) (*userv1.UpdateUserAvatarResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserAvatar(ctx, in)
}

func (s *Server) GetAvatarOutfits(ctx context.Context, in *userv1.GetAvatarOutfitsReq) (*userv1.GetAvatarOutfitsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	result, err := app.ListAvatarOutfits(ctx, userbiz.ListAvatarOutfitsFilter{
		Category: in.GetCategory(),
		Style:    in.GetStyle(),
		Page:     int(in.GetPage()),
		PageSize: int(in.GetPageSize()),
	})
	if err != nil {
		return nil, err
	}
	items := make([]*userv1.AvatarOutfit, 0, len(result.Items))
	for _, item := range result.Items {
		items = append(items, avatarOutfitToProto(item))
	}
	return &userv1.GetAvatarOutfitsResp{Data: items, Total: int32(result.Total)}, nil
}

func (s *Server) GetAvatarOutfit(ctx context.Context, in *userv1.GetAvatarOutfitReq) (*userv1.GetAvatarOutfitResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	item, err := app.GetAvatarOutfit(ctx, in.GetOutfitId())
	if err != nil {
		return nil, err
	}
	return &userv1.GetAvatarOutfitResp{Data: avatarOutfitToProto(item)}, nil
}

func (s *Server) PurchaseAvatarOutfit(ctx context.Context, in *userv1.PurchaseAvatarOutfitReq) (*userv1.PurchaseAvatarOutfitResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	purchaseID, err := app.PurchaseAvatarOutfit(ctx, in.GetUserId(), in.GetOutfitId())
	if err != nil {
		return nil, err
	}
	return &userv1.PurchaseAvatarOutfitResp{Data: purchaseID}, nil
}

func (s *Server) GetEmojiPacks(ctx context.Context, in *userv1.GetEmojiPacksReq) (*userv1.GetEmojiPacksResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	result, err := app.ListEmojiPacks(ctx, emojibiz.ListEmojiPacksFilter{
		Category: in.GetCategory(),
		Page:     int(in.GetPage()),
		PageSize: int(in.GetPageSize()),
	})
	if err != nil {
		return nil, err
	}
	items := make([]*userv1.EmojiPack, 0, len(result.Items))
	for _, item := range result.Items {
		items = append(items, emojiPackToProto(item))
	}
	return &userv1.GetEmojiPacksResp{Data: items, Total: int32(result.Total)}, nil
}

func (s *Server) GetEmojiPack(ctx context.Context, in *userv1.GetEmojiPackReq) (*userv1.GetEmojiPackResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	item, err := app.GetEmojiPack(ctx, in.GetPackId())
	if err != nil {
		return nil, err
	}
	return &userv1.GetEmojiPackResp{Data: emojiPackToProto(item)}, nil
}

func (s *Server) FavoriteEmojiPack(ctx context.Context, in *userv1.FavoriteEmojiPackReq) (*userv1.FavoriteEmojiPackResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if err := app.FavoriteEmojiPack(ctx, in.GetUserId(), in.GetPackId()); err != nil {
		return nil, err
	}
	return &userv1.FavoriteEmojiPackResp{}, nil
}

func (s *Server) PurchaseEmojiPack(ctx context.Context, in *userv1.PurchaseEmojiPackReq) (*userv1.PurchaseEmojiPackResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	purchaseID, err := app.PurchaseEmojiPack(ctx, in.GetUserId(), in.GetPackId())
	if err != nil {
		return nil, err
	}
	return &userv1.PurchaseEmojiPackResp{Data: purchaseID}, nil
}

func (s *Server) GetUserEmojiPacks(ctx context.Context, in *userv1.GetUserEmojiPacksReq) (*userv1.GetUserEmojiPacksResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	items, err := app.ListUserEmojiPacks(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	respItems := make([]*userv1.EmojiPack, 0, len(items))
	for _, item := range items {
		respItems = append(respItems, emojiPackToProto(item))
	}
	return &userv1.GetUserEmojiPacksResp{Data: respItems}, nil
}

func avatarOutfitToProto(item userbiz.AvatarOutfitItem) *userv1.AvatarOutfit {
	parts := make([]*userv1.OutfitPart, 0, len(item.Parts))
	for _, p := range item.Parts {
		parts = append(parts, &userv1.OutfitPart{Id: p.ID, Type: p.Type, ImageUrl: p.ImageURL})
	}
	return &userv1.AvatarOutfit{
		Id: item.ID, Name: item.Name, Description: item.Description,
		Category: item.Category, Style: item.Style, Price: item.Price,
		IsFree: item.IsFree, ImageUrl: item.ImageURL, Parts: parts, CreatedAt: item.CreatedAt,
	}
}

func emojiPackToProto(item emojibiz.EmojiPackItem) *userv1.EmojiPack {
	emojis := make([]*userv1.Emoji, 0, len(item.Emojis))
	for _, e := range item.Emojis {
		emojis = append(emojis, &userv1.Emoji{
			Id: e.ID, ImageUrl: e.ImageURL, Tags: e.Tags, IsAnimated: e.IsAnimated,
		})
	}
	return &userv1.EmojiPack{
		Id: item.ID, Name: item.Name, Description: item.Description,
		AuthorName: item.AuthorName, Category: item.Category, Price: item.Price,
		IsFree: item.IsFree, CoverImage: item.CoverImage, Emojis: emojis,
		DownloadCount: int32(item.DownloadCount),
	}
}
