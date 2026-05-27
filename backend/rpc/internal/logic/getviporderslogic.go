package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipOrdersLogic {
	return &GetVipOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipOrdersLogic) GetVipOrders(in *super.GetVipOrdersReq) (*super.GetVipOrdersResp, error) {
	orders, total, err := userbiz.ListVipOrders(l.ctx, l.svcCtx.DB, in.GetUserId(), userbiz.VipOrdersPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		l.Error("获取订单列表失败: ", err)
		if err == userbiz.ErrInvalidArgument {
			return nil, errorx.InvalidArgument("无效的用户 ID")
		}
		return nil, errorx.Internal("获取订单列表失败: " + err.Error())
	}
	return &super.GetVipOrdersResp{Orders: orders, Total: total}, nil
}
