package common

import (
	"strconv"

	giftv1 "backend/api/gift/v1"
	"backend/internal/legacy/types"
)

func RpcGiftToTypes(g *giftv1.Gift) types.Gift {
	if g == nil {
		return types.Gift{}
	}
	return types.Gift{
		Id:          strconv.FormatUint(g.GetId(), 10),
		Name:        g.GetName(),
		Price:       int(g.GetPrice()),
		Icon:        g.GetIcon(),
		Description: g.GetDescription(),
		CreatedAt:   g.GetCreatedAt(),
		UpdatedAt:   g.GetUpdatedAt(),
		Category:    g.GetCategory(),
		SortOrder:   int(g.GetSortOrder()),
	}
}
