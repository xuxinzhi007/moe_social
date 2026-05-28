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

type AdminGetAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetAnnouncementLogic {
	return &AdminGetAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetAnnouncementLogic) AdminGetAnnouncement(in *moe.AdminGetAnnouncementReq) (*moe.AdminGetAnnouncementResp, error) {
	item, err := adminbiz.GetAnnouncement(l.ctx, l.svcCtx.DB, in.GetAnnouncementId())
	if err != nil {
		switch {
		case errors.Is(err, adminbiz.ErrInvalidAnnouncementID):
			return nil, errorx.InvalidArgument("公告 ID 无效")
		case errors.Is(err, adminbiz.ErrAnnouncementNotFound):
			return nil, errorx.NotFound("公告不存在")
		default:
			return nil, errorx.Internal("查询公告失败")
		}
	}
	return &moe.AdminGetAnnouncementResp{Announcement: item}, nil
}
