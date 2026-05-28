package vipbiz

import (
	"strconv"

	"backend/model"
	"backend/rpc/pb/super"
)

// PlanModelToProto 将 VIP 套餐模型转为 super 消息。
func PlanModelToProto(plan model.VipPlan) *super.VipPlan {
	return &super.VipPlan{
		Id:           strconv.FormatUint(uint64(plan.ID), 10),
		Name:         plan.Name,
		Description:  plan.Features,
		Price:        float32(plan.Price),
		DurationDays: int32(plan.Duration),
		CreatedAt:    plan.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:    plan.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}
