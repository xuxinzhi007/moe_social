package errorcode

// HTTP 状态码常量
const (
	// 成功
	E_SUCCESS = 200

	// 客户端错误
	E_INVALID_PARAM = 400 // 无效参数
	E_UNAUTHORIZED  = 401 // 未授权
	E_FORBIDDEN     = 403 // 禁止访问
	E_NOT_FOUND     = 404 // 资源不存在
	E_CONFLICT      = 409 // 冲突

	// 服务器错误
	E_INTERNAL_ERROR      = 500 // 内部错误
	E_SERVICE_UNAVAILABLE = 503 // 服务不可用
)

// 业务错误码常量
const (
	// 用户相关错误
	E_USER_NOT_EXIST      = 1001 // 用户不存在
	E_PASSWORD_ERROR      = 1002 // 密码错误
	E_EMAIL_EXIST         = 1003 // 邮箱已存在
	E_MOE_NO_EXIST        = 1004 // Moe 号已存在
	E_TOKEN_EXPIRED       = 1005 // 令牌过期
	E_INSUFFICIENT_BALANCE = 1006 // 余额不足

	// 群组相关错误
	E_GROUP_NOT_EXIST     = 2001 // 群组不存在
	E_GROUP_MEMBER_EXIST  = 2002 // 成员已存在
	E_GROUP_CREATE_FAILED = 2003 // 创建群组失败
	E_GROUP_JOIN_FAILED   = 2004 // 加入群组失败
	E_GROUP_LEAVE_FAILED  = 2005 // 退出群组失败

	// 礼物相关错误
	E_GIFT_NOT_EXIST      = 3001 // 礼物不存在
	E_GIFT_SEND_FAILED    = 3002 // 发送礼物失败

	// 帖子相关错误
	E_POST_NOT_EXIST      = 4001 // 帖子不存在
	E_POST_CREATE_FAILED  = 4002 // 创建帖子失败

	// 系统相关错误
	E_SYSTEM_ERROR        = 9000 // 系统错误
)

// 错误码映射到错误信息
var errorMessages = map[int]string{
	// HTTP 状态码
	E_SUCCESS:             "操作成功",
	E_INVALID_PARAM:       "参数无效",
	E_UNAUTHORIZED:        "未授权，请重新登录",
	E_FORBIDDEN:           "权限不足",
	E_NOT_FOUND:           "资源不存在",
	E_CONFLICT:            "资源冲突",
	E_INTERNAL_ERROR:      "服务器内部错误",
	E_SERVICE_UNAVAILABLE: "服务暂时不可用",

	// 业务错误码
	E_USER_NOT_EXIST:      "用户不存在",
	E_PASSWORD_ERROR:      "密码错误",
	E_EMAIL_EXIST:         "邮箱已被注册",
	E_MOE_NO_EXIST:        "Moe 号已被使用",
	E_TOKEN_EXPIRED:       "登录已过期，请重新登录",
	E_INSUFFICIENT_BALANCE: "余额不足",

	E_GROUP_NOT_EXIST:     "群组不存在",
	E_GROUP_MEMBER_EXIST:  "您已经是群组成员",
	E_GROUP_CREATE_FAILED: "创建群组失败",
	E_GROUP_JOIN_FAILED:   "加入群组失败",
	E_GROUP_LEAVE_FAILED:  "退出群组失败",

	E_GIFT_NOT_EXIST:      "礼物不存在",
	E_GIFT_SEND_FAILED:    "发送礼物失败",

	E_POST_NOT_EXIST:      "帖子不存在",
	E_POST_CREATE_FAILED:  "创建帖子失败",

	E_SYSTEM_ERROR:        "系统错误",
}

// GetErrorMessage 根据错误码获取错误信息
func GetErrorMessage(code int) string {
	if msg, ok := errorMessages[code]; ok {
		return msg
	}
	return "未知错误"
}

// IsBusinessError 判断是否为业务错误
func IsBusinessError(code int) bool {
	return code >= 1000 && code < 9999
}

// IsSystemError 判断是否为系统错误
func IsSystemError(code int) bool {
	return code >= 500
}

// IsClientError 判断是否为客户端错误
func IsClientError(code int) bool {
	return code >= 400 && code < 500
}

// IsSuccess 判断是否为成功
func IsSuccess(code int) bool {
	return code == E_SUCCESS
}
