package main

import (
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/server"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"flag"
	"fmt"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/zrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

// 新增模型后执行  go run super.go -migrate
var migrate = flag.Bool("migrate", false, "run GORM AutoMigrate once at startup (use after adding/changing models); omit for normal start")

func main() {
	flag.Parse()

	// 本地性能监控（仅 127.0.0.1，配合项目根目录 monitor.html）
	debug.StartMonitor("127.0.0.1:6060")

	var c config.Config
	conf.MustLoad(*configFile, &c)
	ctx := svc.NewServiceContext(c, *migrate)

	s := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
		super.RegisterSuperServer(grpcServer, server.NewSuperServer(ctx))

		if c.Mode == service.DevMode || c.Mode == service.TestMode {
			reflection.Register(grpcServer)
		}
	})
	defer s.Stop()

	fmt.Printf("Starting rpc server at %s...\n", c.ListenOn)
	s.Start()
}
