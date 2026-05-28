//go:build hybrid

package runserver

import (
	"fmt"
	"log"
	"net/http"

	"backend/api/internal/handler"

	"github.com/zeromicro/go-zero/rest"
)

// Start 装配 ServiceContext 并启动 go-zero rest（紧急回滚）。
func Start(opts Options) (*rest.Server, error) {
	res, err := StartWithResult(opts)
	if err != nil {
		return nil, err
	}
	srv, _ := res.Server.(*rest.Server)
	return srv, nil
}

// StartWithResult hybrid：可选创建 go-zero rest 并注册 handler 路由。
func StartWithResult(opts Options) (*StartResult, error) {
	c, ctx, err := wireServiceContext(opts)
	if err != nil {
		return nil, err
	}

	var server *rest.Server
	if !opts.WireOnly {
		server = rest.MustNewServer(rest.RestConf{
			Name:    c.Name,
			Host:    c.Host,
			Port:    c.Port,
			Timeout: c.Timeout,
		}, rest.WithCustomCors(
			func(header http.Header) {
				header.Set("Access-Control-Allow-Origin", "*")
				header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
				header.Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Admin-Token, X-Requested-With, Accept, Range")
				header.Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges, X-Model-Sha256")
				header.Set("Access-Control-Max-Age", "3600")
			},
			nil,
			"*",
		))
		handler.RegisterHandlers(server, ctx)
	}

	LogEffectiveConfig(&c)
	if opts.WireOnly {
		log.Print("moe api: wire-only (hybrid build)")
		return &StartResult{Server: nil, Svc: ctx, Host: c.Host, Port: c.Port}, nil
	}
	fmt.Printf("Starting hybrid go-zero server at %s:%d...\n", c.Host, c.Port)
	return &StartResult{Server: server, Svc: ctx, Host: c.Host, Port: c.Port}, nil
}
