package logic

import (
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/pb/moe"
)

func parseGiftID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, errorx.InvalidArgument("礼物 ID 不能为空")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, errorx.InvalidArgument("无效的礼物 ID")
	}
	return uint(n), nil
}

func giftModelToProto(gift model.Gift) *moe.Gift {
	return &moe.Gift{
		Id:          uint64(gift.ID),
		Name:        gift.Name,
		Price:       int32(gift.Price),
		Icon:        gift.Icon,
		Description: gift.Description,
		CreatedAt:   gift.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:   gift.UpdatedAt.Format("2006-01-02 15:04:05"),
		Category:    gift.Category,
		SortOrder:   int32(gift.SortOrder),
	}
}
