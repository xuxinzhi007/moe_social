package admin_public

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapAccountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapAccountLogic {
	return &AdminBootstrapAccountLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapAccountLogic) AdminBootstrapAccount(_ *types.EmptyReq) (resp *types.AdminBootstrapAccountResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminBootstrapAccount(l.ctx, &super.AdminBootstrapAccountReq{})
	if err != nil {
		return &types.AdminBootstrapAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	msg := "管理员账号已存在，未创建"
	if rpcResp.GetCreated() > 0 {
		msg = "已创建默认超管，请尽快登录并修改密码"
	}
	return &types.AdminBootstrapAccountResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     types.AdminBootstrapAccountData{Created: int(rpcResp.GetCreated())},
	}, nil
}
