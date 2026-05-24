package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapVipPlansLogic {
	return &AdminBootstrapVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapVipPlansLogic) AdminBootstrapVipPlans(in *super.AdminBootstrapVipPlansReq) (*super.AdminBootstrapVipPlansResp, error) {
	_ = in

	var count int64
	if err := l.svcCtx.DB.Model(&model.VipPlan{}).Count(&count).Error; err != nil {
		l.Errorf("[admin] bootstrap vip plans count: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}
	if count > 0 {
		return &super.AdminBootstrapVipPlansResp{Created: 0}, nil
	}

	defaults := []model.VipPlan{
		{Name: "月度 VIP", Price: 99, Duration: 30, Features: "月卡套餐"},
		{Name: "季度 VIP", Price: 268, Duration: 90, Features: "季度套餐"},
		{Name: "年度 VIP", Price: 899, Duration: 365, Features: "年度套餐"},
	}

	if err := l.svcCtx.DB.Create(&defaults).Error; err != nil {
		l.Errorf("[admin] bootstrap vip plans create: %v", err)
		return nil, errorx.Internal("初始化 VIP 套餐失败")
	}

	return &super.AdminBootstrapVipPlansResp{
		Created: int32(len(defaults)),
	}, nil
}
