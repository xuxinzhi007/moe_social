package svc

import (
	moepb "backend/api/moe/v1"
	"backend/internal/apilegacy/config"
	"backend/internal/platform/moewiring"
	achievementapp "backend/internal/service/achievement"
	adminapp "backend/internal/service/admin"
	aiapp "backend/internal/service/ai"
	behaviorapp "backend/internal/service/behavior"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
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

	"backend/internal/platform/grpcclient"
)

type ServiceContext struct {
	Config         config.Config
	MoeAdmin       *moeadmin.AdminService
	MoeGRPC        moepb.MoeAdminClient
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
	LLMApp         *llmapp.AppService
	MediaApp       *mediaapp.AppService
	ChatApp        *chatapp.AppService
	NotifyApp      *notifyapp.AppService
	UserApp        *userapp.AppService
	VipAdmin       *vipadmin.AdminService
	ModelCache     *utils.ModelCache
}

func NewServiceContext(c config.Config) *ServiceContext {
	var moeGRPC moepb.MoeAdminClient
	// 分体部署：super_grpc_retired=false 时仍可 dial MoeAdmin gRPC（无 Super 单体服务）
	if !moewiring.SuperGrpcRetired() && moewiring.UseMoeGRPCEnabled() {
		conn, err := grpcclient.Dial(c.SuperRpc)
		if err != nil {
			panic(err)
		}
		moeGRPC = moewiring.NewMoeGRPCAdminClient(conn)
	}

	return &ServiceContext{
		Config:     c,
		MoeGRPC:    moeGRPC,
		ModelCache: utils.NewModelCache(),
	}
}
