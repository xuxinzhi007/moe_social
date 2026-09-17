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

// 全仓扫描：每个 proto service 的每个 RPC 都必须有 HTTP 适配方法。
//
// 漏写不会编译报错、不会路由 404、不会被鉴权拦截 —— 嵌入的 Unimplemented* 桩会顶上，
// 线上永远回 501。Companion 的三个方法和 LlmChat.ListLlmModels 都是这么漏掉的：
// 客户端照常调用，用户只看到「功能没反应」。
//
// pet 与 arena 不在表内：它们用手写路由（pethttp.RegisterRoutes / arenahttp.RegisterRoutes），
// 从不嵌入桩，任何基于桩的扫描都看不见它们。
//
// 这里曾经挂着两份「待删死接口」白名单（AdminApp 的 6 个记忆 RPC、LlmChat 的 12 个
// 记忆/聊天记录/离线模型 RPC），已于 #42 连同 proto 定义一起删除。白名单清空后
// pending 字段对 28 个 service 全是 nil，所以连字段一起摘掉了 —— 现在 28 个 service
// 一律零豁免，任何 RPC 落回嵌入桩都会让测试直接红。将来若真要加豁免，得把
// AssertRPCsAdapted 的 pendingDeletion 参数重新引进来，那个动作在 review 里看得见，
// 不像往某一行末尾追加一个方法名那样悄无声息。
//
// 注意 ListLlmModels 不是死接口：它是客户端真的在打的活接口，曾漏写适配方法，已补齐。
func TestEveryProtoRPCHasHTTPAdapter(t *testing.T) {
	services := []struct {
		name string
		srv  any
		stub any
	}{
		{"Achievement", achievementhttp.New(nil), achievementv1.UnimplementedAchievementServer{}},
		{"AdminApp", adminapphttp.New(nil, nil), adminv1.UnimplementedAdminAppServer{}},
		{"AdminInsights", admininsightshttp.New(nil), adminv1.UnimplementedAdminInsightsServer{}},
		{"AiResources", aihttp.New(nil), aiv1.UnimplementedAiResourcesServer{}},
		{"BattleService", battlehttp.New(nil), battlev1.UnimplementedBattleServiceServer{}},
		{"BehaviorApp", behaviorhttp.New(nil), behaviorv1.UnimplementedBehaviorAppServer{}},
		{"ChatPresenceService", chathttp.NewPresence(), chatv1.UnimplementedChatPresenceServiceServer{}},
		{"PrivateMessageService", chathttp.New(nil), chatv1.UnimplementedPrivateMessageServiceServer{}},
		{"PushNotificationService", chathttp.New(nil), chatv1.UnimplementedPushNotificationServiceServer{}},
		{"Checkin", checkinhttp.New(nil), checkinv1.UnimplementedCheckinServer{}},
		{"CommentService", commenthttp.New(nil), commentv1.UnimplementedCommentServiceServer{}},
		{"Community", communityhttp.New(nil), communityv1.UnimplementedCommunityServer{}},
		{"Companion", companionhttp.New(nil), companionv1.UnimplementedCompanionServer{}},
		{"ContentService", contenthttp.New(nil), contentv1.UnimplementedContentServiceServer{}},
		{"Game", gamehttp.New(nil), gamev1.UnimplementedGameServer{}},
		{"GiftService", gifthttp.New(nil), giftv1.UnimplementedGiftServiceServer{}},
		{"Landing", landinghttp.New(nil), landingv1.UnimplementedLandingServer{}},
		{"Life", lifehttp.New(nil), lifev1.UnimplementedLifeServer{}},
		{"LlmChat", llmhttp.New(nil), llmv1.UnimplementedLlmChatServer{}},
		{"Media", mediahttp.New(nil), mediav1.UnimplementedMediaServer{}},
		{"MoeAdmin", moeadminhttp.New(nil), moepb.UnimplementedMoeAdminServer{}},
		{"NotifyService", notifyhttp.New(nil), notifyv1.UnimplementedNotifyServiceServer{}},
		{"Platform", platformhttp.New(platformhttp.Deps{}), platformv1.UnimplementedPlatformServer{}},
		{"PostService", posthttp.New(nil), postv1.UnimplementedPostServiceServer{}},
		{"UserService", userhttp.New(nil), userv1.UnimplementedUserServiceServer{}},
		{"VipPlans", vipplanshttp.New(nil), vipv1.UnimplementedVipPlansServer{}},
		{"VipReadAdmin", vipreadhttp.New(nil), vipv1.UnimplementedVipReadAdminServer{}},
		{"VipService", viphttp.New(nil), vipv1.UnimplementedVipServiceServer{}},
	}

	for _, svc := range services {
		t.Run(svc.name, func(t *testing.T) {
			prototest.AssertRPCsAdapted(t, svc.srv, svc.stub, nil)
		})
	}
}
