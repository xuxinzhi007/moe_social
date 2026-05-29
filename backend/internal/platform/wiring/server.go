package runserver

import (
	"fmt"
	"log"
)

// Options API 启动选项。
type Options struct {
	ConfigFile       string
	InternalHTTPHost string
	InternalHTTPPort int
	WireOnly         bool // 生产纯 Kratos 必须为 true
}

// Start 已废弃；请用 StartWithResult(WireOnly=true) 或 make moe-social。
func Start(opts Options) (any, error) {
	return nil, fmt.Errorf("legacy API HTTP removed; use make moe-social")
}

// StartWithResult 装配 ServiceContext（wire-only，供 Kratos HTTP 注册）。
func StartWithResult(opts Options) (*StartResult, error) {
	if !opts.WireOnly {
		return nil, fmt.Errorf("API start requires WireOnly=true (pure Kratos HTTP)")
	}
	c, ctx, err := wireServiceContext(opts)
	if err != nil {
		return nil, err
	}
	LogEffectiveConfig(&c)
	log.Print("moe api: wire-only (Kratos HTTP)")
	return &StartResult{Server: nil, Svc: ctx, Host: c.Host, Port: c.Port}, nil
}
