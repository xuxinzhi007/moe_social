package voiceapp

import (
	"context"
	voicebiz "backend/internal/biz/voice"
)

// VoiceCall 发起语音呼叫。
func (s *AppService) VoiceCall(ctx context.Context, callerID, receiverID string) (voicebiz.CallResult, error) {
	if s == nil {
		return voicebiz.CallResult{}, errUnavailable()
	}
	return voicebiz.VoiceCall(ctx, s.resolver, callerID, receiverID)
}

// VoiceAnswer 接听呼叫。
func (s *AppService) VoiceAnswer(ctx context.Context, receiverID, callID string) (voicebiz.AnswerResult, error) {
	if s == nil {
		return voicebiz.AnswerResult{}, errUnavailable()
	}
	return voicebiz.VoiceAnswer(ctx, receiverID, callID)
}

// VoiceCancel 取消呼叫。
func (s *AppService) VoiceCancel(ctx context.Context, callerID, callID string) error {
	if s == nil {
		return errUnavailable()
	}
	return voicebiz.VoiceCancel(ctx, callerID, callID)
}

// VoiceReject 拒接呼叫。
func (s *AppService) VoiceReject(ctx context.Context, receiverID, callID string) error {
	if s == nil {
		return errUnavailable()
	}
	return voicebiz.VoiceReject(ctx, receiverID, callID)
}
