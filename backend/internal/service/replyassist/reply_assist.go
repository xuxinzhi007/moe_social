// Package replyassistapp is the application layer for reply-assist suggestions.
package replyassistapp

import (
	"context"

	replyassistv1 "backend/api/replyassist/v1"
	replyassistbiz "backend/internal/biz/replyassist"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

// AppService exposes reply-assist use cases.
type AppService struct {
	engine *replyassistbiz.Engine
}

// New constructs AppService.
func New(engine *replyassistbiz.Engine) *AppService {
	return &AppService{engine: engine}
}

// UseInferenceResolver forwards resolver to the engine.
func (s *AppService) UseInferenceResolver(resolve replyassistbiz.InferenceResolver) {
	if s == nil || s.engine == nil {
		return
	}
	s.engine.UseInferenceResolver(resolve)
}

func (s *AppService) requireEngine() (*replyassistbiz.Engine, error) {
	if s == nil || s.engine == nil {
		return nil, kerrors.ServiceUnavailable("REPLY_ASSIST_UNAVAILABLE", "回复参谋暂不可用")
	}
	return s.engine, nil
}

// Suggest runs judge + three reply options for the authenticated user.
func (s *AppService) Suggest(ctx context.Context, userID uint, in *replyassistv1.ReplyAssistSuggestRequest) (*replyassistv1.ReplyAssistSuggestReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	if in == nil {
		return nil, kerrors.BadRequest("INVALID_REQUEST", "请求不能为空")
	}
	msgs := make([]replyassistbiz.ChatMessage, 0, len(in.GetMessages()))
	for _, m := range in.GetMessages() {
		msgs = append(msgs, replyassistbiz.ChatMessage{
			Role: m.GetRole(),
			Text: m.GetText(),
		})
	}
	result, err := engine.Suggest(ctx, userID, replyassistbiz.SuggestInput{
		Source:     in.GetSource(),
		Messages:   msgs,
		PastedText: in.GetPastedText(),
		ImageURL:   in.GetImageUrl(),
		AppPackage: in.GetAppPackage(),
	})
	if err != nil {
		return nil, kerrors.BadRequest("REPLY_ASSIST_FAILED", err.Error())
	}
	options := make([]*replyassistv1.ReplyAssistOption, 0, len(result.Options))
	for _, opt := range result.Options {
		options = append(options, &replyassistv1.ReplyAssistOption{
			Label: opt.Label,
			Text:  opt.Text,
		})
	}
	return &replyassistv1.ReplyAssistSuggestReply{
		Judge: &replyassistv1.ReplyAssistJudgeSummary{
			Intent:          result.Judge.Intent,
			Emotion:         result.Judge.Emotion,
			Urgency:         result.Judge.Urgency,
			ReplyStance:     result.Judge.ReplyStance,
			ShouldReply:     result.Judge.ShouldReply,
			UncertaintyNote: result.Judge.UncertaintyNote,
			RiskHint:        result.Judge.RiskHint,
		},
		Options:   options,
		SessionId: result.SessionID,
	}, nil
}
