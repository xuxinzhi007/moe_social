package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateCommentLogic {
	return &CreateCommentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 评论相关服务
func (l *CreateCommentLogic) CreateComment(in *rpc.CreateCommentReq) (*rpc.CreateCommentResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.CreateCommentResp{}, nil
}
