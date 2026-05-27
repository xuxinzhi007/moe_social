package logic

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserLogic {
	return &GetUserLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserLogic) GetUser(in *super.GetUserReq) (*super.GetUserResp, error) {
	uid, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || uid == 0 {
		return nil, mapUserBizErr(userbiz.ErrInvalidArgument)
	}
	user, err := userbiz.GetByID(l.ctx, l.svcCtx.DB, uint(uid))
	if err != nil {
		return nil, mapUserBizErr(err)
	}
	return &super.GetUserResp{User: modelUserToProto(&user)}, nil
}
