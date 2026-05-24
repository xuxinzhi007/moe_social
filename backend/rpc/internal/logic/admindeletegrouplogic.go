package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteGroupLogic {
	return &AdminDeleteGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeleteGroupLogic) AdminDeleteGroup(in *super.AdminDeleteGroupReq) (*super.AdminDeleteGroupResp, error) {
	_, err := NewDeleteGroupLogic(l.ctx, l.svcCtx).DeleteGroup(&super.DeleteGroupReq{
		GroupId: in.GetGroupId(),
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminDeleteGroupResp{}, nil
}
