// Package landingapp Landing 域应用服务（FS-3c / Sprint S1）。
package landingapp

import (
	"context"

	landingbiz "backend/internal/biz/landing"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService Landing HTTP/RPC 应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// Submit 提交落地页反馈。
func (s *AppService) Submit(ctx context.Context, in *super.SubmitLandingFeedbackReq) (*super.SubmitLandingFeedbackResp, error) {
	id, err := landingbiz.Submit(ctx, s.db, landingbiz.SubmitInput{
		Email:     in.GetEmail(),
		Category:  in.GetCategory(),
		Content:   in.GetContent(),
		Source:    in.GetSource(),
		ClientIP:  in.GetClientIp(),
		UserAgent: in.GetUserAgent(),
	})
	if err != nil {
		return nil, err
	}
	return &super.SubmitLandingFeedbackResp{Id: id}, nil
}

// List 分页列表。
func (s *AppService) List(ctx context.Context, in *super.ListLandingFeedbackReq) (*super.ListLandingFeedbackResp, error) {
	result, err := landingbiz.List(ctx, s.db, landingbiz.ListFilter{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
		Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return &super.ListLandingFeedbackResp{
		Items: landingbiz.FeedbackItemsToProto(result.Rows),
		Total: int32(result.Total),
	}, nil
}
