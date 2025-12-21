package main

import (
	"flag"
	"fmt"
	"net/http"

	"backend/api/internal/config"
	"backend/api/internal/handler"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)

	// 使用go-zero内置的CORS支持，允许所有来源（开发环境）
	server := rest.MustNewServer(c.RestConf, rest.WithCustomCors(
		func(header http.Header) {
			header.Set("Access-Control-Allow-Origin", "*")
			header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
			header.Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Accept")
			header.Set("Access-Control-Max-Age", "3600")
		},
		nil,
		"*",
	))
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	server.Start()
}
