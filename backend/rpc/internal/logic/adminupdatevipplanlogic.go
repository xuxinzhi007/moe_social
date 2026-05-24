package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpdateVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateVipPlanLogic {
	return &AdminUpdateVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateVipPlanLogic) AdminUpdateVipPlan(in *super.AdminUpdateVipPlanReq) (*super.AdminUpdateVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}

	var plan model.VipPlan
	if err := l.svcCtx.DB.Unscoped().First(&plan, planID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("VIP 套餐不存在")
		}
		l.Errorf("[admin] update vip plan load: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}

	if in.GetUpdateName() {
		name := strings.TrimSpace(in.GetName())
		if name == "" {
			return nil, errorx.InvalidArgument("套餐名称不能为空")
		}
		plan.Name = name
	}
	if in.GetUpdateDescription() {
		plan.Features = strings.TrimSpace(in.GetDescription())
	}
	if in.GetUpdatePrice() {
		if in.GetPrice() < 0 {
			return nil, errorx.InvalidArgument("价格不能为负数")
		}
		plan.Price = float64(in.GetPrice())
	}
	if in.GetUpdateDurationDays() {
		if in.GetDurationDays() <= 0 {
			return nil, errorx.InvalidArgument("有效期天数必须大于 0")
		}
		plan.Duration = int(in.GetDurationDays())
	}

	if err := l.svcCtx.DB.Save(&plan).Error; err != nil {
		l.Errorf("[admin] update vip plan save: %v", err)
		return nil, errorx.Internal("更新 VIP 套餐失败")
	}

	return &super.AdminUpdateVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
