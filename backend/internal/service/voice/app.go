// Package voiceapp 语音通话应用服务。
package voiceapp

import (
	"context"
	"errors"

	voicebiz "backend/internal/biz/voice"
)

var errVoiceUnavailable = errors.New("voice app unavailable")

// AppService 语音通话应用层。
type AppService struct {
	resolver voicebiz.UserDisplayResolver
	agora    voicebiz.AgoraConfig
}

// New 构造 AppService。
func New(resolver voicebiz.UserDisplayResolver, agora voicebiz.AgoraConfig) *AppService {
	return &AppService{resolver: resolver, agora: agora}
}

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

// GetRtcToken 生成 Agora RTC token。
func (s *AppService) GetRtcToken(_ context.Context, in voicebiz.TokenInput) (voicebiz.TokenResult, error) {
	if s == nil {
		return voicebiz.TokenResult{}, errUnavailable()
	}
	return voicebiz.BuildRtcToken(s.agora, in)
}

func errUnavailable() error {
	return errVoiceUnavailable
}
