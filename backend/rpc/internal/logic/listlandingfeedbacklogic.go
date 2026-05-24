package logic

import (
	"context"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListLandingFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLandingFeedbackLogic {
	return &ListLandingFeedbackLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListLandingFeedbackLogic) ListLandingFeedback(in *super.ListLandingFeedbackReq) (*super.ListLandingFeedbackResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := l.svcCtx.DB.Model(&model.LandingFeedback{})
	category := strings.TrimSpace(in.GetCategory())
	if category != "" && category != "all" {
		q = q.Where("category = ?", normalizeLandingFeedbackCategory(category))
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[landing] count feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	var rows []model.LandingFeedback
	offset := int((page - 1) * pageSize)
	if err := q.Order("created_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[landing] list feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	items := make([]*super.LandingFeedbackItem, 0, len(rows))
	for i := range rows {
		row := rows[i]
		items = append(items, &super.LandingFeedbackItem{
			Id:        uint64(row.ID),
			Email:     row.Email,
			Category:  row.Category,
			Content:   row.Content,
			Source:    row.Source,
			ClientIp:  row.ClientIP,
			UserAgent: row.UserAgent,
			CreatedAt: row.CreatedAt.Format(time.RFC3339),
		})
	}

	return &super.ListLandingFeedbackResp{
		Items: items,
		Total: int32(total),
	}, nil
}
