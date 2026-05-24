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

type AdminDeleteVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteVipPlanLogic {
	return &AdminDeleteVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeleteVipPlanLogic) AdminDeleteVipPlan(in *super.AdminDeleteVipPlanReq) (*super.AdminDeleteVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}

	var plan model.VipPlan
	if err := l.svcCtx.DB.First(&plan, planID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("VIP 套餐不存在")
		}
		l.Errorf("[admin] delete vip plan load: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}

	if err := l.svcCtx.DB.Delete(&plan).Error; err != nil {
		l.Errorf("[admin] delete vip plan: %v", err)
		return nil, errorx.Internal("删除 VIP 套餐失败")
	}

	return &super.AdminDeleteVipPlanResp{}, nil
}
