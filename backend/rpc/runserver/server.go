//go:build hybrid

package runserver

import (
	"context"
	"fmt"

	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/svc"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/zrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// Start 启动 zrpc（Super + MoeAdmin gRPC），返回 server、ServiceContext 与可选 Monitor。
func Start(opts Options) (*zrpc.RpcServer, *svc.ServiceContext, *debug.Monitor, error) {
	var c config.Config
	conf.MustLoad(opts.ConfigFile, &c)
	ApplyUnifiedConfigOverrides(&c)
	ctx := svc.NewServiceContext(c, opts.Migrate)
	bootstrap.RegisterSocialAchievementHooks()

	s := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
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
