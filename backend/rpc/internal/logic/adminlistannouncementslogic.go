package logic

import (
	"context"
	"strings"

	"backend/model"
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
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.AdminAnnouncement{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("title LIKE ? OR content LIKE ?", like, like)
	}
	if st := strings.TrimSpace(in.GetStatus()); st != "" {
		q = q.Where("status = ?", st)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count announcements: %v", err)
		return nil, errorx.Internal("查询公告失败")
	}
	var rows []model.AdminAnnouncement
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list announcements: %v", err)
		return nil, errorx.Internal("查询公告失败")
	}
	items := make([]*super.AdminAnnouncementItem, len(rows))
	for i, row := range rows {
		items[i] = announcementToProto(row)
	}
	return &super.AdminListAnnouncementsResp{Items: items, Total: int32(total)}, nil
}
