// Package appcfgapp 客户端公网配置应用服务。
package appcfgapp

import (
	appcfgbiz "backend/internal/biz/appcfg"
)

// ErrNoPublicAPIBaseURL 未配置客户端公网 API 基址。
var ErrNoPublicAPIBaseURL = appcfgbiz.ErrNoPublicAPIBaseURL

// AppService 客户端公网配置。
type AppService struct {
	publicAPIBaseURL string
}

// New 构造 AppService。
func New(publicAPIBaseURL string) *AppService {
	return &AppService{publicAPIBaseURL: publicAPIBaseURL}
}

// PublicClientConfig 返回规范化后的公网 API 基址。
func (s *AppService) PublicClientConfig() (string, error) {
	if s == nil {
		return "", ErrNoPublicAPIBaseURL
	}
	return appcfgbiz.NormalizePublicAPIBaseURL(s.publicAPIBaseURL)
}
