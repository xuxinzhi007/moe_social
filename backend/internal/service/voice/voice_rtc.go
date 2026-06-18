package voiceapp

import (
	"context"
	voicebiz "backend/internal/biz/voice"
)

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
