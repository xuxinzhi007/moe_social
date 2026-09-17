package utils

import (
	"fmt"
	"net"
	"net/url"
	"strings"
)

// OverrideOAuthAPIBaseForTest 把供应商开放平台的根地址指向本地假服务端（httptest），
// 让「授权码 → access_token → 用户资料」这条链路能在不触网、不消耗真实授权的前提下跑通。
//
// 生产代码从不调用它。之所以只接受 loopback 地址：这个函数能改写整条 OAuth 出网
// 目标，如果不加限制，一次误用就能把用户的授权码送到任意主机上 —— 那正是 #50 要
// 修的漏洞本身。限制成 127.0.0.1/[::1] 后，它最多只能把流量导向本机。
//
// 返回的 restore 必须 defer 调用。改写的是包级变量，调用方不得 t.Parallel()。
func OverrideOAuthAPIBaseForTest(provider, base string) (restore func(), err error) {
	base = strings.TrimRight(strings.TrimSpace(base), "/")
	if base == "" {
		return nil, fmt.Errorf("override base is empty")
	}
	parsed, err := url.Parse(base)
	if err != nil {
		return nil, fmt.Errorf("override base %q is not a valid URL: %w", base, err)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, fmt.Errorf("override base %q must be http(s)", base)
	}
	host := parsed.Hostname()
	if ip := net.ParseIP(host); ip == nil || !ip.IsLoopback() {
		return nil, fmt.Errorf("override base %q must point at a loopback address", base)
	}

	switch provider {
	case "feishu":
		prev := feishuAPIBase
		feishuAPIBase = base
		return func() { feishuAPIBase = prev }, nil
	case "wechat":
		prev := wechatAPIBase
		wechatAPIBase = base
		return func() { wechatAPIBase = prev }, nil
	default:
		return nil, fmt.Errorf("unknown provider %q", provider)
	}
}
