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

type CheckInLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckInLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckInLogic {
	return &CheckInLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *CheckInLogic) CheckIn(in *super.CheckInReq) (*super.CheckInResp, error) {
	app := checkinapp.New(l.svcCtx.DB)
	resp, err := app.CheckIn(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, checkinbiz.ErrInvalidUserID):
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		case errors.Is(err, checkinbiz.ErrUserNotFound):
			return nil, fmt.Errorf("用户不存在")
		case errors.Is(err, checkinbiz.ErrAlreadyCheckedIn):
			return nil, fmt.Errorf("今日已签到")
		default:
			return nil, err
		}
	}
	return resp, nil
}
