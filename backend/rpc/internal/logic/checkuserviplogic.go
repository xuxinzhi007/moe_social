package logic

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckUserVipLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckUserVipLogic {
	return &CheckUserVipLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CheckUserVipLogic) CheckUserVip(in *super.CheckUserVipReq) (*super.CheckUserVipResp, error) {
	uid, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || uid == 0 {
		return nil, mapUserBizErr(userbiz.ErrInvalidArgument)
	}
	active, err := userbiz.CheckVipActive(l.ctx, l.svcCtx.DB, uint(uid))
	if err != nil {
		return nil, mapUserBizErr(err)
	}
	return &super.CheckUserVipResp{IsVip: active}, nil
}
