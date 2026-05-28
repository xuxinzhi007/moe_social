package giftbiz

import (
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"
)

// ParseGiftID 解析礼物 ID。
func ParseGiftID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, ErrEmptyGiftID
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, ErrInvalidGiftID
	}
	return uint(n), nil
}

// GiftToProto 礼物模型转 proto。
func GiftToProto(gift model.Gift, ownedQty int32) *moe.Gift {
	return &moe.Gift{
		Id:            uint64(gift.ID),
		Name:          gift.Name,
		Price:         int32(gift.Price),
		Icon:          gift.Icon,
		Description:   gift.Description,
		CreatedAt:     gift.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:     gift.UpdatedAt.Format("2006-01-02 15:04:05"),
		OwnedQuantity: ownedQty,
		Category:      gift.Category,
		SortOrder:     int32(gift.SortOrder),
	}
}

// RecordToProto 赠送记录转 proto。
func RecordToProto(record model.GiftRecord, fromUser, toUser model.User, gift *moe.Gift) *moe.GiftRecord {
	return &moe.GiftRecord{
		Id:           uint64(record.ID),
		FromUserId:   uint64(record.FromUserID),
		FromUserName: fromUser.Username,
		ToUserId:     uint64(record.ToUserID),
		ToUserName:   toUser.Username,
		GiftId:       uint64(record.GiftID),
		Gift:         gift,
		Quantity:     int32(record.Quantity),
		CreatedAt:    record.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}
