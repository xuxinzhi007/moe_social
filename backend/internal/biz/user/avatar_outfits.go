package userbiz

import (
	"context"
)

// OutfitPart 装扮部件。
type OutfitPart struct {
	ID       string
	Type     string
	ImageURL string
}

// AvatarOutfitItem 装扮商品。
type AvatarOutfitItem struct {
	ID          string
	Name        string
	Description string
	Category    string
	Style       string
	Price       float64
	IsFree      bool
	ImageURL    string
	Parts       []OutfitPart
	CreatedAt   string
}

// ListAvatarOutfitsFilter 列表筛选。
type ListAvatarOutfitsFilter struct {
	Category string
	Style    string
	Page     int
	PageSize int
}

// ListAvatarOutfitsResult 列表结果。
type ListAvatarOutfitsResult struct {
	Items []AvatarOutfitItem
	Total int
}

func sampleAvatarOutfit(id string) AvatarOutfitItem {
	return AvatarOutfitItem{
		ID:          id,
		Name:        "休闲服装",
		Description: "舒适的休闲服装",
		Category:    "clothes",
		Style:       "casual",
		Price:       0,
		IsFree:      true,
		ImageURL:    "https://picsum.photos/200/200?random=4",
		Parts: []OutfitPart{
			{ID: "1-1", Type: "top", ImageURL: "https://picsum.photos/150/150?random=5"},
			{ID: "1-2", Type: "bottom", ImageURL: "https://picsum.photos/150/150?random=6"},
		},
		CreatedAt: "2026-01-12",
	}
}

// ListAvatarOutfits 返回装扮列表（当前为示例数据）。
func ListAvatarOutfits(_ context.Context, _ ListAvatarOutfitsFilter) (ListAvatarOutfitsResult, error) {
	item := sampleAvatarOutfit("1")
	return ListAvatarOutfitsResult{Items: []AvatarOutfitItem{item}, Total: 1}, nil
}

// GetAvatarOutfit 返回单个装扮详情。
func GetAvatarOutfit(_ context.Context, outfitID string) (AvatarOutfitItem, error) {
	return sampleAvatarOutfit(outfitID), nil
}

// PurchaseAvatarOutfit 购买装扮，返回购买记录 ID。
func PurchaseAvatarOutfit(_ context.Context, _, _ string) (string, error) {
	return "purchase_123456", nil
}
