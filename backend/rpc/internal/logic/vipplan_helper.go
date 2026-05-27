package logic

import (
	"strconv"

	vipbiz "backend/internal/biz/vip"
	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/pb/super"
)

func parseVipPlanID(raw string) (uint, error) {
	id, err := vipbiz.ParsePlanID(raw)
	if err != nil {
		return 0, errorx.InvalidArgument("无效的套餐 ID")
	}
	return id, nil
}

func vipPlanModelToProto(plan model.VipPlan) *super.VipPlan {
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
