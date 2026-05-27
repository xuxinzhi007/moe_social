package aibiz

import "errors"

var (
	ErrEmptyUserID         = errors.New("user_id不能为空")
	ErrInvalidUserID       = errors.New("无效的user_id")
	ErrInvalidPayload      = errors.New("invalid payload_json")
	ErrUnknownResourceKind = errors.New("unknown AI resource kind")
	ErrEncodeResource      = errors.New("encode AI resource failed")
	ErrListPublicAgents    = errors.New("list public agents failed")
	ErrAdminListAgents     = errors.New("admin list ai agents failed")
)
