package common

import (
	"backend/internal/legacy/types"
	"backend/rpc/pb/moe"
)

func RpcAdminLevelConfigToTypes(item *moe.AdminLevelConfigItem) types.AdminLevelConfigItem {
	if item == nil {
		return types.AdminLevelConfigItem{}
	}
	return types.AdminLevelConfigItem{
		Id:         item.GetId(),
		Level:      int(item.GetLevel()),
		Title:      item.GetTitle(),
		MinExp:     int(item.GetMinExp()),
		MaxExp:     int(item.GetMaxExp()),
		Privileges: item.GetPrivileges(),
		BadgeUrl:   item.GetBadgeUrl(),
	}
}

func RpcAdminCheckInRewardToTypes(item *moe.AdminCheckInRewardItem) types.AdminCheckInRewardItem {
	if item == nil {
		return types.AdminCheckInRewardItem{}
	}
	return types.AdminCheckInRewardItem{
		Id:              item.GetId(),
		ConsecutiveDays: int(item.GetConsecutiveDays()),
		ExpReward:       int(item.GetExpReward()),
		ExtraReward:     item.GetExtraReward(),
	}
}

func RpcAdminUserProfileToTypes(data *moe.AdminUserProfileData) types.AdminUserProfileData {
	if data == nil {
		return types.AdminUserProfileData{}
	}
	out := types.AdminUserProfileData{
		User: RpcUserToTypes(data.GetUser()),
	}
	if c := data.GetCounts(); c != nil {
		out.Counts = types.AdminUserRelationCounts{
			Posts:                int(c.GetPosts()),
			Comments:             int(c.GetComments()),
			Following:            int(c.GetFollowing()),
			Followers:            int(c.GetFollowers()),
			CheckIns:             int(c.GetCheckIns()),
			AchievementsUnlocked: int(c.GetAchievementsUnlocked()),
			VipOrders:            int(c.GetVipOrders()),
			GiftSent:             int(c.GetGiftSent()),
			GiftReceived:         int(c.GetGiftReceived()),
			GiftStocks:           int(c.GetGiftStocks()),
			Transactions:         int(c.GetTransactions()),
			AiAgents:             int(c.GetAiAgents()),
			GroupsJoined:         int(c.GetGroupsJoined()),
		}
	}
	if lv := data.GetLevel(); lv != nil {
		out.Level = types.AdminUserLevelSnapshot{
			Level:      int(lv.GetLevel()),
			Experience: int(lv.GetExperience()),
			TotalExp:   int(lv.GetTotalExp()),
			LevelTitle: lv.GetLevelTitle(),
		}
	}
	if links := data.GetLinks(); len(links) > 0 {
		out.Links = make([]types.AdminUserRelationLink, len(links))
		for i, link := range links {
			out.Links[i] = types.AdminUserRelationLink{
				Label:      link.GetLabel(),
				AdminRoute: link.GetAdminRoute(),
				Hint:       link.GetHint(),
			}
		}
	}
	if b := data.GetBehavior(); b != nil {
		out.Behavior = types.AdminUserBehaviorSummary{
			Tags:          append([]string(nil), b.GetTags()...),
			LastActiveAt:  b.GetLastActiveAt(),
			TotalEvents7d: int(b.GetTotalEvents_7D()),
		}
		if screens := b.GetTopScreens(); len(screens) > 0 {
			out.Behavior.TopScreens = make([]types.AdminUserBehaviorScreenStat, len(screens))
			for i, screen := range screens {
				out.Behavior.TopScreens[i] = types.AdminUserBehaviorScreenStat{
					Screen:          screen.GetScreen(),
					Label:           screen.GetLabel(),
					VisitCount:      int(screen.GetVisitCount()),
					TotalDurationMs: screen.GetTotalDurationMs(),
				}
			}
		}
	}
	return out
}
