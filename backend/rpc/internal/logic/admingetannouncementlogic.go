package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *AdminGetAnnouncementLogic) AdminGetAnnouncement(in *super.AdminGetAnnouncementReq) (*super.AdminGetAnnouncementResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAnnouncementId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("公告 ID 无效")
	}
	var row model.AdminAnnouncement
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, errorx.NotFound("公告不存在")
	}
	return &super.AdminGetAnnouncementResp{Announcement: announcementToProto(row)}, nil
}
