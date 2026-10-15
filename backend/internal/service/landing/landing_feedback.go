package landingapp

import (
	"context"

	landingv1 "backend/api/landing/v1"
	landingbiz "backend/internal/biz/landing"
)

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
