package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
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
	page := int(in.GetPage())
	pageSize := int(in.GetPageSize())
	rows, total, err := vipbiz.ListPlans(l.ctx, l.svcCtx.DB, vipbiz.ListPlansFilter{
		Page:           page,
		PageSize:       pageSize,
		Keyword:        in.GetKeyword(),
		IncludeDeleted: in.GetIncludeDeleted(),
	})
	if err != nil {
		l.Errorf("[admin] list vip plans: %v", err)
		return nil, mapVipBizErr(err)
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
