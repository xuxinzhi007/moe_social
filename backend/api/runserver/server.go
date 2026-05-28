//go:build !hybrid

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

// Start 纯 Kratos 构建不支持 go-zero rest；请用 StartWithResult(WireOnly=true)。
func Start(opts Options) (any, error) {
	return nil, fmt.Errorf("go-zero HTTP removed in default build; use make moe-social or build with -tags hybrid")
}

// StartWithResult 装配 ServiceContext（wire-only，供 Kratos HTTP 注册）。
func StartWithResult(opts Options) (*StartResult, error) {
	if !opts.WireOnly {
		return nil, fmt.Errorf("P5-D: non-wire API start requires -tags hybrid")
	}
	c, ctx, err := wireServiceContext(opts)
	if err != nil {
		return nil, err
	}
	LogEffectiveConfig(&c)
	log.Print("moe api: wire-only (pure Kratos HTTP, no go-zero rest)")
	return &StartResult{Server: nil, Svc: ctx, Host: c.Host, Port: c.Port}, nil
}
