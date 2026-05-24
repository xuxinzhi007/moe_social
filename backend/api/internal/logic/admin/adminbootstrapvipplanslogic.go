// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapVipPlansLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapVipPlansLogic {
	return &AdminBootstrapVipPlansLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapVipPlansLogic) AdminBootstrapVipPlans(_ *types.EmptyReq) (resp *types.AdminBootstrapVipPlansResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminBootstrapVipPlans(l.ctx, &super.AdminBootstrapVipPlansReq{})
	if err != nil {
		return &types.AdminBootstrapVipPlansResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	msg := "ok"
	if rpcResp.GetCreated() > 0 {
		msg = "已导入默认套餐"
	} else {
		msg = "已有套餐，未导入"
	}

	return &types.AdminBootstrapVipPlansResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data: types.AdminBootstrapVipPlansData{
			Created: int(rpcResp.GetCreated()),
		},
	}, nil
}
