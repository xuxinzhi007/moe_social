package userbiz

import (
	"errors"
	"fmt"

	"backend/internal/oauthflow"
)

// mapOAuthFlowError 把 oauthflow 的内部错误翻成本域既有的哨兵错误。
//
// 对外文案刻意笼统：这个端点公开可达，把「state 没见过」和「state 用过了」区分开
// 等于送一个状态探测接口；把白名单内容或 challenge 期望值写进错误里更是直接给攻击者
// 递材料。客户端只需要知道「该重新发起授权了」。
func mapOAuthFlowError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, oauthflow.ErrReturnURLNotAllowed):
		return fmt.Errorf("%w: 回跳地址未被服务端信任，请联系维护者把它加进 oauth.allowed_return_urls",
			ErrInvalidArgument)
	case errors.Is(err, oauthflow.ErrInvalidChallenge),
		errors.Is(err, oauthflow.ErrInvalidVerifier),
		errors.Is(err, oauthflow.ErrChallengeMismatch),
		errors.Is(err, oauthflow.ErrUnknownFlow),
		errors.Is(err, oauthflow.ErrUnknownProvider):
		return fmt.Errorf("%w: 授权参数不合法，请更新客户端后重试", ErrInvalidArgument)
	case errors.Is(err, oauthflow.ErrProviderNotConfigured):
		return fmt.Errorf("%w: 服务端未配置该登录方式", ErrOAuthDisabled)
	case errors.Is(err, oauthflow.ErrStateUnknown),
		errors.Is(err, oauthflow.ErrTicketUnknown):
		return fmt.Errorf("%w: 授权已失效，请重新登录", ErrUnauthorized)
	case errors.Is(err, oauthflow.ErrStoreFull),
		errors.Is(err, oauthflow.ErrRandom):
		return fmt.Errorf("%w: 服务暂时无法处理登录，请稍后重试", ErrUnauthorized)
	default:
		return err
	}
}

// errLegacyOAuthCodeOnly 旧的 code-only 登录通路被明确关闭时的错误。
//
// 旧协议下 /api/auth/{feishu,wechat}/login 只要拿到供应商授权码就能换 JWT，
// 而授权码会出现在回跳 URL、浏览器历史与 Referer 里。新协议要求出示
// ticket（浏览器 flow）或 state（微信原生 flow）加 verifier，二者都由发起方本地保管。
var errLegacyOAuthCodeOnly = fmt.Errorf("%w: 登录方式已升级，请更新 App 后重试", ErrInvalidArgument)
