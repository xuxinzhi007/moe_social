package logic

import (
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/pb/super"
)

func parseVipPlanID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, errorx.InvalidArgument("套餐 ID 不能为空")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, errorx.InvalidArgument("无效的套餐 ID")
	}
	return uint(n), nil
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
