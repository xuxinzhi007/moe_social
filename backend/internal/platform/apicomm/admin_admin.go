package apicomm

import (
	adminv1 "backend/api/admin/v1"
	"backend/internal/legacy/types"
)

func RpcAdminAchievementToTypes(item *adminv1.AdminAchievementItem) types.AdminAchievementItem {
	if item == nil {
		return types.AdminAchievementItem{}
	}
	return types.AdminAchievementItem{
		Id:            item.GetId(),
		Name:          item.GetName(),
		Description:   item.GetDescription(),
		Category:      item.GetCategory(),
		Rarity:        item.GetRarity(),
		ConditionText: item.GetConditionText(),
		RuleType:      item.GetRuleType(),
		RequiredCount: int(item.GetRequiredCount()),
		RuleParams:    item.GetRuleParams(),
		ExpReward:     int(item.GetExpReward()),
		Enabled:       item.GetEnabled(),
		SortOrder:     int(item.GetSortOrder()),
		CreatedAt:     item.GetCreatedAt(),
	}
}

func RpcAdminAnnouncementToTypes(item *adminv1.AdminAnnouncementItem) types.AdminAnnouncementItem {
	if item == nil {
		return types.AdminAnnouncementItem{}
	}
	return types.AdminAnnouncementItem{
		Id:          item.GetId(),
		Title:       item.GetTitle(),
		Content:     item.GetContent(),
		Status:      item.GetStatus(),
		PublishedAt: item.GetPublishedAt(),
		CreatedBy:   item.GetCreatedBy(),
		CreatedAt:   item.GetCreatedAt(),
		UpdatedAt:   item.GetUpdatedAt(),
	}
}

func RpcAdminAiAgentToTypes(item *adminv1.AdminAiAgentItem) types.AdminAiAgentItem {
	if item == nil {
		return types.AdminAiAgentItem{}
	}
	return types.AdminAiAgentItem{
		Id:          item.GetId(),
		OwnerUserId: item.GetOwnerUserId(),
		OwnerName:   item.GetOwnerName(),
		PayloadJson: item.GetPayloadJson(),
	}
}

func RpcAdminFollowToTypes(item *adminv1.AdminFollowItem) types.AdminFollowItem {
	if item == nil {
		return types.AdminFollowItem{}
	}
	return types.AdminFollowItem{
		Id:            item.GetId(),
		FollowerId:    item.GetFollowerId(),
		FollowerName:  item.GetFollowerName(),
		FollowingId:   item.GetFollowingId(),
		FollowingName: item.GetFollowingName(),
		CreatedAt:     item.GetCreatedAt(),
	}
}

func RpcAdminFriendRequestToTypes(item *adminv1.AdminFriendRequestItem) types.AdminFriendRequestItem {
	if item == nil {
		return types.AdminFriendRequestItem{}
	}
	return types.AdminFriendRequestItem{
		Id:           item.GetId(),
		FromUserId:   item.GetFromUserId(),
		FromUserName: item.GetFromUserName(),
		ToUserId:     item.GetToUserId(),
		ToUserName:   item.GetToUserName(),
		Status:       item.GetStatus(),
		CreatedAt:    item.GetCreatedAt(),
	}
}

func RpcAdminAccountToTypes(item *adminv1.AdminAccountItem) types.AdminAccountItem {
	if item == nil {
		return types.AdminAccountItem{}
	}
	return types.AdminAccountItem{
		Id:          item.GetId(),
		Username:    item.GetUsername(),
		Role:        item.GetRole(),
		LastLoginAt: item.GetLastLoginAt(),
		CreatedAt:   item.GetCreatedAt(),
	}
}

func RpcAdminMenuToTypes(item *adminv1.AdminMenuItem) types.AdminMenuItem {
	if item == nil {
		return types.AdminMenuItem{}
	}
	return types.AdminMenuItem{
		Id:           item.GetId(),
		Key:          item.GetKey(),
		Kind:         item.GetKind(),
		ParentKey:    item.GetParentKey(),
		Path:         item.GetPath(),
		Label:        item.GetLabel(),
		Icon:         item.GetIcon(),
		Caption:      item.GetCaption(),
		Status:       item.GetStatus(),
		AppDomain:    item.GetAppDomain(),
		SortOrder:    int(item.GetSortOrder()),
		DefaultOpen:  item.GetDefaultOpen(),
		End:          item.GetEnd(),
		ExternalHref: item.GetExternalHref(),
		Enabled:      item.GetEnabled(),
	}
}

func RpcAdminAuditLogToTypes(item *adminv1.AdminAuditLogItem) types.AdminAuditLogItem {
	if item == nil {
		return types.AdminAuditLogItem{}
	}
	return types.AdminAuditLogItem{
		Id:         item.GetId(),
		AdminId:    item.GetAdminId(),
		AdminName:  item.GetAdminName(),
		Action:     item.GetAction(),
		Resource:   item.GetResource(),
		ResourceId: item.GetResourceId(),
		Detail:     item.GetDetail(),
		Ip:         item.GetIp(),
		CreatedAt:  item.GetCreatedAt(),
	}
}

func RpcAdminGrowthStatsToTypes(stats *adminv1.AdminGrowthStats) types.AdminGrowthStats {
	if stats == nil {
		return types.AdminGrowthStats{}
	}
	return types.AdminGrowthStats{
		AchievementDefinitions:  int(stats.GetAchievementDefinitions()),
		UnlockedProgressRecords: int(stats.GetUnlockedProgressRecords()),
		LevelConfigs:            int(stats.GetLevelConfigs()),
		CheckInRewards:          int(stats.GetCheckInRewards()),
		UserLevels:              int(stats.GetUserLevels()),
		CheckInsToday:           int(stats.GetCheckInsToday()),
		TotalCheckIns:           int(stats.GetTotalCheckIns()),
	}
}
