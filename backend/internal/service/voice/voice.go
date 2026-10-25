// Package voiceapp 语音通话应用服务。
package voiceapp

import (
	"errors"

	voicebiz "backend/internal/biz/voice"
)

var errVoiceUnavailable = errors.New("voice app unavailable")

// AppService 语音通话应用层。
type AppService struct {
	resolver voicebiz.UserDisplayResolver
}

// New 构造 AppService。
func New(resolver voicebiz.UserDisplayResolver) *AppService {
	return &AppService{resolver: resolver}
}

func errUnavailable() error {
	return errVoiceUnavailable
}
