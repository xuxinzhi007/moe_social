package logic

import (
	"context"
	"errors"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminGetVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetVipPlanLogic {
	return &AdminGetVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminGetVipPlanLogic) AdminGetVipPlan(in *super.AdminGetVipPlanReq) (*super.AdminGetVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}

	var plan model.VipPlan
	if err := l.svcCtx.DB.Unscoped().First(&plan, planID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("VIP 套餐不存在")
		}
		l.Errorf("[admin] get vip plan: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}

	return &super.AdminGetVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
