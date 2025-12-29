package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlansLogic {
	return &GetVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// VIP套餐相关服务
func (l *GetVipPlansLogic) GetVipPlans(in *super.GetVipPlansReq) (*super.GetVipPlansResp, error) {
	var plans []model.VipPlan
	result := l.svcCtx.DB.Find(&plans)
	if result.Error != nil {
		l.Errorf("获取VIP套餐失败: %v", result.Error)
		return nil, errorx.Internal("获取VIP套餐失败: " + result.Error.Error())
	}

	// 构建响应
	respPlans := make([]*super.VipPlan, len(plans))
	for i, plan := range plans {
		respPlans[i] = &super.VipPlan{
			Id:           string(rune(plan.ID)),
			Name:         plan.Name,
			Description:  plan.Features,
			Price:        float32(plan.Price),
			DurationDays: int32(plan.Duration),
			CreatedAt:    plan.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    plan.UpdatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.GetVipPlansResp{
		Plans: respPlans,
	}, nil
}
