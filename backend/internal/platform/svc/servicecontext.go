package svc

import (
	"backend/internal/apilegacy/config"
	achievementapp "backend/internal/service/achievement"
	adminapp "backend/internal/service/admin"
	aiapp "backend/internal/service/ai"
	behaviorapp "backend/internal/service/behavior"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	gameapp "backend/internal/service/game"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	llmapp "backend/internal/service/llm"
	mediaapp "backend/internal/service/media"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"
	"backend/utils"
)

type AccessServices struct {
	MoeAdmin   *moeadmin.AdminService
	LandingApp *landingapp.AppService
	AdminApp   *adminapp.AppService
	UserApp    *userapp.AppService
	VipAdmin   *vipadmin.AdminService
}

type CommunityServices struct {
	BehaviorApp    *behaviorapp.AppService
	PostApp        *postapp.AppService
	CommentApp     *commentapp.AppService
	CommunityApp   *communityapp.AppService
	CheckInApp     *checkinapp.AppService
	AchievementApp *achievementapp.AppService
	GiftApp        *giftapp.AppService
	ChatApp        *chatapp.AppService
	NotifyApp      *notifyapp.AppService
}

type AIServices struct {
	AIApp  *aiapp.AppService
	LLMApp *llmapp.AppService
}

type GameServices struct {
	GameApp *gameapp.AppService
}

type PlatformServices struct {
	MediaApp *mediaapp.AppService
}

type ServiceDomains struct {
	Access    AccessServices
	Community CommunityServices
	AI        AIServices
	Game      GameServices
	Platform  PlatformServices
}

type ServiceContext struct {
	Config         config.Config
	Domains        ServiceDomains
	MoeAdmin       *moeadmin.AdminService
	LandingApp     *landingapp.AppService
	AdminApp       *adminapp.AppService
	AIApp          *aiapp.AppService
	BehaviorApp    *behaviorapp.AppService
	PostApp        *postapp.AppService
	CommentApp     *commentapp.AppService
	CommunityApp   *communityapp.AppService
	CheckInApp     *checkinapp.AppService
	AchievementApp *achievementapp.AppService
	GiftApp        *giftapp.AppService
	GameApp        *gameapp.AppService
	LLMApp         *llmapp.AppService
	MediaApp       *mediaapp.AppService
	ChatApp        *chatapp.AppService
	NotifyApp      *notifyapp.AppService
	UserApp        *userapp.AppService
	VipAdmin       *vipadmin.AdminService
	ModelCache     *utils.ModelCache
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config:     c,
		ModelCache: utils.NewModelCache(),
	}
}

// SyncDomains keeps the grouped domain view aligned with the legacy flat fields.
// New code should prefer Domains, while existing call sites can continue using flat fields.
func (c *ServiceContext) SyncDomains() {
	if c == nil {
		return
	}
	c.Domains.Access = AccessServices{
		MoeAdmin:   c.MoeAdmin,
		LandingApp: c.LandingApp,
		AdminApp:   c.AdminApp,
		UserApp:    c.UserApp,
		VipAdmin:   c.VipAdmin,
	}
	c.Domains.Community = CommunityServices{
		BehaviorApp:    c.BehaviorApp,
		PostApp:        c.PostApp,
		CommentApp:     c.CommentApp,
		CommunityApp:   c.CommunityApp,
		CheckInApp:     c.CheckInApp,
		AchievementApp: c.AchievementApp,
		GiftApp:        c.GiftApp,
		ChatApp:        c.ChatApp,
		NotifyApp:      c.NotifyApp,
	}
	c.Domains.AI = AIServices{
		AIApp:  c.AIApp,
		LLMApp: c.LLMApp,
	}
	c.Domains.Game = GameServices{GameApp: c.GameApp}
	c.Domains.Platform = PlatformServices{MediaApp: c.MediaApp}
}
