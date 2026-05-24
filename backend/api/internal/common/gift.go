package common

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func RpcGiftToTypes(g *super.Gift) types.Gift {
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
