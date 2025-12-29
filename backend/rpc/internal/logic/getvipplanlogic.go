package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlanLogic {
	return &GetVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipPlanLogic) GetVipPlan(in *super.GetVipPlanReq) (*super.GetVipPlanResp, error) {
	// 1. 查找VIP套餐
	var plan model.VipPlan
	result := l.svcCtx.DB.First(&plan, in.PlanId)
	if result.Error != nil {
		l.Error("查找VIP套餐失败: ", result.Error)
		return nil, errorx.NotFound("VIP套餐不存在")
	}

	// 2. 构建响应
	return &super.GetVipPlanResp{
		Plan: &super.VipPlan{
			Id:           strconv.Itoa(int(plan.ID)),
			Name:         plan.Name,
			Description:  plan.Features,
			Price:        float32(plan.Price),
			DurationDays: int32(plan.Duration),
			CreatedAt:    plan.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    plan.UpdatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
