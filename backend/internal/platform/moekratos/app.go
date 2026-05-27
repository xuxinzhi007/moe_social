package moekratos

import (
	"log"

	moepb "backend/api/moe/v1"
	"backend/api/moekratospilot"
	moeconfv1 "backend/internal/conf/moe/v1"
	moegrpcserver "backend/internal/server/moegrpc"
	"backend/internal/server/moekratoshttp"
	moeadmin "backend/internal/service/moe"

	"github.com/go-kratos/kratos/v2"
	"github.com/go-kratos/kratos/v2/transport/grpc"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"gorm.io/gorm"
)

// App 纯 Kratos 试点装配结果（Wire 输出）。
type App struct {
	Bootstrap *moeconfv1.Bootstrap
	Admin     *moeadmin.AdminService
	GRPC      *grpc.Server
	HTTP      *khttp.Server
	Kratos    *kratos.App
	GRPCAddr  string
	HTTPAddr  string
	SuperRPC  string
}

// newApp 组装 Kratos App（由 Wire 或 fallback 调用）。
func newApp(
	bootstrap *moeconfv1.Bootstrap,
	admin *moeadmin.AdminService,
	grpcAddr, httpAddr, superRPC string,
	db *gorm.DB,
) *App {
	moeGRPC := moegrpcserver.New(admin)
	grpcSrv := grpc.NewServer(grpc.Address(grpcAddr))
	moepb.RegisterMoeAdminServer(grpcSrv, moeGRPC)

	httpSrv := khttp.NewServer(khttp.Address(httpAddr))
	moekratoshttp.Register(httpSrv, admin)
	moekratospilot.RegisterAdminCompat(httpSrv, admin)
	if bootstrap != nil && bootstrap.GetVip() != nil && bootstrap.GetVip().GetAdminReadEnabled() {
		moekratospilot.RegisterVipCompat(httpSrv, db)
	}

	kratosApp := kratos.New(
		kratos.Name("moe-kratos"),
		kratos.Server(grpcSrv, httpSrv),
	)

	return &App{
		Bootstrap: bootstrap,
		Admin:     admin,
		GRPC:      grpcSrv,
		HTTP:      httpSrv,
		Kratos:    kratosApp,
		GRPCAddr:  grpcAddr,
		HTTPAddr:  httpAddr,
		SuperRPC:  superRPC,
	}
}

func (a *App) logStartup(grpcAddr, httpAddr, superRPC string) {
	log.Printf("moe-kratos (pure kratos, 100%% pilot): gRPC %s, HTTP %s (dev only)", grpcAddr, httpAddr)
	log.Printf("moe-kratos: production external HTTP remains :8888 via make moe-social")
	if a.Bootstrap != nil && a.Bootstrap.GetProduction() != nil {
		p := a.Bootstrap.GetProduction()
		log.Printf("moe-kratos: unified_entry=%s external_http=%s internal_grpc=%s",
			p.GetUnifiedEntry(), p.GetExternalHttpPort(), p.GetInternalGrpcPort())
	}
	log.Printf("moe-kratos: config SSOT moe.conf.v1.Bootstrap (Wire DI)")
	if superRPC != "" {
		log.Printf("moe-kratos: Super RPC %s", superRPC)
	} else {
		log.Printf("moe-kratos: no super RPC; read-only Moe APIs without legacy deps")
	}
}
