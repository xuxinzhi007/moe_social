package svc

import (
	"backend/internal/apilegacy/achievementgw"
	"backend/internal/apilegacy/admingw"
	"backend/internal/apilegacy/aigw"
	"backend/internal/apilegacy/behaviorgw"
	"backend/internal/apilegacy/chatgw"
	"backend/internal/apilegacy/checkinwg"
	"backend/internal/apilegacy/commentgw"
	"backend/internal/apilegacy/communitygw"
	"backend/internal/apilegacy/config"
	"backend/internal/apilegacy/giftgw"
	"backend/internal/apilegacy/landinggw"
	"backend/internal/apilegacy/llmgw"
	"backend/internal/apilegacy/moeadmingw"
	"backend/internal/apilegacy/postgw"
	"backend/internal/apilegacy/usergw"
	"backend/internal/apilegacy/vipadmingw"
	moepb "backend/api/moe/v1"
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
	MoeGW          *moeadmingw.Gateway
	LandingApp     *landingapp.AppService
	LandingGW      *landinggw.Gateway
	AdminApp       *adminapp.AppService
	AdminGW        *admingw.Gateway
	AIApp          *aiapp.AppService
	AIGW           *aigw.Gateway
	BehaviorApp    *behaviorapp.AppService
	BehaviorGW     *behaviorgw.Gateway
	PostApp        *postapp.AppService
	PostGW         *postgw.Gateway
	CommentApp     *commentapp.AppService
	CommentGW      *commentgw.Gateway
	CommunityApp   *communityapp.AppService
	CommunityGW    *communitygw.Gateway
	CheckInApp     *checkinapp.AppService
	CheckInGW      *checkinwg.Gateway
	AchievementApp *achievementapp.AppService
	AchievementGW  *achievementgw.Gateway
	GiftApp        *giftapp.AppService
	GiftGW         *giftgw.Gateway
	LLMApp         *llmapp.AppService
	LLMGW          *llmgw.Gateway
	ChatApp        *chatapp.AppService
	ChatGW         *chatgw.Gateway
	NotifyApp      *notifyapp.AppService
	UserApp        *userapp.AppService
	UserGW         *usergw.Gateway
	VipAdmin       *vipadmin.AdminService
	VipGW          *vipadmingw.Gateway
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
		Config:         c,
		MoeGRPC:        moeGRPC,
		MoeGW:          moeadmingw.NewConfigured(nil, moeGRPC),
		LandingGW:      landinggw.New(nil),
		AdminGW:        admingw.NewConfigured(nil),
		AIGW:           aigw.New(nil),
		BehaviorGW:     behaviorgw.New(nil),
		PostGW:         postgw.New(nil),
		CommentGW:      commentgw.New(nil),
		CommunityGW:    communitygw.New(nil),
		CheckInGW:      checkinwg.New(nil),
		AchievementGW:  achievementgw.New(nil),
		GiftGW:         giftgw.New(nil),
		LLMGW:          llmgw.New(nil),
		ChatGW:         chatgw.New(nil),
		UserGW:         usergw.New(nil),
		VipGW:          vipadmingw.NewConfigured(nil),
		ModelCache:     utils.NewModelCache(),
	}
}
