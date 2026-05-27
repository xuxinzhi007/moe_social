package admingw

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/super"
	"backend/utils"

	"google.golang.org/grpc"
)

// Gateway Admin 只读 HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *adminapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *adminapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) AdminGetGrowthStats(ctx context.Context, in *super.AdminGetGrowthStatsReq, opts ...grpc.CallOption) (*super.AdminGetGrowthStatsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GrowthStats(ctx)
	}
	return g.super.AdminGetGrowthStats(ctx, in, opts...)
}

func (g *Gateway) AdminGetSchemaCatalog(ctx context.Context, in *super.AdminGetSchemaCatalogReq, opts ...grpc.CallOption) (*super.AdminGetSchemaCatalogResp, error) {
	if g != nil && g.local != nil {
		return g.local.SchemaCatalog(ctx)
	}
	return g.super.AdminGetSchemaCatalog(ctx, in, opts...)
}

// ReadRuntimeConfig 运行时配置（无 super RPC，in_process 时走 biz）。
func (g *Gateway) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	if g != nil && g.local != nil {
		return g.local.ReadRuntimeConfig()
	}
	return utils.ReadRuntimeConfig()
}

func (g *Gateway) AdminBroadcastNotification(ctx context.Context, in *super.AdminBroadcastNotificationReq, opts ...grpc.CallOption) (*super.AdminBroadcastNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.BroadcastNotification(ctx, in)
	}
	return g.super.AdminBroadcastNotification(ctx, in, opts...)
}

func (g *Gateway) AdminSendNotification(ctx context.Context, in *super.AdminSendNotificationReq, opts ...grpc.CallOption) (*super.AdminSendNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendNotification(ctx, in)
	}
	return g.super.AdminSendNotification(ctx, in, opts...)
}

func (g *Gateway) AdminListAnnouncements(ctx context.Context, in *super.AdminListAnnouncementsReq, opts ...grpc.CallOption) (*super.AdminListAnnouncementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAnnouncements(ctx, in)
	}
	return g.super.AdminListAnnouncements(ctx, in, opts...)
}

func (g *Gateway) AdminGetAnnouncement(ctx context.Context, in *super.AdminGetAnnouncementReq, opts ...grpc.CallOption) (*super.AdminGetAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetAnnouncement(ctx, in)
	}
	return g.super.AdminGetAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListAuditLogs(ctx context.Context, in *super.AdminListAuditLogsReq, opts ...grpc.CallOption) (*super.AdminListAuditLogsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAuditLogs(ctx, in)
	}
	return g.super.AdminListAuditLogs(ctx, in, opts...)
}

func (g *Gateway) AdminCreateAnnouncement(ctx context.Context, in *super.AdminCreateAnnouncementReq, opts ...grpc.CallOption) (*super.AdminCreateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateAnnouncement(ctx, in)
	}
	return g.super.AdminCreateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAnnouncement(ctx context.Context, in *super.AdminUpdateAnnouncementReq, opts ...grpc.CallOption) (*super.AdminUpdateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAnnouncement(ctx, in)
	}
	return g.super.AdminUpdateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminPublishAnnouncement(ctx context.Context, in *super.AdminPublishAnnouncementReq, opts ...grpc.CallOption) (*super.AdminPublishAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.PublishAnnouncement(ctx, in)
	}
	return g.super.AdminPublishAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAnnouncement(ctx context.Context, in *super.AdminDeleteAnnouncementReq, opts ...grpc.CallOption) (*super.AdminDeleteAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAnnouncement(ctx, in)
	}
	return g.super.AdminDeleteAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListGifts(ctx context.Context, in *super.AdminListGiftsReq, opts ...grpc.CallOption) (*super.AdminListGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminListGifts(ctx, in)
	}
	return g.super.AdminListGifts(ctx, in, opts...)
}

func (g *Gateway) AdminGetGift(ctx context.Context, in *super.AdminGetGiftReq, opts ...grpc.CallOption) (*super.AdminGetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminGetGift(ctx, in)
	}
	return g.super.AdminGetGift(ctx, in, opts...)
}

func (g *Gateway) AdminCreateGift(ctx context.Context, in *super.AdminCreateGiftReq, opts ...grpc.CallOption) (*super.AdminCreateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminCreateGift(ctx, in)
	}
	return g.super.AdminCreateGift(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateGift(ctx context.Context, in *super.AdminUpdateGiftReq, opts ...grpc.CallOption) (*super.AdminUpdateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminUpdateGift(ctx, in)
	}
	return g.super.AdminUpdateGift(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteGift(ctx context.Context, in *super.AdminDeleteGiftReq, opts ...grpc.CallOption) (*super.AdminDeleteGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminDeleteGift(ctx, in)
	}
	return g.super.AdminDeleteGift(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapGifts(ctx context.Context, in *super.AdminBootstrapGiftsReq, opts ...grpc.CallOption) (*super.AdminBootstrapGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapGifts(ctx, in)
	}
	return g.super.AdminBootstrapGifts(ctx, in, opts...)
}

func (g *Gateway) AdminDedupeGifts(ctx context.Context, in *super.AdminDedupeGiftsReq, opts ...grpc.CallOption) (*super.AdminDedupeGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminDedupeGifts(ctx, in)
	}
	return g.super.AdminDedupeGifts(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapTopicTags(ctx context.Context, in *super.AdminBootstrapTopicTagsReq, opts ...grpc.CallOption) (*super.AdminBootstrapTopicTagsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapTopicTags(ctx, in)
	}
	return g.super.AdminBootstrapTopicTags(ctx, in, opts...)
}

func (g *Gateway) AdminListUsers(ctx context.Context, in *super.AdminListUsersReq, opts ...grpc.CallOption) (*super.AdminListUsersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUsers(ctx, in)
	}
	return g.super.AdminListUsers(ctx, in, opts...)
}

func (g *Gateway) AdminListAchievements(ctx context.Context, in *super.AdminListAchievementsReq, opts ...grpc.CallOption) (*super.AdminListAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAchievements(ctx, in)
	}
	return g.super.AdminListAchievements(ctx, in, opts...)
}

func (g *Gateway) AdminListMenus(ctx context.Context, in *super.AdminListMenusReq, opts ...grpc.CallOption) (*super.AdminListMenusResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListMenus(ctx, in)
	}
	return g.super.AdminListMenus(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateUser(ctx context.Context, in *super.AdminUpdateUserReq, opts ...grpc.CallOption) (*super.AdminUpdateUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUser(ctx, in)
	}
	return g.super.AdminUpdateUser(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAchievement(ctx context.Context, in *super.AdminUpdateAchievementReq, opts ...grpc.CallOption) (*super.AdminUpdateAchievementResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAchievement(ctx, in)
	}
	return g.super.AdminUpdateAchievement(ctx, in, opts...)
}

func (g *Gateway) AdminUpsertMenu(ctx context.Context, in *super.AdminUpsertMenuReq, opts ...grpc.CallOption) (*super.AdminUpsertMenuResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertMenu(ctx, in)
	}
	return g.super.AdminUpsertMenu(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteMenu(ctx context.Context, in *super.AdminDeleteMenuReq, opts ...grpc.CallOption) (*super.AdminDeleteMenuResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteMenu(ctx, in)
	}
	return g.super.AdminDeleteMenu(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapAchievements(ctx context.Context, in *super.AdminBootstrapAchievementsReq, opts ...grpc.CallOption) (*super.AdminBootstrapAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapAchievements(ctx, in)
	}
	return g.super.AdminBootstrapAchievements(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapMenus(ctx context.Context, in *super.AdminBootstrapMenusReq, opts ...grpc.CallOption) (*super.AdminBootstrapMenusResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapMenus(ctx, in)
	}
	return g.super.AdminBootstrapMenus(ctx, in, opts...)
}

func (g *Gateway) AdminListAiChatSessions(ctx context.Context, in *super.AdminListAiChatSessionsReq, opts ...grpc.CallOption) (*super.AdminListAiChatSessionsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiChatSessions(ctx, in)
	}
	return g.super.AdminListAiChatSessions(ctx, in, opts...)
}

func (g *Gateway) AdminListAiChatMessages(ctx context.Context, in *super.AdminListAiChatMessagesReq, opts ...grpc.CallOption) (*super.AdminListAiChatMessagesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiChatMessages(ctx, in)
	}
	return g.super.AdminListAiChatMessages(ctx, in, opts...)
}

func (g *Gateway) AdminExportAiChatMessages(ctx context.Context, in *super.AdminExportAiChatMessagesReq, opts ...grpc.CallOption) (*super.AdminExportAiChatMessagesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ExportAiChatMessages(ctx, in)
	}
	return g.super.AdminExportAiChatMessages(ctx, in, opts...)
}

func (g *Gateway) AdminAnalyticsOverview(ctx context.Context, in *super.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*super.AdminAnalyticsOverviewResp, error) {
	if g != nil && g.local != nil {
		return g.local.AnalyticsOverview(ctx, in)
	}
	return g.super.AdminAnalyticsOverview(ctx, in, opts...)
}

func (g *Gateway) AdminListTopicTags(ctx context.Context, in *super.AdminListTopicTagsReq, opts ...grpc.CallOption) (*super.AdminListTopicTagsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListTopicTags(ctx, in)
	}
	return g.super.AdminListTopicTags(ctx, in, opts...)
}

func (g *Gateway) AdminCreateTopicTag(ctx context.Context, in *super.AdminCreateTopicTagReq, opts ...grpc.CallOption) (*super.AdminCreateTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateTopicTag(ctx, in)
	}
	return g.super.AdminCreateTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateTopicTag(ctx context.Context, in *super.AdminUpdateTopicTagReq, opts ...grpc.CallOption) (*super.AdminUpdateTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateTopicTag(ctx, in)
	}
	return g.super.AdminUpdateTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteTopicTag(ctx context.Context, in *super.AdminDeleteTopicTagReq, opts ...grpc.CallOption) (*super.AdminDeleteTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteTopicTag(ctx, in)
	}
	return g.super.AdminDeleteTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminListTagDictionary(ctx context.Context, in *super.AdminListTagDictionaryReq, opts ...grpc.CallOption) (*super.AdminListTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListTagDictionary(ctx, in)
	}
	return g.super.AdminListTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminCreateTagDictionary(ctx context.Context, in *super.AdminCreateTagDictionaryReq, opts ...grpc.CallOption) (*super.AdminCreateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateTagDictionary(ctx, in)
	}
	return g.super.AdminCreateTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateTagDictionary(ctx context.Context, in *super.AdminUpdateTagDictionaryReq, opts ...grpc.CallOption) (*super.AdminUpdateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateTagDictionary(ctx, in)
	}
	return g.super.AdminUpdateTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteTagDictionary(ctx context.Context, in *super.AdminDeleteTagDictionaryReq, opts ...grpc.CallOption) (*super.AdminDeleteTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteTagDictionary(ctx, in)
	}
	return g.super.AdminDeleteTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminListAiAgents(ctx context.Context, in *super.AdminListAiAgentsReq, opts ...grpc.CallOption) (*super.AdminListAiAgentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiAgents(ctx, in)
	}
	return g.super.AdminListAiAgents(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAiAgent(ctx context.Context, in *super.AdminDeleteAiAgentReq, opts ...grpc.CallOption) (*super.AdminDeleteAiAgentResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAiAgent(ctx, in)
	}
	return g.super.AdminDeleteAiAgent(ctx, in, opts...)
}

func (g *Gateway) AdminListFollows(ctx context.Context, in *super.AdminListFollowsReq, opts ...grpc.CallOption) (*super.AdminListFollowsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFollows(ctx, in)
	}
	return g.super.AdminListFollows(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteFollow(ctx context.Context, in *super.AdminDeleteFollowReq, opts ...grpc.CallOption) (*super.AdminDeleteFollowResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteFollow(ctx, in)
	}
	return g.super.AdminDeleteFollow(ctx, in, opts...)
}

func (g *Gateway) AdminListPosts(ctx context.Context, in *super.AdminListPostsReq, opts ...grpc.CallOption) (*super.AdminListPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPosts(ctx, in)
	}
	return g.super.AdminListPosts(ctx, in, opts...)
}

func (g *Gateway) AdminDeletePost(ctx context.Context, in *super.AdminDeletePostReq, opts ...grpc.CallOption) (*super.AdminDeletePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeletePost(ctx, in)
	}
	return g.super.AdminDeletePost(ctx, in, opts...)
}

func (g *Gateway) AdminListComments(ctx context.Context, in *super.AdminListCommentsReq, opts ...grpc.CallOption) (*super.AdminListCommentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListComments(ctx, in)
	}
	return g.super.AdminListComments(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteComment(ctx context.Context, in *super.AdminDeleteCommentReq, opts ...grpc.CallOption) (*super.AdminDeleteCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteComment(ctx, in)
	}
	return g.super.AdminDeleteComment(ctx, in, opts...)
}

func (g *Gateway) AdminListGroups(ctx context.Context, in *super.AdminListGroupsReq, opts ...grpc.CallOption) (*super.AdminListGroupsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListGroups(ctx, in)
	}
	return g.super.AdminListGroups(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteGroup(ctx context.Context, in *super.AdminDeleteGroupReq, opts ...grpc.CallOption) (*super.AdminDeleteGroupResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteGroup(ctx, in)
	}
	return g.super.AdminDeleteGroup(ctx, in, opts...)
}

func (g *Gateway) AdminListFriendRequests(ctx context.Context, in *super.AdminListFriendRequestsReq, opts ...grpc.CallOption) (*super.AdminListFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFriendRequests(ctx, in)
	}
	return g.super.AdminListFriendRequests(ctx, in, opts...)
}

func (g *Gateway) AdminListPostReports(ctx context.Context, in *super.AdminListPostReportsReq, opts ...grpc.CallOption) (*super.AdminListPostReportsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPostReports(ctx, in)
	}
	return g.super.AdminListPostReports(ctx, in, opts...)
}

func (g *Gateway) AdminListMemories(ctx context.Context, in *super.AdminListMemoriesReq, opts ...grpc.CallOption) (*super.AdminListMemoriesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListMemories(ctx, in)
	}
	return g.super.AdminListMemories(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteMemory(ctx context.Context, in *super.AdminDeleteMemoryReq, opts ...grpc.CallOption) (*super.AdminDeleteMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteMemory(ctx, in)
	}
	return g.super.AdminDeleteMemory(ctx, in, opts...)
}

func (g *Gateway) AdminGetMemoryStats(ctx context.Context, in *super.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*super.AdminGetMemoryStatsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetMemoryStats(ctx, in)
	}
	return g.super.AdminGetMemoryStats(ctx, in, opts...)
}

func (g *Gateway) AdminListAccounts(ctx context.Context, in *super.AdminListAccountsReq, opts ...grpc.CallOption) (*super.AdminListAccountsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAccounts(ctx, in)
	}
	return g.super.AdminListAccounts(ctx, in, opts...)
}

func (g *Gateway) AdminCreateAccount(ctx context.Context, in *super.AdminCreateAccountReq, opts ...grpc.CallOption) (*super.AdminCreateAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateAccount(ctx, in)
	}
	return g.super.AdminCreateAccount(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAccount(ctx context.Context, in *super.AdminUpdateAccountReq, opts ...grpc.CallOption) (*super.AdminUpdateAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAccount(ctx, in)
	}
	return g.super.AdminUpdateAccount(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAccount(ctx context.Context, in *super.AdminDeleteAccountReq, opts ...grpc.CallOption) (*super.AdminDeleteAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAccount(ctx, in)
	}
	return g.super.AdminDeleteAccount(ctx, in, opts...)
}

func (g *Gateway) AdminGetUser(ctx context.Context, in *super.AdminGetUserReq, opts ...grpc.CallOption) (*super.AdminGetUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUser(ctx, in)
	}
	return g.super.AdminGetUser(ctx, in, opts...)
}

func (g *Gateway) AdminGetUserProfile(ctx context.Context, in *super.AdminGetUserProfileReq, opts ...grpc.CallOption) (*super.AdminGetUserProfileResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserProfile(ctx, in)
	}
	return g.super.AdminGetUserProfile(ctx, in, opts...)
}

func (g *Gateway) AdminDashboard(ctx context.Context, in *super.AdminDashboardReq, opts ...grpc.CallOption) (*super.AdminDashboardResp, error) {
	if g != nil && g.local != nil {
		return g.local.Dashboard(ctx, in)
	}
	return g.super.AdminDashboard(ctx, in, opts...)
}

func (g *Gateway) AdminListLevelConfigs(ctx context.Context, in *super.AdminListLevelConfigsReq, opts ...grpc.CallOption) (*super.AdminListLevelConfigsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListLevelConfigs(ctx, in)
	}
	return g.super.AdminListLevelConfigs(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateLevelConfig(ctx context.Context, in *super.AdminUpdateLevelConfigReq, opts ...grpc.CallOption) (*super.AdminUpdateLevelConfigResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateLevelConfig(ctx, in)
	}
	return g.super.AdminUpdateLevelConfig(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapLevels(ctx context.Context, in *super.AdminBootstrapLevelsReq, opts ...grpc.CallOption) (*super.AdminBootstrapLevelsResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapLevels(ctx, in)
	}
	return g.super.AdminBootstrapLevels(ctx, in, opts...)
}

func (g *Gateway) AdminListCheckInRewards(ctx context.Context, in *super.AdminListCheckInRewardsReq, opts ...grpc.CallOption) (*super.AdminListCheckInRewardsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListCheckInRewards(ctx, in)
	}
	return g.super.AdminListCheckInRewards(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateCheckInReward(ctx context.Context, in *super.AdminUpdateCheckInRewardReq, opts ...grpc.CallOption) (*super.AdminUpdateCheckInRewardResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateCheckInReward(ctx, in)
	}
	return g.super.AdminUpdateCheckInReward(ctx, in, opts...)
}

func (g *Gateway) AdminListVipOrders(ctx context.Context, in *super.AdminListVipOrdersReq, opts ...grpc.CallOption) (*super.AdminListVipOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListVipOrders(ctx, in)
	}
	return g.super.AdminListVipOrders(ctx, in, opts...)
}

func (g *Gateway) AdminListGiftPurchaseOrders(ctx context.Context, in *super.AdminListGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*super.AdminListGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListGiftPurchaseOrders(ctx, in)
	}
	return g.super.AdminListGiftPurchaseOrders(ctx, in, opts...)
}
