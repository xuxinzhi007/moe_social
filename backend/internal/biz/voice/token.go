package voicebiz

import (
	"errors"

	rtctokenbuilder "github.com/AgoraIO-Community/go-tokenbuilder/rtctokenbuilder"
)

// AgoraConfig Agora RTC 凭证。
type AgoraConfig struct {
	AppID          string
	AppCertificate string
}

// TokenInput RTC token 生成参数。
type TokenInput struct {
	ChannelName string
	UserAccount string
	Role        uint8
}

// TokenResult RTC token 生成结果。
type TokenResult struct {
	Token string
	AppID string
}

const rtcTokenExpireSeconds = uint32(86400)

// BuildRtcToken 生成 Agora RTC token。
func BuildRtcToken(cfg AgoraConfig, in TokenInput) (TokenResult, error) {
	if cfg.AppID == "" || cfg.AppCertificate == "" {
		return TokenResult{}, errors.New("Agora AppId/Certificate not configured")
	}
	if in.UserAccount == "" {
		return TokenResult{}, errors.New("User not logged in or userId not found in context")
	}

	role := rtctokenbuilder.RolePublisher
	if in.Role == 2 {
		role = rtctokenbuilder.RoleSubscriber
	}

	token, err := rtctokenbuilder.BuildTokenWithAccount(
		cfg.AppID, cfg.AppCertificate, in.ChannelName, in.UserAccount, rtctokenbuilder.Role(role), rtcTokenExpireSeconds,
	)
	if err != nil {
		return TokenResult{}, err
	}
	return TokenResult{Token: token, AppID: cfg.AppID}, nil
}
