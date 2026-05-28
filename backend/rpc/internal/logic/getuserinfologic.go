package logic

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserInfoLogic {
	return &GetUserInfoLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserInfoLogic) GetUserInfo(in *moe.GetUserInfoReq) (*moe.GetUserInfoResp, error) {
	uid, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || uid == 0 {
		return nil, mapUserBizErr(userbiz.ErrInvalidArgument)
	}
	user, err := userbiz.GetByID(l.ctx, l.svcCtx.UserStore(), uint(uid))
	if err != nil {
		l.Errorf("get user info: %v", err)
		return nil, mapUserBizErr(err)
	}
	return &moe.GetUserInfoResp{User: modelUserToProto(&user)}, nil
}
