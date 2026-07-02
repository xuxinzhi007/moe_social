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
	giftapp "backend/internal/service/gift"
	gameapp "backend/internal/service/game"
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

type ServiceContext struct {
	Config         config.Config
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
