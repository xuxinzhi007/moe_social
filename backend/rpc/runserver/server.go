package runserver

import (
	"context"
	"fmt"

	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/server"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/zrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// Options RPC 启动选项。
type Options struct {
	ConfigFile    string
	Migrate       utils.MigrateOptions
	EnableMonitor bool // 本地 :19011 pprof / JSON stats（moe-admin RPC 监控）
}

// Start 启动 zrpc（Super + MoeAdmin gRPC），返回 server、ServiceContext 与可选 Monitor。
func Start(opts Options) (*zrpc.RpcServer, *svc.ServiceContext, *debug.Monitor, error) {
	var c config.Config
	conf.MustLoad(opts.ConfigFile, &c)
	ctx := svc.NewServiceContext(c, opts.Migrate)
	bootstrap.RegisterSocialAchievementHooks()

	s := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
		super.RegisterSuperServer(grpcServer, server.NewSuperServer(ctx))
		bootstrap.RegisterMoeGRPC(grpcServer, ctx)
		if c.Mode == service.DevMode || c.Mode == service.TestMode {
			reflection.Register(grpcServer)
		}
	})

	bootstrap.WireMoeAdmin(ctx)
	bootstrap.StartMoeBotScheduler(context.Background(), ctx)

	var mon *debug.Monitor
	if opts.EnableMonitor {
		mon = debug.StartMonitor("")
	}

	fmt.Printf("Starting rpc server at %s...\n", c.ListenOn)
	return s, ctx, mon, nil
}
