package svc

import (
	"backend/api/internal/admingw"
	"backend/api/internal/achievementgw"
	"backend/api/internal/behaviorgw"
	"backend/api/internal/checkinwg"
	"backend/api/internal/commentgw"
	"backend/api/internal/communitygw"
	"backend/api/internal/giftgw"
	"backend/api/internal/config"
	"backend/api/internal/landinggw"
	"backend/api/internal/llmgw"
	"backend/api/internal/moeadmingw"
	"backend/api/internal/postgw"
	"backend/api/internal/usergw"
	"backend/api/internal/vipadmingw"
	moepb "backend/api/moe/v1"
	moeadmin "backend/internal/service/moe"
	adminapp "backend/internal/service/admin"
	achievementapp "backend/internal/service/achievement"
	behaviorapp "backend/internal/service/behavior"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	giftapp "backend/internal/service/gift"
	llmapp "backend/internal/service/llm"
	landingapp "backend/internal/service/landing"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"
	"backend/internal/platform/moewiring"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config         config.Config
	SuperRpcClient super.SuperClient
	MoeAdmin       *moeadmin.AdminService
	MoeGRPC        moepb.MoeAdminClient
	MoeGW          *moeadmingw.Gateway
	LandingApp     *landingapp.AppService
	LandingGW      *landinggw.Gateway
	AdminApp       *adminapp.AppService
	AdminGW        *admingw.Gateway
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
	UserApp        *userapp.AppService
	UserGW         *usergw.Gateway
	VipAdmin       *vipadmin.AdminService
	VipGW          *vipadmingw.Gateway
	ModelCache     *utils.ModelCache
}

func NewServiceContext(c config.Config) *ServiceContext {
	rpcClient := zrpc.MustNewClient(c.SuperRpc)
	conn := rpcClient.Conn()
	superClient := super.NewSuperClient(conn)

	var moeGRPC moepb.MoeAdminClient
	if moewiring.UseMoeGRPCEnabled() {
		moeGRPC = moewiring.NewMoeGRPCAdminClient(conn)
	}

	return &ServiceContext{
		Config:         c,
		SuperRpcClient: superClient,
		MoeGRPC:        moeGRPC,
		MoeGW:          moeadmingw.NewConfigured(nil, moeGRPC, superClient),
		LandingGW:      landinggw.New(nil, superClient),
		AdminGW:        admingw.New(nil, superClient),
		BehaviorGW:     behaviorgw.New(nil, superClient),
		PostGW:         postgw.New(nil, superClient),
		CommentGW:      commentgw.New(nil, superClient),
		CommunityGW:    communitygw.New(nil, superClient),
		CheckInGW:      checkinwg.New(nil, superClient),
		AchievementGW:  achievementgw.New(nil, superClient),
		GiftGW:         giftgw.New(nil, superClient),
		LLMGW:          llmgw.New(nil, superClient),
		UserGW:         usergw.New(nil, superClient),
		VipGW:          vipadmingw.New(nil, superClient),
		ModelCache:     utils.NewModelCache(),
	}
}
