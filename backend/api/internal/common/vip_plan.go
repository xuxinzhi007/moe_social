package common

import (
	"strconv"

	"backend/api/internal/types"
	"backend/model"
	"backend/rpc/pb/super"
)

// VipPlanModelToTypes 将 model 转为 API types。
func VipPlanModelToTypes(p model.VipPlan) types.VipPlan {
	return types.VipPlan{
		Id:           strconv.FormatUint(uint64(p.ID), 10),
		Name:         p.Name,
		Description:  p.Features,
		Price:        p.Price,
		DurationDays: p.Duration,
		CreatedAt:    p.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:    p.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}

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
