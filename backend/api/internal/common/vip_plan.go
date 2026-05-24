package common

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func RpcVipPlanToTypes(p *super.VipPlan) types.VipPlan {
	if p == nil {
		return types.VipPlan{}
	}
	return types.VipPlan{
		Id:           p.GetId(),
		Name:         p.GetName(),
		Description:  p.GetDescription(),
		Price:        float64(p.GetPrice()),
		DurationDays: int(p.GetDurationDays()),
		CreatedAt:    p.GetCreatedAt(),
		UpdatedAt:    p.GetUpdatedAt(),
	}
}
