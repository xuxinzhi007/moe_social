package runserver

import (
	"fmt"
	"log"
	"net/http"

	"backend/api/internal/achievementgw"
	"backend/api/internal/admingw"
	"backend/api/internal/aigw"
	"backend/api/internal/behaviorgw"
	"backend/api/internal/chatgw"
	"backend/api/internal/checkinwg"
	"backend/api/internal/commentgw"
	"backend/api/internal/communitygw"
	"backend/api/internal/config"
	"backend/api/internal/giftgw"
	"backend/api/internal/handler"
	"backend/api/internal/landinggw"
	"backend/api/internal/llmgw"
	"backend/api/internal/moeadmingw"
	"backend/api/internal/postgw"
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
	if moewiring.LandingAPIInProcessEnabled() {
		landingApp, err := moewiring.NewAPILandingService()
		if err != nil {
			log.Printf("landing api_in_process: init failed, fallback to RPC only: %v", err)
		} else if landingApp != nil {
			ctx.LandingApp = landingApp
			log.Print("landing api_in_process: enabled (Landing HTTP uses in-process biz)")
		}
	}
	ctx.LandingGW = landinggw.New(ctx.LandingApp, ctx.SuperRpcClient)
	log.Printf("landing gateway route: %s", ctx.LandingGW.Route())
	if moewiring.AdminReadonlyAPIInProcessEnabled() {
		adminApp, err := moewiring.NewAPIAdminReadonlyService()
		if err != nil {
			log.Printf("admin readonly api_in_process: init failed, fallback to RPC only: %v", err)
		} else if adminApp != nil {
			ctx.AdminApp = adminApp
			log.Print("admin api_in_process: enabled (growth/schema/runtime/notify HTTP uses in-process biz)")
		}
	}
	ctx.AdminGW = admingw.New(ctx.AdminApp, ctx.SuperRpcClient)
	log.Printf("admin gateway route: %s", ctx.AdminGW.Route())
	if moewiring.AIAPIInProcessEnabled() {
		aiApp, err := moewiring.NewAPIAIService()
		if err != nil {
			log.Printf("ai api_in_process: init failed, fallback to RPC only: %v", err)
		} else if aiApp != nil {
			ctx.AIApp = aiApp
			log.Print("ai api_in_process: enabled (AI resources HTTP uses in-process biz)")
		}
	}
	ctx.AIGW = aigw.New(ctx.AIApp, ctx.SuperRpcClient)
	log.Printf("ai gateway route: %s", ctx.AIGW.Route())
	if moewiring.BehaviorAPIInProcessEnabled() {
		behaviorApp, err := moewiring.NewAPIBehaviorService()
		if err != nil {
			log.Printf("behavior api_in_process: init failed, fallback to RPC only: %v", err)
		} else if behaviorApp != nil {
			ctx.BehaviorApp = behaviorApp
			log.Print("behavior api_in_process: enabled (behavior HTTP uses in-process biz)")
		}
	}
	ctx.BehaviorGW = behaviorgw.New(ctx.BehaviorApp, ctx.SuperRpcClient)
	log.Printf("behavior gateway route: %s", ctx.BehaviorGW.Route())
	if moewiring.PostAPIInProcessEnabled() {
		postApp, err := moewiring.NewAPIPostService()
		if err != nil {
			log.Printf("post api_in_process: init failed, fallback to RPC only: %v", err)
		} else if postApp != nil {
			ctx.PostApp = postApp
			log.Print("post api_in_process: enabled (post HTTP uses in-process biz)")
		}
	}
	ctx.PostGW = postgw.New(ctx.PostApp, ctx.SuperRpcClient)
	log.Printf("post gateway route: %s", ctx.PostGW.Route())
	if moewiring.CommentAPIInProcessEnabled() {
		commentApp, err := moewiring.NewAPICommentService()
		if err != nil {
			log.Printf("comment api_in_process: init failed, fallback to RPC only: %v", err)
		} else if commentApp != nil {
			ctx.CommentApp = commentApp
			log.Print("comment api_in_process: enabled (comment HTTP uses in-process biz)")
		}
	}
	ctx.CommentGW = commentgw.New(ctx.CommentApp, ctx.SuperRpcClient)
	log.Printf("comment gateway route: %s", ctx.CommentGW.Route())
	if moewiring.CheckInAPIInProcessEnabled() {
		checkInApp, err := moewiring.NewAPICheckInService()
		if err != nil {
			log.Printf("checkin api_in_process: init failed, fallback to RPC only: %v", err)
		} else if checkInApp != nil {
			ctx.CheckInApp = checkInApp
			log.Print("checkin api_in_process: enabled (checkin HTTP uses in-process biz)")
		}
	}
	ctx.CheckInGW = checkinwg.New(ctx.CheckInApp, ctx.SuperRpcClient)
	log.Printf("checkin gateway route: %s", ctx.CheckInGW.Route())
	if moewiring.AchievementAPIInProcessEnabled() {
		achApp, err := moewiring.NewAPIAchievementService()
		if err != nil {
			log.Printf("achievement api_in_process: init failed, fallback to RPC only: %v", err)
		} else if achApp != nil {
			ctx.AchievementApp = achApp
			log.Print("achievement api_in_process: enabled (achievement HTTP uses in-process biz)")
		}
	}
	ctx.AchievementGW = achievementgw.New(ctx.AchievementApp, ctx.SuperRpcClient)
	log.Printf("achievement gateway route: %s", ctx.AchievementGW.Route())
	if moewiring.GiftAPIInProcessEnabled() {
		giftApp, err := moewiring.NewAPIGiftService()
		if err != nil {
			log.Printf("gift api_in_process: init failed, fallback to RPC only: %v", err)
		} else if giftApp != nil {
			ctx.GiftApp = giftApp
			log.Print("gift api_in_process: enabled (gift HTTP uses in-process biz)")
		}
	}
	ctx.GiftGW = giftgw.New(ctx.GiftApp, ctx.SuperRpcClient)
	log.Printf("gift gateway route: %s", ctx.GiftGW.Route())
	if moewiring.LLMAPIInProcessEnabled() {
		llmApp, err := moewiring.NewAPILLMService()
		if err != nil {
			log.Printf("llm api_in_process: init failed, fallback to RPC only: %v", err)
		} else if llmApp != nil {
			ctx.LLMApp = llmApp
			log.Print("llm api_in_process: enabled (LLM models/catalog/chat-turn HTTP uses in-process biz)")
		}
	}
	ctx.LLMGW = llmgw.New(ctx.LLMApp, ctx.SuperRpcClient)
	log.Printf("llm gateway route: %s", ctx.LLMGW.Route())
	if moewiring.AIAPIInProcessEnabled() {
		aiApp, err := moewiring.NewAPIAIService()
		if err != nil {
			log.Printf("ai api_in_process: init failed, fallback to RPC only: %v", err)
		} else if aiApp != nil {
			ctx.AIApp = aiApp
			log.Print("ai api_in_process: enabled (AI providers/agents/lorebooks HTTP uses in-process biz)")
		}
	}
	ctx.AIGW = aigw.New(ctx.AIApp, ctx.SuperRpcClient)
	log.Printf("ai gateway route: %s", ctx.AIGW.Route())
	if moewiring.ChatAPIInProcessEnabled() {
		chatApp, err := moewiring.NewAPIChatService()
		if err != nil {
			log.Printf("chat api_in_process: init failed, fallback to RPC only: %v", err)
		} else if chatApp != nil {
			ctx.ChatApp = chatApp
			log.Print("chat api_in_process: enabled (private message HTTP/WS uses in-process biz)")
		}
	}
	ctx.ChatGW = chatgw.New(ctx.ChatApp, ctx.SuperRpcClient)
	log.Printf("chat gateway route: %s", ctx.ChatGW.Route())
	if moewiring.CommunityAPIInProcessEnabled() {
		communityApp, err := moewiring.NewAPICommunityService()
		if err != nil {
			log.Printf("community api_in_process: init failed, fallback to RPC only: %v", err)
		} else if communityApp != nil {
			ctx.CommunityApp = communityApp
			log.Print("community api_in_process: enabled (community HTTP uses in-process biz)")
		}
	}
	ctx.CommunityGW = communitygw.New(ctx.CommunityApp, ctx.SuperRpcClient)
	log.Printf("community gateway route: %s", ctx.CommunityGW.Route())
	ctx.VipGW = vipadmingw.NewConfigured(ctx.VipAdmin, ctx.SuperRpcClient)
	log.Printf("vip gateway route: %s", ctx.VipGW.Route())
	if moewiring.KratosAdminHTTPEnabled() {
		log.Printf("moe kratos admin http: enabled → %s (ListRuntimes, GetBrainPipeline)", moewiring.KratosPilotBaseURL())
	}
	if moewiring.KratosVipHTTPEnabled() {
		log.Printf("vip kratos http: enabled → %s (ListPlans)", moewiring.KratosPilotBaseURL())
	}
	handler.RegisterHandlers(server, ctx)

	LogEffectiveConfig(&c)
	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	return server, nil
}
