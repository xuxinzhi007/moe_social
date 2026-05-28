package runserver

import (
	"context"
	"fmt"
	"strings"

	moepb "backend/api/moe/v1"
	moegrpcserver "backend/internal/server/moegrpc"
	"backend/internal/platform/moewiring"
	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/server"
	"backend/rpc/internal/svc"
	moerpc "backend/rpc/pb/moe"

	"github.com/go-kratos/kratos/v2/transport/grpc"
	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	googlegrpc "google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// KratosStartResult PK-11：Kratos gRPC 启动结果（无 zrpc）。
type KratosStartResult struct {
	Server *grpc.Server
	Svc    *svc.ServiceContext
	Addr   string
	Mode   string
}

// StartKratos 使用 kratos/transport/grpc 监听（Super + MoeAdmin）。
func StartKratos(opts Options) (*KratosStartResult, *debug.Monitor, error) {
	var c config.Config
	conf.MustLoad(opts.ConfigFile, &c)
	ApplyUnifiedConfigOverrides(&c)
	svcCtx := svc.NewServiceContext(c, opts.Migrate)
	bootstrap.RegisterSocialAchievementHooks()

	addr := normalizeListenAddr(c.ListenOn, "8080")
	grpcSrv := grpc.NewServer(grpc.Address(addr))
	registerKratosGRPCServices(grpcSrv, svcCtx, c.Mode)
	bootstrap.WireMoeAdmin(svcCtx)
	bootstrap.StartMoeBotScheduler(context.Background(), svcCtx)

	var mon *debug.Monitor
	if opts.EnableMonitor {
		mon = debug.StartMonitor("")
	}

	fmt.Printf("Starting kratos grpc server at %s...\n", c.ListenOn)
	return &KratosStartResult{
		Server: grpcSrv,
		Svc:    svcCtx,
		Addr:   addr,
		Mode:   c.Mode,
	}, mon, nil
}

func normalizeListenAddr(host, defaultPort string) string {
	host = strings.TrimSpace(host)
	if host == "" {
		return "0.0.0.0:" + defaultPort
	}
	if strings.HasPrefix(host, ":") {
		return "0.0.0.0" + host
	}
	if strings.Contains(host, ":") {
		return host
	}
	return host + ":" + defaultPort
}

func registerKratosGRPCServices(grpcSrv *grpc.Server, svcCtx *svc.ServiceContext, mode string) {
	if grpcSrv == nil || svcCtx == nil {
		return
	}
	moerpc.RegisterSuperServer(grpcSrv, server.NewSuperServer(svcCtx))
	if moewiring.RegisterMoeGRPCEnabled() && svcCtx.MoeAdmin != nil {
		moepb.RegisterMoeAdminServer(grpcSrv, moegrpcserver.New(svcCtx.MoeAdmin))
	}
	if mode == service.DevMode || mode == service.TestMode {
		if underlying := kratosUnderlyingGRPC(grpcSrv); underlying != nil {
			reflection.Register(underlying)
		}
	}
}

func kratosUnderlyingGRPC(srv *grpc.Server) *googlegrpc.Server {
	if srv == nil {
		return nil
	}
	type grpcGetter interface {
		GetServer() *googlegrpc.Server
	}
	if g, ok := any(srv).(grpcGetter); ok {
		return g.GetServer()
	}
	return nil
}
