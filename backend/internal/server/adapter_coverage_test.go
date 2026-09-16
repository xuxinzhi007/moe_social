package server

import (
	"testing"

	achievementv1 "backend/api/achievement/v1"
	adminv1 "backend/api/admin/v1"
	aiv1 "backend/api/ai/v1"
	battlev1 "backend/api/battle/v1"
	behaviorv1 "backend/api/behavior/v1"
	chatv1 "backend/api/chat/v1"
	checkinv1 "backend/api/checkin/v1"
	commentv1 "backend/api/comment/v1"
	communityv1 "backend/api/community/v1"
	companionv1 "backend/api/companion/v1"
	contentv1 "backend/api/content/v1"
	gamev1 "backend/api/game/v1"
	giftv1 "backend/api/gift/v1"
	landingv1 "backend/api/landing/v1"
	lifev1 "backend/api/life/v1"
	llmv1 "backend/api/llm/v1"
	mediav1 "backend/api/media/v1"
	moepb "backend/api/moe/v1"
	notifyv1 "backend/api/notify/v1"
	platformv1 "backend/api/platform/v1"
	postv1 "backend/api/post/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/internal/server/protohttp/prototest"

	moeadminhttp "backend/internal/server/protohttp"
	achievementhttp "backend/internal/server/protohttp/achievement"
	adminapphttp "backend/internal/server/protohttp/adminapp"
	admininsightshttp "backend/internal/server/protohttp/admininsights"
	aihttp "backend/internal/server/protohttp/ai"
	battlehttp "backend/internal/server/protohttp/battle"
	behaviorhttp "backend/internal/server/protohttp/behavior"
	chathttp "backend/internal/server/protohttp/chat"
	checkinhttp "backend/internal/server/protohttp/checkin"
	commenthttp "backend/internal/server/protohttp/comment"
	communityhttp "backend/internal/server/protohttp/community"
	companionhttp "backend/internal/server/protohttp/companion"
	contenthttp "backend/internal/server/protohttp/content"
	gamehttp "backend/internal/server/protohttp/game"
	gifthttp "backend/internal/server/protohttp/gift"
	landinghttp "backend/internal/server/protohttp/landing"
	lifehttp "backend/internal/server/protohttp/life"
	llmhttp "backend/internal/server/protohttp/llm"
	mediahttp "backend/internal/server/protohttp/media"
	notifyhttp "backend/internal/server/protohttp/notify"
	platformhttp "backend/internal/server/protohttp/platform"
	posthttp "backend/internal/server/protohttp/post"
	userhttp "backend/internal/server/protohttp/user"
	viphttp "backend/internal/server/protohttp/vip"
	vipplanshttp "backend/internal/server/protohttp/vipplans"
	vipreadhttp "backend/internal/server/protohttp/vipread"
)

// 下面两批 RPC 在 proto 里声明了、路由也注册了，但既没有适配方法也没有活的调用方，
// 线上永远回 501。已定为整条删除，删掉后这里的条目会自动失效（方法名不再存在于桩上），
// 不需要回来改这个测试。
//
// 注意 ListLlmModels 不在表内：它是客户端真的在打的活接口，已经补上实现了。
var (
	adminMemoryRPCsPendingDeletion = []string{
		"AdminDeleteMemory",
		"AdminExportLearningDataset",
		"AdminGetMemoryHealth",
		"AdminGetMemoryStats",
		"AdminListMemories",
		"AdminRebuildMemoryEmbeddings",
	}

	llmDeadRPCsPendingDeletion = []string{
		"DeleteUserMemory",
		"GetAiMemorySettings",
		"GetUserMemories",
		"GetUserMemoriesDisplay",
		"GetUserMemoryProfiles",
		"ListLlmLocalModelsCatalog",
		"PutAiMemorySettings",
		"RebuildUserMemoryEmbeddings",
		"RecordLlmChatTurn",
		"SearchUserMemories",
		"SubmitUserMemoryFeedback",
		"UpsertUserMemory",
	}
)

// 全仓扫描：每个 proto service 的每个 RPC 都必须有 HTTP 适配方法。
//
// 漏写不会编译报错、不会路由 404、不会被鉴权拦截 —— 嵌入的 Unimplemented* 桩会顶上，
// 线上永远回 501。Companion 的三个方法和 LlmChat.ListLlmModels 都是这么漏掉的：
// 客户端照常调用，用户只看到「功能没反应」。
//
// pet 与 arena 不在表内：它们用手写路由（pethttp.RegisterRoutes / arenahttp.RegisterRoutes），
// 从不嵌入桩，任何基于桩的扫描都看不见它们。
func TestEveryProtoRPCHasHTTPAdapter(t *testing.T) {
	services := []struct {
		name    string
		srv     any
		stub    any
		pending []string
	}{
		{"Achievement", achievementhttp.New(nil), achievementv1.UnimplementedAchievementServer{}, nil},
		{"AdminApp", adminapphttp.New(nil, nil), adminv1.UnimplementedAdminAppServer{}, adminMemoryRPCsPendingDeletion},
		{"AdminInsights", admininsightshttp.New(nil), adminv1.UnimplementedAdminInsightsServer{}, nil},
		{"AiResources", aihttp.New(nil), aiv1.UnimplementedAiResourcesServer{}, nil},
		{"BattleService", battlehttp.New(nil), battlev1.UnimplementedBattleServiceServer{}, nil},
		{"BehaviorApp", behaviorhttp.New(nil), behaviorv1.UnimplementedBehaviorAppServer{}, nil},
		{"ChatPresenceService", chathttp.NewPresence(), chatv1.UnimplementedChatPresenceServiceServer{}, nil},
		{"PrivateMessageService", chathttp.New(nil), chatv1.UnimplementedPrivateMessageServiceServer{}, nil},
		{"PushNotificationService", chathttp.New(nil), chatv1.UnimplementedPushNotificationServiceServer{}, nil},
		{"Checkin", checkinhttp.New(nil), checkinv1.UnimplementedCheckinServer{}, nil},
		{"CommentService", commenthttp.New(nil), commentv1.UnimplementedCommentServiceServer{}, nil},
		{"Community", communityhttp.New(nil), communityv1.UnimplementedCommunityServer{}, nil},
		{"Companion", companionhttp.New(nil), companionv1.UnimplementedCompanionServer{}, []string{"GetContextPreview"}},
		{"ContentService", contenthttp.New(nil), contentv1.UnimplementedContentServiceServer{}, nil},
		{"Game", gamehttp.New(nil), gamev1.UnimplementedGameServer{}, nil},
		{"GiftService", gifthttp.New(nil), giftv1.UnimplementedGiftServiceServer{}, nil},
		{"Landing", landinghttp.New(nil), landingv1.UnimplementedLandingServer{}, nil},
		{"Life", lifehttp.New(nil), lifev1.UnimplementedLifeServer{}, nil},
		{"LlmChat", llmhttp.New(nil), llmv1.UnimplementedLlmChatServer{}, llmDeadRPCsPendingDeletion},
		{"Media", mediahttp.New(nil), mediav1.UnimplementedMediaServer{}, nil},
		{"MoeAdmin", moeadminhttp.New(nil), moepb.UnimplementedMoeAdminServer{}, nil},
		{"NotifyService", notifyhttp.New(nil), notifyv1.UnimplementedNotifyServiceServer{}, nil},
		{"Platform", platformhttp.New(platformhttp.Deps{}), platformv1.UnimplementedPlatformServer{}, nil},
		{"PostService", posthttp.New(nil), postv1.UnimplementedPostServiceServer{}, nil},
		{"UserService", userhttp.New(nil), userv1.UnimplementedUserServiceServer{}, nil},
		{"VipPlans", vipplanshttp.New(nil), vipv1.UnimplementedVipPlansServer{}, nil},
		{"VipReadAdmin", vipreadhttp.New(nil), vipv1.UnimplementedVipReadAdminServer{}, nil},
		{"VipService", viphttp.New(nil), vipv1.UnimplementedVipServiceServer{}, nil},
	}

	for _, svc := range services {
		t.Run(svc.name, func(t *testing.T) {
			prototest.AssertRPCsAdapted(t, svc.srv, svc.stub, nil, svc.pending...)
		})
	}
}
