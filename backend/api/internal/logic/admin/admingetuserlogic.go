// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserLogic {
	return &AdminGetUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetUserLogic) AdminGetUser(req *types.AdminGetUserReq) (resp *types.AdminGetUserResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminGetUser(l.ctx, &super.AdminGetUserReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.AdminGetUserResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminGetUserResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcUserToTypes(rpcResp.User),
	}, nil
}
