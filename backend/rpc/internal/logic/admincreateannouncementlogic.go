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

type AdminCreateAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAnnouncementLogic {
	return &AdminCreateAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateAnnouncementLogic) AdminCreateAnnouncement(in *moe.AdminCreateAnnouncementReq) (*moe.AdminCreateAnnouncementResp, error) {
	app := adminapp.New(l.svcCtx.DB)
	resp, err := app.CreateAnnouncement(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, adminbiz.ErrEmptyAnnouncementTitle):
			return nil, errorx.InvalidArgument("标题不能为空")
		default:
			l.Errorf("[admin] create announcement: %v", err)
			return nil, errorx.Internal("创建公告失败")
		}
	}
	return resp, nil
}
