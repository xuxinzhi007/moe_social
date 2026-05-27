package logic

import (
	"context"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAnnouncementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAnnouncementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAnnouncementsLogic {
	return &AdminListAnnouncementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAnnouncementsLogic) AdminListAnnouncements(in *super.AdminListAnnouncementsReq) (*super.AdminListAnnouncementsResp, error) {
	items, total, err := adminbiz.ListAnnouncements(l.ctx, l.svcCtx.DB, adminbiz.AnnouncementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(), Status: in.GetStatus(),
	})
	if err != nil {
		l.Errorf("[admin] list announcements: %v", err)
		return nil, errorx.Internal("查询公告失败")
	}
	return &super.AdminListAnnouncementsResp{Items: items, Total: total}, nil
}
