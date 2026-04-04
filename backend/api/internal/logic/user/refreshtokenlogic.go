package user

import (
	"context"

	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

// RefreshTokenLogic 由 goctl 生成；实际逻辑在 refreshtokenhandler.go（需读取 Authorization）。
type RefreshTokenLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewRefreshTokenLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RefreshTokenLogic {
	return &RefreshTokenLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}
