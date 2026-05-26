package utils

import "backend/model"

// MigrateEntry 描述一张待 AutoMigrate 的表及其 CLI 筛选 key。
type MigrateEntry struct {
	Key   string
	Model interface{}
}

// MigrateModelRegistry 与 autoMigrate 列表对齐；Key 与 AdminSchemaCatalog 的 Key 一致（便于 -models 筛选）。
func MigrateModelRegistry() []MigrateEntry {
	return []MigrateEntry{
		// 用户和 VIP 相关
		{Key: "users", Model: &model.User{}},
		{Key: "vip_plans", Model: &model.VipPlan{}},
		{Key: "vip_orders", Model: &model.VipOrder{}},
		{Key: "vip_records", Model: &model.VipRecord{}},
		{Key: "transactions", Model: &model.Transaction{}},
		// 社交相关
		{Key: "posts", Model: &model.Post{}},
		{Key: "post_reports", Model: &model.PostReport{}},
		{Key: "likes", Model: &model.Like{}},
		{Key: "topic_tags", Model: &model.TopicTag{}},
		{Key: "post_topics", Model: &model.PostTopic{}},
		{Key: "comments", Model: &model.Comment{}},
		{Key: "follows", Model: &model.Follow{}},
		// 通知和形象相关
		{Key: "notifications", Model: &model.Notification{}},
		{Key: "user_avatars", Model: &model.UserAvatar{}},
		{Key: "avatar_outfits", Model: &model.AvatarOutfit{}},
		{Key: "emojis", Model: &model.Emoji{}},
		{Key: "emoji_packs", Model: &model.EmojiPack{}},
		{Key: "user_emoji_packs", Model: &model.UserEmojiPack{}},
		{Key: "user_memories", Model: &model.UserMemory{}},
		{Key: "user_memory_feedbacks", Model: &model.UserMemoryFeedback{}},
		{Key: "user_memory_profile_caches", Model: &model.UserMemoryProfileCache{}},
		{Key: "user_devices", Model: &model.UserDevice{}},
		{Key: "user_memory_embeddings", Model: &model.UserMemoryEmbedding{}},
		{Key: "user_memory_relations", Model: &model.UserMemoryRelation{}},
		{Key: "ai_user_configs", Model: &model.AiUserConfig{}},
		// 签到等级系统
		{Key: "user_levels", Model: &model.UserLevel{}},
		{Key: "level_configs", Model: &model.LevelConfig{}},
		{Key: "user_check_ins", Model: &model.UserCheckIn{}},
		{Key: "check_in_rewards", Model: &model.CheckInReward{}},
		{Key: "exp_logs", Model: &model.ExpLog{}},
		{Key: "achievement_definitions", Model: &model.AchievementDefinition{}},
		{Key: "user_achievement_progress", Model: &model.UserAchievementProgress{}},
		{Key: "user_daily_activities", Model: &model.UserDailyActivity{}},
		{Key: "user_weekly_activities", Model: &model.UserWeeklyActivity{}},
		{Key: "friend_requests", Model: &model.FriendRequest{}},
		// 礼物和社区相关
		{Key: "gifts", Model: &model.Gift{}},
		{Key: "gift_records", Model: &model.GiftRecord{}},
		{Key: "user_gift_stocks", Model: &model.UserGiftStock{}},
		{Key: "gift_purchase_orders", Model: &model.GiftPurchaseOrder{}},
		{Key: "groups", Model: &model.Group{}},
		{Key: "group_members", Model: &model.GroupMember{}},
		{Key: "group_posts", Model: &model.GroupPost{}},
		{Key: "private_messages", Model: &model.PrivateMessage{}},
		{Key: "landing_feedbacks", Model: &model.LandingFeedback{}},
		{Key: "admin_accounts", Model: &model.AdminAccount{}},
		{Key: "admin_announcements", Model: &model.AdminAnnouncement{}},
		{Key: "admin_menus", Model: &model.AdminMenu{}},
		{Key: "admin_audit_logs", Model: &model.AdminAuditLog{}},
		{Key: "user_behavior_events", Model: &model.UserBehaviorEvent{}},
		{Key: "user_behavior_daily", Model: &model.UserBehaviorDaily{}},
		{Key: "moe_agent_runtimes", Model: &model.MoeAgentRuntime{}},
		{Key: "moe_bot_episodes", Model: &model.MoeBotEpisode{}},
		{Key: "moe_tool_calls", Model: &model.MoeToolCall{}},
	}
}
