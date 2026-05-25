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

type AdminUpdateAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAnnouncementLogic {
	return &AdminUpdateAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateAnnouncementLogic) AdminUpdateAnnouncement(in *super.AdminUpdateAnnouncementReq) (*super.AdminUpdateAnnouncementResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAnnouncementId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("公告 ID 无效")
	}
	var row model.AdminAnnouncement
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, errorx.NotFound("公告不存在")
	}
	updates := false
	if in.GetUpdateTitle() {
		title := strings.TrimSpace(in.GetTitle())
		if title == "" {
			return nil, errorx.InvalidArgument("标题不能为空")
		}
		row.Title = title
		updates = true
	}
	if in.GetUpdateContent() {
		row.Content = strings.TrimSpace(in.GetContent())
		updates = true
	}
	if !updates {
		if reqTitle := strings.TrimSpace(in.GetTitle()); reqTitle != "" {
			row.Title = reqTitle
			updates = true
		}
		if in.GetContent() != "" {
			row.Content = strings.TrimSpace(in.GetContent())
			updates = true
		}
	}
	if err := l.svcCtx.DB.Save(&row).Error; err != nil {
		l.Errorf("[admin] update announcement: %v", err)
		return nil, errorx.Internal("更新公告失败")
	}
	return &super.AdminUpdateAnnouncementResp{Announcement: announcementToProto(row)}, nil
}
