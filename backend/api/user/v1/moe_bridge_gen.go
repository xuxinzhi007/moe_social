package userv1

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

func AcceptFriendRequestReqFromMoe(in *moe.AcceptFriendRequestReq) *AcceptFriendRequestReq {
	return cloneTo(in, func() *AcceptFriendRequestReq { return &AcceptFriendRequestReq{} })
}

func AcceptFriendRequestReqToMoe(in *AcceptFriendRequestReq) *moe.AcceptFriendRequestReq {
	return cloneTo(in, func() *moe.AcceptFriendRequestReq { return &moe.AcceptFriendRequestReq{} })
}

func AcceptFriendRequestRespFromMoe(in *moe.AcceptFriendRequestResp) *AcceptFriendRequestResp {
	return cloneTo(in, func() *AcceptFriendRequestResp { return &AcceptFriendRequestResp{} })
}

func AcceptFriendRequestRespToMoe(in *AcceptFriendRequestResp) *moe.AcceptFriendRequestResp {
	return cloneTo(in, func() *moe.AcceptFriendRequestResp { return &moe.AcceptFriendRequestResp{} })
}

func AchievementBadgeItemFromMoe(in *moe.AchievementBadgeItem) *AchievementBadgeItem {
	return cloneTo(in, func() *AchievementBadgeItem { return &AchievementBadgeItem{} })
}

func AchievementBadgeItemToMoe(in *AchievementBadgeItem) *moe.AchievementBadgeItem {
	return cloneTo(in, func() *moe.AchievementBadgeItem { return &moe.AchievementBadgeItem{} })
}

func AvatarBaseConfigFromMoe(in *moe.AvatarBaseConfig) *AvatarBaseConfig {
	return cloneTo(in, func() *AvatarBaseConfig { return &AvatarBaseConfig{} })
}

func AvatarBaseConfigToMoe(in *AvatarBaseConfig) *moe.AvatarBaseConfig {
	return cloneTo(in, func() *moe.AvatarBaseConfig { return &moe.AvatarBaseConfig{} })
}

func AvatarOutfitConfigFromMoe(in *moe.AvatarOutfitConfig) *AvatarOutfitConfig {
	return cloneTo(in, func() *AvatarOutfitConfig { return &AvatarOutfitConfig{} })
}

func AvatarOutfitConfigToMoe(in *AvatarOutfitConfig) *moe.AvatarOutfitConfig {
	return cloneTo(in, func() *moe.AvatarOutfitConfig { return &moe.AvatarOutfitConfig{} })
}

func BindFeishuReqFromMoe(in *moe.BindFeishuReq) *BindFeishuReq {
	return cloneTo(in, func() *BindFeishuReq { return &BindFeishuReq{} })
}

func BindFeishuReqToMoe(in *BindFeishuReq) *moe.BindFeishuReq {
	return cloneTo(in, func() *moe.BindFeishuReq { return &moe.BindFeishuReq{} })
}

func BindFeishuRespFromMoe(in *moe.BindFeishuResp) *BindFeishuResp {
	return cloneTo(in, func() *BindFeishuResp { return &BindFeishuResp{} })
}

func BindFeishuRespToMoe(in *BindFeishuResp) *moe.BindFeishuResp {
	return cloneTo(in, func() *moe.BindFeishuResp { return &moe.BindFeishuResp{} })
}

func CheckFollowReqFromMoe(in *moe.CheckFollowReq) *CheckFollowReq {
	return cloneTo(in, func() *CheckFollowReq { return &CheckFollowReq{} })
}

func CheckFollowReqToMoe(in *CheckFollowReq) *moe.CheckFollowReq {
	return cloneTo(in, func() *moe.CheckFollowReq { return &moe.CheckFollowReq{} })
}

func CheckFollowRespFromMoe(in *moe.CheckFollowResp) *CheckFollowResp {
	return cloneTo(in, func() *CheckFollowResp { return &CheckFollowResp{} })
}

func CheckFollowRespToMoe(in *CheckFollowResp) *moe.CheckFollowResp {
	return cloneTo(in, func() *moe.CheckFollowResp { return &moe.CheckFollowResp{} })
}

func CreateNotificationReqFromMoe(in *moe.CreateNotificationReq) *CreateNotificationReq {
	return cloneTo(in, func() *CreateNotificationReq { return &CreateNotificationReq{} })
}

func CreateNotificationReqToMoe(in *CreateNotificationReq) *moe.CreateNotificationReq {
	return cloneTo(in, func() *moe.CreateNotificationReq { return &moe.CreateNotificationReq{} })
}

func CreateNotificationRespFromMoe(in *moe.CreateNotificationResp) *CreateNotificationResp {
	return cloneTo(in, func() *CreateNotificationResp { return &CreateNotificationResp{} })
}

func CreateNotificationRespToMoe(in *CreateNotificationResp) *moe.CreateNotificationResp {
	return cloneTo(in, func() *moe.CreateNotificationResp { return &moe.CreateNotificationResp{} })
}

func DeleteUserReqFromMoe(in *moe.DeleteUserReq) *DeleteUserReq {
	return cloneTo(in, func() *DeleteUserReq { return &DeleteUserReq{} })
}

func DeleteUserReqToMoe(in *DeleteUserReq) *moe.DeleteUserReq {
	return cloneTo(in, func() *moe.DeleteUserReq { return &moe.DeleteUserReq{} })
}

func DeleteUserRespFromMoe(in *moe.DeleteUserResp) *DeleteUserResp {
	return cloneTo(in, func() *DeleteUserResp { return &DeleteUserResp{} })
}

func DeleteUserRespToMoe(in *DeleteUserResp) *moe.DeleteUserResp {
	return cloneTo(in, func() *moe.DeleteUserResp { return &moe.DeleteUserResp{} })
}

func FeishuAuthorizeURLReqFromMoe(in *moe.FeishuAuthorizeURLReq) *FeishuAuthorizeURLReq {
	return cloneTo(in, func() *FeishuAuthorizeURLReq { return &FeishuAuthorizeURLReq{} })
}

func FeishuAuthorizeURLReqToMoe(in *FeishuAuthorizeURLReq) *moe.FeishuAuthorizeURLReq {
	return cloneTo(in, func() *moe.FeishuAuthorizeURLReq { return &moe.FeishuAuthorizeURLReq{} })
}

func FeishuAuthorizeURLRespFromMoe(in *moe.FeishuAuthorizeURLResp) *FeishuAuthorizeURLResp {
	return cloneTo(in, func() *FeishuAuthorizeURLResp { return &FeishuAuthorizeURLResp{} })
}

func FeishuAuthorizeURLRespToMoe(in *FeishuAuthorizeURLResp) *moe.FeishuAuthorizeURLResp {
	return cloneTo(in, func() *moe.FeishuAuthorizeURLResp { return &moe.FeishuAuthorizeURLResp{} })
}

func FeishuLoginReqFromMoe(in *moe.FeishuLoginReq) *FeishuLoginReq {
	return cloneTo(in, func() *FeishuLoginReq { return &FeishuLoginReq{} })
}

func FeishuLoginReqToMoe(in *FeishuLoginReq) *moe.FeishuLoginReq {
	return cloneTo(in, func() *moe.FeishuLoginReq { return &moe.FeishuLoginReq{} })
}

func FeishuLoginRespFromMoe(in *moe.FeishuLoginResp) *FeishuLoginResp {
	return cloneTo(in, func() *FeishuLoginResp { return &FeishuLoginResp{} })
}

func FeishuLoginRespToMoe(in *FeishuLoginResp) *moe.FeishuLoginResp {
	return cloneTo(in, func() *moe.FeishuLoginResp { return &moe.FeishuLoginResp{} })
}

func FollowUserReqFromMoe(in *moe.FollowUserReq) *FollowUserReq {
	return cloneTo(in, func() *FollowUserReq { return &FollowUserReq{} })
}

func FollowUserReqToMoe(in *FollowUserReq) *moe.FollowUserReq {
	return cloneTo(in, func() *moe.FollowUserReq { return &moe.FollowUserReq{} })
}

func FollowUserRespFromMoe(in *moe.FollowUserResp) *FollowUserResp {
	return cloneTo(in, func() *FollowUserResp { return &FollowUserResp{} })
}

func FollowUserRespToMoe(in *FollowUserResp) *moe.FollowUserResp {
	return cloneTo(in, func() *moe.FollowUserResp { return &moe.FollowUserResp{} })
}

func FriendRequestViewFromMoe(in *moe.FriendRequestView) *FriendRequestView {
	return cloneTo(in, func() *FriendRequestView { return &FriendRequestView{} })
}

func FriendRequestViewToMoe(in *FriendRequestView) *moe.FriendRequestView {
	return cloneTo(in, func() *moe.FriendRequestView { return &moe.FriendRequestView{} })
}

func GetFollowersReqFromMoe(in *moe.GetFollowersReq) *GetFollowersReq {
	return cloneTo(in, func() *GetFollowersReq { return &GetFollowersReq{} })
}

func GetFollowersReqToMoe(in *GetFollowersReq) *moe.GetFollowersReq {
	return cloneTo(in, func() *moe.GetFollowersReq { return &moe.GetFollowersReq{} })
}

func GetFollowersRespFromMoe(in *moe.GetFollowersResp) *GetFollowersResp {
	return cloneTo(in, func() *GetFollowersResp { return &GetFollowersResp{} })
}

func GetFollowersRespToMoe(in *GetFollowersResp) *moe.GetFollowersResp {
	return cloneTo(in, func() *moe.GetFollowersResp { return &moe.GetFollowersResp{} })
}

func GetFollowingsReqFromMoe(in *moe.GetFollowingsReq) *GetFollowingsReq {
	return cloneTo(in, func() *GetFollowingsReq { return &GetFollowingsReq{} })
}

func GetFollowingsReqToMoe(in *GetFollowingsReq) *moe.GetFollowingsReq {
	return cloneTo(in, func() *moe.GetFollowingsReq { return &moe.GetFollowingsReq{} })
}

func GetFollowingsRespFromMoe(in *moe.GetFollowingsResp) *GetFollowingsResp {
	return cloneTo(in, func() *GetFollowingsResp { return &GetFollowingsResp{} })
}

func GetFollowingsRespToMoe(in *GetFollowingsResp) *moe.GetFollowingsResp {
	return cloneTo(in, func() *moe.GetFollowingsResp { return &moe.GetFollowingsResp{} })
}

func GetFriendRelationReqFromMoe(in *moe.GetFriendRelationReq) *GetFriendRelationReq {
	return cloneTo(in, func() *GetFriendRelationReq { return &GetFriendRelationReq{} })
}

func GetFriendRelationReqToMoe(in *GetFriendRelationReq) *moe.GetFriendRelationReq {
	return cloneTo(in, func() *moe.GetFriendRelationReq { return &moe.GetFriendRelationReq{} })
}

func GetFriendRelationRespFromMoe(in *moe.GetFriendRelationResp) *GetFriendRelationResp {
	return cloneTo(in, func() *GetFriendRelationResp { return &GetFriendRelationResp{} })
}

func GetFriendRelationRespToMoe(in *GetFriendRelationResp) *moe.GetFriendRelationResp {
	return cloneTo(in, func() *moe.GetFriendRelationResp { return &moe.GetFriendRelationResp{} })
}

func GetNotificationsReqFromMoe(in *moe.GetNotificationsReq) *GetNotificationsReq {
	return cloneTo(in, func() *GetNotificationsReq { return &GetNotificationsReq{} })
}

func GetNotificationsReqToMoe(in *GetNotificationsReq) *moe.GetNotificationsReq {
	return cloneTo(in, func() *moe.GetNotificationsReq { return &moe.GetNotificationsReq{} })
}

func GetNotificationsRespFromMoe(in *moe.GetNotificationsResp) *GetNotificationsResp {
	return cloneTo(in, func() *GetNotificationsResp { return &GetNotificationsResp{} })
}

func GetNotificationsRespToMoe(in *GetNotificationsResp) *moe.GetNotificationsResp {
	return cloneTo(in, func() *moe.GetNotificationsResp { return &moe.GetNotificationsResp{} })
}

func GetTransactionReqFromMoe(in *moe.GetTransactionReq) *GetTransactionReq {
	return cloneTo(in, func() *GetTransactionReq { return &GetTransactionReq{} })
}

func GetTransactionReqToMoe(in *GetTransactionReq) *moe.GetTransactionReq {
	return cloneTo(in, func() *moe.GetTransactionReq { return &moe.GetTransactionReq{} })
}

func GetTransactionRespFromMoe(in *moe.GetTransactionResp) *GetTransactionResp {
	return cloneTo(in, func() *GetTransactionResp { return &GetTransactionResp{} })
}

func GetTransactionRespToMoe(in *GetTransactionResp) *moe.GetTransactionResp {
	return cloneTo(in, func() *moe.GetTransactionResp { return &moe.GetTransactionResp{} })
}

func GetTransactionsReqFromMoe(in *moe.GetTransactionsReq) *GetTransactionsReq {
	return cloneTo(in, func() *GetTransactionsReq { return &GetTransactionsReq{} })
}

func GetTransactionsReqToMoe(in *GetTransactionsReq) *moe.GetTransactionsReq {
	return cloneTo(in, func() *moe.GetTransactionsReq { return &moe.GetTransactionsReq{} })
}

func GetTransactionsRespFromMoe(in *moe.GetTransactionsResp) *GetTransactionsResp {
	return cloneTo(in, func() *GetTransactionsResp { return &GetTransactionsResp{} })
}

func GetTransactionsRespToMoe(in *GetTransactionsResp) *moe.GetTransactionsResp {
	return cloneTo(in, func() *moe.GetTransactionsResp { return &moe.GetTransactionsResp{} })
}

func GetUnreadCountReqFromMoe(in *moe.GetUnreadCountReq) *GetUnreadCountReq {
	return cloneTo(in, func() *GetUnreadCountReq { return &GetUnreadCountReq{} })
}

func GetUnreadCountReqToMoe(in *GetUnreadCountReq) *moe.GetUnreadCountReq {
	return cloneTo(in, func() *moe.GetUnreadCountReq { return &moe.GetUnreadCountReq{} })
}

func GetUnreadCountRespFromMoe(in *moe.GetUnreadCountResp) *GetUnreadCountResp {
	return cloneTo(in, func() *GetUnreadCountResp { return &GetUnreadCountResp{} })
}

func GetUnreadCountRespToMoe(in *GetUnreadCountResp) *moe.GetUnreadCountResp {
	return cloneTo(in, func() *moe.GetUnreadCountResp { return &moe.GetUnreadCountResp{} })
}

func GetUserAvatarReqFromMoe(in *moe.GetUserAvatarReq) *GetUserAvatarReq {
	return cloneTo(in, func() *GetUserAvatarReq { return &GetUserAvatarReq{} })
}

func GetUserAvatarReqToMoe(in *GetUserAvatarReq) *moe.GetUserAvatarReq {
	return cloneTo(in, func() *moe.GetUserAvatarReq { return &moe.GetUserAvatarReq{} })
}

func GetUserAvatarRespFromMoe(in *moe.GetUserAvatarResp) *GetUserAvatarResp {
	return cloneTo(in, func() *GetUserAvatarResp { return &GetUserAvatarResp{} })
}

func GetUserAvatarRespToMoe(in *GetUserAvatarResp) *moe.GetUserAvatarResp {
	return cloneTo(in, func() *moe.GetUserAvatarResp { return &moe.GetUserAvatarResp{} })
}

func GetUserByEmailReqFromMoe(in *moe.GetUserByEmailReq) *GetUserByEmailReq {
	return cloneTo(in, func() *GetUserByEmailReq { return &GetUserByEmailReq{} })
}

func GetUserByEmailReqToMoe(in *GetUserByEmailReq) *moe.GetUserByEmailReq {
	return cloneTo(in, func() *moe.GetUserByEmailReq { return &moe.GetUserByEmailReq{} })
}

func GetUserByEmailRespFromMoe(in *moe.GetUserByEmailResp) *GetUserByEmailResp {
	return cloneTo(in, func() *GetUserByEmailResp { return &GetUserByEmailResp{} })
}

func GetUserByEmailRespToMoe(in *GetUserByEmailResp) *moe.GetUserByEmailResp {
	return cloneTo(in, func() *moe.GetUserByEmailResp { return &moe.GetUserByEmailResp{} })
}

func GetUserCountReqFromMoe(in *moe.GetUserCountReq) *GetUserCountReq {
	return cloneTo(in, func() *GetUserCountReq { return &GetUserCountReq{} })
}

func GetUserCountReqToMoe(in *GetUserCountReq) *moe.GetUserCountReq {
	return cloneTo(in, func() *moe.GetUserCountReq { return &moe.GetUserCountReq{} })
}

func GetUserCountRespFromMoe(in *moe.GetUserCountResp) *GetUserCountResp {
	return cloneTo(in, func() *GetUserCountResp { return &GetUserCountResp{} })
}

func GetUserCountRespToMoe(in *GetUserCountResp) *moe.GetUserCountResp {
	return cloneTo(in, func() *moe.GetUserCountResp { return &moe.GetUserCountResp{} })
}

func GetUserInfoReqFromMoe(in *moe.GetUserInfoReq) *GetUserInfoReq {
	return cloneTo(in, func() *GetUserInfoReq { return &GetUserInfoReq{} })
}

func GetUserInfoReqToMoe(in *GetUserInfoReq) *moe.GetUserInfoReq {
	return cloneTo(in, func() *moe.GetUserInfoReq { return &moe.GetUserInfoReq{} })
}

func GetUserInfoRespFromMoe(in *moe.GetUserInfoResp) *GetUserInfoResp {
	return cloneTo(in, func() *GetUserInfoResp { return &GetUserInfoResp{} })
}

func GetUserInfoRespToMoe(in *GetUserInfoResp) *moe.GetUserInfoResp {
	return cloneTo(in, func() *moe.GetUserInfoResp { return &moe.GetUserInfoResp{} })
}

func GetUserMemoriesReqFromMoe(in *moe.GetUserMemoriesReq) *GetUserMemoriesReq {
	return cloneTo(in, func() *GetUserMemoriesReq { return &GetUserMemoriesReq{} })
}

func GetUserMemoriesReqToMoe(in *GetUserMemoriesReq) *moe.GetUserMemoriesReq {
	return cloneTo(in, func() *moe.GetUserMemoriesReq { return &moe.GetUserMemoriesReq{} })
}

func GetUserMemoriesRespFromMoe(in *moe.GetUserMemoriesResp) *GetUserMemoriesResp {
	return cloneTo(in, func() *GetUserMemoriesResp { return &GetUserMemoriesResp{} })
}

func GetUserMemoriesRespToMoe(in *GetUserMemoriesResp) *moe.GetUserMemoriesResp {
	return cloneTo(in, func() *moe.GetUserMemoriesResp { return &moe.GetUserMemoriesResp{} })
}

func GetUserReqFromMoe(in *moe.GetUserReq) *GetUserReq {
	return cloneTo(in, func() *GetUserReq { return &GetUserReq{} })
}

func GetUserReqToMoe(in *GetUserReq) *moe.GetUserReq {
	return cloneTo(in, func() *moe.GetUserReq { return &moe.GetUserReq{} })
}

func GetUserRespFromMoe(in *moe.GetUserResp) *GetUserResp {
	return cloneTo(in, func() *GetUserResp { return &GetUserResp{} })
}

func GetUserRespToMoe(in *GetUserResp) *moe.GetUserResp {
	return cloneTo(in, func() *moe.GetUserResp { return &moe.GetUserResp{} })
}

func GetUserUnlockedAchievementsReqFromMoe(in *moe.GetUserUnlockedAchievementsReq) *GetUserUnlockedAchievementsReq {
	return cloneTo(in, func() *GetUserUnlockedAchievementsReq { return &GetUserUnlockedAchievementsReq{} })
}

func GetUserUnlockedAchievementsReqToMoe(in *GetUserUnlockedAchievementsReq) *moe.GetUserUnlockedAchievementsReq {
	return cloneTo(in, func() *moe.GetUserUnlockedAchievementsReq { return &moe.GetUserUnlockedAchievementsReq{} })
}

func GetUserUnlockedAchievementsRespFromMoe(in *moe.GetUserUnlockedAchievementsResp) *GetUserUnlockedAchievementsResp {
	return cloneTo(in, func() *GetUserUnlockedAchievementsResp { return &GetUserUnlockedAchievementsResp{} })
}

func GetUserUnlockedAchievementsRespToMoe(in *GetUserUnlockedAchievementsResp) *moe.GetUserUnlockedAchievementsResp {
	return cloneTo(in, func() *moe.GetUserUnlockedAchievementsResp { return &moe.GetUserUnlockedAchievementsResp{} })
}

func GetUsersReqFromMoe(in *moe.GetUsersReq) *GetUsersReq {
	return cloneTo(in, func() *GetUsersReq { return &GetUsersReq{} })
}

func GetUsersReqToMoe(in *GetUsersReq) *moe.GetUsersReq {
	return cloneTo(in, func() *moe.GetUsersReq { return &moe.GetUsersReq{} })
}

func GetUsersRespFromMoe(in *moe.GetUsersResp) *GetUsersResp {
	return cloneTo(in, func() *GetUsersResp { return &GetUsersResp{} })
}

func GetUsersRespToMoe(in *GetUsersResp) *moe.GetUsersResp {
	return cloneTo(in, func() *moe.GetUsersResp { return &moe.GetUsersResp{} })
}

func ListFriendsReqFromMoe(in *moe.ListFriendsReq) *ListFriendsReq {
	return cloneTo(in, func() *ListFriendsReq { return &ListFriendsReq{} })
}

func ListFriendsReqToMoe(in *ListFriendsReq) *moe.ListFriendsReq {
	return cloneTo(in, func() *moe.ListFriendsReq { return &moe.ListFriendsReq{} })
}

func ListFriendsRespFromMoe(in *moe.ListFriendsResp) *ListFriendsResp {
	return cloneTo(in, func() *ListFriendsResp { return &ListFriendsResp{} })
}

func ListFriendsRespToMoe(in *ListFriendsResp) *moe.ListFriendsResp {
	return cloneTo(in, func() *moe.ListFriendsResp { return &moe.ListFriendsResp{} })
}

func ListIncomingFriendRequestsReqFromMoe(in *moe.ListIncomingFriendRequestsReq) *ListIncomingFriendRequestsReq {
	return cloneTo(in, func() *ListIncomingFriendRequestsReq { return &ListIncomingFriendRequestsReq{} })
}

func ListIncomingFriendRequestsReqToMoe(in *ListIncomingFriendRequestsReq) *moe.ListIncomingFriendRequestsReq {
	return cloneTo(in, func() *moe.ListIncomingFriendRequestsReq { return &moe.ListIncomingFriendRequestsReq{} })
}

func ListIncomingFriendRequestsRespFromMoe(in *moe.ListIncomingFriendRequestsResp) *ListIncomingFriendRequestsResp {
	return cloneTo(in, func() *ListIncomingFriendRequestsResp { return &ListIncomingFriendRequestsResp{} })
}

func ListIncomingFriendRequestsRespToMoe(in *ListIncomingFriendRequestsResp) *moe.ListIncomingFriendRequestsResp {
	return cloneTo(in, func() *moe.ListIncomingFriendRequestsResp { return &moe.ListIncomingFriendRequestsResp{} })
}

func ListOutgoingFriendRequestsReqFromMoe(in *moe.ListOutgoingFriendRequestsReq) *ListOutgoingFriendRequestsReq {
	return cloneTo(in, func() *ListOutgoingFriendRequestsReq { return &ListOutgoingFriendRequestsReq{} })
}

func ListOutgoingFriendRequestsReqToMoe(in *ListOutgoingFriendRequestsReq) *moe.ListOutgoingFriendRequestsReq {
	return cloneTo(in, func() *moe.ListOutgoingFriendRequestsReq { return &moe.ListOutgoingFriendRequestsReq{} })
}

func ListOutgoingFriendRequestsRespFromMoe(in *moe.ListOutgoingFriendRequestsResp) *ListOutgoingFriendRequestsResp {
	return cloneTo(in, func() *ListOutgoingFriendRequestsResp { return &ListOutgoingFriendRequestsResp{} })
}

func ListOutgoingFriendRequestsRespToMoe(in *ListOutgoingFriendRequestsResp) *moe.ListOutgoingFriendRequestsResp {
	return cloneTo(in, func() *moe.ListOutgoingFriendRequestsResp { return &moe.ListOutgoingFriendRequestsResp{} })
}

func ListPrivateConversationsReqFromMoe(in *moe.ListPrivateConversationsReq) *ListPrivateConversationsReq {
	return cloneTo(in, func() *ListPrivateConversationsReq { return &ListPrivateConversationsReq{} })
}

func ListPrivateConversationsReqToMoe(in *ListPrivateConversationsReq) *moe.ListPrivateConversationsReq {
	return cloneTo(in, func() *moe.ListPrivateConversationsReq { return &moe.ListPrivateConversationsReq{} })
}

func ListPrivateConversationsRespFromMoe(in *moe.ListPrivateConversationsResp) *ListPrivateConversationsResp {
	return cloneTo(in, func() *ListPrivateConversationsResp { return &ListPrivateConversationsResp{} })
}

func ListPrivateConversationsRespToMoe(in *ListPrivateConversationsResp) *moe.ListPrivateConversationsResp {
	return cloneTo(in, func() *moe.ListPrivateConversationsResp { return &moe.ListPrivateConversationsResp{} })
}

func ListPrivateMessagesReqFromMoe(in *moe.ListPrivateMessagesReq) *ListPrivateMessagesReq {
	return cloneTo(in, func() *ListPrivateMessagesReq { return &ListPrivateMessagesReq{} })
}

func ListPrivateMessagesReqToMoe(in *ListPrivateMessagesReq) *moe.ListPrivateMessagesReq {
	return cloneTo(in, func() *moe.ListPrivateMessagesReq { return &moe.ListPrivateMessagesReq{} })
}

func ListPrivateMessagesRespFromMoe(in *moe.ListPrivateMessagesResp) *ListPrivateMessagesResp {
	return cloneTo(in, func() *ListPrivateMessagesResp { return &ListPrivateMessagesResp{} })
}

func ListPrivateMessagesRespToMoe(in *ListPrivateMessagesResp) *moe.ListPrivateMessagesResp {
	return cloneTo(in, func() *moe.ListPrivateMessagesResp { return &moe.ListPrivateMessagesResp{} })
}

func ListUserDevicesReqFromMoe(in *moe.ListUserDevicesReq) *ListUserDevicesReq {
	return cloneTo(in, func() *ListUserDevicesReq { return &ListUserDevicesReq{} })
}

func ListUserDevicesReqToMoe(in *ListUserDevicesReq) *moe.ListUserDevicesReq {
	return cloneTo(in, func() *moe.ListUserDevicesReq { return &moe.ListUserDevicesReq{} })
}

func ListUserDevicesRespFromMoe(in *moe.ListUserDevicesResp) *ListUserDevicesResp {
	return cloneTo(in, func() *ListUserDevicesResp { return &ListUserDevicesResp{} })
}

func ListUserDevicesRespToMoe(in *ListUserDevicesResp) *moe.ListUserDevicesResp {
	return cloneTo(in, func() *moe.ListUserDevicesResp { return &moe.ListUserDevicesResp{} })
}

func LoginReqFromMoe(in *moe.LoginReq) *LoginReq {
	return cloneTo(in, func() *LoginReq { return &LoginReq{} })
}

func LoginReqToMoe(in *LoginReq) *moe.LoginReq {
	return cloneTo(in, func() *moe.LoginReq { return &moe.LoginReq{} })
}

func LoginRespFromMoe(in *moe.LoginResp) *LoginResp {
	return cloneTo(in, func() *LoginResp { return &LoginResp{} })
}

func LoginRespToMoe(in *LoginResp) *moe.LoginResp {
	return cloneTo(in, func() *moe.LoginResp { return &moe.LoginResp{} })
}

func NotificationFromMoe(in *moe.Notification) *Notification {
	return cloneTo(in, func() *Notification { return &Notification{} })
}

func NotificationToMoe(in *Notification) *moe.Notification {
	return cloneTo(in, func() *moe.Notification { return &moe.Notification{} })
}

func PrivateConversationFromMoe(in *moe.PrivateConversation) *PrivateConversation {
	return cloneTo(in, func() *PrivateConversation { return &PrivateConversation{} })
}

func PrivateConversationToMoe(in *PrivateConversation) *moe.PrivateConversation {
	return cloneTo(in, func() *moe.PrivateConversation { return &moe.PrivateConversation{} })
}

func PrivateMessageFromMoe(in *moe.PrivateMessage) *PrivateMessage {
	return cloneTo(in, func() *PrivateMessage { return &PrivateMessage{} })
}

func PrivateMessageToMoe(in *PrivateMessage) *moe.PrivateMessage {
	return cloneTo(in, func() *moe.PrivateMessage { return &moe.PrivateMessage{} })
}

func ReadAllNotificationsReqFromMoe(in *moe.ReadAllNotificationsReq) *ReadAllNotificationsReq {
	return cloneTo(in, func() *ReadAllNotificationsReq { return &ReadAllNotificationsReq{} })
}

func ReadAllNotificationsReqToMoe(in *ReadAllNotificationsReq) *moe.ReadAllNotificationsReq {
	return cloneTo(in, func() *moe.ReadAllNotificationsReq { return &moe.ReadAllNotificationsReq{} })
}

func ReadAllNotificationsRespFromMoe(in *moe.ReadAllNotificationsResp) *ReadAllNotificationsResp {
	return cloneTo(in, func() *ReadAllNotificationsResp { return &ReadAllNotificationsResp{} })
}

func ReadAllNotificationsRespToMoe(in *ReadAllNotificationsResp) *moe.ReadAllNotificationsResp {
	return cloneTo(in, func() *moe.ReadAllNotificationsResp { return &moe.ReadAllNotificationsResp{} })
}

func ReadNotificationReqFromMoe(in *moe.ReadNotificationReq) *ReadNotificationReq {
	return cloneTo(in, func() *ReadNotificationReq { return &ReadNotificationReq{} })
}

func ReadNotificationReqToMoe(in *ReadNotificationReq) *moe.ReadNotificationReq {
	return cloneTo(in, func() *moe.ReadNotificationReq { return &moe.ReadNotificationReq{} })
}

func ReadNotificationRespFromMoe(in *moe.ReadNotificationResp) *ReadNotificationResp {
	return cloneTo(in, func() *ReadNotificationResp { return &ReadNotificationResp{} })
}

func ReadNotificationRespToMoe(in *ReadNotificationResp) *moe.ReadNotificationResp {
	return cloneTo(in, func() *moe.ReadNotificationResp { return &moe.ReadNotificationResp{} })
}

func RechargeReqFromMoe(in *moe.RechargeReq) *RechargeReq {
	return cloneTo(in, func() *RechargeReq { return &RechargeReq{} })
}

func RechargeReqToMoe(in *RechargeReq) *moe.RechargeReq {
	return cloneTo(in, func() *moe.RechargeReq { return &moe.RechargeReq{} })
}

func RechargeRespFromMoe(in *moe.RechargeResp) *RechargeResp {
	return cloneTo(in, func() *RechargeResp { return &RechargeResp{} })
}

func RechargeRespToMoe(in *RechargeResp) *moe.RechargeResp {
	return cloneTo(in, func() *moe.RechargeResp { return &moe.RechargeResp{} })
}

func RegisterReqFromMoe(in *moe.RegisterReq) *RegisterReq {
	return cloneTo(in, func() *RegisterReq { return &RegisterReq{} })
}

func RegisterReqToMoe(in *RegisterReq) *moe.RegisterReq {
	return cloneTo(in, func() *moe.RegisterReq { return &moe.RegisterReq{} })
}

func RegisterRespFromMoe(in *moe.RegisterResp) *RegisterResp {
	return cloneTo(in, func() *RegisterResp { return &RegisterResp{} })
}

func RegisterRespToMoe(in *RegisterResp) *moe.RegisterResp {
	return cloneTo(in, func() *moe.RegisterResp { return &moe.RegisterResp{} })
}

func RejectFriendRequestReqFromMoe(in *moe.RejectFriendRequestReq) *RejectFriendRequestReq {
	return cloneTo(in, func() *RejectFriendRequestReq { return &RejectFriendRequestReq{} })
}

func RejectFriendRequestReqToMoe(in *RejectFriendRequestReq) *moe.RejectFriendRequestReq {
	return cloneTo(in, func() *moe.RejectFriendRequestReq { return &moe.RejectFriendRequestReq{} })
}

func RejectFriendRequestRespFromMoe(in *moe.RejectFriendRequestResp) *RejectFriendRequestResp {
	return cloneTo(in, func() *RejectFriendRequestResp { return &RejectFriendRequestResp{} })
}

func RejectFriendRequestRespToMoe(in *RejectFriendRequestResp) *moe.RejectFriendRequestResp {
	return cloneTo(in, func() *moe.RejectFriendRequestResp { return &moe.RejectFriendRequestResp{} })
}

func ResetPasswordReqFromMoe(in *moe.ResetPasswordReq) *ResetPasswordReq {
	return cloneTo(in, func() *ResetPasswordReq { return &ResetPasswordReq{} })
}

func ResetPasswordReqToMoe(in *ResetPasswordReq) *moe.ResetPasswordReq {
	return cloneTo(in, func() *moe.ResetPasswordReq { return &moe.ResetPasswordReq{} })
}

func ResetPasswordRespFromMoe(in *moe.ResetPasswordResp) *ResetPasswordResp {
	return cloneTo(in, func() *ResetPasswordResp { return &ResetPasswordResp{} })
}

func ResetPasswordRespToMoe(in *ResetPasswordResp) *moe.ResetPasswordResp {
	return cloneTo(in, func() *moe.ResetPasswordResp { return &moe.ResetPasswordResp{} })
}

func SendFeishuTestCardReqFromMoe(in *moe.SendFeishuTestCardReq) *SendFeishuTestCardReq {
	return cloneTo(in, func() *SendFeishuTestCardReq { return &SendFeishuTestCardReq{} })
}

func SendFeishuTestCardReqToMoe(in *SendFeishuTestCardReq) *moe.SendFeishuTestCardReq {
	return cloneTo(in, func() *moe.SendFeishuTestCardReq { return &moe.SendFeishuTestCardReq{} })
}

func SendFeishuTestCardRespFromMoe(in *moe.SendFeishuTestCardResp) *SendFeishuTestCardResp {
	return cloneTo(in, func() *SendFeishuTestCardResp { return &SendFeishuTestCardResp{} })
}

func SendFeishuTestCardRespToMoe(in *SendFeishuTestCardResp) *moe.SendFeishuTestCardResp {
	return cloneTo(in, func() *moe.SendFeishuTestCardResp { return &moe.SendFeishuTestCardResp{} })
}

func SendFriendRequestReqFromMoe(in *moe.SendFriendRequestReq) *SendFriendRequestReq {
	return cloneTo(in, func() *SendFriendRequestReq { return &SendFriendRequestReq{} })
}

func SendFriendRequestReqToMoe(in *SendFriendRequestReq) *moe.SendFriendRequestReq {
	return cloneTo(in, func() *moe.SendFriendRequestReq { return &moe.SendFriendRequestReq{} })
}

func SendFriendRequestRespFromMoe(in *moe.SendFriendRequestResp) *SendFriendRequestResp {
	return cloneTo(in, func() *SendFriendRequestResp { return &SendFriendRequestResp{} })
}

func SendFriendRequestRespToMoe(in *SendFriendRequestResp) *moe.SendFriendRequestResp {
	return cloneTo(in, func() *moe.SendFriendRequestResp { return &moe.SendFriendRequestResp{} })
}

func SendPrivateMessageReqFromMoe(in *moe.SendPrivateMessageReq) *SendPrivateMessageReq {
	return cloneTo(in, func() *SendPrivateMessageReq { return &SendPrivateMessageReq{} })
}

func SendPrivateMessageReqToMoe(in *SendPrivateMessageReq) *moe.SendPrivateMessageReq {
	return cloneTo(in, func() *moe.SendPrivateMessageReq { return &moe.SendPrivateMessageReq{} })
}

func SendPrivateMessageRespFromMoe(in *moe.SendPrivateMessageResp) *SendPrivateMessageResp {
	return cloneTo(in, func() *SendPrivateMessageResp { return &SendPrivateMessageResp{} })
}

func SendPrivateMessageRespToMoe(in *SendPrivateMessageResp) *moe.SendPrivateMessageResp {
	return cloneTo(in, func() *moe.SendPrivateMessageResp { return &moe.SendPrivateMessageResp{} })
}

func SyncUserDeviceReqFromMoe(in *moe.SyncUserDeviceReq) *SyncUserDeviceReq {
	return cloneTo(in, func() *SyncUserDeviceReq { return &SyncUserDeviceReq{} })
}

func SyncUserDeviceReqToMoe(in *SyncUserDeviceReq) *moe.SyncUserDeviceReq {
	return cloneTo(in, func() *moe.SyncUserDeviceReq { return &moe.SyncUserDeviceReq{} })
}

func SyncUserDeviceRespFromMoe(in *moe.SyncUserDeviceResp) *SyncUserDeviceResp {
	return cloneTo(in, func() *SyncUserDeviceResp { return &SyncUserDeviceResp{} })
}

func SyncUserDeviceRespToMoe(in *SyncUserDeviceResp) *moe.SyncUserDeviceResp {
	return cloneTo(in, func() *moe.SyncUserDeviceResp { return &moe.SyncUserDeviceResp{} })
}

func TransactionFromMoe(in *moe.Transaction) *Transaction {
	return cloneTo(in, func() *Transaction { return &Transaction{} })
}

func TransactionToMoe(in *Transaction) *moe.Transaction {
	return cloneTo(in, func() *moe.Transaction { return &moe.Transaction{} })
}

func UnbindFeishuReqFromMoe(in *moe.UnbindFeishuReq) *UnbindFeishuReq {
	return cloneTo(in, func() *UnbindFeishuReq { return &UnbindFeishuReq{} })
}

func UnbindFeishuReqToMoe(in *UnbindFeishuReq) *moe.UnbindFeishuReq {
	return cloneTo(in, func() *moe.UnbindFeishuReq { return &moe.UnbindFeishuReq{} })
}

func UnbindFeishuRespFromMoe(in *moe.UnbindFeishuResp) *UnbindFeishuResp {
	return cloneTo(in, func() *UnbindFeishuResp { return &UnbindFeishuResp{} })
}

func UnbindFeishuRespToMoe(in *UnbindFeishuResp) *moe.UnbindFeishuResp {
	return cloneTo(in, func() *moe.UnbindFeishuResp { return &moe.UnbindFeishuResp{} })
}

func UnfollowUserReqFromMoe(in *moe.UnfollowUserReq) *UnfollowUserReq {
	return cloneTo(in, func() *UnfollowUserReq { return &UnfollowUserReq{} })
}

func UnfollowUserReqToMoe(in *UnfollowUserReq) *moe.UnfollowUserReq {
	return cloneTo(in, func() *moe.UnfollowUserReq { return &moe.UnfollowUserReq{} })
}

func UpdateUserAvatarReqFromMoe(in *moe.UpdateUserAvatarReq) *UpdateUserAvatarReq {
	return cloneTo(in, func() *UpdateUserAvatarReq { return &UpdateUserAvatarReq{} })
}

func UpdateUserAvatarReqToMoe(in *UpdateUserAvatarReq) *moe.UpdateUserAvatarReq {
	return cloneTo(in, func() *moe.UpdateUserAvatarReq { return &moe.UpdateUserAvatarReq{} })
}

func UpdateUserAvatarRespFromMoe(in *moe.UpdateUserAvatarResp) *UpdateUserAvatarResp {
	return cloneTo(in, func() *UpdateUserAvatarResp { return &UpdateUserAvatarResp{} })
}

func UpdateUserAvatarRespToMoe(in *UpdateUserAvatarResp) *moe.UpdateUserAvatarResp {
	return cloneTo(in, func() *moe.UpdateUserAvatarResp { return &moe.UpdateUserAvatarResp{} })
}

func UpdateUserInfoReqFromMoe(in *moe.UpdateUserInfoReq) *UpdateUserInfoReq {
	return cloneTo(in, func() *UpdateUserInfoReq { return &UpdateUserInfoReq{} })
}

func UpdateUserInfoReqToMoe(in *UpdateUserInfoReq) *moe.UpdateUserInfoReq {
	return cloneTo(in, func() *moe.UpdateUserInfoReq { return &moe.UpdateUserInfoReq{} })
}

func UpdateUserInfoRespFromMoe(in *moe.UpdateUserInfoResp) *UpdateUserInfoResp {
	return cloneTo(in, func() *UpdateUserInfoResp { return &UpdateUserInfoResp{} })
}

func UpdateUserInfoRespToMoe(in *UpdateUserInfoResp) *moe.UpdateUserInfoResp {
	return cloneTo(in, func() *moe.UpdateUserInfoResp { return &moe.UpdateUserInfoResp{} })
}

func UpdateUserPasswordReqFromMoe(in *moe.UpdateUserPasswordReq) *UpdateUserPasswordReq {
	return cloneTo(in, func() *UpdateUserPasswordReq { return &UpdateUserPasswordReq{} })
}

func UpdateUserPasswordReqToMoe(in *UpdateUserPasswordReq) *moe.UpdateUserPasswordReq {
	return cloneTo(in, func() *moe.UpdateUserPasswordReq { return &moe.UpdateUserPasswordReq{} })
}

func UpdateUserPasswordRespFromMoe(in *moe.UpdateUserPasswordResp) *UpdateUserPasswordResp {
	return cloneTo(in, func() *UpdateUserPasswordResp { return &UpdateUserPasswordResp{} })
}

func UpdateUserPasswordRespToMoe(in *UpdateUserPasswordResp) *moe.UpdateUserPasswordResp {
	return cloneTo(in, func() *moe.UpdateUserPasswordResp { return &moe.UpdateUserPasswordResp{} })
}

func UserFromMoe(in *moe.User) *User {
	return cloneTo(in, func() *User { return &User{} })
}

func UserToMoe(in *User) *moe.User {
	return cloneTo(in, func() *moe.User { return &moe.User{} })
}

func UserAvatarDataFromMoe(in *moe.UserAvatarData) *UserAvatarData {
	return cloneTo(in, func() *UserAvatarData { return &UserAvatarData{} })
}

func UserAvatarDataToMoe(in *UserAvatarData) *moe.UserAvatarData {
	return cloneTo(in, func() *moe.UserAvatarData { return &moe.UserAvatarData{} })
}

func UserDeviceRecordFromMoe(in *moe.UserDeviceRecord) *UserDeviceRecord {
	return cloneTo(in, func() *UserDeviceRecord { return &UserDeviceRecord{} })
}

func UserDeviceRecordToMoe(in *UserDeviceRecord) *moe.UserDeviceRecord {
	return cloneTo(in, func() *moe.UserDeviceRecord { return &moe.UserDeviceRecord{} })
}

func UserMemoryFromMoe(in *moe.UserMemory) *UserMemory {
	return cloneTo(in, func() *UserMemory { return &UserMemory{} })
}

func UserMemoryToMoe(in *UserMemory) *moe.UserMemory {
	return cloneTo(in, func() *moe.UserMemory { return &moe.UserMemory{} })
}

func WechatAuthorizeURLReqFromMoe(in *moe.WechatAuthorizeURLReq) *WechatAuthorizeURLReq {
	return cloneTo(in, func() *WechatAuthorizeURLReq { return &WechatAuthorizeURLReq{} })
}

func WechatAuthorizeURLReqToMoe(in *WechatAuthorizeURLReq) *moe.WechatAuthorizeURLReq {
	return cloneTo(in, func() *moe.WechatAuthorizeURLReq { return &moe.WechatAuthorizeURLReq{} })
}

func WechatAuthorizeURLRespFromMoe(in *moe.WechatAuthorizeURLResp) *WechatAuthorizeURLResp {
	return cloneTo(in, func() *WechatAuthorizeURLResp { return &WechatAuthorizeURLResp{} })
}

func WechatAuthorizeURLRespToMoe(in *WechatAuthorizeURLResp) *moe.WechatAuthorizeURLResp {
	return cloneTo(in, func() *moe.WechatAuthorizeURLResp { return &moe.WechatAuthorizeURLResp{} })
}

func WechatLoginReqFromMoe(in *moe.WechatLoginReq) *WechatLoginReq {
	return cloneTo(in, func() *WechatLoginReq { return &WechatLoginReq{} })
}

func WechatLoginReqToMoe(in *WechatLoginReq) *moe.WechatLoginReq {
	return cloneTo(in, func() *moe.WechatLoginReq { return &moe.WechatLoginReq{} })
}

func WechatLoginRespFromMoe(in *moe.WechatLoginResp) *WechatLoginResp {
	return cloneTo(in, func() *WechatLoginResp { return &WechatLoginResp{} })
}

func WechatLoginRespToMoe(in *WechatLoginResp) *moe.WechatLoginResp {
	return cloneTo(in, func() *moe.WechatLoginResp { return &moe.WechatLoginResp{} })
}
