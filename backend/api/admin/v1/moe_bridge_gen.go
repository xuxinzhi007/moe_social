package adminv1

import (
	"backend/rpc/pb/moe"

	"google.golang.org/protobuf/proto"
)

func cloneTo[S, D proto.Message](src S, newDst func() D) D {
	var zero D
	if any(src) == nil {
		return zero
	}
	dst := newDst()
	b, err := proto.Marshal(src)
	if err != nil {
		return zero
	}
	if err := proto.Unmarshal(b, dst); err != nil {
		return zero
	}
	return dst
}

func AdminAccountItemFromMoe(in *moe.AdminAccountItem) *AdminAccountItem {
	return cloneTo(in, func() *AdminAccountItem { return &AdminAccountItem{} })
}

func AdminAccountItemToMoe(in *AdminAccountItem) *moe.AdminAccountItem {
	return cloneTo(in, func() *moe.AdminAccountItem { return &moe.AdminAccountItem{} })
}

func AdminAchievementItemFromMoe(in *moe.AdminAchievementItem) *AdminAchievementItem {
	return cloneTo(in, func() *AdminAchievementItem { return &AdminAchievementItem{} })
}

func AdminAchievementItemToMoe(in *AdminAchievementItem) *moe.AdminAchievementItem {
	return cloneTo(in, func() *moe.AdminAchievementItem { return &moe.AdminAchievementItem{} })
}

func AdminAiAgentItemFromMoe(in *moe.AdminAiAgentItem) *AdminAiAgentItem {
	return cloneTo(in, func() *AdminAiAgentItem { return &AdminAiAgentItem{} })
}

func AdminAiAgentItemToMoe(in *AdminAiAgentItem) *moe.AdminAiAgentItem {
	return cloneTo(in, func() *moe.AdminAiAgentItem { return &moe.AdminAiAgentItem{} })
}

func AdminAiChatMessageItemFromMoe(in *moe.AdminAiChatMessageItem) *AdminAiChatMessageItem {
	return cloneTo(in, func() *AdminAiChatMessageItem { return &AdminAiChatMessageItem{} })
}

func AdminAiChatMessageItemToMoe(in *AdminAiChatMessageItem) *moe.AdminAiChatMessageItem {
	return cloneTo(in, func() *moe.AdminAiChatMessageItem { return &moe.AdminAiChatMessageItem{} })
}

func AdminAiChatSessionItemFromMoe(in *moe.AdminAiChatSessionItem) *AdminAiChatSessionItem {
	return cloneTo(in, func() *AdminAiChatSessionItem { return &AdminAiChatSessionItem{} })
}

func AdminAiChatSessionItemToMoe(in *AdminAiChatSessionItem) *moe.AdminAiChatSessionItem {
	return cloneTo(in, func() *moe.AdminAiChatSessionItem { return &moe.AdminAiChatSessionItem{} })
}

func AdminAnalyticsOverviewRespFromMoe(in *moe.AdminAnalyticsOverviewResp) *AdminAnalyticsOverviewResp {
	return cloneTo(in, func() *AdminAnalyticsOverviewResp { return &AdminAnalyticsOverviewResp{} })
}

func AdminAnalyticsOverviewRespToMoe(in *AdminAnalyticsOverviewResp) *moe.AdminAnalyticsOverviewResp {
	return cloneTo(in, func() *moe.AdminAnalyticsOverviewResp { return &moe.AdminAnalyticsOverviewResp{} })
}

func AdminAnnouncementItemFromMoe(in *moe.AdminAnnouncementItem) *AdminAnnouncementItem {
	return cloneTo(in, func() *AdminAnnouncementItem { return &AdminAnnouncementItem{} })
}

func AdminAnnouncementItemToMoe(in *AdminAnnouncementItem) *moe.AdminAnnouncementItem {
	return cloneTo(in, func() *moe.AdminAnnouncementItem { return &moe.AdminAnnouncementItem{} })
}

func AdminAuditLogItemFromMoe(in *moe.AdminAuditLogItem) *AdminAuditLogItem {
	return cloneTo(in, func() *AdminAuditLogItem { return &AdminAuditLogItem{} })
}

func AdminAuditLogItemToMoe(in *AdminAuditLogItem) *moe.AdminAuditLogItem {
	return cloneTo(in, func() *moe.AdminAuditLogItem { return &moe.AdminAuditLogItem{} })
}

func AdminBootstrapAccountReqFromMoe(in *moe.AdminBootstrapAccountReq) *AdminBootstrapAccountReq {
	return cloneTo(in, func() *AdminBootstrapAccountReq { return &AdminBootstrapAccountReq{} })
}

func AdminBootstrapAccountReqToMoe(in *AdminBootstrapAccountReq) *moe.AdminBootstrapAccountReq {
	return cloneTo(in, func() *moe.AdminBootstrapAccountReq { return &moe.AdminBootstrapAccountReq{} })
}

func AdminBootstrapAccountRespFromMoe(in *moe.AdminBootstrapAccountResp) *AdminBootstrapAccountResp {
	return cloneTo(in, func() *AdminBootstrapAccountResp { return &AdminBootstrapAccountResp{} })
}

func AdminBootstrapAccountRespToMoe(in *AdminBootstrapAccountResp) *moe.AdminBootstrapAccountResp {
	return cloneTo(in, func() *moe.AdminBootstrapAccountResp { return &moe.AdminBootstrapAccountResp{} })
}

func AdminBootstrapAchievementsReqFromMoe(in *moe.AdminBootstrapAchievementsReq) *AdminBootstrapAchievementsReq {
	return cloneTo(in, func() *AdminBootstrapAchievementsReq { return &AdminBootstrapAchievementsReq{} })
}

func AdminBootstrapAchievementsReqToMoe(in *AdminBootstrapAchievementsReq) *moe.AdminBootstrapAchievementsReq {
	return cloneTo(in, func() *moe.AdminBootstrapAchievementsReq { return &moe.AdminBootstrapAchievementsReq{} })
}

func AdminBootstrapAchievementsRespFromMoe(in *moe.AdminBootstrapAchievementsResp) *AdminBootstrapAchievementsResp {
	return cloneTo(in, func() *AdminBootstrapAchievementsResp { return &AdminBootstrapAchievementsResp{} })
}

func AdminBootstrapAchievementsRespToMoe(in *AdminBootstrapAchievementsResp) *moe.AdminBootstrapAchievementsResp {
	return cloneTo(in, func() *moe.AdminBootstrapAchievementsResp { return &moe.AdminBootstrapAchievementsResp{} })
}

func AdminBootstrapGiftsReqFromMoe(in *moe.AdminBootstrapGiftsReq) *AdminBootstrapGiftsReq {
	return cloneTo(in, func() *AdminBootstrapGiftsReq { return &AdminBootstrapGiftsReq{} })
}

func AdminBootstrapGiftsReqToMoe(in *AdminBootstrapGiftsReq) *moe.AdminBootstrapGiftsReq {
	return cloneTo(in, func() *moe.AdminBootstrapGiftsReq { return &moe.AdminBootstrapGiftsReq{} })
}

func AdminBootstrapGiftsRespFromMoe(in *moe.AdminBootstrapGiftsResp) *AdminBootstrapGiftsResp {
	return cloneTo(in, func() *AdminBootstrapGiftsResp { return &AdminBootstrapGiftsResp{} })
}

func AdminBootstrapGiftsRespToMoe(in *AdminBootstrapGiftsResp) *moe.AdminBootstrapGiftsResp {
	return cloneTo(in, func() *moe.AdminBootstrapGiftsResp { return &moe.AdminBootstrapGiftsResp{} })
}

func AdminBootstrapLevelsReqFromMoe(in *moe.AdminBootstrapLevelsReq) *AdminBootstrapLevelsReq {
	return cloneTo(in, func() *AdminBootstrapLevelsReq { return &AdminBootstrapLevelsReq{} })
}

func AdminBootstrapLevelsReqToMoe(in *AdminBootstrapLevelsReq) *moe.AdminBootstrapLevelsReq {
	return cloneTo(in, func() *moe.AdminBootstrapLevelsReq { return &moe.AdminBootstrapLevelsReq{} })
}

func AdminBootstrapLevelsRespFromMoe(in *moe.AdminBootstrapLevelsResp) *AdminBootstrapLevelsResp {
	return cloneTo(in, func() *AdminBootstrapLevelsResp { return &AdminBootstrapLevelsResp{} })
}

func AdminBootstrapLevelsRespToMoe(in *AdminBootstrapLevelsResp) *moe.AdminBootstrapLevelsResp {
	return cloneTo(in, func() *moe.AdminBootstrapLevelsResp { return &moe.AdminBootstrapLevelsResp{} })
}

func AdminBootstrapMenusReqFromMoe(in *moe.AdminBootstrapMenusReq) *AdminBootstrapMenusReq {
	return cloneTo(in, func() *AdminBootstrapMenusReq { return &AdminBootstrapMenusReq{} })
}

func AdminBootstrapMenusReqToMoe(in *AdminBootstrapMenusReq) *moe.AdminBootstrapMenusReq {
	return cloneTo(in, func() *moe.AdminBootstrapMenusReq { return &moe.AdminBootstrapMenusReq{} })
}

func AdminBootstrapMenusRespFromMoe(in *moe.AdminBootstrapMenusResp) *AdminBootstrapMenusResp {
	return cloneTo(in, func() *AdminBootstrapMenusResp { return &AdminBootstrapMenusResp{} })
}

func AdminBootstrapMenusRespToMoe(in *AdminBootstrapMenusResp) *moe.AdminBootstrapMenusResp {
	return cloneTo(in, func() *moe.AdminBootstrapMenusResp { return &moe.AdminBootstrapMenusResp{} })
}

func AdminBootstrapTopicTagsReqFromMoe(in *moe.AdminBootstrapTopicTagsReq) *AdminBootstrapTopicTagsReq {
	return cloneTo(in, func() *AdminBootstrapTopicTagsReq { return &AdminBootstrapTopicTagsReq{} })
}

func AdminBootstrapTopicTagsReqToMoe(in *AdminBootstrapTopicTagsReq) *moe.AdminBootstrapTopicTagsReq {
	return cloneTo(in, func() *moe.AdminBootstrapTopicTagsReq { return &moe.AdminBootstrapTopicTagsReq{} })
}

func AdminBootstrapTopicTagsRespFromMoe(in *moe.AdminBootstrapTopicTagsResp) *AdminBootstrapTopicTagsResp {
	return cloneTo(in, func() *AdminBootstrapTopicTagsResp { return &AdminBootstrapTopicTagsResp{} })
}

func AdminBootstrapTopicTagsRespToMoe(in *AdminBootstrapTopicTagsResp) *moe.AdminBootstrapTopicTagsResp {
	return cloneTo(in, func() *moe.AdminBootstrapTopicTagsResp { return &moe.AdminBootstrapTopicTagsResp{} })
}

func AdminBootstrapVipPlansReqFromMoe(in *moe.AdminBootstrapVipPlansReq) *AdminBootstrapVipPlansReq {
	return cloneTo(in, func() *AdminBootstrapVipPlansReq { return &AdminBootstrapVipPlansReq{} })
}

func AdminBootstrapVipPlansReqToMoe(in *AdminBootstrapVipPlansReq) *moe.AdminBootstrapVipPlansReq {
	return cloneTo(in, func() *moe.AdminBootstrapVipPlansReq { return &moe.AdminBootstrapVipPlansReq{} })
}

func AdminBootstrapVipPlansRespFromMoe(in *moe.AdminBootstrapVipPlansResp) *AdminBootstrapVipPlansResp {
	return cloneTo(in, func() *AdminBootstrapVipPlansResp { return &AdminBootstrapVipPlansResp{} })
}

func AdminBootstrapVipPlansRespToMoe(in *AdminBootstrapVipPlansResp) *moe.AdminBootstrapVipPlansResp {
	return cloneTo(in, func() *moe.AdminBootstrapVipPlansResp { return &moe.AdminBootstrapVipPlansResp{} })
}

func AdminBroadcastNotificationReqFromMoe(in *moe.AdminBroadcastNotificationReq) *AdminBroadcastNotificationReq {
	return cloneTo(in, func() *AdminBroadcastNotificationReq { return &AdminBroadcastNotificationReq{} })
}

func AdminBroadcastNotificationReqToMoe(in *AdminBroadcastNotificationReq) *moe.AdminBroadcastNotificationReq {
	return cloneTo(in, func() *moe.AdminBroadcastNotificationReq { return &moe.AdminBroadcastNotificationReq{} })
}

func AdminBroadcastNotificationRespFromMoe(in *moe.AdminBroadcastNotificationResp) *AdminBroadcastNotificationResp {
	return cloneTo(in, func() *AdminBroadcastNotificationResp { return &AdminBroadcastNotificationResp{} })
}

func AdminBroadcastNotificationRespToMoe(in *AdminBroadcastNotificationResp) *moe.AdminBroadcastNotificationResp {
	return cloneTo(in, func() *moe.AdminBroadcastNotificationResp { return &moe.AdminBroadcastNotificationResp{} })
}

func AdminCheckInRewardItemFromMoe(in *moe.AdminCheckInRewardItem) *AdminCheckInRewardItem {
	return cloneTo(in, func() *AdminCheckInRewardItem { return &AdminCheckInRewardItem{} })
}

func AdminCheckInRewardItemToMoe(in *AdminCheckInRewardItem) *moe.AdminCheckInRewardItem {
	return cloneTo(in, func() *moe.AdminCheckInRewardItem { return &moe.AdminCheckInRewardItem{} })
}

func AdminCreateAccountReqFromMoe(in *moe.AdminCreateAccountReq) *AdminCreateAccountReq {
	return cloneTo(in, func() *AdminCreateAccountReq { return &AdminCreateAccountReq{} })
}

func AdminCreateAccountReqToMoe(in *AdminCreateAccountReq) *moe.AdminCreateAccountReq {
	return cloneTo(in, func() *moe.AdminCreateAccountReq { return &moe.AdminCreateAccountReq{} })
}

func AdminCreateAccountRespFromMoe(in *moe.AdminCreateAccountResp) *AdminCreateAccountResp {
	return cloneTo(in, func() *AdminCreateAccountResp { return &AdminCreateAccountResp{} })
}

func AdminCreateAccountRespToMoe(in *AdminCreateAccountResp) *moe.AdminCreateAccountResp {
	return cloneTo(in, func() *moe.AdminCreateAccountResp { return &moe.AdminCreateAccountResp{} })
}

func AdminCreateAnnouncementReqFromMoe(in *moe.AdminCreateAnnouncementReq) *AdminCreateAnnouncementReq {
	return cloneTo(in, func() *AdminCreateAnnouncementReq { return &AdminCreateAnnouncementReq{} })
}

func AdminCreateAnnouncementReqToMoe(in *AdminCreateAnnouncementReq) *moe.AdminCreateAnnouncementReq {
	return cloneTo(in, func() *moe.AdminCreateAnnouncementReq { return &moe.AdminCreateAnnouncementReq{} })
}

func AdminCreateAnnouncementRespFromMoe(in *moe.AdminCreateAnnouncementResp) *AdminCreateAnnouncementResp {
	return cloneTo(in, func() *AdminCreateAnnouncementResp { return &AdminCreateAnnouncementResp{} })
}

func AdminCreateAnnouncementRespToMoe(in *AdminCreateAnnouncementResp) *moe.AdminCreateAnnouncementResp {
	return cloneTo(in, func() *moe.AdminCreateAnnouncementResp { return &moe.AdminCreateAnnouncementResp{} })
}

func AdminCreateGiftReqFromMoe(in *moe.AdminCreateGiftReq) *AdminCreateGiftReq {
	return cloneTo(in, func() *AdminCreateGiftReq { return &AdminCreateGiftReq{} })
}

func AdminCreateGiftReqToMoe(in *AdminCreateGiftReq) *moe.AdminCreateGiftReq {
	return cloneTo(in, func() *moe.AdminCreateGiftReq { return &moe.AdminCreateGiftReq{} })
}

func AdminCreateGiftRespFromMoe(in *moe.AdminCreateGiftResp) *AdminCreateGiftResp {
	return cloneTo(in, func() *AdminCreateGiftResp { return &AdminCreateGiftResp{} })
}

func AdminCreateGiftRespToMoe(in *AdminCreateGiftResp) *moe.AdminCreateGiftResp {
	return cloneTo(in, func() *moe.AdminCreateGiftResp { return &moe.AdminCreateGiftResp{} })
}

func AdminCreateTagDictionaryReqFromMoe(in *moe.AdminCreateTagDictionaryReq) *AdminCreateTagDictionaryReq {
	return cloneTo(in, func() *AdminCreateTagDictionaryReq { return &AdminCreateTagDictionaryReq{} })
}

func AdminCreateTagDictionaryReqToMoe(in *AdminCreateTagDictionaryReq) *moe.AdminCreateTagDictionaryReq {
	return cloneTo(in, func() *moe.AdminCreateTagDictionaryReq { return &moe.AdminCreateTagDictionaryReq{} })
}

func AdminCreateTagDictionaryRespFromMoe(in *moe.AdminCreateTagDictionaryResp) *AdminCreateTagDictionaryResp {
	return cloneTo(in, func() *AdminCreateTagDictionaryResp { return &AdminCreateTagDictionaryResp{} })
}

func AdminCreateTagDictionaryRespToMoe(in *AdminCreateTagDictionaryResp) *moe.AdminCreateTagDictionaryResp {
	return cloneTo(in, func() *moe.AdminCreateTagDictionaryResp { return &moe.AdminCreateTagDictionaryResp{} })
}

func AdminCreateTopicTagReqFromMoe(in *moe.AdminCreateTopicTagReq) *AdminCreateTopicTagReq {
	return cloneTo(in, func() *AdminCreateTopicTagReq { return &AdminCreateTopicTagReq{} })
}

func AdminCreateTopicTagReqToMoe(in *AdminCreateTopicTagReq) *moe.AdminCreateTopicTagReq {
	return cloneTo(in, func() *moe.AdminCreateTopicTagReq { return &moe.AdminCreateTopicTagReq{} })
}

func AdminCreateTopicTagRespFromMoe(in *moe.AdminCreateTopicTagResp) *AdminCreateTopicTagResp {
	return cloneTo(in, func() *AdminCreateTopicTagResp { return &AdminCreateTopicTagResp{} })
}

func AdminCreateTopicTagRespToMoe(in *AdminCreateTopicTagResp) *moe.AdminCreateTopicTagResp {
	return cloneTo(in, func() *moe.AdminCreateTopicTagResp { return &moe.AdminCreateTopicTagResp{} })
}

func AdminCurateMoeBrainReqFromMoe(in *moe.AdminCurateMoeBrainReq) *AdminCurateMoeBrainReq {
	return cloneTo(in, func() *AdminCurateMoeBrainReq { return &AdminCurateMoeBrainReq{} })
}

func AdminCurateMoeBrainReqToMoe(in *AdminCurateMoeBrainReq) *moe.AdminCurateMoeBrainReq {
	return cloneTo(in, func() *moe.AdminCurateMoeBrainReq { return &moe.AdminCurateMoeBrainReq{} })
}

func AdminCurateMoeBrainRespFromMoe(in *moe.AdminCurateMoeBrainResp) *AdminCurateMoeBrainResp {
	return cloneTo(in, func() *AdminCurateMoeBrainResp { return &AdminCurateMoeBrainResp{} })
}

func AdminCurateMoeBrainRespToMoe(in *AdminCurateMoeBrainResp) *moe.AdminCurateMoeBrainResp {
	return cloneTo(in, func() *moe.AdminCurateMoeBrainResp { return &moe.AdminCurateMoeBrainResp{} })
}

func AdminDashboardReqFromMoe(in *moe.AdminDashboardReq) *AdminDashboardReq {
	return cloneTo(in, func() *AdminDashboardReq { return &AdminDashboardReq{} })
}

func AdminDashboardReqToMoe(in *AdminDashboardReq) *moe.AdminDashboardReq {
	return cloneTo(in, func() *moe.AdminDashboardReq { return &moe.AdminDashboardReq{} })
}

func AdminDashboardRespFromMoe(in *moe.AdminDashboardResp) *AdminDashboardResp {
	return cloneTo(in, func() *AdminDashboardResp { return &AdminDashboardResp{} })
}

func AdminDashboardRespToMoe(in *AdminDashboardResp) *moe.AdminDashboardResp {
	return cloneTo(in, func() *moe.AdminDashboardResp { return &moe.AdminDashboardResp{} })
}

func AdminDayStatFromMoe(in *moe.AdminDayStat) *AdminDayStat {
	return cloneTo(in, func() *AdminDayStat { return &AdminDayStat{} })
}

func AdminDayStatToMoe(in *AdminDayStat) *moe.AdminDayStat {
	return cloneTo(in, func() *moe.AdminDayStat { return &moe.AdminDayStat{} })
}

func AdminDedupeGiftsReqFromMoe(in *moe.AdminDedupeGiftsReq) *AdminDedupeGiftsReq {
	return cloneTo(in, func() *AdminDedupeGiftsReq { return &AdminDedupeGiftsReq{} })
}

func AdminDedupeGiftsReqToMoe(in *AdminDedupeGiftsReq) *moe.AdminDedupeGiftsReq {
	return cloneTo(in, func() *moe.AdminDedupeGiftsReq { return &moe.AdminDedupeGiftsReq{} })
}

func AdminDedupeGiftsRespFromMoe(in *moe.AdminDedupeGiftsResp) *AdminDedupeGiftsResp {
	return cloneTo(in, func() *AdminDedupeGiftsResp { return &AdminDedupeGiftsResp{} })
}

func AdminDedupeGiftsRespToMoe(in *AdminDedupeGiftsResp) *moe.AdminDedupeGiftsResp {
	return cloneTo(in, func() *moe.AdminDedupeGiftsResp { return &moe.AdminDedupeGiftsResp{} })
}

func AdminDeleteAccountReqFromMoe(in *moe.AdminDeleteAccountReq) *AdminDeleteAccountReq {
	return cloneTo(in, func() *AdminDeleteAccountReq { return &AdminDeleteAccountReq{} })
}

func AdminDeleteAccountReqToMoe(in *AdminDeleteAccountReq) *moe.AdminDeleteAccountReq {
	return cloneTo(in, func() *moe.AdminDeleteAccountReq { return &moe.AdminDeleteAccountReq{} })
}

func AdminDeleteAccountRespFromMoe(in *moe.AdminDeleteAccountResp) *AdminDeleteAccountResp {
	return cloneTo(in, func() *AdminDeleteAccountResp { return &AdminDeleteAccountResp{} })
}

func AdminDeleteAccountRespToMoe(in *AdminDeleteAccountResp) *moe.AdminDeleteAccountResp {
	return cloneTo(in, func() *moe.AdminDeleteAccountResp { return &moe.AdminDeleteAccountResp{} })
}

func AdminDeleteAiAgentReqFromMoe(in *moe.AdminDeleteAiAgentReq) *AdminDeleteAiAgentReq {
	return cloneTo(in, func() *AdminDeleteAiAgentReq { return &AdminDeleteAiAgentReq{} })
}

func AdminDeleteAiAgentReqToMoe(in *AdminDeleteAiAgentReq) *moe.AdminDeleteAiAgentReq {
	return cloneTo(in, func() *moe.AdminDeleteAiAgentReq { return &moe.AdminDeleteAiAgentReq{} })
}

func AdminDeleteAiAgentRespFromMoe(in *moe.AdminDeleteAiAgentResp) *AdminDeleteAiAgentResp {
	return cloneTo(in, func() *AdminDeleteAiAgentResp { return &AdminDeleteAiAgentResp{} })
}

func AdminDeleteAiAgentRespToMoe(in *AdminDeleteAiAgentResp) *moe.AdminDeleteAiAgentResp {
	return cloneTo(in, func() *moe.AdminDeleteAiAgentResp { return &moe.AdminDeleteAiAgentResp{} })
}

func AdminDeleteAnnouncementReqFromMoe(in *moe.AdminDeleteAnnouncementReq) *AdminDeleteAnnouncementReq {
	return cloneTo(in, func() *AdminDeleteAnnouncementReq { return &AdminDeleteAnnouncementReq{} })
}

func AdminDeleteAnnouncementReqToMoe(in *AdminDeleteAnnouncementReq) *moe.AdminDeleteAnnouncementReq {
	return cloneTo(in, func() *moe.AdminDeleteAnnouncementReq { return &moe.AdminDeleteAnnouncementReq{} })
}

func AdminDeleteAnnouncementRespFromMoe(in *moe.AdminDeleteAnnouncementResp) *AdminDeleteAnnouncementResp {
	return cloneTo(in, func() *AdminDeleteAnnouncementResp { return &AdminDeleteAnnouncementResp{} })
}

func AdminDeleteAnnouncementRespToMoe(in *AdminDeleteAnnouncementResp) *moe.AdminDeleteAnnouncementResp {
	return cloneTo(in, func() *moe.AdminDeleteAnnouncementResp { return &moe.AdminDeleteAnnouncementResp{} })
}

func AdminDeleteCommentReqFromMoe(in *moe.AdminDeleteCommentReq) *AdminDeleteCommentReq {
	return cloneTo(in, func() *AdminDeleteCommentReq { return &AdminDeleteCommentReq{} })
}

func AdminDeleteCommentReqToMoe(in *AdminDeleteCommentReq) *moe.AdminDeleteCommentReq {
	return cloneTo(in, func() *moe.AdminDeleteCommentReq { return &moe.AdminDeleteCommentReq{} })
}

func AdminDeleteCommentRespFromMoe(in *moe.AdminDeleteCommentResp) *AdminDeleteCommentResp {
	return cloneTo(in, func() *AdminDeleteCommentResp { return &AdminDeleteCommentResp{} })
}

func AdminDeleteCommentRespToMoe(in *AdminDeleteCommentResp) *moe.AdminDeleteCommentResp {
	return cloneTo(in, func() *moe.AdminDeleteCommentResp { return &moe.AdminDeleteCommentResp{} })
}

func AdminDeleteFollowReqFromMoe(in *moe.AdminDeleteFollowReq) *AdminDeleteFollowReq {
	return cloneTo(in, func() *AdminDeleteFollowReq { return &AdminDeleteFollowReq{} })
}

func AdminDeleteFollowReqToMoe(in *AdminDeleteFollowReq) *moe.AdminDeleteFollowReq {
	return cloneTo(in, func() *moe.AdminDeleteFollowReq { return &moe.AdminDeleteFollowReq{} })
}

func AdminDeleteFollowRespFromMoe(in *moe.AdminDeleteFollowResp) *AdminDeleteFollowResp {
	return cloneTo(in, func() *AdminDeleteFollowResp { return &AdminDeleteFollowResp{} })
}

func AdminDeleteFollowRespToMoe(in *AdminDeleteFollowResp) *moe.AdminDeleteFollowResp {
	return cloneTo(in, func() *moe.AdminDeleteFollowResp { return &moe.AdminDeleteFollowResp{} })
}

func AdminDeleteGiftReqFromMoe(in *moe.AdminDeleteGiftReq) *AdminDeleteGiftReq {
	return cloneTo(in, func() *AdminDeleteGiftReq { return &AdminDeleteGiftReq{} })
}

func AdminDeleteGiftReqToMoe(in *AdminDeleteGiftReq) *moe.AdminDeleteGiftReq {
	return cloneTo(in, func() *moe.AdminDeleteGiftReq { return &moe.AdminDeleteGiftReq{} })
}

func AdminDeleteGiftRespFromMoe(in *moe.AdminDeleteGiftResp) *AdminDeleteGiftResp {
	return cloneTo(in, func() *AdminDeleteGiftResp { return &AdminDeleteGiftResp{} })
}

func AdminDeleteGiftRespToMoe(in *AdminDeleteGiftResp) *moe.AdminDeleteGiftResp {
	return cloneTo(in, func() *moe.AdminDeleteGiftResp { return &moe.AdminDeleteGiftResp{} })
}

func AdminDeleteGroupReqFromMoe(in *moe.AdminDeleteGroupReq) *AdminDeleteGroupReq {
	return cloneTo(in, func() *AdminDeleteGroupReq { return &AdminDeleteGroupReq{} })
}

func AdminDeleteGroupReqToMoe(in *AdminDeleteGroupReq) *moe.AdminDeleteGroupReq {
	return cloneTo(in, func() *moe.AdminDeleteGroupReq { return &moe.AdminDeleteGroupReq{} })
}

func AdminDeleteGroupRespFromMoe(in *moe.AdminDeleteGroupResp) *AdminDeleteGroupResp {
	return cloneTo(in, func() *AdminDeleteGroupResp { return &AdminDeleteGroupResp{} })
}

func AdminDeleteGroupRespToMoe(in *AdminDeleteGroupResp) *moe.AdminDeleteGroupResp {
	return cloneTo(in, func() *moe.AdminDeleteGroupResp { return &moe.AdminDeleteGroupResp{} })
}

func AdminDeleteMemoryReqFromMoe(in *moe.AdminDeleteMemoryReq) *AdminDeleteMemoryReq {
	return cloneTo(in, func() *AdminDeleteMemoryReq { return &AdminDeleteMemoryReq{} })
}

func AdminDeleteMemoryReqToMoe(in *AdminDeleteMemoryReq) *moe.AdminDeleteMemoryReq {
	return cloneTo(in, func() *moe.AdminDeleteMemoryReq { return &moe.AdminDeleteMemoryReq{} })
}

func AdminDeleteMemoryRespFromMoe(in *moe.AdminDeleteMemoryResp) *AdminDeleteMemoryResp {
	return cloneTo(in, func() *AdminDeleteMemoryResp { return &AdminDeleteMemoryResp{} })
}

func AdminDeleteMemoryRespToMoe(in *AdminDeleteMemoryResp) *moe.AdminDeleteMemoryResp {
	return cloneTo(in, func() *moe.AdminDeleteMemoryResp { return &moe.AdminDeleteMemoryResp{} })
}

func AdminDeleteMenuReqFromMoe(in *moe.AdminDeleteMenuReq) *AdminDeleteMenuReq {
	return cloneTo(in, func() *AdminDeleteMenuReq { return &AdminDeleteMenuReq{} })
}

func AdminDeleteMenuReqToMoe(in *AdminDeleteMenuReq) *moe.AdminDeleteMenuReq {
	return cloneTo(in, func() *moe.AdminDeleteMenuReq { return &moe.AdminDeleteMenuReq{} })
}

func AdminDeleteMenuRespFromMoe(in *moe.AdminDeleteMenuResp) *AdminDeleteMenuResp {
	return cloneTo(in, func() *AdminDeleteMenuResp { return &AdminDeleteMenuResp{} })
}

func AdminDeleteMenuRespToMoe(in *AdminDeleteMenuResp) *moe.AdminDeleteMenuResp {
	return cloneTo(in, func() *moe.AdminDeleteMenuResp { return &moe.AdminDeleteMenuResp{} })
}

func AdminDeleteMoeBrainEpisodeReqFromMoe(in *moe.AdminDeleteMoeBrainEpisodeReq) *AdminDeleteMoeBrainEpisodeReq {
	return cloneTo(in, func() *AdminDeleteMoeBrainEpisodeReq { return &AdminDeleteMoeBrainEpisodeReq{} })
}

func AdminDeleteMoeBrainEpisodeReqToMoe(in *AdminDeleteMoeBrainEpisodeReq) *moe.AdminDeleteMoeBrainEpisodeReq {
	return cloneTo(in, func() *moe.AdminDeleteMoeBrainEpisodeReq { return &moe.AdminDeleteMoeBrainEpisodeReq{} })
}

func AdminDeleteMoeBrainEpisodeRespFromMoe(in *moe.AdminDeleteMoeBrainEpisodeResp) *AdminDeleteMoeBrainEpisodeResp {
	return cloneTo(in, func() *AdminDeleteMoeBrainEpisodeResp { return &AdminDeleteMoeBrainEpisodeResp{} })
}

func AdminDeleteMoeBrainEpisodeRespToMoe(in *AdminDeleteMoeBrainEpisodeResp) *moe.AdminDeleteMoeBrainEpisodeResp {
	return cloneTo(in, func() *moe.AdminDeleteMoeBrainEpisodeResp { return &moe.AdminDeleteMoeBrainEpisodeResp{} })
}

func AdminDeletePostReqFromMoe(in *moe.AdminDeletePostReq) *AdminDeletePostReq {
	return cloneTo(in, func() *AdminDeletePostReq { return &AdminDeletePostReq{} })
}

func AdminDeletePostReqToMoe(in *AdminDeletePostReq) *moe.AdminDeletePostReq {
	return cloneTo(in, func() *moe.AdminDeletePostReq { return &moe.AdminDeletePostReq{} })
}

func AdminDeletePostRespFromMoe(in *moe.AdminDeletePostResp) *AdminDeletePostResp {
	return cloneTo(in, func() *AdminDeletePostResp { return &AdminDeletePostResp{} })
}

func AdminDeletePostRespToMoe(in *AdminDeletePostResp) *moe.AdminDeletePostResp {
	return cloneTo(in, func() *moe.AdminDeletePostResp { return &moe.AdminDeletePostResp{} })
}

func AdminDeleteTagDictionaryReqFromMoe(in *moe.AdminDeleteTagDictionaryReq) *AdminDeleteTagDictionaryReq {
	return cloneTo(in, func() *AdminDeleteTagDictionaryReq { return &AdminDeleteTagDictionaryReq{} })
}

func AdminDeleteTagDictionaryReqToMoe(in *AdminDeleteTagDictionaryReq) *moe.AdminDeleteTagDictionaryReq {
	return cloneTo(in, func() *moe.AdminDeleteTagDictionaryReq { return &moe.AdminDeleteTagDictionaryReq{} })
}

func AdminDeleteTagDictionaryRespFromMoe(in *moe.AdminDeleteTagDictionaryResp) *AdminDeleteTagDictionaryResp {
	return cloneTo(in, func() *AdminDeleteTagDictionaryResp { return &AdminDeleteTagDictionaryResp{} })
}

func AdminDeleteTagDictionaryRespToMoe(in *AdminDeleteTagDictionaryResp) *moe.AdminDeleteTagDictionaryResp {
	return cloneTo(in, func() *moe.AdminDeleteTagDictionaryResp { return &moe.AdminDeleteTagDictionaryResp{} })
}

func AdminDeleteTopicTagReqFromMoe(in *moe.AdminDeleteTopicTagReq) *AdminDeleteTopicTagReq {
	return cloneTo(in, func() *AdminDeleteTopicTagReq { return &AdminDeleteTopicTagReq{} })
}

func AdminDeleteTopicTagReqToMoe(in *AdminDeleteTopicTagReq) *moe.AdminDeleteTopicTagReq {
	return cloneTo(in, func() *moe.AdminDeleteTopicTagReq { return &moe.AdminDeleteTopicTagReq{} })
}

func AdminDeleteTopicTagRespFromMoe(in *moe.AdminDeleteTopicTagResp) *AdminDeleteTopicTagResp {
	return cloneTo(in, func() *AdminDeleteTopicTagResp { return &AdminDeleteTopicTagResp{} })
}

func AdminDeleteTopicTagRespToMoe(in *AdminDeleteTopicTagResp) *moe.AdminDeleteTopicTagResp {
	return cloneTo(in, func() *moe.AdminDeleteTopicTagResp { return &moe.AdminDeleteTopicTagResp{} })
}

func AdminDeleteVipPlanReqFromMoe(in *moe.AdminDeleteVipPlanReq) *AdminDeleteVipPlanReq {
	return cloneTo(in, func() *AdminDeleteVipPlanReq { return &AdminDeleteVipPlanReq{} })
}

func AdminDeleteVipPlanReqToMoe(in *AdminDeleteVipPlanReq) *moe.AdminDeleteVipPlanReq {
	return cloneTo(in, func() *moe.AdminDeleteVipPlanReq { return &moe.AdminDeleteVipPlanReq{} })
}

func AdminDeleteVipPlanRespFromMoe(in *moe.AdminDeleteVipPlanResp) *AdminDeleteVipPlanResp {
	return cloneTo(in, func() *AdminDeleteVipPlanResp { return &AdminDeleteVipPlanResp{} })
}

func AdminDeleteVipPlanRespToMoe(in *AdminDeleteVipPlanResp) *moe.AdminDeleteVipPlanResp {
	return cloneTo(in, func() *moe.AdminDeleteVipPlanResp { return &moe.AdminDeleteVipPlanResp{} })
}

func AdminExportAiChatMessagesReqFromMoe(in *moe.AdminExportAiChatMessagesReq) *AdminExportAiChatMessagesReq {
	return cloneTo(in, func() *AdminExportAiChatMessagesReq { return &AdminExportAiChatMessagesReq{} })
}

func AdminExportAiChatMessagesReqToMoe(in *AdminExportAiChatMessagesReq) *moe.AdminExportAiChatMessagesReq {
	return cloneTo(in, func() *moe.AdminExportAiChatMessagesReq { return &moe.AdminExportAiChatMessagesReq{} })
}

func AdminExportAiChatMessagesRespFromMoe(in *moe.AdminExportAiChatMessagesResp) *AdminExportAiChatMessagesResp {
	return cloneTo(in, func() *AdminExportAiChatMessagesResp { return &AdminExportAiChatMessagesResp{} })
}

func AdminExportAiChatMessagesRespToMoe(in *AdminExportAiChatMessagesResp) *moe.AdminExportAiChatMessagesResp {
	return cloneTo(in, func() *moe.AdminExportAiChatMessagesResp { return &moe.AdminExportAiChatMessagesResp{} })
}

func AdminFollowItemFromMoe(in *moe.AdminFollowItem) *AdminFollowItem {
	return cloneTo(in, func() *AdminFollowItem { return &AdminFollowItem{} })
}

func AdminFollowItemToMoe(in *AdminFollowItem) *moe.AdminFollowItem {
	return cloneTo(in, func() *moe.AdminFollowItem { return &moe.AdminFollowItem{} })
}

func AdminFriendRequestItemFromMoe(in *moe.AdminFriendRequestItem) *AdminFriendRequestItem {
	return cloneTo(in, func() *AdminFriendRequestItem { return &AdminFriendRequestItem{} })
}

func AdminFriendRequestItemToMoe(in *AdminFriendRequestItem) *moe.AdminFriendRequestItem {
	return cloneTo(in, func() *moe.AdminFriendRequestItem { return &moe.AdminFriendRequestItem{} })
}

func AdminGetAnnouncementReqFromMoe(in *moe.AdminGetAnnouncementReq) *AdminGetAnnouncementReq {
	return cloneTo(in, func() *AdminGetAnnouncementReq { return &AdminGetAnnouncementReq{} })
}

func AdminGetAnnouncementReqToMoe(in *AdminGetAnnouncementReq) *moe.AdminGetAnnouncementReq {
	return cloneTo(in, func() *moe.AdminGetAnnouncementReq { return &moe.AdminGetAnnouncementReq{} })
}

func AdminGetAnnouncementRespFromMoe(in *moe.AdminGetAnnouncementResp) *AdminGetAnnouncementResp {
	return cloneTo(in, func() *AdminGetAnnouncementResp { return &AdminGetAnnouncementResp{} })
}

func AdminGetAnnouncementRespToMoe(in *AdminGetAnnouncementResp) *moe.AdminGetAnnouncementResp {
	return cloneTo(in, func() *moe.AdminGetAnnouncementResp { return &moe.AdminGetAnnouncementResp{} })
}

func AdminGetGiftReqFromMoe(in *moe.AdminGetGiftReq) *AdminGetGiftReq {
	return cloneTo(in, func() *AdminGetGiftReq { return &AdminGetGiftReq{} })
}

func AdminGetGiftReqToMoe(in *AdminGetGiftReq) *moe.AdminGetGiftReq {
	return cloneTo(in, func() *moe.AdminGetGiftReq { return &moe.AdminGetGiftReq{} })
}

func AdminGetGiftRespFromMoe(in *moe.AdminGetGiftResp) *AdminGetGiftResp {
	return cloneTo(in, func() *AdminGetGiftResp { return &AdminGetGiftResp{} })
}

func AdminGetGiftRespToMoe(in *AdminGetGiftResp) *moe.AdminGetGiftResp {
	return cloneTo(in, func() *moe.AdminGetGiftResp { return &moe.AdminGetGiftResp{} })
}

func AdminGetGrowthStatsReqFromMoe(in *moe.AdminGetGrowthStatsReq) *AdminGetGrowthStatsReq {
	return cloneTo(in, func() *AdminGetGrowthStatsReq { return &AdminGetGrowthStatsReq{} })
}

func AdminGetGrowthStatsReqToMoe(in *AdminGetGrowthStatsReq) *moe.AdminGetGrowthStatsReq {
	return cloneTo(in, func() *moe.AdminGetGrowthStatsReq { return &moe.AdminGetGrowthStatsReq{} })
}

func AdminGetGrowthStatsRespFromMoe(in *moe.AdminGetGrowthStatsResp) *AdminGetGrowthStatsResp {
	return cloneTo(in, func() *AdminGetGrowthStatsResp { return &AdminGetGrowthStatsResp{} })
}

func AdminGetGrowthStatsRespToMoe(in *AdminGetGrowthStatsResp) *moe.AdminGetGrowthStatsResp {
	return cloneTo(in, func() *moe.AdminGetGrowthStatsResp { return &moe.AdminGetGrowthStatsResp{} })
}

func AdminGetMemoryStatsReqFromMoe(in *moe.AdminGetMemoryStatsReq) *AdminGetMemoryStatsReq {
	return cloneTo(in, func() *AdminGetMemoryStatsReq { return &AdminGetMemoryStatsReq{} })
}

func AdminGetMemoryStatsReqToMoe(in *AdminGetMemoryStatsReq) *moe.AdminGetMemoryStatsReq {
	return cloneTo(in, func() *moe.AdminGetMemoryStatsReq { return &moe.AdminGetMemoryStatsReq{} })
}

func AdminGetMemoryStatsRespFromMoe(in *moe.AdminGetMemoryStatsResp) *AdminGetMemoryStatsResp {
	return cloneTo(in, func() *AdminGetMemoryStatsResp { return &AdminGetMemoryStatsResp{} })
}

func AdminGetMemoryStatsRespToMoe(in *AdminGetMemoryStatsResp) *moe.AdminGetMemoryStatsResp {
	return cloneTo(in, func() *moe.AdminGetMemoryStatsResp { return &moe.AdminGetMemoryStatsResp{} })
}

func AdminGetMoeBrainPipelineReqFromMoe(in *moe.AdminGetMoeBrainPipelineReq) *AdminGetMoeBrainPipelineReq {
	return cloneTo(in, func() *AdminGetMoeBrainPipelineReq { return &AdminGetMoeBrainPipelineReq{} })
}

func AdminGetMoeBrainPipelineReqToMoe(in *AdminGetMoeBrainPipelineReq) *moe.AdminGetMoeBrainPipelineReq {
	return cloneTo(in, func() *moe.AdminGetMoeBrainPipelineReq { return &moe.AdminGetMoeBrainPipelineReq{} })
}

func AdminGetMoeBrainPipelineRespFromMoe(in *moe.AdminGetMoeBrainPipelineResp) *AdminGetMoeBrainPipelineResp {
	return cloneTo(in, func() *AdminGetMoeBrainPipelineResp { return &AdminGetMoeBrainPipelineResp{} })
}

func AdminGetMoeBrainPipelineRespToMoe(in *AdminGetMoeBrainPipelineResp) *moe.AdminGetMoeBrainPipelineResp {
	return cloneTo(in, func() *moe.AdminGetMoeBrainPipelineResp { return &moe.AdminGetMoeBrainPipelineResp{} })
}

func AdminGetMoeBrainReqFromMoe(in *moe.AdminGetMoeBrainReq) *AdminGetMoeBrainReq {
	return cloneTo(in, func() *AdminGetMoeBrainReq { return &AdminGetMoeBrainReq{} })
}

func AdminGetMoeBrainReqToMoe(in *AdminGetMoeBrainReq) *moe.AdminGetMoeBrainReq {
	return cloneTo(in, func() *moe.AdminGetMoeBrainReq { return &moe.AdminGetMoeBrainReq{} })
}

func AdminGetMoeBrainRespFromMoe(in *moe.AdminGetMoeBrainResp) *AdminGetMoeBrainResp {
	return cloneTo(in, func() *AdminGetMoeBrainResp { return &AdminGetMoeBrainResp{} })
}

func AdminGetMoeBrainRespToMoe(in *AdminGetMoeBrainResp) *moe.AdminGetMoeBrainResp {
	return cloneTo(in, func() *moe.AdminGetMoeBrainResp { return &moe.AdminGetMoeBrainResp{} })
}

func AdminGetMoeToolStatsReqFromMoe(in *moe.AdminGetMoeToolStatsReq) *AdminGetMoeToolStatsReq {
	return cloneTo(in, func() *AdminGetMoeToolStatsReq { return &AdminGetMoeToolStatsReq{} })
}

func AdminGetMoeToolStatsReqToMoe(in *AdminGetMoeToolStatsReq) *moe.AdminGetMoeToolStatsReq {
	return cloneTo(in, func() *moe.AdminGetMoeToolStatsReq { return &moe.AdminGetMoeToolStatsReq{} })
}

func AdminGetMoeToolStatsRespFromMoe(in *moe.AdminGetMoeToolStatsResp) *AdminGetMoeToolStatsResp {
	return cloneTo(in, func() *AdminGetMoeToolStatsResp { return &AdminGetMoeToolStatsResp{} })
}

func AdminGetMoeToolStatsRespToMoe(in *AdminGetMoeToolStatsResp) *moe.AdminGetMoeToolStatsResp {
	return cloneTo(in, func() *moe.AdminGetMoeToolStatsResp { return &moe.AdminGetMoeToolStatsResp{} })
}

func AdminGetSchemaCatalogReqFromMoe(in *moe.AdminGetSchemaCatalogReq) *AdminGetSchemaCatalogReq {
	return cloneTo(in, func() *AdminGetSchemaCatalogReq { return &AdminGetSchemaCatalogReq{} })
}

func AdminGetSchemaCatalogReqToMoe(in *AdminGetSchemaCatalogReq) *moe.AdminGetSchemaCatalogReq {
	return cloneTo(in, func() *moe.AdminGetSchemaCatalogReq { return &moe.AdminGetSchemaCatalogReq{} })
}

func AdminGetSchemaCatalogRespFromMoe(in *moe.AdminGetSchemaCatalogResp) *AdminGetSchemaCatalogResp {
	return cloneTo(in, func() *AdminGetSchemaCatalogResp { return &AdminGetSchemaCatalogResp{} })
}

func AdminGetSchemaCatalogRespToMoe(in *AdminGetSchemaCatalogResp) *moe.AdminGetSchemaCatalogResp {
	return cloneTo(in, func() *moe.AdminGetSchemaCatalogResp { return &moe.AdminGetSchemaCatalogResp{} })
}

func AdminGetUserProfileReqFromMoe(in *moe.AdminGetUserProfileReq) *AdminGetUserProfileReq {
	return cloneTo(in, func() *AdminGetUserProfileReq { return &AdminGetUserProfileReq{} })
}

func AdminGetUserProfileReqToMoe(in *AdminGetUserProfileReq) *moe.AdminGetUserProfileReq {
	return cloneTo(in, func() *moe.AdminGetUserProfileReq { return &moe.AdminGetUserProfileReq{} })
}

func AdminGetUserProfileRespFromMoe(in *moe.AdminGetUserProfileResp) *AdminGetUserProfileResp {
	return cloneTo(in, func() *AdminGetUserProfileResp { return &AdminGetUserProfileResp{} })
}

func AdminGetUserProfileRespToMoe(in *AdminGetUserProfileResp) *moe.AdminGetUserProfileResp {
	return cloneTo(in, func() *moe.AdminGetUserProfileResp { return &moe.AdminGetUserProfileResp{} })
}

func AdminGetUserReqFromMoe(in *moe.AdminGetUserReq) *AdminGetUserReq {
	return cloneTo(in, func() *AdminGetUserReq { return &AdminGetUserReq{} })
}

func AdminGetUserReqToMoe(in *AdminGetUserReq) *moe.AdminGetUserReq {
	return cloneTo(in, func() *moe.AdminGetUserReq { return &moe.AdminGetUserReq{} })
}

func AdminGetUserRespFromMoe(in *moe.AdminGetUserResp) *AdminGetUserResp {
	return cloneTo(in, func() *AdminGetUserResp { return &AdminGetUserResp{} })
}

func AdminGetUserRespToMoe(in *AdminGetUserResp) *moe.AdminGetUserResp {
	return cloneTo(in, func() *moe.AdminGetUserResp { return &moe.AdminGetUserResp{} })
}

func AdminGetVipPlanReqFromMoe(in *moe.AdminGetVipPlanReq) *AdminGetVipPlanReq {
	return cloneTo(in, func() *AdminGetVipPlanReq { return &AdminGetVipPlanReq{} })
}

func AdminGetVipPlanReqToMoe(in *AdminGetVipPlanReq) *moe.AdminGetVipPlanReq {
	return cloneTo(in, func() *moe.AdminGetVipPlanReq { return &moe.AdminGetVipPlanReq{} })
}

func AdminGetVipPlanRespFromMoe(in *moe.AdminGetVipPlanResp) *AdminGetVipPlanResp {
	return cloneTo(in, func() *AdminGetVipPlanResp { return &AdminGetVipPlanResp{} })
}

func AdminGetVipPlanRespToMoe(in *AdminGetVipPlanResp) *moe.AdminGetVipPlanResp {
	return cloneTo(in, func() *moe.AdminGetVipPlanResp { return &moe.AdminGetVipPlanResp{} })
}

func AdminGrowthStatsFromMoe(in *moe.AdminGrowthStats) *AdminGrowthStats {
	return cloneTo(in, func() *AdminGrowthStats { return &AdminGrowthStats{} })
}

func AdminGrowthStatsToMoe(in *AdminGrowthStats) *moe.AdminGrowthStats {
	return cloneTo(in, func() *moe.AdminGrowthStats { return &moe.AdminGrowthStats{} })
}

func AdminLevelConfigItemFromMoe(in *moe.AdminLevelConfigItem) *AdminLevelConfigItem {
	return cloneTo(in, func() *AdminLevelConfigItem { return &AdminLevelConfigItem{} })
}

func AdminLevelConfigItemToMoe(in *AdminLevelConfigItem) *moe.AdminLevelConfigItem {
	return cloneTo(in, func() *moe.AdminLevelConfigItem { return &moe.AdminLevelConfigItem{} })
}

func AdminListAccountsReqFromMoe(in *moe.AdminListAccountsReq) *AdminListAccountsReq {
	return cloneTo(in, func() *AdminListAccountsReq { return &AdminListAccountsReq{} })
}

func AdminListAccountsReqToMoe(in *AdminListAccountsReq) *moe.AdminListAccountsReq {
	return cloneTo(in, func() *moe.AdminListAccountsReq { return &moe.AdminListAccountsReq{} })
}

func AdminListAccountsRespFromMoe(in *moe.AdminListAccountsResp) *AdminListAccountsResp {
	return cloneTo(in, func() *AdminListAccountsResp { return &AdminListAccountsResp{} })
}

func AdminListAccountsRespToMoe(in *AdminListAccountsResp) *moe.AdminListAccountsResp {
	return cloneTo(in, func() *moe.AdminListAccountsResp { return &moe.AdminListAccountsResp{} })
}

func AdminListAchievementsReqFromMoe(in *moe.AdminListAchievementsReq) *AdminListAchievementsReq {
	return cloneTo(in, func() *AdminListAchievementsReq { return &AdminListAchievementsReq{} })
}

func AdminListAchievementsReqToMoe(in *AdminListAchievementsReq) *moe.AdminListAchievementsReq {
	return cloneTo(in, func() *moe.AdminListAchievementsReq { return &moe.AdminListAchievementsReq{} })
}

func AdminListAchievementsRespFromMoe(in *moe.AdminListAchievementsResp) *AdminListAchievementsResp {
	return cloneTo(in, func() *AdminListAchievementsResp { return &AdminListAchievementsResp{} })
}

func AdminListAchievementsRespToMoe(in *AdminListAchievementsResp) *moe.AdminListAchievementsResp {
	return cloneTo(in, func() *moe.AdminListAchievementsResp { return &moe.AdminListAchievementsResp{} })
}

func AdminListAiAgentsReqFromMoe(in *moe.AdminListAiAgentsReq) *AdminListAiAgentsReq {
	return cloneTo(in, func() *AdminListAiAgentsReq { return &AdminListAiAgentsReq{} })
}

func AdminListAiAgentsReqToMoe(in *AdminListAiAgentsReq) *moe.AdminListAiAgentsReq {
	return cloneTo(in, func() *moe.AdminListAiAgentsReq { return &moe.AdminListAiAgentsReq{} })
}

func AdminListAiAgentsRespFromMoe(in *moe.AdminListAiAgentsResp) *AdminListAiAgentsResp {
	return cloneTo(in, func() *AdminListAiAgentsResp { return &AdminListAiAgentsResp{} })
}

func AdminListAiAgentsRespToMoe(in *AdminListAiAgentsResp) *moe.AdminListAiAgentsResp {
	return cloneTo(in, func() *moe.AdminListAiAgentsResp { return &moe.AdminListAiAgentsResp{} })
}

func AdminListAiChatMessagesReqFromMoe(in *moe.AdminListAiChatMessagesReq) *AdminListAiChatMessagesReq {
	return cloneTo(in, func() *AdminListAiChatMessagesReq { return &AdminListAiChatMessagesReq{} })
}

func AdminListAiChatMessagesReqToMoe(in *AdminListAiChatMessagesReq) *moe.AdminListAiChatMessagesReq {
	return cloneTo(in, func() *moe.AdminListAiChatMessagesReq { return &moe.AdminListAiChatMessagesReq{} })
}

func AdminListAiChatMessagesRespFromMoe(in *moe.AdminListAiChatMessagesResp) *AdminListAiChatMessagesResp {
	return cloneTo(in, func() *AdminListAiChatMessagesResp { return &AdminListAiChatMessagesResp{} })
}

func AdminListAiChatMessagesRespToMoe(in *AdminListAiChatMessagesResp) *moe.AdminListAiChatMessagesResp {
	return cloneTo(in, func() *moe.AdminListAiChatMessagesResp { return &moe.AdminListAiChatMessagesResp{} })
}

func AdminListAiChatSessionsReqFromMoe(in *moe.AdminListAiChatSessionsReq) *AdminListAiChatSessionsReq {
	return cloneTo(in, func() *AdminListAiChatSessionsReq { return &AdminListAiChatSessionsReq{} })
}

func AdminListAiChatSessionsReqToMoe(in *AdminListAiChatSessionsReq) *moe.AdminListAiChatSessionsReq {
	return cloneTo(in, func() *moe.AdminListAiChatSessionsReq { return &moe.AdminListAiChatSessionsReq{} })
}

func AdminListAiChatSessionsRespFromMoe(in *moe.AdminListAiChatSessionsResp) *AdminListAiChatSessionsResp {
	return cloneTo(in, func() *AdminListAiChatSessionsResp { return &AdminListAiChatSessionsResp{} })
}

func AdminListAiChatSessionsRespToMoe(in *AdminListAiChatSessionsResp) *moe.AdminListAiChatSessionsResp {
	return cloneTo(in, func() *moe.AdminListAiChatSessionsResp { return &moe.AdminListAiChatSessionsResp{} })
}

func AdminListAnnouncementsReqFromMoe(in *moe.AdminListAnnouncementsReq) *AdminListAnnouncementsReq {
	return cloneTo(in, func() *AdminListAnnouncementsReq { return &AdminListAnnouncementsReq{} })
}

func AdminListAnnouncementsReqToMoe(in *AdminListAnnouncementsReq) *moe.AdminListAnnouncementsReq {
	return cloneTo(in, func() *moe.AdminListAnnouncementsReq { return &moe.AdminListAnnouncementsReq{} })
}

func AdminListAnnouncementsRespFromMoe(in *moe.AdminListAnnouncementsResp) *AdminListAnnouncementsResp {
	return cloneTo(in, func() *AdminListAnnouncementsResp { return &AdminListAnnouncementsResp{} })
}

func AdminListAnnouncementsRespToMoe(in *AdminListAnnouncementsResp) *moe.AdminListAnnouncementsResp {
	return cloneTo(in, func() *moe.AdminListAnnouncementsResp { return &moe.AdminListAnnouncementsResp{} })
}

func AdminListAuditLogsReqFromMoe(in *moe.AdminListAuditLogsReq) *AdminListAuditLogsReq {
	return cloneTo(in, func() *AdminListAuditLogsReq { return &AdminListAuditLogsReq{} })
}

func AdminListAuditLogsReqToMoe(in *AdminListAuditLogsReq) *moe.AdminListAuditLogsReq {
	return cloneTo(in, func() *moe.AdminListAuditLogsReq { return &moe.AdminListAuditLogsReq{} })
}

func AdminListAuditLogsRespFromMoe(in *moe.AdminListAuditLogsResp) *AdminListAuditLogsResp {
	return cloneTo(in, func() *AdminListAuditLogsResp { return &AdminListAuditLogsResp{} })
}

func AdminListAuditLogsRespToMoe(in *AdminListAuditLogsResp) *moe.AdminListAuditLogsResp {
	return cloneTo(in, func() *moe.AdminListAuditLogsResp { return &moe.AdminListAuditLogsResp{} })
}

func AdminListCheckInRewardsReqFromMoe(in *moe.AdminListCheckInRewardsReq) *AdminListCheckInRewardsReq {
	return cloneTo(in, func() *AdminListCheckInRewardsReq { return &AdminListCheckInRewardsReq{} })
}

func AdminListCheckInRewardsReqToMoe(in *AdminListCheckInRewardsReq) *moe.AdminListCheckInRewardsReq {
	return cloneTo(in, func() *moe.AdminListCheckInRewardsReq { return &moe.AdminListCheckInRewardsReq{} })
}

func AdminListCheckInRewardsRespFromMoe(in *moe.AdminListCheckInRewardsResp) *AdminListCheckInRewardsResp {
	return cloneTo(in, func() *AdminListCheckInRewardsResp { return &AdminListCheckInRewardsResp{} })
}

func AdminListCheckInRewardsRespToMoe(in *AdminListCheckInRewardsResp) *moe.AdminListCheckInRewardsResp {
	return cloneTo(in, func() *moe.AdminListCheckInRewardsResp { return &moe.AdminListCheckInRewardsResp{} })
}

func AdminListCommentsReqFromMoe(in *moe.AdminListCommentsReq) *AdminListCommentsReq {
	return cloneTo(in, func() *AdminListCommentsReq { return &AdminListCommentsReq{} })
}

func AdminListCommentsReqToMoe(in *AdminListCommentsReq) *moe.AdminListCommentsReq {
	return cloneTo(in, func() *moe.AdminListCommentsReq { return &moe.AdminListCommentsReq{} })
}

func AdminListCommentsRespFromMoe(in *moe.AdminListCommentsResp) *AdminListCommentsResp {
	return cloneTo(in, func() *AdminListCommentsResp { return &AdminListCommentsResp{} })
}

func AdminListCommentsRespToMoe(in *AdminListCommentsResp) *moe.AdminListCommentsResp {
	return cloneTo(in, func() *moe.AdminListCommentsResp { return &moe.AdminListCommentsResp{} })
}

func AdminListFollowsReqFromMoe(in *moe.AdminListFollowsReq) *AdminListFollowsReq {
	return cloneTo(in, func() *AdminListFollowsReq { return &AdminListFollowsReq{} })
}

func AdminListFollowsReqToMoe(in *AdminListFollowsReq) *moe.AdminListFollowsReq {
	return cloneTo(in, func() *moe.AdminListFollowsReq { return &moe.AdminListFollowsReq{} })
}

func AdminListFollowsRespFromMoe(in *moe.AdminListFollowsResp) *AdminListFollowsResp {
	return cloneTo(in, func() *AdminListFollowsResp { return &AdminListFollowsResp{} })
}

func AdminListFollowsRespToMoe(in *AdminListFollowsResp) *moe.AdminListFollowsResp {
	return cloneTo(in, func() *moe.AdminListFollowsResp { return &moe.AdminListFollowsResp{} })
}

func AdminListFriendRequestsReqFromMoe(in *moe.AdminListFriendRequestsReq) *AdminListFriendRequestsReq {
	return cloneTo(in, func() *AdminListFriendRequestsReq { return &AdminListFriendRequestsReq{} })
}

func AdminListFriendRequestsReqToMoe(in *AdminListFriendRequestsReq) *moe.AdminListFriendRequestsReq {
	return cloneTo(in, func() *moe.AdminListFriendRequestsReq { return &moe.AdminListFriendRequestsReq{} })
}

func AdminListFriendRequestsRespFromMoe(in *moe.AdminListFriendRequestsResp) *AdminListFriendRequestsResp {
	return cloneTo(in, func() *AdminListFriendRequestsResp { return &AdminListFriendRequestsResp{} })
}

func AdminListFriendRequestsRespToMoe(in *AdminListFriendRequestsResp) *moe.AdminListFriendRequestsResp {
	return cloneTo(in, func() *moe.AdminListFriendRequestsResp { return &moe.AdminListFriendRequestsResp{} })
}

func AdminListGiftPurchaseOrdersReqFromMoe(in *moe.AdminListGiftPurchaseOrdersReq) *AdminListGiftPurchaseOrdersReq {
	return cloneTo(in, func() *AdminListGiftPurchaseOrdersReq { return &AdminListGiftPurchaseOrdersReq{} })
}

func AdminListGiftPurchaseOrdersReqToMoe(in *AdminListGiftPurchaseOrdersReq) *moe.AdminListGiftPurchaseOrdersReq {
	return cloneTo(in, func() *moe.AdminListGiftPurchaseOrdersReq { return &moe.AdminListGiftPurchaseOrdersReq{} })
}

func AdminListGiftPurchaseOrdersRespFromMoe(in *moe.AdminListGiftPurchaseOrdersResp) *AdminListGiftPurchaseOrdersResp {
	return cloneTo(in, func() *AdminListGiftPurchaseOrdersResp { return &AdminListGiftPurchaseOrdersResp{} })
}

func AdminListGiftPurchaseOrdersRespToMoe(in *AdminListGiftPurchaseOrdersResp) *moe.AdminListGiftPurchaseOrdersResp {
	return cloneTo(in, func() *moe.AdminListGiftPurchaseOrdersResp { return &moe.AdminListGiftPurchaseOrdersResp{} })
}

func AdminListGiftsReqFromMoe(in *moe.AdminListGiftsReq) *AdminListGiftsReq {
	return cloneTo(in, func() *AdminListGiftsReq { return &AdminListGiftsReq{} })
}

func AdminListGiftsReqToMoe(in *AdminListGiftsReq) *moe.AdminListGiftsReq {
	return cloneTo(in, func() *moe.AdminListGiftsReq { return &moe.AdminListGiftsReq{} })
}

func AdminListGiftsRespFromMoe(in *moe.AdminListGiftsResp) *AdminListGiftsResp {
	return cloneTo(in, func() *AdminListGiftsResp { return &AdminListGiftsResp{} })
}

func AdminListGiftsRespToMoe(in *AdminListGiftsResp) *moe.AdminListGiftsResp {
	return cloneTo(in, func() *moe.AdminListGiftsResp { return &moe.AdminListGiftsResp{} })
}

func AdminListGroupsReqFromMoe(in *moe.AdminListGroupsReq) *AdminListGroupsReq {
	return cloneTo(in, func() *AdminListGroupsReq { return &AdminListGroupsReq{} })
}

func AdminListGroupsReqToMoe(in *AdminListGroupsReq) *moe.AdminListGroupsReq {
	return cloneTo(in, func() *moe.AdminListGroupsReq { return &moe.AdminListGroupsReq{} })
}

func AdminListGroupsRespFromMoe(in *moe.AdminListGroupsResp) *AdminListGroupsResp {
	return cloneTo(in, func() *AdminListGroupsResp { return &AdminListGroupsResp{} })
}

func AdminListGroupsRespToMoe(in *AdminListGroupsResp) *moe.AdminListGroupsResp {
	return cloneTo(in, func() *moe.AdminListGroupsResp { return &moe.AdminListGroupsResp{} })
}

func AdminListLevelConfigsReqFromMoe(in *moe.AdminListLevelConfigsReq) *AdminListLevelConfigsReq {
	return cloneTo(in, func() *AdminListLevelConfigsReq { return &AdminListLevelConfigsReq{} })
}

func AdminListLevelConfigsReqToMoe(in *AdminListLevelConfigsReq) *moe.AdminListLevelConfigsReq {
	return cloneTo(in, func() *moe.AdminListLevelConfigsReq { return &moe.AdminListLevelConfigsReq{} })
}

func AdminListLevelConfigsRespFromMoe(in *moe.AdminListLevelConfigsResp) *AdminListLevelConfigsResp {
	return cloneTo(in, func() *AdminListLevelConfigsResp { return &AdminListLevelConfigsResp{} })
}

func AdminListLevelConfigsRespToMoe(in *AdminListLevelConfigsResp) *moe.AdminListLevelConfigsResp {
	return cloneTo(in, func() *moe.AdminListLevelConfigsResp { return &moe.AdminListLevelConfigsResp{} })
}

func AdminListMemoriesReqFromMoe(in *moe.AdminListMemoriesReq) *AdminListMemoriesReq {
	return cloneTo(in, func() *AdminListMemoriesReq { return &AdminListMemoriesReq{} })
}

func AdminListMemoriesReqToMoe(in *AdminListMemoriesReq) *moe.AdminListMemoriesReq {
	return cloneTo(in, func() *moe.AdminListMemoriesReq { return &moe.AdminListMemoriesReq{} })
}

func AdminListMemoriesRespFromMoe(in *moe.AdminListMemoriesResp) *AdminListMemoriesResp {
	return cloneTo(in, func() *AdminListMemoriesResp { return &AdminListMemoriesResp{} })
}

func AdminListMemoriesRespToMoe(in *AdminListMemoriesResp) *moe.AdminListMemoriesResp {
	return cloneTo(in, func() *moe.AdminListMemoriesResp { return &moe.AdminListMemoriesResp{} })
}

func AdminListMenusReqFromMoe(in *moe.AdminListMenusReq) *AdminListMenusReq {
	return cloneTo(in, func() *AdminListMenusReq { return &AdminListMenusReq{} })
}

func AdminListMenusReqToMoe(in *AdminListMenusReq) *moe.AdminListMenusReq {
	return cloneTo(in, func() *moe.AdminListMenusReq { return &moe.AdminListMenusReq{} })
}

func AdminListMenusRespFromMoe(in *moe.AdminListMenusResp) *AdminListMenusResp {
	return cloneTo(in, func() *AdminListMenusResp { return &AdminListMenusResp{} })
}

func AdminListMenusRespToMoe(in *AdminListMenusResp) *moe.AdminListMenusResp {
	return cloneTo(in, func() *moe.AdminListMenusResp { return &moe.AdminListMenusResp{} })
}

func AdminListMoeRuntimesReqFromMoe(in *moe.AdminListMoeRuntimesReq) *AdminListMoeRuntimesReq {
	return cloneTo(in, func() *AdminListMoeRuntimesReq { return &AdminListMoeRuntimesReq{} })
}

func AdminListMoeRuntimesReqToMoe(in *AdminListMoeRuntimesReq) *moe.AdminListMoeRuntimesReq {
	return cloneTo(in, func() *moe.AdminListMoeRuntimesReq { return &moe.AdminListMoeRuntimesReq{} })
}

func AdminListMoeRuntimesRespFromMoe(in *moe.AdminListMoeRuntimesResp) *AdminListMoeRuntimesResp {
	return cloneTo(in, func() *AdminListMoeRuntimesResp { return &AdminListMoeRuntimesResp{} })
}

func AdminListMoeRuntimesRespToMoe(in *AdminListMoeRuntimesResp) *moe.AdminListMoeRuntimesResp {
	return cloneTo(in, func() *moe.AdminListMoeRuntimesResp { return &moe.AdminListMoeRuntimesResp{} })
}

func AdminListMoeToolCallsReqFromMoe(in *moe.AdminListMoeToolCallsReq) *AdminListMoeToolCallsReq {
	return cloneTo(in, func() *AdminListMoeToolCallsReq { return &AdminListMoeToolCallsReq{} })
}

func AdminListMoeToolCallsReqToMoe(in *AdminListMoeToolCallsReq) *moe.AdminListMoeToolCallsReq {
	return cloneTo(in, func() *moe.AdminListMoeToolCallsReq { return &moe.AdminListMoeToolCallsReq{} })
}

func AdminListMoeToolCallsRespFromMoe(in *moe.AdminListMoeToolCallsResp) *AdminListMoeToolCallsResp {
	return cloneTo(in, func() *AdminListMoeToolCallsResp { return &AdminListMoeToolCallsResp{} })
}

func AdminListMoeToolCallsRespToMoe(in *AdminListMoeToolCallsResp) *moe.AdminListMoeToolCallsResp {
	return cloneTo(in, func() *moe.AdminListMoeToolCallsResp { return &moe.AdminListMoeToolCallsResp{} })
}

func AdminListPostReportsReqFromMoe(in *moe.AdminListPostReportsReq) *AdminListPostReportsReq {
	return cloneTo(in, func() *AdminListPostReportsReq { return &AdminListPostReportsReq{} })
}

func AdminListPostReportsReqToMoe(in *AdminListPostReportsReq) *moe.AdminListPostReportsReq {
	return cloneTo(in, func() *moe.AdminListPostReportsReq { return &moe.AdminListPostReportsReq{} })
}

func AdminListPostReportsRespFromMoe(in *moe.AdminListPostReportsResp) *AdminListPostReportsResp {
	return cloneTo(in, func() *AdminListPostReportsResp { return &AdminListPostReportsResp{} })
}

func AdminListPostReportsRespToMoe(in *AdminListPostReportsResp) *moe.AdminListPostReportsResp {
	return cloneTo(in, func() *moe.AdminListPostReportsResp { return &moe.AdminListPostReportsResp{} })
}

func AdminListPostsReqFromMoe(in *moe.AdminListPostsReq) *AdminListPostsReq {
	return cloneTo(in, func() *AdminListPostsReq { return &AdminListPostsReq{} })
}

func AdminListPostsReqToMoe(in *AdminListPostsReq) *moe.AdminListPostsReq {
	return cloneTo(in, func() *moe.AdminListPostsReq { return &moe.AdminListPostsReq{} })
}

func AdminListPostsRespFromMoe(in *moe.AdminListPostsResp) *AdminListPostsResp {
	return cloneTo(in, func() *AdminListPostsResp { return &AdminListPostsResp{} })
}

func AdminListPostsRespToMoe(in *AdminListPostsResp) *moe.AdminListPostsResp {
	return cloneTo(in, func() *moe.AdminListPostsResp { return &moe.AdminListPostsResp{} })
}

func AdminListTagDictionaryReqFromMoe(in *moe.AdminListTagDictionaryReq) *AdminListTagDictionaryReq {
	return cloneTo(in, func() *AdminListTagDictionaryReq { return &AdminListTagDictionaryReq{} })
}

func AdminListTagDictionaryReqToMoe(in *AdminListTagDictionaryReq) *moe.AdminListTagDictionaryReq {
	return cloneTo(in, func() *moe.AdminListTagDictionaryReq { return &moe.AdminListTagDictionaryReq{} })
}

func AdminListTagDictionaryRespFromMoe(in *moe.AdminListTagDictionaryResp) *AdminListTagDictionaryResp {
	return cloneTo(in, func() *AdminListTagDictionaryResp { return &AdminListTagDictionaryResp{} })
}

func AdminListTagDictionaryRespToMoe(in *AdminListTagDictionaryResp) *moe.AdminListTagDictionaryResp {
	return cloneTo(in, func() *moe.AdminListTagDictionaryResp { return &moe.AdminListTagDictionaryResp{} })
}

func AdminListTopicTagsReqFromMoe(in *moe.AdminListTopicTagsReq) *AdminListTopicTagsReq {
	return cloneTo(in, func() *AdminListTopicTagsReq { return &AdminListTopicTagsReq{} })
}

func AdminListTopicTagsReqToMoe(in *AdminListTopicTagsReq) *moe.AdminListTopicTagsReq {
	return cloneTo(in, func() *moe.AdminListTopicTagsReq { return &moe.AdminListTopicTagsReq{} })
}

func AdminListTopicTagsRespFromMoe(in *moe.AdminListTopicTagsResp) *AdminListTopicTagsResp {
	return cloneTo(in, func() *AdminListTopicTagsResp { return &AdminListTopicTagsResp{} })
}

func AdminListTopicTagsRespToMoe(in *AdminListTopicTagsResp) *moe.AdminListTopicTagsResp {
	return cloneTo(in, func() *moe.AdminListTopicTagsResp { return &moe.AdminListTopicTagsResp{} })
}

func AdminListUsersReqFromMoe(in *moe.AdminListUsersReq) *AdminListUsersReq {
	return cloneTo(in, func() *AdminListUsersReq { return &AdminListUsersReq{} })
}

func AdminListUsersReqToMoe(in *AdminListUsersReq) *moe.AdminListUsersReq {
	return cloneTo(in, func() *moe.AdminListUsersReq { return &moe.AdminListUsersReq{} })
}

func AdminListUsersRespFromMoe(in *moe.AdminListUsersResp) *AdminListUsersResp {
	return cloneTo(in, func() *AdminListUsersResp { return &AdminListUsersResp{} })
}

func AdminListUsersRespToMoe(in *AdminListUsersResp) *moe.AdminListUsersResp {
	return cloneTo(in, func() *moe.AdminListUsersResp { return &moe.AdminListUsersResp{} })
}

func AdminListVipOrdersReqFromMoe(in *moe.AdminListVipOrdersReq) *AdminListVipOrdersReq {
	return cloneTo(in, func() *AdminListVipOrdersReq { return &AdminListVipOrdersReq{} })
}

func AdminListVipOrdersReqToMoe(in *AdminListVipOrdersReq) *moe.AdminListVipOrdersReq {
	return cloneTo(in, func() *moe.AdminListVipOrdersReq { return &moe.AdminListVipOrdersReq{} })
}

func AdminListVipOrdersRespFromMoe(in *moe.AdminListVipOrdersResp) *AdminListVipOrdersResp {
	return cloneTo(in, func() *AdminListVipOrdersResp { return &AdminListVipOrdersResp{} })
}

func AdminListVipOrdersRespToMoe(in *AdminListVipOrdersResp) *moe.AdminListVipOrdersResp {
	return cloneTo(in, func() *moe.AdminListVipOrdersResp { return &moe.AdminListVipOrdersResp{} })
}

func AdminListVipPlansReqFromMoe(in *moe.AdminListVipPlansReq) *AdminListVipPlansReq {
	return cloneTo(in, func() *AdminListVipPlansReq { return &AdminListVipPlansReq{} })
}

func AdminListVipPlansReqToMoe(in *AdminListVipPlansReq) *moe.AdminListVipPlansReq {
	return cloneTo(in, func() *moe.AdminListVipPlansReq { return &moe.AdminListVipPlansReq{} })
}

func AdminListVipPlansRespFromMoe(in *moe.AdminListVipPlansResp) *AdminListVipPlansResp {
	return cloneTo(in, func() *AdminListVipPlansResp { return &AdminListVipPlansResp{} })
}

func AdminListVipPlansRespToMoe(in *AdminListVipPlansResp) *moe.AdminListVipPlansResp {
	return cloneTo(in, func() *moe.AdminListVipPlansResp { return &moe.AdminListVipPlansResp{} })
}

func AdminLoginReqFromMoe(in *moe.AdminLoginReq) *AdminLoginReq {
	return cloneTo(in, func() *AdminLoginReq { return &AdminLoginReq{} })
}

func AdminLoginReqToMoe(in *AdminLoginReq) *moe.AdminLoginReq {
	return cloneTo(in, func() *moe.AdminLoginReq { return &moe.AdminLoginReq{} })
}

func AdminLoginRespFromMoe(in *moe.AdminLoginResp) *AdminLoginResp {
	return cloneTo(in, func() *AdminLoginResp { return &AdminLoginResp{} })
}

func AdminLoginRespToMoe(in *AdminLoginResp) *moe.AdminLoginResp {
	return cloneTo(in, func() *moe.AdminLoginResp { return &moe.AdminLoginResp{} })
}

func AdminMemoryItemFromMoe(in *moe.AdminMemoryItem) *AdminMemoryItem {
	return cloneTo(in, func() *AdminMemoryItem { return &AdminMemoryItem{} })
}

func AdminMemoryItemToMoe(in *AdminMemoryItem) *moe.AdminMemoryItem {
	return cloneTo(in, func() *moe.AdminMemoryItem { return &moe.AdminMemoryItem{} })
}

func AdminMemoryStatsFromMoe(in *moe.AdminMemoryStats) *AdminMemoryStats {
	return cloneTo(in, func() *AdminMemoryStats { return &AdminMemoryStats{} })
}

func AdminMemoryStatsToMoe(in *AdminMemoryStats) *moe.AdminMemoryStats {
	return cloneTo(in, func() *moe.AdminMemoryStats { return &moe.AdminMemoryStats{} })
}

func AdminMemoryTypeStatFromMoe(in *moe.AdminMemoryTypeStat) *AdminMemoryTypeStat {
	return cloneTo(in, func() *AdminMemoryTypeStat { return &AdminMemoryTypeStat{} })
}

func AdminMemoryTypeStatToMoe(in *AdminMemoryTypeStat) *moe.AdminMemoryTypeStat {
	return cloneTo(in, func() *moe.AdminMemoryTypeStat { return &moe.AdminMemoryTypeStat{} })
}

func AdminMenuItemFromMoe(in *moe.AdminMenuItem) *AdminMenuItem {
	return cloneTo(in, func() *AdminMenuItem { return &AdminMenuItem{} })
}

func AdminMenuItemToMoe(in *AdminMenuItem) *moe.AdminMenuItem {
	return cloneTo(in, func() *moe.AdminMenuItem { return &moe.AdminMenuItem{} })
}

func AdminMoeToolCallItemFromMoe(in *moe.AdminMoeToolCallItem) *AdminMoeToolCallItem {
	return cloneTo(in, func() *AdminMoeToolCallItem { return &AdminMoeToolCallItem{} })
}

func AdminMoeToolCallItemToMoe(in *AdminMoeToolCallItem) *moe.AdminMoeToolCallItem {
	return cloneTo(in, func() *moe.AdminMoeToolCallItem { return &moe.AdminMoeToolCallItem{} })
}

func AdminMoeToolDayStatFromMoe(in *moe.AdminMoeToolDayStat) *AdminMoeToolDayStat {
	return cloneTo(in, func() *AdminMoeToolDayStat { return &AdminMoeToolDayStat{} })
}

func AdminMoeToolDayStatToMoe(in *AdminMoeToolDayStat) *moe.AdminMoeToolDayStat {
	return cloneTo(in, func() *moe.AdminMoeToolDayStat { return &moe.AdminMoeToolDayStat{} })
}

func AdminMoeToolStatRowFromMoe(in *moe.AdminMoeToolStatRow) *AdminMoeToolStatRow {
	return cloneTo(in, func() *AdminMoeToolStatRow { return &AdminMoeToolStatRow{} })
}

func AdminMoeToolStatRowToMoe(in *AdminMoeToolStatRow) *moe.AdminMoeToolStatRow {
	return cloneTo(in, func() *moe.AdminMoeToolStatRow { return &moe.AdminMoeToolStatRow{} })
}

func AdminPostReportItemFromMoe(in *moe.AdminPostReportItem) *AdminPostReportItem {
	return cloneTo(in, func() *AdminPostReportItem { return &AdminPostReportItem{} })
}

func AdminPostReportItemToMoe(in *AdminPostReportItem) *moe.AdminPostReportItem {
	return cloneTo(in, func() *moe.AdminPostReportItem { return &moe.AdminPostReportItem{} })
}

func AdminPublishAnnouncementReqFromMoe(in *moe.AdminPublishAnnouncementReq) *AdminPublishAnnouncementReq {
	return cloneTo(in, func() *AdminPublishAnnouncementReq { return &AdminPublishAnnouncementReq{} })
}

func AdminPublishAnnouncementReqToMoe(in *AdminPublishAnnouncementReq) *moe.AdminPublishAnnouncementReq {
	return cloneTo(in, func() *moe.AdminPublishAnnouncementReq { return &moe.AdminPublishAnnouncementReq{} })
}

func AdminPublishAnnouncementRespFromMoe(in *moe.AdminPublishAnnouncementResp) *AdminPublishAnnouncementResp {
	return cloneTo(in, func() *AdminPublishAnnouncementResp { return &AdminPublishAnnouncementResp{} })
}

func AdminPublishAnnouncementRespToMoe(in *AdminPublishAnnouncementResp) *moe.AdminPublishAnnouncementResp {
	return cloneTo(in, func() *moe.AdminPublishAnnouncementResp { return &moe.AdminPublishAnnouncementResp{} })
}

func AdminRefineMoeBrainEpisodeReqFromMoe(in *moe.AdminRefineMoeBrainEpisodeReq) *AdminRefineMoeBrainEpisodeReq {
	return cloneTo(in, func() *AdminRefineMoeBrainEpisodeReq { return &AdminRefineMoeBrainEpisodeReq{} })
}

func AdminRefineMoeBrainEpisodeReqToMoe(in *AdminRefineMoeBrainEpisodeReq) *moe.AdminRefineMoeBrainEpisodeReq {
	return cloneTo(in, func() *moe.AdminRefineMoeBrainEpisodeReq { return &moe.AdminRefineMoeBrainEpisodeReq{} })
}

func AdminRefineMoeBrainEpisodeRespFromMoe(in *moe.AdminRefineMoeBrainEpisodeResp) *AdminRefineMoeBrainEpisodeResp {
	return cloneTo(in, func() *AdminRefineMoeBrainEpisodeResp { return &AdminRefineMoeBrainEpisodeResp{} })
}

func AdminRefineMoeBrainEpisodeRespToMoe(in *AdminRefineMoeBrainEpisodeResp) *moe.AdminRefineMoeBrainEpisodeResp {
	return cloneTo(in, func() *moe.AdminRefineMoeBrainEpisodeResp { return &moe.AdminRefineMoeBrainEpisodeResp{} })
}

func AdminRunMoeAgentOnceReqFromMoe(in *moe.AdminRunMoeAgentOnceReq) *AdminRunMoeAgentOnceReq {
	return cloneTo(in, func() *AdminRunMoeAgentOnceReq { return &AdminRunMoeAgentOnceReq{} })
}

func AdminRunMoeAgentOnceReqToMoe(in *AdminRunMoeAgentOnceReq) *moe.AdminRunMoeAgentOnceReq {
	return cloneTo(in, func() *moe.AdminRunMoeAgentOnceReq { return &moe.AdminRunMoeAgentOnceReq{} })
}

func AdminRunMoeAgentOnceRespFromMoe(in *moe.AdminRunMoeAgentOnceResp) *AdminRunMoeAgentOnceResp {
	return cloneTo(in, func() *AdminRunMoeAgentOnceResp { return &AdminRunMoeAgentOnceResp{} })
}

func AdminRunMoeAgentOnceRespToMoe(in *AdminRunMoeAgentOnceResp) *moe.AdminRunMoeAgentOnceResp {
	return cloneTo(in, func() *moe.AdminRunMoeAgentOnceResp { return &moe.AdminRunMoeAgentOnceResp{} })
}

func AdminSchemaCatalogSummaryFromMoe(in *moe.AdminSchemaCatalogSummary) *AdminSchemaCatalogSummary {
	return cloneTo(in, func() *AdminSchemaCatalogSummary { return &AdminSchemaCatalogSummary{} })
}

func AdminSchemaCatalogSummaryToMoe(in *AdminSchemaCatalogSummary) *moe.AdminSchemaCatalogSummary {
	return cloneTo(in, func() *moe.AdminSchemaCatalogSummary { return &moe.AdminSchemaCatalogSummary{} })
}

func AdminSchemaTableItemFromMoe(in *moe.AdminSchemaTableItem) *AdminSchemaTableItem {
	return cloneTo(in, func() *AdminSchemaTableItem { return &AdminSchemaTableItem{} })
}

func AdminSchemaTableItemToMoe(in *AdminSchemaTableItem) *moe.AdminSchemaTableItem {
	return cloneTo(in, func() *moe.AdminSchemaTableItem { return &moe.AdminSchemaTableItem{} })
}

func AdminSendNotificationReqFromMoe(in *moe.AdminSendNotificationReq) *AdminSendNotificationReq {
	return cloneTo(in, func() *AdminSendNotificationReq { return &AdminSendNotificationReq{} })
}

func AdminSendNotificationReqToMoe(in *AdminSendNotificationReq) *moe.AdminSendNotificationReq {
	return cloneTo(in, func() *moe.AdminSendNotificationReq { return &moe.AdminSendNotificationReq{} })
}

func AdminSendNotificationRespFromMoe(in *moe.AdminSendNotificationResp) *AdminSendNotificationResp {
	return cloneTo(in, func() *AdminSendNotificationResp { return &AdminSendNotificationResp{} })
}

func AdminSendNotificationRespToMoe(in *AdminSendNotificationResp) *moe.AdminSendNotificationResp {
	return cloneTo(in, func() *moe.AdminSendNotificationResp { return &moe.AdminSendNotificationResp{} })
}

func AdminTagDictionaryItemFromMoe(in *moe.AdminTagDictionaryItem) *AdminTagDictionaryItem {
	return cloneTo(in, func() *AdminTagDictionaryItem { return &AdminTagDictionaryItem{} })
}

func AdminTagDictionaryItemToMoe(in *AdminTagDictionaryItem) *moe.AdminTagDictionaryItem {
	return cloneTo(in, func() *moe.AdminTagDictionaryItem { return &moe.AdminTagDictionaryItem{} })
}

func AdminUpdateAccountReqFromMoe(in *moe.AdminUpdateAccountReq) *AdminUpdateAccountReq {
	return cloneTo(in, func() *AdminUpdateAccountReq { return &AdminUpdateAccountReq{} })
}

func AdminUpdateAccountReqToMoe(in *AdminUpdateAccountReq) *moe.AdminUpdateAccountReq {
	return cloneTo(in, func() *moe.AdminUpdateAccountReq { return &moe.AdminUpdateAccountReq{} })
}

func AdminUpdateAccountRespFromMoe(in *moe.AdminUpdateAccountResp) *AdminUpdateAccountResp {
	return cloneTo(in, func() *AdminUpdateAccountResp { return &AdminUpdateAccountResp{} })
}

func AdminUpdateAccountRespToMoe(in *AdminUpdateAccountResp) *moe.AdminUpdateAccountResp {
	return cloneTo(in, func() *moe.AdminUpdateAccountResp { return &moe.AdminUpdateAccountResp{} })
}

func AdminUpdateAchievementReqFromMoe(in *moe.AdminUpdateAchievementReq) *AdminUpdateAchievementReq {
	return cloneTo(in, func() *AdminUpdateAchievementReq { return &AdminUpdateAchievementReq{} })
}

func AdminUpdateAchievementReqToMoe(in *AdminUpdateAchievementReq) *moe.AdminUpdateAchievementReq {
	return cloneTo(in, func() *moe.AdminUpdateAchievementReq { return &moe.AdminUpdateAchievementReq{} })
}

func AdminUpdateAchievementRespFromMoe(in *moe.AdminUpdateAchievementResp) *AdminUpdateAchievementResp {
	return cloneTo(in, func() *AdminUpdateAchievementResp { return &AdminUpdateAchievementResp{} })
}

func AdminUpdateAchievementRespToMoe(in *AdminUpdateAchievementResp) *moe.AdminUpdateAchievementResp {
	return cloneTo(in, func() *moe.AdminUpdateAchievementResp { return &moe.AdminUpdateAchievementResp{} })
}

func AdminUpdateAnnouncementReqFromMoe(in *moe.AdminUpdateAnnouncementReq) *AdminUpdateAnnouncementReq {
	return cloneTo(in, func() *AdminUpdateAnnouncementReq { return &AdminUpdateAnnouncementReq{} })
}

func AdminUpdateAnnouncementReqToMoe(in *AdminUpdateAnnouncementReq) *moe.AdminUpdateAnnouncementReq {
	return cloneTo(in, func() *moe.AdminUpdateAnnouncementReq { return &moe.AdminUpdateAnnouncementReq{} })
}

func AdminUpdateAnnouncementRespFromMoe(in *moe.AdminUpdateAnnouncementResp) *AdminUpdateAnnouncementResp {
	return cloneTo(in, func() *AdminUpdateAnnouncementResp { return &AdminUpdateAnnouncementResp{} })
}

func AdminUpdateAnnouncementRespToMoe(in *AdminUpdateAnnouncementResp) *moe.AdminUpdateAnnouncementResp {
	return cloneTo(in, func() *moe.AdminUpdateAnnouncementResp { return &moe.AdminUpdateAnnouncementResp{} })
}

func AdminUpdateCheckInRewardReqFromMoe(in *moe.AdminUpdateCheckInRewardReq) *AdminUpdateCheckInRewardReq {
	return cloneTo(in, func() *AdminUpdateCheckInRewardReq { return &AdminUpdateCheckInRewardReq{} })
}

func AdminUpdateCheckInRewardReqToMoe(in *AdminUpdateCheckInRewardReq) *moe.AdminUpdateCheckInRewardReq {
	return cloneTo(in, func() *moe.AdminUpdateCheckInRewardReq { return &moe.AdminUpdateCheckInRewardReq{} })
}

func AdminUpdateCheckInRewardRespFromMoe(in *moe.AdminUpdateCheckInRewardResp) *AdminUpdateCheckInRewardResp {
	return cloneTo(in, func() *AdminUpdateCheckInRewardResp { return &AdminUpdateCheckInRewardResp{} })
}

func AdminUpdateCheckInRewardRespToMoe(in *AdminUpdateCheckInRewardResp) *moe.AdminUpdateCheckInRewardResp {
	return cloneTo(in, func() *moe.AdminUpdateCheckInRewardResp { return &moe.AdminUpdateCheckInRewardResp{} })
}

func AdminUpdateGiftReqFromMoe(in *moe.AdminUpdateGiftReq) *AdminUpdateGiftReq {
	return cloneTo(in, func() *AdminUpdateGiftReq { return &AdminUpdateGiftReq{} })
}

func AdminUpdateGiftReqToMoe(in *AdminUpdateGiftReq) *moe.AdminUpdateGiftReq {
	return cloneTo(in, func() *moe.AdminUpdateGiftReq { return &moe.AdminUpdateGiftReq{} })
}

func AdminUpdateGiftRespFromMoe(in *moe.AdminUpdateGiftResp) *AdminUpdateGiftResp {
	return cloneTo(in, func() *AdminUpdateGiftResp { return &AdminUpdateGiftResp{} })
}

func AdminUpdateGiftRespToMoe(in *AdminUpdateGiftResp) *moe.AdminUpdateGiftResp {
	return cloneTo(in, func() *moe.AdminUpdateGiftResp { return &moe.AdminUpdateGiftResp{} })
}

func AdminUpdateLevelConfigReqFromMoe(in *moe.AdminUpdateLevelConfigReq) *AdminUpdateLevelConfigReq {
	return cloneTo(in, func() *AdminUpdateLevelConfigReq { return &AdminUpdateLevelConfigReq{} })
}

func AdminUpdateLevelConfigReqToMoe(in *AdminUpdateLevelConfigReq) *moe.AdminUpdateLevelConfigReq {
	return cloneTo(in, func() *moe.AdminUpdateLevelConfigReq { return &moe.AdminUpdateLevelConfigReq{} })
}

func AdminUpdateLevelConfigRespFromMoe(in *moe.AdminUpdateLevelConfigResp) *AdminUpdateLevelConfigResp {
	return cloneTo(in, func() *AdminUpdateLevelConfigResp { return &AdminUpdateLevelConfigResp{} })
}

func AdminUpdateLevelConfigRespToMoe(in *AdminUpdateLevelConfigResp) *moe.AdminUpdateLevelConfigResp {
	return cloneTo(in, func() *moe.AdminUpdateLevelConfigResp { return &moe.AdminUpdateLevelConfigResp{} })
}

func AdminUpdateMoeBrainPolicyReqFromMoe(in *moe.AdminUpdateMoeBrainPolicyReq) *AdminUpdateMoeBrainPolicyReq {
	return cloneTo(in, func() *AdminUpdateMoeBrainPolicyReq { return &AdminUpdateMoeBrainPolicyReq{} })
}

func AdminUpdateMoeBrainPolicyReqToMoe(in *AdminUpdateMoeBrainPolicyReq) *moe.AdminUpdateMoeBrainPolicyReq {
	return cloneTo(in, func() *moe.AdminUpdateMoeBrainPolicyReq { return &moe.AdminUpdateMoeBrainPolicyReq{} })
}

func AdminUpdateTagDictionaryReqFromMoe(in *moe.AdminUpdateTagDictionaryReq) *AdminUpdateTagDictionaryReq {
	return cloneTo(in, func() *AdminUpdateTagDictionaryReq { return &AdminUpdateTagDictionaryReq{} })
}

func AdminUpdateTagDictionaryReqToMoe(in *AdminUpdateTagDictionaryReq) *moe.AdminUpdateTagDictionaryReq {
	return cloneTo(in, func() *moe.AdminUpdateTagDictionaryReq { return &moe.AdminUpdateTagDictionaryReq{} })
}

func AdminUpdateTagDictionaryRespFromMoe(in *moe.AdminUpdateTagDictionaryResp) *AdminUpdateTagDictionaryResp {
	return cloneTo(in, func() *AdminUpdateTagDictionaryResp { return &AdminUpdateTagDictionaryResp{} })
}

func AdminUpdateTagDictionaryRespToMoe(in *AdminUpdateTagDictionaryResp) *moe.AdminUpdateTagDictionaryResp {
	return cloneTo(in, func() *moe.AdminUpdateTagDictionaryResp { return &moe.AdminUpdateTagDictionaryResp{} })
}

func AdminUpdateTopicTagReqFromMoe(in *moe.AdminUpdateTopicTagReq) *AdminUpdateTopicTagReq {
	return cloneTo(in, func() *AdminUpdateTopicTagReq { return &AdminUpdateTopicTagReq{} })
}

func AdminUpdateTopicTagReqToMoe(in *AdminUpdateTopicTagReq) *moe.AdminUpdateTopicTagReq {
	return cloneTo(in, func() *moe.AdminUpdateTopicTagReq { return &moe.AdminUpdateTopicTagReq{} })
}

func AdminUpdateTopicTagRespFromMoe(in *moe.AdminUpdateTopicTagResp) *AdminUpdateTopicTagResp {
	return cloneTo(in, func() *AdminUpdateTopicTagResp { return &AdminUpdateTopicTagResp{} })
}

func AdminUpdateTopicTagRespToMoe(in *AdminUpdateTopicTagResp) *moe.AdminUpdateTopicTagResp {
	return cloneTo(in, func() *moe.AdminUpdateTopicTagResp { return &moe.AdminUpdateTopicTagResp{} })
}

func AdminUpdateUserReqFromMoe(in *moe.AdminUpdateUserReq) *AdminUpdateUserReq {
	return cloneTo(in, func() *AdminUpdateUserReq { return &AdminUpdateUserReq{} })
}

func AdminUpdateUserReqToMoe(in *AdminUpdateUserReq) *moe.AdminUpdateUserReq {
	return cloneTo(in, func() *moe.AdminUpdateUserReq { return &moe.AdminUpdateUserReq{} })
}

func AdminUpdateUserRespFromMoe(in *moe.AdminUpdateUserResp) *AdminUpdateUserResp {
	return cloneTo(in, func() *AdminUpdateUserResp { return &AdminUpdateUserResp{} })
}

func AdminUpdateUserRespToMoe(in *AdminUpdateUserResp) *moe.AdminUpdateUserResp {
	return cloneTo(in, func() *moe.AdminUpdateUserResp { return &moe.AdminUpdateUserResp{} })
}

func AdminUpdateVipPlanReqFromMoe(in *moe.AdminUpdateVipPlanReq) *AdminUpdateVipPlanReq {
	return cloneTo(in, func() *AdminUpdateVipPlanReq { return &AdminUpdateVipPlanReq{} })
}

func AdminUpdateVipPlanReqToMoe(in *AdminUpdateVipPlanReq) *moe.AdminUpdateVipPlanReq {
	return cloneTo(in, func() *moe.AdminUpdateVipPlanReq { return &moe.AdminUpdateVipPlanReq{} })
}

func AdminUpdateVipPlanRespFromMoe(in *moe.AdminUpdateVipPlanResp) *AdminUpdateVipPlanResp {
	return cloneTo(in, func() *AdminUpdateVipPlanResp { return &AdminUpdateVipPlanResp{} })
}

func AdminUpdateVipPlanRespToMoe(in *AdminUpdateVipPlanResp) *moe.AdminUpdateVipPlanResp {
	return cloneTo(in, func() *moe.AdminUpdateVipPlanResp { return &moe.AdminUpdateVipPlanResp{} })
}

func AdminUpsertMenuReqFromMoe(in *moe.AdminUpsertMenuReq) *AdminUpsertMenuReq {
	return cloneTo(in, func() *AdminUpsertMenuReq { return &AdminUpsertMenuReq{} })
}

func AdminUpsertMenuReqToMoe(in *AdminUpsertMenuReq) *moe.AdminUpsertMenuReq {
	return cloneTo(in, func() *moe.AdminUpsertMenuReq { return &moe.AdminUpsertMenuReq{} })
}

func AdminUpsertMenuRespFromMoe(in *moe.AdminUpsertMenuResp) *AdminUpsertMenuResp {
	return cloneTo(in, func() *AdminUpsertMenuResp { return &AdminUpsertMenuResp{} })
}

func AdminUpsertMenuRespToMoe(in *AdminUpsertMenuResp) *moe.AdminUpsertMenuResp {
	return cloneTo(in, func() *moe.AdminUpsertMenuResp { return &moe.AdminUpsertMenuResp{} })
}

func AdminUpsertMoeRuntimeReqFromMoe(in *moe.AdminUpsertMoeRuntimeReq) *AdminUpsertMoeRuntimeReq {
	return cloneTo(in, func() *AdminUpsertMoeRuntimeReq { return &AdminUpsertMoeRuntimeReq{} })
}

func AdminUpsertMoeRuntimeReqToMoe(in *AdminUpsertMoeRuntimeReq) *moe.AdminUpsertMoeRuntimeReq {
	return cloneTo(in, func() *moe.AdminUpsertMoeRuntimeReq { return &moe.AdminUpsertMoeRuntimeReq{} })
}

func AdminUpsertMoeRuntimeRespFromMoe(in *moe.AdminUpsertMoeRuntimeResp) *AdminUpsertMoeRuntimeResp {
	return cloneTo(in, func() *AdminUpsertMoeRuntimeResp { return &AdminUpsertMoeRuntimeResp{} })
}

func AdminUpsertMoeRuntimeRespToMoe(in *AdminUpsertMoeRuntimeResp) *moe.AdminUpsertMoeRuntimeResp {
	return cloneTo(in, func() *moe.AdminUpsertMoeRuntimeResp { return &moe.AdminUpsertMoeRuntimeResp{} })
}

func AdminUserBehaviorScreenStatFromMoe(in *moe.AdminUserBehaviorScreenStat) *AdminUserBehaviorScreenStat {
	return cloneTo(in, func() *AdminUserBehaviorScreenStat { return &AdminUserBehaviorScreenStat{} })
}

func AdminUserBehaviorScreenStatToMoe(in *AdminUserBehaviorScreenStat) *moe.AdminUserBehaviorScreenStat {
	return cloneTo(in, func() *moe.AdminUserBehaviorScreenStat { return &moe.AdminUserBehaviorScreenStat{} })
}

func AdminUserBehaviorSummaryFromMoe(in *moe.AdminUserBehaviorSummary) *AdminUserBehaviorSummary {
	return cloneTo(in, func() *AdminUserBehaviorSummary { return &AdminUserBehaviorSummary{} })
}

func AdminUserBehaviorSummaryToMoe(in *AdminUserBehaviorSummary) *moe.AdminUserBehaviorSummary {
	return cloneTo(in, func() *moe.AdminUserBehaviorSummary { return &moe.AdminUserBehaviorSummary{} })
}

func AdminUserLevelSnapshotFromMoe(in *moe.AdminUserLevelSnapshot) *AdminUserLevelSnapshot {
	return cloneTo(in, func() *AdminUserLevelSnapshot { return &AdminUserLevelSnapshot{} })
}

func AdminUserLevelSnapshotToMoe(in *AdminUserLevelSnapshot) *moe.AdminUserLevelSnapshot {
	return cloneTo(in, func() *moe.AdminUserLevelSnapshot { return &moe.AdminUserLevelSnapshot{} })
}

func AdminUserProfileDataFromMoe(in *moe.AdminUserProfileData) *AdminUserProfileData {
	return cloneTo(in, func() *AdminUserProfileData { return &AdminUserProfileData{} })
}

func AdminUserProfileDataToMoe(in *AdminUserProfileData) *moe.AdminUserProfileData {
	return cloneTo(in, func() *moe.AdminUserProfileData { return &moe.AdminUserProfileData{} })
}

func AdminUserRelationCountsFromMoe(in *moe.AdminUserRelationCounts) *AdminUserRelationCounts {
	return cloneTo(in, func() *AdminUserRelationCounts { return &AdminUserRelationCounts{} })
}

func AdminUserRelationCountsToMoe(in *AdminUserRelationCounts) *moe.AdminUserRelationCounts {
	return cloneTo(in, func() *moe.AdminUserRelationCounts { return &moe.AdminUserRelationCounts{} })
}

func AdminUserRelationLinkFromMoe(in *moe.AdminUserRelationLink) *AdminUserRelationLink {
	return cloneTo(in, func() *AdminUserRelationLink { return &AdminUserRelationLink{} })
}

func AdminUserRelationLinkToMoe(in *AdminUserRelationLink) *moe.AdminUserRelationLink {
	return cloneTo(in, func() *moe.AdminUserRelationLink { return &moe.AdminUserRelationLink{} })
}

func CommentFromMoe(in *moe.Comment) *Comment {
	return cloneTo(in, func() *Comment { return &Comment{} })
}

func CommentToMoe(in *Comment) *moe.Comment {
	return cloneTo(in, func() *moe.Comment { return &moe.Comment{} })
}

func GiftFromMoe(in *moe.Gift) *Gift {
	return cloneTo(in, func() *Gift { return &Gift{} })
}

func GiftToMoe(in *Gift) *moe.Gift {
	return cloneTo(in, func() *moe.Gift { return &moe.Gift{} })
}

func GiftPurchaseOrderFromMoe(in *moe.GiftPurchaseOrder) *GiftPurchaseOrder {
	return cloneTo(in, func() *GiftPurchaseOrder { return &GiftPurchaseOrder{} })
}

func GiftPurchaseOrderToMoe(in *GiftPurchaseOrder) *moe.GiftPurchaseOrder {
	return cloneTo(in, func() *moe.GiftPurchaseOrder { return &moe.GiftPurchaseOrder{} })
}

func GroupFromMoe(in *moe.Group) *Group {
	return cloneTo(in, func() *Group { return &Group{} })
}

func GroupToMoe(in *Group) *moe.Group {
	return cloneTo(in, func() *moe.Group { return &moe.Group{} })
}

func MoeAgentRuntimeItemFromMoe(in *moe.MoeAgentRuntimeItem) *MoeAgentRuntimeItem {
	return cloneTo(in, func() *MoeAgentRuntimeItem { return &MoeAgentRuntimeItem{} })
}

func MoeAgentRuntimeItemToMoe(in *MoeAgentRuntimeItem) *moe.MoeAgentRuntimeItem {
	return cloneTo(in, func() *moe.MoeAgentRuntimeItem { return &moe.MoeAgentRuntimeItem{} })
}

func MoeBrainEpisodeItemFromMoe(in *moe.MoeBrainEpisodeItem) *MoeBrainEpisodeItem {
	return cloneTo(in, func() *MoeBrainEpisodeItem { return &MoeBrainEpisodeItem{} })
}

func MoeBrainEpisodeItemToMoe(in *MoeBrainEpisodeItem) *moe.MoeBrainEpisodeItem {
	return cloneTo(in, func() *moe.MoeBrainEpisodeItem { return &moe.MoeBrainEpisodeItem{} })
}

func MoeBrainGenerationMetaFromMoe(in *moe.MoeBrainGenerationMeta) *MoeBrainGenerationMeta {
	return cloneTo(in, func() *MoeBrainGenerationMeta { return &MoeBrainGenerationMeta{} })
}

func MoeBrainGenerationMetaToMoe(in *MoeBrainGenerationMeta) *moe.MoeBrainGenerationMeta {
	return cloneTo(in, func() *moe.MoeBrainGenerationMeta { return &moe.MoeBrainGenerationMeta{} })
}

func MoeBrainMemoryItemFromMoe(in *moe.MoeBrainMemoryItem) *MoeBrainMemoryItem {
	return cloneTo(in, func() *MoeBrainMemoryItem { return &MoeBrainMemoryItem{} })
}

func MoeBrainMemoryItemToMoe(in *MoeBrainMemoryItem) *moe.MoeBrainMemoryItem {
	return cloneTo(in, func() *moe.MoeBrainMemoryItem { return &moe.MoeBrainMemoryItem{} })
}

func MoeBrainTagStatFromMoe(in *moe.MoeBrainTagStat) *MoeBrainTagStat {
	return cloneTo(in, func() *MoeBrainTagStat { return &MoeBrainTagStat{} })
}

func MoeBrainTagStatToMoe(in *MoeBrainTagStat) *moe.MoeBrainTagStat {
	return cloneTo(in, func() *moe.MoeBrainTagStat { return &moe.MoeBrainTagStat{} })
}

func MoeGenAttemptItemFromMoe(in *moe.MoeGenAttemptItem) *MoeGenAttemptItem {
	return cloneTo(in, func() *MoeGenAttemptItem { return &MoeGenAttemptItem{} })
}

func MoeGenAttemptItemToMoe(in *MoeGenAttemptItem) *moe.MoeGenAttemptItem {
	return cloneTo(in, func() *moe.MoeGenAttemptItem { return &moe.MoeGenAttemptItem{} })
}

func MoeHostMetricsFromMoe(in *moe.MoeHostMetrics) *MoeHostMetrics {
	return cloneTo(in, func() *MoeHostMetrics { return &MoeHostMetrics{} })
}

func MoeHostMetricsToMoe(in *MoeHostMetrics) *moe.MoeHostMetrics {
	return cloneTo(in, func() *moe.MoeHostMetrics { return &moe.MoeHostMetrics{} })
}

func MoePipelineStepItemFromMoe(in *moe.MoePipelineStepItem) *MoePipelineStepItem {
	return cloneTo(in, func() *MoePipelineStepItem { return &MoePipelineStepItem{} })
}

func MoePipelineStepItemToMoe(in *MoePipelineStepItem) *moe.MoePipelineStepItem {
	return cloneTo(in, func() *moe.MoePipelineStepItem { return &moe.MoePipelineStepItem{} })
}

func PostFromMoe(in *moe.Post) *Post {
	return cloneTo(in, func() *Post { return &Post{} })
}

func PostToMoe(in *Post) *moe.Post {
	return cloneTo(in, func() *moe.Post { return &moe.Post{} })
}

func RecordAdminAuditLogReqFromMoe(in *moe.RecordAdminAuditLogReq) *RecordAdminAuditLogReq {
	return cloneTo(in, func() *RecordAdminAuditLogReq { return &RecordAdminAuditLogReq{} })
}

func RecordAdminAuditLogReqToMoe(in *RecordAdminAuditLogReq) *moe.RecordAdminAuditLogReq {
	return cloneTo(in, func() *moe.RecordAdminAuditLogReq { return &moe.RecordAdminAuditLogReq{} })
}

func RecordAdminAuditLogRespFromMoe(in *moe.RecordAdminAuditLogResp) *RecordAdminAuditLogResp {
	return cloneTo(in, func() *RecordAdminAuditLogResp { return &RecordAdminAuditLogResp{} })
}

func RecordAdminAuditLogRespToMoe(in *RecordAdminAuditLogResp) *moe.RecordAdminAuditLogResp {
	return cloneTo(in, func() *moe.RecordAdminAuditLogResp { return &moe.RecordAdminAuditLogResp{} })
}

func TopicTagFromMoe(in *moe.TopicTag) *TopicTag {
	return cloneTo(in, func() *TopicTag { return &TopicTag{} })
}

func TopicTagToMoe(in *TopicTag) *moe.TopicTag {
	return cloneTo(in, func() *moe.TopicTag { return &moe.TopicTag{} })
}

func UserFromMoe(in *moe.User) *User {
	return cloneTo(in, func() *User { return &User{} })
}

func UserToMoe(in *User) *moe.User {
	return cloneTo(in, func() *moe.User { return &moe.User{} })
}

func VipOrderFromMoe(in *moe.VipOrder) *VipOrder {
	return cloneTo(in, func() *VipOrder { return &VipOrder{} })
}

func VipOrderToMoe(in *VipOrder) *moe.VipOrder {
	return cloneTo(in, func() *moe.VipOrder { return &moe.VipOrder{} })
}

func VipPlanFromMoe(in *moe.VipPlan) *VipPlan {
	return cloneTo(in, func() *VipPlan { return &VipPlan{} })
}

func VipPlanToMoe(in *VipPlan) *moe.VipPlan {
	return cloneTo(in, func() *moe.VipPlan { return &moe.VipPlan{} })
}
