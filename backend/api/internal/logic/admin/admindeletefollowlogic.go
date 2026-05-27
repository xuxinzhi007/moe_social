package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteFollowLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteFollowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteFollowLogic {
	return &AdminDeleteFollowLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteFollowLogic) AdminDeleteFollow(req *types.AdminDeleteFollowReq) (*types.AdminDeleteFollowResp, error) {
	_, err := l.svcCtx.AdminGW.AdminDeleteFollow(l.ctx, &super.AdminDeleteFollowReq{
		FollowId: req.FollowId,
	})
	if err != nil {
		return &types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "follow", req.FollowId, "删除关注关系")
	}
	return resp, nil
}
