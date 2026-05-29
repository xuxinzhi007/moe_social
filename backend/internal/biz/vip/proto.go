package vipbiz

import (
	"strconv"

	adminv1 "backend/api/admin/v1"
	"backend/model"
)

// PlanModelToAdminProto 将 VIP 套餐模型转为 admin 域消息。
func PlanModelToAdminProto(plan model.VipPlan) *adminv1.VipPlan {
	return &adminv1.VipPlan{
		Id:           strconv.FormatUint(uint64(plan.ID), 10),
		Name:         plan.Name,
		Description:  plan.Features,
		Price:        float32(plan.Price),
		DurationDays: int32(plan.Duration),
		CreatedAt:    plan.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:    plan.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}
