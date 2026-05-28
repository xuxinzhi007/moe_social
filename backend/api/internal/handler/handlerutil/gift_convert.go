package handlerutil

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

// GiftFromRPC proto Gift → API types。
func GiftFromRPC(g *moe.Gift) types.Gift {
	if g == nil {
		return types.Gift{}
	}
	return types.Gift{
		Id:            strconv.FormatUint(g.Id, 10),
		Name:          g.Name,
		Price:         int(g.Price),
		Icon:          g.Icon,
		Description:   g.Description,
		CreatedAt:     g.CreatedAt,
		UpdatedAt:     g.UpdatedAt,
		OwnedQuantity: int(g.OwnedQuantity),
		Category:      g.Category,
		SortOrder:     int(g.SortOrder),
	}
}

// GiftsFromRPC proto Gift 列表 → API types。
func GiftsFromRPC(gifts []*moe.Gift) []types.Gift {
	out := make([]types.Gift, len(gifts))
	for i, g := range gifts {
		out[i] = GiftFromRPC(g)
	}
	return out
}

// GiftRecordFromRPC proto GiftRecord → API types。
func GiftRecordFromRPC(r *moe.GiftRecord) types.GiftRecord {
	if r == nil {
		return types.GiftRecord{}
	}
	return types.GiftRecord{
		Id:         strconv.FormatUint(r.Id, 10),
		FromUserID: strconv.FormatUint(r.FromUserId, 10),
		ToUserID:   strconv.FormatUint(r.ToUserId, 10),
		GiftID:     strconv.FormatUint(r.GiftId, 10),
		Gift:       GiftFromRPC(r.Gift),
		Quantity:   int(r.Quantity),
		CreatedAt:  r.CreatedAt,
	}
}

// GiftRecordsFromRPC proto GiftRecord 列表 → API types。
func GiftRecordsFromRPC(records []*moe.GiftRecord) []types.GiftRecord {
	out := make([]types.GiftRecord, len(records))
	for i, r := range records {
		out[i] = GiftRecordFromRPC(r)
	}
	return out
}
