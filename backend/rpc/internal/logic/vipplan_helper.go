package logic

import (
	vipbiz "backend/internal/biz/vip"
	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/pb/moe"
)

func parseVipPlanID(raw string) (uint, error) {
	id, err := vipbiz.ParsePlanID(raw)
	if err != nil {
		return 0, errorx.InvalidArgument("无效的套餐 ID")
	}
	return id, nil
}

func vipPlanModelToProto(plan model.VipPlan) *moe.VipPlan {
	return vipbiz.PlanModelToProto(plan)
}
