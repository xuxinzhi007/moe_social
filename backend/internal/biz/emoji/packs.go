package emojibiz

import (
	"context"
)

// EmojiItem 单个表情。
type EmojiItem struct {
	ID         string
	ImageURL   string
	Tags       []string
	IsAnimated bool
}

// EmojiPackItem 表情包。
type EmojiPackItem struct {
	ID            string
	Name          string
	Description   string
	AuthorName    string
	Category      string
	Price         float64
	IsFree        bool
	CoverImage    string
	Emojis        []EmojiItem
	DownloadCount int
}

// ListEmojiPacksFilter 列表筛选。
type ListEmojiPacksFilter struct {
	Category string
	Page     int
	PageSize int
}

// ListEmojiPacksResult 列表结果。
type ListEmojiPacksResult struct {
	Items []EmojiPackItem
	Total int
}

func sampleEmojiPack(id string) EmojiPackItem {
	return EmojiPackItem{
		ID:          id,
		Name:        "可爱猫咪",
		Description: "可爱的猫咪表情包",
		AuthorName:  "系统管理员",
		Category:    "animals",
		Price:       0,
		IsFree:      true,
		CoverImage:  "https://picsum.photos/300/200?random=1",
		Emojis: []EmojiItem{
			{ID: "1-1", ImageURL: "https://picsum.photos/100/100?random=2", Tags: []string{"cat", "cute"}},
			{ID: "1-2", ImageURL: "https://picsum.photos/100/100?random=3", Tags: []string{"cat", "happy"}},
		},
		DownloadCount: 1000,
	}
}

// ListEmojiPacks 返回表情包列表。
func ListEmojiPacks(_ context.Context, _ ListEmojiPacksFilter) (ListEmojiPacksResult, error) {
	item := sampleEmojiPack("1")
	return ListEmojiPacksResult{Items: []EmojiPackItem{item}, Total: 1}, nil
}

// GetEmojiPack 返回单个表情包。
func GetEmojiPack(_ context.Context, packID string) (EmojiPackItem, error) {
	return sampleEmojiPack(packID), nil
}

// FavoriteEmojiPack 收藏表情包。
func FavoriteEmojiPack(_ context.Context, _, _ string) error {
	return nil
}

// PurchaseEmojiPack 购买表情包。
func PurchaseEmojiPack(_ context.Context, _, _ string) (string, error) {
	return "emoji_purchase_123456", nil
}

// ListUserEmojiPacks 用户已拥有的表情包。
func ListUserEmojiPacks(_ context.Context, _ string) ([]EmojiPackItem, error) {
	return []EmojiPackItem{sampleEmojiPack("1")}, nil
}
