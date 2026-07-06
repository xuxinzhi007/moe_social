package runserver

import (
	"fmt"

	"backend/internal/apilegacy/config"
	"backend/internal/platform/svc"
	"backend/internal/platform/yamlconf"
	"backend/utils"
)

// wireServiceContext assembles ServiceContext and domain app services for pure Kratos HTTP.
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
		return c, nil, fmt.Errorf("JWT configuration invalid: %w", err)
	}

	rep := newWireReporter()
	ctx := svc.NewServiceContext(c)
	wirePlatformServices(ctx, ImageConfig{
		LocalDir:      c.Image.LocalDir,
		PublicBaseUrl: c.Image.PublicBaseUrl,
	})
	wireAccessServices(rep, ctx)
	wireCommunityServices(rep, ctx)
	wireAIServices(rep, ctx)
	wireGameServices(rep, ctx)
	wireLifeServices(rep, ctx)
	ctx.SyncDomains()
	reportWiredDomains(rep, ctx)
	wireKratosNotes(rep)
	logWireSummary(rep, &c)
	return c, ctx, nil
}

func reportWiredDomains(rep *wireReporter, ctx *svc.ServiceContext) {
	if rep == nil || ctx == nil {
		return
	}
	reportAppDomain(rep, "vip", ctx.Domains.Access.VipAdmin)
	reportAppDomain(rep, "user", ctx.Domains.Access.UserApp)
	reportAppDomain(rep, "landing", ctx.Domains.Access.LandingApp)
	reportAppDomain(rep, "admin", ctx.Domains.Access.AdminApp)
	reportAppDomain(rep, "ai", ctx.Domains.AI.AIApp)
	reportAppDomain(rep, "behavior", ctx.Domains.Community.BehaviorApp)
	reportAppDomain(rep, "post", ctx.Domains.Community.PostApp)
	reportAppDomain(rep, "comment", ctx.Domains.Community.CommentApp)
	reportAppDomain(rep, "checkin", ctx.Domains.Community.CheckInApp)
	reportAppDomain(rep, "achievement", ctx.Domains.Community.AchievementApp)
	reportAppDomain(rep, "gift", ctx.Domains.Community.GiftApp)
	reportAppDomain(rep, "game", ctx.Domains.Game.GameApp)
	reportAppDomain(rep, "life", ctx.Domains.Life.LifeApp)
	reportAppDomain(rep, "llm", ctx.Domains.AI.LLMApp)
	reportAppDomain(rep, "media", ctx.Domains.Platform.MediaApp)
	reportAppDomain(rep, "moe", ctx.Domains.Access.MoeAdmin)
	reportAppDomain(rep, "chat", ctx.Domains.Community.ChatApp)
	reportAppDomain(rep, "notify", ctx.Domains.Community.NotifyApp)
	reportAppDomain(rep, "community", ctx.Domains.Community.CommunityApp)
}

func reportAppDomain(rep *wireReporter, name string, app any) {
	if app != nil {
		rep.domain(name, "in_process")
		return
	}
	rep.domain(name, "none")
}
