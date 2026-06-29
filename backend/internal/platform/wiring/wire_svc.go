package runserver

import (
	"fmt"

	"backend/internal/apilegacy/config"
	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
	"backend/internal/platform/yamlconf"
	mediaapp "backend/internal/service/media"
	"backend/utils"
)

// wireServiceContext 装配 ServiceContext 与各域 App 服务（无 go-zero HTTP）。
func wireServiceContext(opts Options) (config.Config, *svc.ServiceContext, error) {
	var c config.Config
	yamlconf.MustLoad(opts.ConfigFile, &c)
	if opts.InternalHTTPPort > 0 {
		c.Host = opts.InternalHTTPHost
		if c.Host == "" {
			c.Host = "127.0.0.1"
		}
		c.Port = opts.InternalHTTPPort
	}
	ApplyUnifiedConfigOverrides(&c)
	if err := utils.ConfigureJWT(c.Auth.AccessSecret, c.Auth.AccessExpire); err != nil {
		return c, nil, fmt.Errorf("JWT 配置无效: %w（请在 backend/config/config.yaml 设置 auth.access_secret）", err)
	}

	rep := newWireReporter()
	ctx := svc.NewServiceContext(c)
	ctx.MediaApp = mediaapp.New(mediabiz.ImageConfig{
		LocalDir:      c.Image.LocalDir,
		PublicBaseURL: c.Image.PublicBaseUrl,
	})

	if moewiring.VIPAPIInProcessEnabled() {
		vipAdm, err := moewiring.NewAPIVipAdminService()
		if err != nil {
			rep.domainWarn("vip", "db", err.Error())
		} else if vipAdm != nil {
			ctx.VipAdmin = vipAdm
		}
	}

	if moewiring.UserAPIInProcessEnabled() {
		userApp, err := moewiring.NewAPIUserService()
		if err != nil {
			rep.domainWarn("user", "db", err.Error())
		} else if userApp != nil {
			ctx.UserApp = userApp
		}
	}

	if moewiring.LandingAPIInProcessEnabled() {
		landingApp, err := moewiring.NewAPILandingService()
		if err != nil {
			rep.domainWarn("landing", "db", err.Error())
		} else if landingApp != nil {
			ctx.LandingApp = landingApp
		}
	}

	if moewiring.AdminReadonlyAPIInProcessEnabled() {
		adminApp, err := moewiring.NewAPIAdminReadonlyService()
		if err != nil {
			rep.domainWarn("admin", "db", err.Error())
		} else if adminApp != nil {
			ctx.AdminApp = adminApp
		}
	}
	if moewiring.KratosAdminInsightsHTTPEnabled() {
		rep.note(fmt.Sprintf("admin insights → %s", moewiring.KratosPilotBaseURL()))
	}

	if moewiring.AIAPIInProcessEnabled() {
		aiApp, err := moewiring.NewAPIAIService()
		if err != nil {
			rep.domainWarn("ai", "db", err.Error())
		} else if aiApp != nil {
			ctx.AIApp = aiApp
		}
	}

	if moewiring.BehaviorAPIInProcessEnabled() {
		behaviorApp, err := moewiring.NewAPIBehaviorService()
		if err != nil {
			rep.domainWarn("behavior", "db", err.Error())
		} else if behaviorApp != nil {
			ctx.BehaviorApp = behaviorApp
		}
	}

	if moewiring.PostAPIInProcessEnabled() {
		postApp, err := moewiring.NewAPIPostService()
		if err != nil {
			rep.domainWarn("post", "db", err.Error())
		} else if postApp != nil {
			ctx.PostApp = postApp
		}
	}

	if moewiring.CommentAPIInProcessEnabled() {
		commentApp, err := moewiring.NewAPICommentService()
		if err != nil {
			rep.domainWarn("comment", "db", err.Error())
		} else if commentApp != nil {
			ctx.CommentApp = commentApp
		}
	}

	if moewiring.CheckInAPIInProcessEnabled() {
		checkInApp, err := moewiring.NewAPICheckInService()
		if err != nil {
			rep.domainWarn("checkin", "db", err.Error())
		} else if checkInApp != nil {
			ctx.CheckInApp = checkInApp
		}
	}

	if moewiring.AchievementAPIInProcessEnabled() {
		achApp, err := moewiring.NewAPIAchievementService()
		if err != nil {
			rep.domainWarn("achievement", "db", err.Error())
		} else if achApp != nil {
			ctx.AchievementApp = achApp
		}
	}

	if moewiring.GiftAPIInProcessEnabled() {
		giftApp, err := moewiring.NewAPIGiftService()
		if err != nil {
			rep.domainWarn("gift", "db", err.Error())
		} else if giftApp != nil {
			ctx.GiftApp = giftApp
		}
	}

	if moewiring.LLMAPIInProcessEnabled() {
		llmApp, err := moewiring.NewAPILLMService()
		if err != nil {
			rep.domainWarn("llm", "db", err.Error())
		} else if llmApp != nil {
			ctx.LLMApp = llmApp
		}
	}

	if moewiring.APIInProcessEnabled() {
		appPort := moewiring.NewAppAdapter(ctx.PostApp, ctx.LLMApp)
		adm, err := moewiring.NewAPIAdminService(appPort)
		if err != nil {
			rep.domainWarn("moe", "db", err.Error())
		} else if adm != nil {
			ctx.MoeAdmin = adm
		}
	}

	if moewiring.ChatAPIInProcessEnabled() {
		chatApp, err := moewiring.NewAPIChatService()
		if err != nil {
			rep.domainWarn("chat", "db", err.Error())
		} else if chatApp != nil {
			ctx.ChatApp = chatApp
		}
	}

	if moewiring.NotifyAPIInProcessEnabled() {
		notifyApp, err := moewiring.NewAPINotifyService()
		if err != nil {
			rep.domainWarn("notify", "none", err.Error())
		} else if notifyApp != nil {
			ctx.NotifyApp = notifyApp
		}
	}

	if moewiring.CommunityAPIInProcessEnabled() {
		communityApp, err := moewiring.NewAPICommunityService()
		if err != nil {
			rep.domainWarn("community", "db", err.Error())
		} else if communityApp != nil {
			ctx.CommunityApp = communityApp
		}
	}

	reportAppDomain(rep, "vip", ctx.VipAdmin)
	reportAppDomain(rep, "user", ctx.UserApp)
	reportAppDomain(rep, "landing", ctx.LandingApp)
	reportAppDomain(rep, "admin", ctx.AdminApp)
	reportAppDomain(rep, "ai", ctx.AIApp)
	reportAppDomain(rep, "behavior", ctx.BehaviorApp)
	reportAppDomain(rep, "post", ctx.PostApp)
	reportAppDomain(rep, "comment", ctx.CommentApp)
	reportAppDomain(rep, "checkin", ctx.CheckInApp)
	reportAppDomain(rep, "achievement", ctx.AchievementApp)
	reportAppDomain(rep, "gift", ctx.GiftApp)
	reportAppDomain(rep, "llm", ctx.LLMApp)
	reportAppDomain(rep, "media", ctx.MediaApp)
	reportAppDomain(rep, "moe", ctx.MoeAdmin)
	reportAppDomain(rep, "chat", ctx.ChatApp)
	reportAppDomain(rep, "notify", ctx.NotifyApp)
	reportAppDomain(rep, "community", ctx.CommunityApp)

	if moewiring.KratosAdminHTTPEnabled() {
		rep.note(fmt.Sprintf("moe admin kratos http → %s", moewiring.KratosPilotBaseURL()))
	}
	if moewiring.KratosVipHTTPEnabled() {
		rep.note(fmt.Sprintf("vip kratos http → %s", moewiring.KratosPilotBaseURL()))
	}

	logWireSummary(rep, &c)
	return c, ctx, nil
}

func reportAppDomain(rep *wireReporter, name string, app any) {
	if app != nil {
		rep.domain(name, "in_process")
		return
	}
	rep.domain(name, "none")
}
