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

type AdminListPostReportsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListPostReportsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostReportsLogic {
	return &AdminListPostReportsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func previewContent(s string) string {
	s = strings.TrimSpace(s)
	if len(s) <= 120 {
		return s
	}
	return s[:120] + "…"
}

func (l *AdminListPostReportsLogic) AdminListPostReports(in *super.AdminListPostReportsReq) (*super.AdminListPostReportsResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := l.svcCtx.DB.Model(&model.PostReport{})

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count post reports: %v", err)
		return nil, errorx.Internal("查询举报失败")
	}

	var rows []model.PostReport
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list post reports: %v", err)
		return nil, errorx.Internal("查询举报失败")
	}

	postIDs := make([]uint, 0, len(rows))
	for _, r := range rows {
		postIDs = append(postIDs, r.PostID)
	}
	postPreview := map[uint]string{}
	if len(postIDs) > 0 {
		var posts []model.Post
		_ = l.svcCtx.DB.Unscoped().Select("id", "content").Where("id IN ?", postIDs).Find(&posts).Error
		for _, p := range posts {
			postPreview[p.ID] = previewContent(p.Content)
		}
	}

	reports := make([]*super.AdminPostReportItem, len(rows))
	for i, r := range rows {
		reports[i] = &super.AdminPostReportItem{
			Id:                 strconv.FormatUint(uint64(r.ID), 10),
			PostId:             strconv.FormatUint(uint64(r.PostID), 10),
			ReporterUserId:     strconv.FormatUint(uint64(r.ReporterUserID), 10),
			Reason:             r.Reason,
			CreatedAt:          r.CreatedAt.Format("2006-01-02 15:04:05"),
			PostContentPreview: postPreview[r.PostID],
		}
	}

	return &super.AdminListPostReportsResp{
		Reports: reports,
		Total:   int32(total),
	}, nil
}
