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

type GetCheckInHistoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetCheckInHistoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInHistoryLogic {
	return &GetCheckInHistoryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetCheckInHistoryLogic) GetCheckInHistory(in *moe.GetCheckInHistoryReq) (*moe.GetCheckInHistoryResp, error) {
	app := checkinapp.New(l.svcCtx.DB)
	resp, err := app.GetCheckInHistory(l.ctx, in)
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
