package logic

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserVipStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserVipStatusLogic {
	return &GetUserVipStatusLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserVipStatusLogic) GetUserVipStatus(in *moe.GetUserVipStatusReq) (*moe.GetUserVipStatusResp, error) {
	uid, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || uid == 0 {
		return nil, mapUserBizErr(userbiz.ErrInvalidArgument)
	}
	st, err := userbiz.GetVipStatus(l.ctx, l.svcCtx.DB, uint(uid))
	if err != nil {
		return nil, mapUserBizErr(err)
	}
	return &moe.GetUserVipStatusResp{
		IsVip:     st.IsVip,
		ExpiresAt: st.ExpiresAt,
		AutoRenew: st.AutoRenew,
	}, nil
}
