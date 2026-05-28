package runserver

import (
	"context"
	"fmt"
	"strings"

	achievementv1 "backend/api/achievement/v1"
	chatv1 "backend/api/chat/v1"
	checkinv1 "backend/api/checkin/v1"
	commentv1 "backend/api/comment/v1"
	communityv1 "backend/api/community/v1"
	giftv1 "backend/api/gift/v1"
	landingv1 "backend/api/landing/v1"
	moepb "backend/api/moe/v1"
	notifyv1 "backend/api/notify/v1"
	postv1 "backend/api/post/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/internal/platform/moewiring"
	moegrpcserver "backend/internal/server/moegrpc"
	achievementgrpc "backend/internal/server/moegrpc/achievement"
	chatgrpc "backend/internal/server/moegrpc/chat"
	checkingrpc "backend/internal/server/moegrpc/checkin"
	commentgrpc "backend/internal/server/moegrpc/comment"
	communitygrpc "backend/internal/server/moegrpc/community"
	giftgrpc "backend/internal/server/moegrpc/gift"
	landinggrpc "backend/internal/server/moegrpc/landing"
	notifygrpc "backend/internal/server/moegrpc/notify"
	postgrpc "backend/internal/server/moegrpc/post"
	usergrpc "backend/internal/server/moegrpc/user"
	vipgrpc "backend/internal/server/moegrpc/vip"
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
	if svcCtx.LandingApp != nil {
		landingv1.RegisterLandingServer(grpcSrv, landinggrpc.New(svcCtx.LandingApp))
	}
	if svcCtx.CheckinApp != nil {
		checkinv1.RegisterCheckinServer(grpcSrv, checkingrpc.New(svcCtx.CheckinApp))
	}
	if svcCtx.AchievementApp != nil {
		achievementv1.RegisterAchievementServer(grpcSrv, achievementgrpc.New(svcCtx.AchievementApp))
	}
	if svcCtx.PostApp != nil {
		postv1.RegisterPostServiceServer(grpcSrv, postgrpc.New(svcCtx.PostApp))
	}
	if svcCtx.GiftApp != nil {
		giftv1.RegisterGiftServiceServer(grpcSrv, giftgrpc.New(svcCtx.GiftApp))
	}
	if svcCtx.UserApp != nil {
		userv1.RegisterUserServiceServer(grpcSrv, usergrpc.New(svcCtx.UserApp))
	}
	if svcCtx.CommentApp != nil {
		commentv1.RegisterCommentServiceServer(grpcSrv, commentgrpc.New(svcCtx.CommentApp))
	}
	if svcCtx.CommunityApp != nil {
		communityv1.RegisterCommunityServer(grpcSrv, communitygrpc.New(svcCtx.CommunityApp))
	}
	if svcCtx.ChatApp != nil {
		chatv1.RegisterPrivateMessageServiceServer(grpcSrv, chatgrpc.New(svcCtx.ChatApp))
	}
	if svcCtx.NotifyApp != nil {
		notifyv1.RegisterNotifyServiceServer(grpcSrv, notifygrpc.New(svcCtx.NotifyApp))
	}
	if svcCtx.UserApp != nil {
		vipv1.RegisterVipServiceServer(grpcSrv, vipgrpc.New(svcCtx.UserApp))
	}
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
