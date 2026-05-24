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

type AdminUpdateUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateUserLogic {
	return &AdminUpdateUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateUserLogic) AdminUpdateUser(req *types.AdminUpdateUserReq) (resp *types.AdminUpdateUserResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateUser(l.ctx, &super.AdminUpdateUserReq{
		UserId:          req.UserId,
		Role:            req.Role,
		IsVip:           req.IsVip,
		UpdateIsVip:     req.UpdateIsVip,
		Signature:       req.Signature,
		UpdateSignature: req.UpdateSignature,
	})
	if err != nil {
		return &types.AdminUpdateUserResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminUpdateUserResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcUserToTypes(rpcResp.User),
	}, nil
}
