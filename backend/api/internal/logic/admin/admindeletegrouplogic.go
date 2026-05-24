package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteGroupLogic {
	return &AdminDeleteGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteGroupLogic) AdminDeleteGroup(req *types.AdminDeleteGroupReq) (resp *types.AdminDeleteGroupResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.AdminDeleteGroup(l.ctx, &super.AdminDeleteGroupReq{
		GroupId: req.GroupId,
	})
	if err != nil {
		return &types.AdminDeleteGroupResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminDeleteGroupResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}, nil
}
