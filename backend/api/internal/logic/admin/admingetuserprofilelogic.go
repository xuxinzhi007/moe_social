package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetUserProfileLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetUserProfileLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserProfileLogic {
	return &AdminGetUserProfileLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetUserProfileLogic) AdminGetUserProfile(req *types.AdminGetUserProfileReq) (*types.AdminGetUserProfileResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetUserProfile(l.ctx, &moe.AdminGetUserProfileReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.AdminGetUserProfileResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetUserProfileResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminUserProfileToTypes(rpcResp.GetData()),
	}, nil
}
