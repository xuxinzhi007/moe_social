package logic

import (
	"context"
	"errors"
	"fmt"

	checkinapp "backend/internal/service/checkin"
	checkinbiz "backend/internal/biz/checkin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserLevelLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserLevelLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserLevelLogic {
	return &GetUserLevelLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserLevelLogic) GetUserLevel(in *moe.GetUserLevelReq) (*moe.GetUserLevelResp, error) {
	app := checkinapp.New(l.svcCtx.DB)
	resp, err := app.GetUserLevel(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, checkinbiz.ErrInvalidUserID):
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		default:
			return nil, err
		}
	}
	return resp, nil
}
