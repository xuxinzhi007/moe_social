package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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
	_, err = l.svcCtx.SuperRpcClient.AdminDeleteComment(l.ctx, &super.AdminDeleteCommentReq{
		CommentId: req.CommentId,
	})
	if err != nil {
		return &types.AdminDeleteCommentResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminDeleteCommentResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}, nil
}
