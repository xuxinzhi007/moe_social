package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteCommentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteCommentLogic {
	return &AdminDeleteCommentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteCommentLogic) AdminDeleteComment(req *types.AdminDeleteCommentReq) (resp *types.AdminDeleteCommentResp, err error) {
	_, err = l.svcCtx.AdminGW.AdminDeleteComment(l.ctx, &moe.AdminDeleteCommentReq{
		CommentId: req.CommentId,
	})
	if err != nil {
		return &types.AdminDeleteCommentResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp = &types.AdminDeleteCommentResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "comment", req.CommentId, "删除评论")
	}
	return resp, nil
}
