package common

import (
	"strconv"

	adminv1 "backend/api/admin/v1"
	"backend/internal/legacy/types"
	"backend/model"
	"backend/rpc/pb/moe"
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

func RpcVipPlanToTypes(p *moe.VipPlan) types.VipPlan {
	if p == nil {
		return types.VipPlan{}
	}
	return vipPlanFields(
		p.GetId(),
		p.GetName(),
		p.GetDescription(),
		float64(p.GetPrice()),
		int(p.GetDurationDays()),
		p.GetCreatedAt(),
		p.GetUpdatedAt(),
	)
}

// AdminVipPlanToTypes 将 admin 域 VIP 套餐消息转为 API types。
func AdminVipPlanToTypes(p *adminv1.VipPlan) types.VipPlan {
	if p == nil {
		return types.VipPlan{}
	}
	return vipPlanFields(
		p.GetId(),
		p.GetName(),
		p.GetDescription(),
		float64(p.GetPrice()),
		int(p.GetDurationDays()),
		p.GetCreatedAt(),
		p.GetUpdatedAt(),
	)
}

func vipPlanFields(id, name, description string, price float64, durationDays int, createdAt, updatedAt string) types.VipPlan {
	return types.VipPlan{
		Id:           id,
		Name:         name,
		Description:  description,
		Price:        price,
		DurationDays: durationDays,
		CreatedAt:    createdAt,
		UpdatedAt:    updatedAt,
	}
}
