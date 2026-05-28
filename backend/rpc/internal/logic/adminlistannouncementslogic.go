package logic

import (
	"context"

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
	resp, err := newAdminApp(l.svcCtx.DB).ListAnnouncements(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] list announcements: %v", err)
		return nil, mapAdminAnnouncementErr(err)
	}
	return resp, nil
}
