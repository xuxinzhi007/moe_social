package landingapp

import (
	"context"

	landingv1 "backend/api/landing/v1"
	landingbiz "backend/internal/biz/landing"
	landingdata "backend/internal/data/landing"

	"gorm.io/gorm"
)

// AppService Landing HTTP/RPC 应用层。
type AppService struct {
	feedback landingbiz.FeedbackStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{feedback: landingdata.NewFeedbackStore(db)}
}

// Submit 提交落地页反馈。
func (s *AppService) Submit(ctx context.Context, in *landingv1.SubmitLandingFeedbackRequest) (*landingv1.SubmitLandingFeedbackReply, error) {
	id, err := landingbiz.Submit(ctx, s.feedback, landingbiz.SubmitInput{
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
	return &landingv1.SubmitLandingFeedbackReply{Id: id}, nil
}

// List 分页列表。
func (s *AppService) List(ctx context.Context, in *landingv1.ListLandingFeedbackRequest) (*landingv1.ListLandingFeedbackReply, error) {
	result, err := landingbiz.List(ctx, s.feedback, landingbiz.ListFilter{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
		Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return &landingv1.ListLandingFeedbackReply{
		Items: landingv1.FeedbackItemsFromMoe(landingbiz.FeedbackItemsToProto(result.Rows)),
		Total: int32(result.Total),
	}, nil
}
