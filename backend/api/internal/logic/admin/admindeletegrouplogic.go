package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

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
	_, err = l.svcCtx.AdminGW.AdminDeleteGroup(l.ctx, &moe.AdminDeleteGroupReq{
		GroupId: req.GroupId,
	})
	if err != nil {
		return &types.AdminDeleteGroupResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp = &types.AdminDeleteGroupResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "group", req.GroupId, "删除群组")
	}
	return resp, nil
}
