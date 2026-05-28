package admingw

import (
	"backend/api/internal/gwutil"
	"context"

	adminv1 "backend/api/admin/v1"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"
	"backend/utils"

	"google.golang.org/grpc"
)

// Gateway Admin 只读 HTTP → kratos 试点 HTTP（灰度）→ biz → super RPC。
type Gateway struct {
	kratos *KratosHTTPClient
	local  *adminapp.AppService
}

// New 构造网关；kratos 启用时 Insights 读路径走 :19032。
func New(local *adminapp.AppService, kratos *KratosHTTPClient) *Gateway {
	return &Gateway{local: local, kratos: kratos}
}

func (g *Gateway) kratosHTTPReady() bool {
	return g != nil && g.kratos != nil && g.kratos.enabled()
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.kratosHTTPReady() {
		return "kratos_http"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) AdminGetGrowthStats(ctx context.Context, in *moe.AdminGetGrowthStatsReq, opts ...grpc.CallOption) (*moe.AdminGetGrowthStatsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GrowthStats(ctx)
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetGrowthStatsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetSchemaCatalog(ctx context.Context, in *moe.AdminGetSchemaCatalogReq, opts ...grpc.CallOption) (*moe.AdminGetSchemaCatalogResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SchemaCatalog(ctx)
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetSchemaCatalogRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

// ReadRuntimeConfig 运行时配置（无 super RPC，in_process 时走 biz）。
func (g *Gateway) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	if g != nil && g.local != nil {
		return g.local.ReadRuntimeConfig()
	}
	return utils.ReadRuntimeConfig()
}

func (g *Gateway) AdminBroadcastNotification(ctx context.Context, in *moe.AdminBroadcastNotificationReq, opts ...grpc.CallOption) (*moe.AdminBroadcastNotificationResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.BroadcastNotification(ctx, adminv1.AdminBroadcastNotificationReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBroadcastNotificationRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminSendNotification(ctx context.Context, in *moe.AdminSendNotificationReq, opts ...grpc.CallOption) (*moe.AdminSendNotificationResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SendNotification(ctx, adminv1.AdminSendNotificationReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminSendNotificationRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAnnouncements(ctx context.Context, in *moe.AdminListAnnouncementsReq, opts ...grpc.CallOption) (*moe.AdminListAnnouncementsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAnnouncements(ctx, adminv1.AdminListAnnouncementsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAnnouncementsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetAnnouncement(ctx context.Context, in *moe.AdminGetAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminGetAnnouncementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetAnnouncement(ctx, adminv1.AdminGetAnnouncementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetAnnouncementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAuditLogs(ctx context.Context, in *moe.AdminListAuditLogsReq, opts ...grpc.CallOption) (*moe.AdminListAuditLogsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAuditLogs(ctx, adminv1.AdminListAuditLogsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAuditLogsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminCreateAnnouncement(ctx context.Context, in *moe.AdminCreateAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminCreateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateAnnouncement(ctx, adminv1.AdminCreateAnnouncementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminCreateAnnouncementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateAnnouncement(ctx context.Context, in *moe.AdminUpdateAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminUpdateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateAnnouncement(ctx, adminv1.AdminUpdateAnnouncementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateAnnouncementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminPublishAnnouncement(ctx context.Context, in *moe.AdminPublishAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminPublishAnnouncementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.PublishAnnouncement(ctx, adminv1.AdminPublishAnnouncementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminPublishAnnouncementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteAnnouncement(ctx context.Context, in *moe.AdminDeleteAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminDeleteAnnouncementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAnnouncement(ctx, adminv1.AdminDeleteAnnouncementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteAnnouncementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListGifts(ctx context.Context, in *moe.AdminListGiftsReq, opts ...grpc.CallOption) (*moe.AdminListGiftsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminListGifts(ctx, adminv1.AdminListGiftsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListGiftsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetGift(ctx context.Context, in *moe.AdminGetGiftReq, opts ...grpc.CallOption) (*moe.AdminGetGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminGetGift(ctx, adminv1.AdminGetGiftReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetGiftRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminCreateGift(ctx context.Context, in *moe.AdminCreateGiftReq, opts ...grpc.CallOption) (*moe.AdminCreateGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminCreateGift(ctx, adminv1.AdminCreateGiftReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminCreateGiftRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateGift(ctx context.Context, in *moe.AdminUpdateGiftReq, opts ...grpc.CallOption) (*moe.AdminUpdateGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminUpdateGift(ctx, adminv1.AdminUpdateGiftReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateGiftRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteGift(ctx context.Context, in *moe.AdminDeleteGiftReq, opts ...grpc.CallOption) (*moe.AdminDeleteGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminDeleteGift(ctx, adminv1.AdminDeleteGiftReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteGiftRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapGifts(ctx context.Context, in *moe.AdminBootstrapGiftsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapGiftsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminBootstrapGifts(ctx, adminv1.AdminBootstrapGiftsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapGiftsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDedupeGifts(ctx context.Context, in *moe.AdminDedupeGiftsReq, opts ...grpc.CallOption) (*moe.AdminDedupeGiftsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminDedupeGifts(ctx, adminv1.AdminDedupeGiftsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDedupeGiftsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapTopicTags(ctx context.Context, in *moe.AdminBootstrapTopicTagsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapTopicTagsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminBootstrapTopicTags(ctx, adminv1.AdminBootstrapTopicTagsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapTopicTagsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListUsers(ctx context.Context, in *moe.AdminListUsersReq, opts ...grpc.CallOption) (*moe.AdminListUsersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListUsers(ctx, adminv1.AdminListUsersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListUsersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAchievements(ctx context.Context, in *moe.AdminListAchievementsReq, opts ...grpc.CallOption) (*moe.AdminListAchievementsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAchievements(ctx, adminv1.AdminListAchievementsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAchievementsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListMenus(ctx context.Context, in *moe.AdminListMenusReq, opts ...grpc.CallOption) (*moe.AdminListMenusResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListMenus(ctx, adminv1.AdminListMenusReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListMenusRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateUser(ctx context.Context, in *moe.AdminUpdateUserReq, opts ...grpc.CallOption) (*moe.AdminUpdateUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateUser(ctx, adminv1.AdminUpdateUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateAchievement(ctx context.Context, in *moe.AdminUpdateAchievementReq, opts ...grpc.CallOption) (*moe.AdminUpdateAchievementResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateAchievement(ctx, adminv1.AdminUpdateAchievementReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateAchievementRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpsertMenu(ctx context.Context, in *moe.AdminUpsertMenuReq, opts ...grpc.CallOption) (*moe.AdminUpsertMenuResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertMenu(ctx, adminv1.AdminUpsertMenuReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpsertMenuRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteMenu(ctx context.Context, in *moe.AdminDeleteMenuReq, opts ...grpc.CallOption) (*moe.AdminDeleteMenuResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteMenu(ctx, adminv1.AdminDeleteMenuReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteMenuRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapAchievements(ctx context.Context, in *moe.AdminBootstrapAchievementsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapAchievementsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.BootstrapAchievements(ctx, adminv1.AdminBootstrapAchievementsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapAchievementsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapMenus(ctx context.Context, in *moe.AdminBootstrapMenusReq, opts ...grpc.CallOption) (*moe.AdminBootstrapMenusResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.BootstrapMenus(ctx, adminv1.AdminBootstrapMenusReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapMenusRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAiChatSessions(ctx context.Context, in *moe.AdminListAiChatSessionsReq, opts ...grpc.CallOption) (*moe.AdminListAiChatSessionsResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListAiChatSessions(ctx, in)
	}
	if g != nil && g.local != nil {
		out, err := g.local.ListAiChatSessions(ctx, adminv1.AdminListAiChatSessionsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAiChatSessionsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAiChatMessages(ctx context.Context, in *moe.AdminListAiChatMessagesReq, opts ...grpc.CallOption) (*moe.AdminListAiChatMessagesResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListAiChatMessages(ctx, in)
	}
	if g != nil && g.local != nil {
		out, err := g.local.ListAiChatMessages(ctx, adminv1.AdminListAiChatMessagesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAiChatMessagesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminExportAiChatMessages(ctx context.Context, in *moe.AdminExportAiChatMessagesReq, opts ...grpc.CallOption) (*moe.AdminExportAiChatMessagesResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminExportAiChatMessages(ctx, in)
	}
	if g != nil && g.local != nil {
		out, err := g.local.ExportAiChatMessages(ctx, adminv1.AdminExportAiChatMessagesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminExportAiChatMessagesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminAnalyticsOverview(ctx context.Context, in *moe.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*moe.AdminAnalyticsOverviewResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminAnalyticsOverview(ctx, in)
	}
	if g != nil && g.local != nil {
		out, err := g.local.AnalyticsOverview(ctx, adminv1.AdminGetMemoryStatsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminAnalyticsOverviewRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListTopicTags(ctx context.Context, in *moe.AdminListTopicTagsReq, opts ...grpc.CallOption) (*moe.AdminListTopicTagsResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListTopicTags(ctx, in)
	}
	if g != nil && g.local != nil {
		out, err := g.local.ListTopicTags(ctx, adminv1.AdminListTopicTagsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListTopicTagsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminCreateTopicTag(ctx context.Context, in *moe.AdminCreateTopicTagReq, opts ...grpc.CallOption) (*moe.AdminCreateTopicTagResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateTopicTag(ctx, adminv1.AdminCreateTopicTagReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminCreateTopicTagRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateTopicTag(ctx context.Context, in *moe.AdminUpdateTopicTagReq, opts ...grpc.CallOption) (*moe.AdminUpdateTopicTagResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateTopicTag(ctx, adminv1.AdminUpdateTopicTagReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateTopicTagRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteTopicTag(ctx context.Context, in *moe.AdminDeleteTopicTagReq, opts ...grpc.CallOption) (*moe.AdminDeleteTopicTagResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteTopicTag(ctx, adminv1.AdminDeleteTopicTagReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteTopicTagRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListTagDictionary(ctx context.Context, in *moe.AdminListTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminListTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListTagDictionary(ctx, adminv1.AdminListTagDictionaryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListTagDictionaryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminCreateTagDictionary(ctx context.Context, in *moe.AdminCreateTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminCreateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateTagDictionary(ctx, adminv1.AdminCreateTagDictionaryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminCreateTagDictionaryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateTagDictionary(ctx context.Context, in *moe.AdminUpdateTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminUpdateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateTagDictionary(ctx, adminv1.AdminUpdateTagDictionaryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateTagDictionaryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteTagDictionary(ctx context.Context, in *moe.AdminDeleteTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminDeleteTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteTagDictionary(ctx, adminv1.AdminDeleteTagDictionaryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteTagDictionaryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAiAgents(ctx context.Context, in *moe.AdminListAiAgentsReq, opts ...grpc.CallOption) (*moe.AdminListAiAgentsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAiAgents(ctx, adminv1.AdminListAiAgentsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAiAgentsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteAiAgent(ctx context.Context, in *moe.AdminDeleteAiAgentReq, opts ...grpc.CallOption) (*moe.AdminDeleteAiAgentResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAiAgent(ctx, adminv1.AdminDeleteAiAgentReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteAiAgentRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListFollows(ctx context.Context, in *moe.AdminListFollowsReq, opts ...grpc.CallOption) (*moe.AdminListFollowsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListFollows(ctx, adminv1.AdminListFollowsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListFollowsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteFollow(ctx context.Context, in *moe.AdminDeleteFollowReq, opts ...grpc.CallOption) (*moe.AdminDeleteFollowResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteFollow(ctx, adminv1.AdminDeleteFollowReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteFollowRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListPosts(ctx context.Context, in *moe.AdminListPostsReq, opts ...grpc.CallOption) (*moe.AdminListPostsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListPosts(ctx, adminv1.AdminListPostsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListPostsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeletePost(ctx context.Context, in *moe.AdminDeletePostReq, opts ...grpc.CallOption) (*moe.AdminDeletePostResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeletePost(ctx, adminv1.AdminDeletePostReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeletePostRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListComments(ctx context.Context, in *moe.AdminListCommentsReq, opts ...grpc.CallOption) (*moe.AdminListCommentsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListComments(ctx, adminv1.AdminListCommentsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListCommentsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteComment(ctx context.Context, in *moe.AdminDeleteCommentReq, opts ...grpc.CallOption) (*moe.AdminDeleteCommentResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteComment(ctx, adminv1.AdminDeleteCommentReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteCommentRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListGroups(ctx context.Context, in *moe.AdminListGroupsReq, opts ...grpc.CallOption) (*moe.AdminListGroupsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListGroups(ctx, adminv1.AdminListGroupsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListGroupsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteGroup(ctx context.Context, in *moe.AdminDeleteGroupReq, opts ...grpc.CallOption) (*moe.AdminDeleteGroupResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteGroup(ctx, adminv1.AdminDeleteGroupReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteGroupRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListFriendRequests(ctx context.Context, in *moe.AdminListFriendRequestsReq, opts ...grpc.CallOption) (*moe.AdminListFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListFriendRequests(ctx, adminv1.AdminListFriendRequestsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListFriendRequestsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListPostReports(ctx context.Context, in *moe.AdminListPostReportsReq, opts ...grpc.CallOption) (*moe.AdminListPostReportsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListPostReports(ctx, adminv1.AdminListPostReportsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListPostReportsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListMemories(ctx context.Context, in *moe.AdminListMemoriesReq, opts ...grpc.CallOption) (*moe.AdminListMemoriesResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListMemories(ctx, adminv1.AdminListMemoriesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListMemoriesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteMemory(ctx context.Context, in *moe.AdminDeleteMemoryReq, opts ...grpc.CallOption) (*moe.AdminDeleteMemoryResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteMemory(ctx, adminv1.AdminDeleteMemoryReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteMemoryRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetMemoryStats(ctx context.Context, in *moe.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*moe.AdminGetMemoryStatsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetMemoryStats(ctx, adminv1.AdminGetMemoryStatsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetMemoryStatsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListAccounts(ctx context.Context, in *moe.AdminListAccountsReq, opts ...grpc.CallOption) (*moe.AdminListAccountsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAccounts(ctx, adminv1.AdminListAccountsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListAccountsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminCreateAccount(ctx context.Context, in *moe.AdminCreateAccountReq, opts ...grpc.CallOption) (*moe.AdminCreateAccountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateAccount(ctx, adminv1.AdminCreateAccountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminCreateAccountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateAccount(ctx context.Context, in *moe.AdminUpdateAccountReq, opts ...grpc.CallOption) (*moe.AdminUpdateAccountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateAccount(ctx, adminv1.AdminUpdateAccountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateAccountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDeleteAccount(ctx context.Context, in *moe.AdminDeleteAccountReq, opts ...grpc.CallOption) (*moe.AdminDeleteAccountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAccount(ctx, adminv1.AdminDeleteAccountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDeleteAccountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetUser(ctx context.Context, in *moe.AdminGetUserReq, opts ...grpc.CallOption) (*moe.AdminGetUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUser(ctx, adminv1.AdminGetUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminGetUserProfile(ctx context.Context, in *moe.AdminGetUserProfileReq, opts ...grpc.CallOption) (*moe.AdminGetUserProfileResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserProfile(ctx, adminv1.AdminGetUserProfileReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminGetUserProfileRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminDashboard(ctx context.Context, in *moe.AdminDashboardReq, opts ...grpc.CallOption) (*moe.AdminDashboardResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Dashboard(ctx, adminv1.AdminDashboardReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminDashboardRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListLevelConfigs(ctx context.Context, in *moe.AdminListLevelConfigsReq, opts ...grpc.CallOption) (*moe.AdminListLevelConfigsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListLevelConfigs(ctx, adminv1.AdminListLevelConfigsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListLevelConfigsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateLevelConfig(ctx context.Context, in *moe.AdminUpdateLevelConfigReq, opts ...grpc.CallOption) (*moe.AdminUpdateLevelConfigResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateLevelConfig(ctx, adminv1.AdminUpdateLevelConfigReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateLevelConfigRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapLevels(ctx context.Context, in *moe.AdminBootstrapLevelsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapLevelsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.BootstrapLevels(ctx, adminv1.AdminBootstrapLevelsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapLevelsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListCheckInRewards(ctx context.Context, in *moe.AdminListCheckInRewardsReq, opts ...grpc.CallOption) (*moe.AdminListCheckInRewardsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListCheckInRewards(ctx, adminv1.AdminListCheckInRewardsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListCheckInRewardsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminUpdateCheckInReward(ctx context.Context, in *moe.AdminUpdateCheckInRewardReq, opts ...grpc.CallOption) (*moe.AdminUpdateCheckInRewardResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateCheckInReward(ctx, adminv1.AdminUpdateCheckInRewardReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminUpdateCheckInRewardRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListVipOrders(ctx context.Context, in *moe.AdminListVipOrdersReq, opts ...grpc.CallOption) (*moe.AdminListVipOrdersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListVipOrders(ctx, adminv1.AdminListVipOrdersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListVipOrdersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminListGiftPurchaseOrders(ctx context.Context, in *moe.AdminListGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*moe.AdminListGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListGiftPurchaseOrders(ctx, adminv1.AdminListGiftPurchaseOrdersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminListGiftPurchaseOrdersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
