package logic

import (
	"context"
	"errors"

	adminapp "backend/internal/service/admin"
	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminPublishAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminPublishAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminPublishAnnouncementLogic {
	return &AdminPublishAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminPublishAnnouncementLogic) AdminPublishAnnouncement(in *moe.AdminPublishAnnouncementReq) (*moe.AdminPublishAnnouncementResp, error) {
	app := adminapp.New(l.svcCtx.DB)
	resp, err := app.PublishAnnouncement(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, adminbiz.ErrInvalidAnnouncementID):
			return nil, errorx.InvalidArgument("公告 ID 无效")
		case errors.Is(err, adminbiz.ErrAnnouncementNotFound):
			return nil, errorx.NotFound("公告不存在")
		default:
			l.Errorf("[admin] publish announcement: %v", err)
			return nil, errorx.Internal("发布公告失败")
		}
	}
	return resp, nil
}
