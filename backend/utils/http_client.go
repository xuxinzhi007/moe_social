package utils

import (
	"net/http"
	"time"
)

// NewHTTPClient 创建一个配置了连接池和超时的HTTP客户端
func NewHTTPClient(timeoutSeconds int) *http.Client {
	if timeoutSeconds <= 0 {
		timeoutSeconds = 60
	}

	return &http.Client{
		Timeout: time.Duration(timeoutSeconds) * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
			TLSHandshakeTimeout: 10 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
		},
	}
}
