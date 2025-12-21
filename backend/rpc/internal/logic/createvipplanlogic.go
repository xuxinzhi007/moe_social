package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipPlanLogic {
	return &CreateVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateVipPlanLogic) CreateVipPlan(in *rpc.CreateVipPlanReq) (*rpc.CreateVipPlanResp, error) {
	// 1. 创建VIP套餐
	plan := model.VipPlan{
		Name:     in.Name,
		Features: in.Description,
		Price:    float64(in.Price),
		Duration: int(in.DurationDays),
	}

	// 2. 保存到数据库
	err := l.svcCtx.DB.Create(&plan).Error
	if err != nil {
		l.Error("创建VIP套餐失败: ", err)
		return nil, errorx.Internal("创建VIP套餐失败，请稍后重试")
	}

	// 3. 构建响应
	return &rpc.CreateVipPlanResp{
		Plan: &rpc.VipPlan{
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
