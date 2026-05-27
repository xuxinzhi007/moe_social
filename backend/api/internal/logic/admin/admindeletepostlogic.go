package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeletePostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeletePostLogic {
	return &AdminDeletePostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeletePostLogic) AdminDeletePost(req *types.AdminDeletePostReq) (resp *types.AdminDeletePostResp, err error) {
	_, err = l.svcCtx.AdminGW.AdminDeletePost(l.ctx, &super.AdminDeletePostReq{
		PostId: req.PostId,
	})
	if err != nil {
		return &types.AdminDeletePostResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp = &types.AdminDeletePostResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "post", req.PostId, "删除帖子")
	}
	return resp, nil
}
