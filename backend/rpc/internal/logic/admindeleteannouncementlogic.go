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

type AdminDeleteAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAnnouncementLogic {
	return &AdminDeleteAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteAnnouncementLogic) AdminDeleteAnnouncement(in *moe.AdminDeleteAnnouncementReq) (*moe.AdminDeleteAnnouncementResp, error) {
	app := adminapp.New(l.svcCtx.DB)
	resp, err := app.DeleteAnnouncement(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, adminbiz.ErrInvalidAnnouncementID):
			return nil, errorx.InvalidArgument("公告 ID 无效")
		default:
			l.Errorf("[admin] delete announcement: %v", err)
			return nil, errorx.Internal("删除公告失败")
		}
	}
	return resp, nil
}
