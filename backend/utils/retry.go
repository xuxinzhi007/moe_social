package utils

import (
	"net/http"
	"time"
)

// RetryConfig 重试配置
type RetryConfig struct {
	MaxRetries    int
	InitialDelay  time.Duration
	MaxDelay      time.Duration
	BackoffFactor float64
	RetryableStatusCodes []int
}

// DefaultRetryConfig 默认重试配置
var DefaultRetryConfig = RetryConfig{
	MaxRetries:    3,
	InitialDelay:  500 * time.Millisecond,
	MaxDelay:      5 * time.Second,
	BackoffFactor: 2.0,
	RetryableStatusCodes: []int{
		http.StatusRequestTimeout,
		http.StatusTooEarly,
		http.StatusTooManyRequests,
		http.StatusInternalServerError,
		http.StatusServiceUnavailable,
		http.StatusGatewayTimeout,
	},
}

// IsRetryableStatus 检查状态码是否可重试
func IsRetryableStatus(statusCode int) bool {
	for _, code := range DefaultRetryConfig.RetryableStatusCodes {
		if code == statusCode {
			return true
		}
	}
	return false
}
