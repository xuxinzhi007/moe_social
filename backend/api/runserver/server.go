package runserver

import (
	"fmt"
	"log"
	"net/http"

	"backend/api/internal/config"
	"backend/api/internal/handler"
	"backend/api/internal/moeadmingw"
	"backend/api/internal/svc"
	"backend/api/internal/usergw"
	"backend/api/internal/vipadmingw"
	"backend/internal/platform/moewiring"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"
)

// Options API 启动选项。
type Options struct {
	ConfigFile string
}

// Start 装配 ServiceContext、MoeGW 并注册 HTTP 路由。
func Start(opts Options) (*rest.Server, error) {
	var c config.Config
	conf.MustLoad(opts.ConfigFile, &c)
	ApplyUnifiedConfigOverrides(&c)
	if err := utils.ConfigureJWT(c.Auth.AccessSecret, c.Auth.AccessExpire); err != nil {
		return nil, fmt.Errorf("JWT 配置无效: %w（请在 backend/config/config.yaml 设置 auth.access_secret）", err)
	}

	server := rest.MustNewServer(c.RestConf, rest.WithCustomCors(
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

	ctx := svc.NewServiceContext(c)
	if moewiring.APIInProcessEnabled() {
		adm, err := moewiring.NewAPIAdminService(ctx.SuperRpcClient)
		if err != nil {
			log.Printf("moe api_in_process: init failed, fallback to RPC only: %v", err)
		} else if adm != nil {
			ctx.MoeAdmin = adm
			log.Print("moe api_in_process: enabled (Admin Moe HTTP uses in-process MoeAdmin)")
		}
	}
	ctx.MoeGW = moeadmingw.NewConfigured(ctx.MoeAdmin, ctx.MoeGRPC, ctx.SuperRpcClient)
	log.Printf("moe admin gateway route: %s", ctx.MoeGW.Route())
	if moewiring.VIPAPIInProcessEnabled() {
		vipAdm, err := moewiring.NewAPIVipAdminService()
		if err != nil {
			log.Printf("vip api_in_process: init failed, fallback to RPC only: %v", err)
		} else if vipAdm != nil {
			ctx.VipAdmin = vipAdm
			log.Print("vip api_in_process: enabled (VIP plan HTTP uses in-process biz)")
		}
	}
	if moewiring.UserAPIInProcessEnabled() {
		userApp, err := moewiring.NewAPIUserService()
		if err != nil {
			log.Printf("user api_in_process: init failed, fallback to RPC only: %v", err)
		} else if userApp != nil {
			ctx.UserApp = userApp
			log.Print("user api_in_process: enabled (User auth/profile/vip HTTP uses in-process biz)")
		}
	}
	ctx.UserGW = usergw.New(ctx.UserApp, ctx.SuperRpcClient)
	log.Printf("user gateway route: %s", ctx.UserGW.Route())
	ctx.VipGW = vipadmingw.New(ctx.VipAdmin, ctx.SuperRpcClient)
	log.Printf("vip gateway route: %s", ctx.VipGW.Route())
	if moewiring.KratosAdminHTTPEnabled() {
		log.Printf("moe kratos admin http: enabled → %s (ListRuntimes, GetBrainPipeline)", moewiring.KratosAdminBaseURL())
	}
	handler.RegisterHandlers(server, ctx)

	LogEffectiveConfig(&c)
	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	return server, nil
}
