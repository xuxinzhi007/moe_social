package runserver

import (
	"context"
	"fmt"

	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
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
	ConfigFile string
	Migrate    utils.MigrateOptions
}

// Start 启动 zrpc（Super + MoeAdmin gRPC），返回 server 与 ServiceContext（须 WireMoeAdmin 后使用）。
func Start(opts Options) (*zrpc.RpcServer, *svc.ServiceContext, error) {
	var c config.Config
	conf.MustLoad(opts.ConfigFile, &c)
	ctx := svc.NewServiceContext(c, opts.Migrate)

	s := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
		super.RegisterSuperServer(grpcServer, server.NewSuperServer(ctx))
		bootstrap.RegisterMoeGRPC(grpcServer, ctx)
		if c.Mode == service.DevMode || c.Mode == service.TestMode {
			reflection.Register(grpcServer)
		}
	})

	bootstrap.WireMoeAdmin(ctx)
	bootstrap.StartMoeBotScheduler(context.Background(), ctx)

	fmt.Printf("Starting rpc server at %s...\n", c.ListenOn)
	return s, ctx, nil
}
