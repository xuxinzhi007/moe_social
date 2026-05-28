package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFriendRelationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetFriendRelationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFriendRelationLogic {
	return &GetFriendRelationLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetFriendRelationLogic) GetFriendRelation(in *moe.GetFriendRelationReq) (*moe.GetFriendRelationResp, error) {
	return NewFriendRelationLogic(l.ctx, l.svcCtx).GetFriendRelation(in)
}
