package userbiz

import "errors"

var (
	// ErrMissingAuthorization 缺少 Authorization 头。
	ErrMissingAuthorization = errors.New("missing authorization")
	// ErrInvalidAuthorizationFormat Authorization 格式错误。
	ErrInvalidAuthorizationFormat = errors.New("invalid authorization format")
	// ErrMissingToken 缺少 token。
	ErrMissingToken = errors.New("missing token")
	// ErrInvalidToken 令牌无效或已过期。
	ErrInvalidToken = errors.New("invalid token")
)
