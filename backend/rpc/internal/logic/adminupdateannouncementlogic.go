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

type AdminUpdateAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAnnouncementLogic {
	return &AdminUpdateAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateAnnouncementLogic) AdminUpdateAnnouncement(in *moe.AdminUpdateAnnouncementReq) (*moe.AdminUpdateAnnouncementResp, error) {
	app := adminapp.New(l.svcCtx.DB)
	resp, err := app.UpdateAnnouncement(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, adminbiz.ErrInvalidAnnouncementID):
			return nil, errorx.InvalidArgument("公告 ID 无效")
		case errors.Is(err, adminbiz.ErrAnnouncementNotFound):
			return nil, errorx.NotFound("公告不存在")
		case errors.Is(err, adminbiz.ErrEmptyAnnouncementTitle):
			return nil, errorx.InvalidArgument("标题不能为空")
		default:
			l.Errorf("[admin] update announcement: %v", err)
			return nil, errorx.Internal("更新公告失败")
		}
	}
	return resp, nil
}
