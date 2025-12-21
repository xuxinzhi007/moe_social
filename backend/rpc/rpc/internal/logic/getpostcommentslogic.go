package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostCommentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostCommentsLogic {
	return &GetPostCommentsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetPostCommentsLogic) GetPostComments(in *rpc.GetPostCommentsReq) (*rpc.GetPostCommentsResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetPostCommentsResp{}, nil
}
