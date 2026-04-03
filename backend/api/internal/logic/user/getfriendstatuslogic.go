// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFriendStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetFriendStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFriendStatusLogic {
	return &GetFriendStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetFriendStatusLogic) GetFriendStatus(req *types.FriendStatusPathReq) (resp *types.FriendStatusResp, err error) {
	// todo: add your logic here and delete this line

	return
}
