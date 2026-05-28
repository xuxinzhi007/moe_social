package logic

import (
	"context"
	"errors"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminLoginLogic {
	return &AdminLoginLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminLoginLogic) AdminLogin(in *moe.AdminLoginReq) (*moe.AdminLoginResp, error) {
	resp, err := adminbiz.AdminLogin(l.ctx, l.svcCtx.DB, in)
	if err != nil {
		if errors.Is(err, adminbiz.ErrAdminLoginEmpty) {
			return nil, errorx.InvalidArgument("请输入用户名和密码")
		}
		if errors.Is(err, adminbiz.ErrAdminAuthFailed) {
			return nil, errorx.New(401, "用户名或密码错误")
		}
		l.Errorf("[admin] login: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}
	return resp, nil
}
