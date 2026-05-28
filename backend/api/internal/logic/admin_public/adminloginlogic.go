// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin_public

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminLoginLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminLoginLogic {
	return &AdminLoginLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminLoginLogic) AdminLogin(req *types.AdminLoginReq) (resp *types.AdminLoginResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminLogin(l.ctx, &moe.AdminLoginReq{
		Username: req.Username,
		Password: req.Password,
	})
	if err != nil {
		return &types.AdminLoginResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminLoginResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminLoginData{
			Token:    rpcResp.Token,
			AdminId:  rpcResp.AdminId,
			Username: rpcResp.Username,
			Role:     rpcResp.Role,
			ExpireAt: rpcResp.ExpireAt,
		},
	}, nil
}
