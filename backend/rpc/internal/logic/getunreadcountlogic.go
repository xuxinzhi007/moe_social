package logic

import (
	"context"
	"errors"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUnreadCountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUnreadCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUnreadCountLogic {
	return &GetUnreadCountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUnreadCountLogic) GetUnreadCount(in *moe.GetUnreadCountReq) (*moe.GetUnreadCountResp, error) {
	count, err := notifybiz.UnreadCount(l.ctx, l.svcCtx.NotifyStore(), in.GetUserId())
	if err != nil {
		if errors.Is(err, notifybiz.ErrInvalidUserID) {
			return nil, errorx.InvalidArgument("用户 ID 无效")
		}
		l.Error("查询未读数失败:", err)
		return nil, errorx.Internal("查询未读数失败")
	}
	return &moe.GetUnreadCountResp{Count: count}, nil
}
