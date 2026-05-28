package giftbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListGifts 礼物列表（含 viewer 库存）。
func ListGifts(ctx context.Context, store GiftStore, page, pageSize int32, viewerUserID string) ([]*moe.Gift, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	total, err := store.CountGifts(ctx)
	if err != nil {
		return nil, 0, err
	}
	offset := int((page - 1) * pageSize)
	gifts, err := store.ListGifts(ctx, offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}
	stockByGift := map[uint]int32{}
	if viewer := strings.TrimSpace(viewerUserID); viewer != "" {
		if uid, err := strconv.ParseUint(viewer, 10, 64); err == nil && len(gifts) > 0 {
			ids := make([]uint, 0, len(gifts))
			for _, g := range gifts {
				ids = append(ids, g.ID)
			}
			rows, _ := store.FindUserGiftStock(ctx, uint(uid), ids)
			for _, r := range rows {
				stockByGift[r.GiftID] = int32(r.Quantity)
			}
		}
	}
	out := make([]*moe.Gift, len(gifts))
	for i, gift := range gifts {
		out[i] = GiftToProto(gift, stockByGift[gift.ID])
	}
	return out, int32(total), nil
}

// GetGift 单个礼物详情。
func GetGift(ctx context.Context, store GiftStore, giftIDRaw string) (*moe.GetGiftResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	giftID, err := ParseGiftID(giftIDRaw)
	if err != nil {
		return &moe.GetGiftResp{Success: false, Message: "invalid gift id"}, nil
	}
	gift, err := store.GetGiftByID(ctx, giftID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &moe.GetGiftResp{Success: false, Message: "gift not found"}, nil
		}
		return nil, err
	}
	return &moe.GetGiftResp{
		Success: true, Message: "success", Gift: GiftToProto(gift, 0),
	}, nil
}

// ListRecords 用户礼物赠送记录。
func ListRecords(ctx context.Context, store GiftStore, userIDRaw string, page, pageSize int32) ([]*moe.GiftRecord, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 64)
	if err != nil || userID == 0 {
		return nil, 0, nil
	}
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	total, err := store.CountGiftRecords(ctx, uint(userID))
	if err != nil {
		return nil, 0, err
	}
	offset := int((page - 1) * pageSize)
	rows, err := store.ListGiftRecords(ctx, uint(userID), offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}
	out := make([]*moe.GiftRecord, len(rows))
	for i, record := range rows {
		fromUser, _ := store.GetUserByID(ctx, record.FromUserID)
		toUser, _ := store.GetUserByID(ctx, record.ToUserID)
		var giftProto *moe.Gift
		if record.Gift.ID != 0 {
			giftProto = &moe.Gift{
				Id: uint64(record.Gift.ID), Name: record.Gift.Name,
				Price: int32(record.Gift.Price), Icon: record.Gift.Icon,
				Description: record.Gift.Description,
			}
		}
		out[i] = RecordToProto(record, fromUser, toUser, giftProto)
	}
	return out, int32(total), nil
}

// ListPurchaseOrders 用户礼物购买订单。
func ListPurchaseOrders(ctx context.Context, store GiftStore, userIDRaw string, page, pageSize int32) ([]*moe.GiftPurchaseOrder, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	uid, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 64)
	if err != nil || uid == 0 {
		return nil, 0, ErrInvalidUserID
	}
	if err := store.UserExists(ctx, uint(uid)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, 0, ErrUserNotFound
		}
		return nil, 0, err
	}
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := int((page - 1) * pageSize)
	total, err := store.CountPurchaseOrders(ctx, uint(uid))
	if err != nil {
		return nil, 0, err
	}
	rows, err := store.ListPurchaseOrders(ctx, uint(uid), offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}
	out := make([]*moe.GiftPurchaseOrder, 0, len(rows))
	for _, o := range rows {
		out = append(out, &moe.GiftPurchaseOrder{
			Id: strconv.FormatUint(uint64(o.ID), 10), UserId: userIDRaw,
			OrderNo: o.OrderNo, GiftId: strconv.FormatUint(uint64(o.GiftID), 10),
			GiftName: o.GiftName, Quantity: int32(o.Quantity), UnitPrice: o.UnitPrice,
			TotalAmount: o.TotalAmount, PayMethod: o.PayMethod, Status: o.Status,
			CreatedAt: o.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out, int32(total), nil
}
