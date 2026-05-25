package logic

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *AdminPublishAnnouncementLogic) AdminPublishAnnouncement(in *super.AdminPublishAnnouncementReq) (*super.AdminPublishAnnouncementResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAnnouncementId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("公告 ID 无效")
	}
	var row model.AdminAnnouncement
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, errorx.NotFound("公告不存在")
	}
	now := time.Now()
	row.Status = model.AnnouncementStatusPublished
	row.PublishedAt = &now
	if err := l.svcCtx.DB.Save(&row).Error; err != nil {
		l.Errorf("[admin] publish announcement: %v", err)
		return nil, errorx.Internal("发布公告失败")
	}
	return &super.AdminPublishAnnouncementResp{Announcement: announcementToProto(row)}, nil
}
