package runserver

import (
	"context"
	"fmt"
	"strings"

	"backend/internal/platform/moewiring"
	"backend/internal/server"
	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/svc"

	"backend/internal/platform/yamlconf"
	"github.com/go-kratos/kratos/v2/transport/grpc"
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
	yamlconf.MustLoad(opts.ConfigFile, &c)
	ApplyUnifiedConfigOverrides(&c)
	svcCtx := svc.NewServiceContext(c, opts.Migrate)
	bootstrap.RegisterSocialAchievementHooks()

	addr := normalizeListenAddr(c.ListenOn, "8080")
	grpcSrv := grpc.NewServer(grpc.Address(addr))
	server.RegisterSocialGRPC(grpcSrv, socialGRPCDepsFromRPC(svcCtx, c))
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

func socialGRPCDepsFromRPC(svcCtx *svc.ServiceContext, c config.Config) server.SocialGRPCDeps {
	if svcCtx == nil {
		return server.SocialGRPCDeps{}
	}
	return server.SocialGRPCDeps{
		LandingApp:       svcCtx.LandingApp,
		CheckinApp:       svcCtx.CheckinApp,
		AchievementApp:   svcCtx.AchievementApp,
		PostApp:          svcCtx.PostApp,
		GiftApp:          svcCtx.GiftApp,
		UserApp:          svcCtx.UserApp,
		CommentApp:       svcCtx.CommentApp,
		CommunityApp:     svcCtx.CommunityApp,
		ChatApp:          svcCtx.ChatApp,
		NotifyApp:        svcCtx.NotifyApp,
		MoeAdmin:         svcCtx.MoeAdmin,
		RegisterMoeAdmin: moewiring.RegisterMoeGRPCEnabled(),
		EnableReflection: c.DevOrTest(),
	}
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
