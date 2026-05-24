package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipPlansLogic {
	return &AdminListVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListVipPlansLogic) AdminListVipPlans(in *super.AdminListVipPlansReq) (*super.AdminListVipPlansResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := l.svcCtx.DB.Model(&model.VipPlan{})
	if in.GetIncludeDeleted() {
		q = q.Unscoped()
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR features LIKE ?", like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count vip plans: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}

	var rows []model.VipPlan
	offset := int((page - 1) * pageSize)
	if err := q.Order("id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list vip plans: %v", err)
		return nil, errorx.Internal("查询 VIP 套餐失败")
	}

	plans := make([]*super.VipPlan, len(rows))
	for i := range rows {
		plans[i] = vipPlanModelToProto(rows[i])
	}

	return &super.AdminListVipPlansResp{
		Plans: plans,
		Total: int32(total),
	}, nil
}
