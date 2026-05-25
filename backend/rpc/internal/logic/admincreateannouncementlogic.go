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

type AdminCreateAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAnnouncementLogic {
	return &AdminCreateAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateAnnouncementLogic) AdminCreateAnnouncement(in *super.AdminCreateAnnouncementReq) (*super.AdminCreateAnnouncementResp, error) {
	title := strings.TrimSpace(in.GetTitle())
	if title == "" {
		return nil, errorx.InvalidArgument("标题不能为空")
	}
	createdBy, _ := strconv.ParseUint(strings.TrimSpace(in.GetCreatedBy()), 10, 64)
	row := model.AdminAnnouncement{
		Title:     title,
		Content:   strings.TrimSpace(in.GetContent()),
		Status:    model.AnnouncementStatusDraft,
		CreatedBy: uint(createdBy),
	}
	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		l.Errorf("[admin] create announcement: %v", err)
		return nil, errorx.Internal("创建公告失败")
	}
	return &super.AdminCreateAnnouncementResp{Announcement: announcementToProto(row)}, nil
}
