package logic

import (
	"context"
	"errors"
	"fmt"

	checkinapp "backend/internal/service/checkin"
	checkinbiz "backend/internal/biz/checkin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetCheckInStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetCheckInStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInStatusLogic {
	return &GetCheckInStatusLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetCheckInStatusLogic) GetCheckInStatus(in *super.GetCheckInStatusReq) (*super.GetCheckInStatusResp, error) {
	app := checkinapp.New(l.svcCtx.DB)
	resp, err := app.GetCheckInStatus(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, checkinbiz.ErrInvalidUserID):
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		case errors.Is(err, checkinbiz.ErrUserNotFound):
			return nil, fmt.Errorf("用户不存在")
		default:
			return nil, err
		}
	}
	return resp, nil
}
