package utils

import "backend/model"

// AdminSchemaEntry 描述一张 AutoMigrate 表在 Moe Admin 中的管理能力。
type AdminSchemaEntry struct {
	Key          string
	Label        string
	Domain       string
	Capabilities []string
	AdminRoute   string
	BootstrapKey string
	Note         string
	Model        interface{}
}

// AdminSchemaCatalog 与 utils/db.go autoMigrate 列表对齐（业务表 + 管理表）。
func AdminSchemaCatalog() []AdminSchemaEntry {
	return []AdminSchemaEntry{
		// 用户与会员
		{Key: "users", Label: "App 用户", Domain: "用户与会员", Capabilities: []string{"list", "get", "update", "profile"}, AdminRoute: "/users", Note: "可编辑 avatar URL、签名、角色与 VIP；详情含关联计数", Model: &model.User{}},
		{Key: "vip_plans", Label: "VIP 套餐", Domain: "用户与会员", Capabilities: []string{"list", "get", "create", "update", "delete", "bootstrap"}, AdminRoute: "/vip/plans", BootstrapKey: "vip_plans", Model: &model.VipPlan{}},
		{Key: "vip_orders", Label: "VIP 订单", Domain: "用户与会员", Capabilities: []string{"list"}, AdminRoute: "/wallet/orders", Model: &model.VipOrder{}},
		{Key: "vip_records", Label: "VIP 开通记录", Domain: "用户与会员", Capabilities: nil, Note: "由订单/支付流程写入，暂无独立管理页", Model: &model.VipRecord{}},
		{Key: "transactions", Label: "钱包流水", Domain: "用户与会员", Capabilities: nil, Note: "App 内交易流水，后续可接钱包页", Model: &model.Transaction{}},

		// 内容与社区
		{Key: "posts", Label: "动态", Domain: "内容与社区", Capabilities: []string{"list", "delete"}, AdminRoute: "/content/posts", Model: &model.Post{}},
		{Key: "post_reports", Label: "动态举报", Domain: "内容与社区", Capabilities: []string{"list"}, AdminRoute: "/content/reports", Model: &model.PostReport{}},
		{Key: "comments", Label: "评论", Domain: "内容与社区", Capabilities: []string{"list", "delete"}, AdminRoute: "/content/comments", Model: &model.Comment{}},
		{Key: "likes", Label: "点赞", Domain: "内容与社区", Capabilities: nil, Note: "关联动态，通过动态页治理", Model: &model.Like{}},
		{Key: "topic_tags", Label: "话题标签", Domain: "内容与社区", Capabilities: nil, Note: "随动态创建，暂无独立 CRUD", Model: &model.TopicTag{}},
		{Key: "post_topics", Label: "动态-话题关联", Domain: "内容与社区", Capabilities: nil, Note: "中间表", Model: &model.PostTopic{}},
		{Key: "groups", Label: "兴趣社区", Domain: "内容与社区", Capabilities: []string{"list", "delete"}, AdminRoute: "/content/community", Model: &model.Group{}},
		{Key: "group_members", Label: "社区成员", Domain: "内容与社区", Capabilities: nil, Note: "随社区管理，暂无独立页", Model: &model.GroupMember{}},
		{Key: "group_posts", Label: "社区帖子", Domain: "内容与社区", Capabilities: nil, Note: "随社区管理，暂无独立页", Model: &model.GroupPost{}},

		// 社交
		{Key: "follows", Label: "关注关系", Domain: "社交", Capabilities: []string{"list", "delete"}, AdminRoute: "/app/social", Model: &model.Follow{}},
		{Key: "friend_requests", Label: "好友申请", Domain: "社交", Capabilities: []string{"list"}, AdminRoute: "/app/social", Model: &model.FriendRequest{}},

		// 成长体系
		{Key: "achievement_definitions", Label: "成就定义", Domain: "成长体系", Capabilities: []string{"list", "update", "bootstrap"}, AdminRoute: "/app/growth", BootstrapKey: "achievements", Model: &model.AchievementDefinition{}},
		{Key: "user_achievement_progress", Label: "用户成就进度", Domain: "成长体系", Capabilities: []string{"stats"}, AdminRoute: "/app/growth", Note: "通过用户详情关联查询", Model: &model.UserAchievementProgress{}},
		{Key: "level_configs", Label: "等级配置", Domain: "成长体系", Capabilities: []string{"list", "update", "bootstrap", "stats"}, AdminRoute: "/app/growth", BootstrapKey: "levels", Model: &model.LevelConfig{}},
		{Key: "check_in_rewards", Label: "签到奖励", Domain: "成长体系", Capabilities: []string{"list", "update", "bootstrap", "stats"}, AdminRoute: "/app/growth", BootstrapKey: "levels", Model: &model.CheckInReward{}},
		{Key: "user_levels", Label: "用户等级", Domain: "成长体系", Capabilities: []string{"stats"}, AdminRoute: "/app/growth", Model: &model.UserLevel{}},
		{Key: "user_check_ins", Label: "签到记录", Domain: "成长体系", Capabilities: []string{"stats"}, AdminRoute: "/app/growth", Model: &model.UserCheckIn{}},
		{Key: "exp_logs", Label: "经验流水", Domain: "成长体系", Capabilities: nil, Note: "用户行为产生，只读审计向", Model: &model.ExpLog{}},
		{Key: "user_daily_activities", Label: "日活统计", Domain: "成长体系", Capabilities: nil, Note: "成就引擎写入", Model: &model.UserDailyActivity{}},
		{Key: "user_weekly_activities", Label: "周活统计", Domain: "成长体系", Capabilities: nil, Note: "成就引擎写入", Model: &model.UserWeeklyActivity{}},

		// 礼物与玩法
		{Key: "gifts", Label: "礼物目录", Domain: "礼物与玩法", Capabilities: []string{"list", "get", "create", "update", "delete", "bootstrap"}, AdminRoute: "/gifts/catalog", BootstrapKey: "gifts", Model: &model.Gift{}},
		{Key: "gift_records", Label: "送礼记录", Domain: "礼物与玩法", Capabilities: nil, Note: "用户送礼产生", Model: &model.GiftRecord{}},
		{Key: "user_gift_stocks", Label: "用户礼物库存", Domain: "礼物与玩法", Capabilities: nil, Note: "背包数据，后续可接用户详情", Model: &model.UserGiftStock{}},
		{Key: "gift_purchase_orders", Label: "礼物购买订单", Domain: "礼物与玩法", Capabilities: []string{"list"}, AdminRoute: "/wallet/orders", Model: &model.GiftPurchaseOrder{}},

		// AI 与形象
		{Key: "ai_user_configs", Label: "AI 用户配置", Domain: "AI 与形象", Capabilities: []string{"list", "delete"}, AdminRoute: "/app/ai", Note: "公开 Agent 治理", Model: &model.AiUserConfig{}},
		{Key: "moe_agent_runtimes", Label: "Moe Bot 运行时", Domain: "AI 与形象", Capabilities: []string{"list", "create", "update"}, AdminRoute: "/app/moe", Note: "社区 AI Bot 配置与 run-once", Model: &model.MoeAgentRuntime{}},
		{Key: "moe_tool_calls", Label: "Moe 工具调用", Domain: "AI 与形象", Capabilities: []string{"list", "stats"}, AdminRoute: "/app/moe", Note: "AI 工具执行审计与统计", Model: &model.MoeToolCall{}},
		{Key: "user_avatars", Label: "用户形象", Domain: "AI 与形象", Capabilities: nil, Note: "App 内编辑，暂无 Admin CRUD", Model: &model.UserAvatar{}},
		{Key: "avatar_outfits", Label: "形象装扮", Domain: "AI 与形象", Capabilities: nil, Note: "商城装扮，后续可接商品管理", Model: &model.AvatarOutfit{}},
		{Key: "emojis", Label: "表情", Domain: "AI 与形象", Capabilities: nil, Note: "表情资源，后续可接素材管理", Model: &model.Emoji{}},
		{Key: "emoji_packs", Label: "表情包", Domain: "AI 与形象", Capabilities: nil, Note: "表情资源，后续可接素材管理", Model: &model.EmojiPack{}},
		{Key: "user_emoji_packs", Label: "用户表情包", Domain: "AI 与形象", Capabilities: nil, Note: "用户已购/解锁包", Model: &model.UserEmojiPack{}},

		// 记忆与设备（偏运维/DevTools）
		{Key: "user_memories", Label: "用户记忆", Domain: "记忆与设备", Capabilities: []string{"list", "delete", "stats"}, AdminRoute: "/system/platform?tab=memory", Model: &model.UserMemory{}},
		{Key: "user_memory_feedbacks", Label: "记忆反馈", Domain: "记忆与设备", Capabilities: []string{"stats"}, AdminRoute: "/system/platform?tab=memory", Model: &model.UserMemoryFeedback{}},
		{Key: "user_memory_profile_caches", Label: "记忆画像缓存", Domain: "记忆与设备", Capabilities: []string{"stats"}, AdminRoute: "/system/platform?tab=memory", Model: &model.UserMemoryProfileCache{}},
		{Key: "user_devices", Label: "用户设备", Domain: "记忆与设备", Capabilities: nil, Note: "App 同步写入，后续可接只读列表", Model: &model.UserDevice{}},
		{Key: "user_memory_embeddings", Label: "记忆向量", Domain: "记忆与设备", Capabilities: []string{"stats"}, AdminRoute: "/system/platform?tab=memory", Model: &model.UserMemoryEmbedding{}},
		{Key: "user_memory_relations", Label: "记忆关系", Domain: "记忆与设备", Capabilities: nil, Note: "向量关系图，后续接入", Model: &model.UserMemoryRelation{}},

		// 触达
		{Key: "notifications", Label: "App 通知", Domain: "运营触达", Capabilities: []string{"broadcast", "send"}, AdminRoute: "/app/notify", Model: &model.Notification{}},
		{Key: "admin_announcements", Label: "运营公告", Domain: "运营触达", Capabilities: []string{"list", "get", "create", "update", "delete", "publish"}, AdminRoute: "/app/announcements", Model: &model.AdminAnnouncement{}},
		{Key: "landing_feedbacks", Label: "官网反馈", Domain: "运营触达", Capabilities: []string{"list"}, AdminRoute: "/feedback", Model: &model.LandingFeedback{}},
		{Key: "private_messages", Label: "私信", Domain: "运营触达", Capabilities: nil, Note: "合规审计向，后续可接只读列表", Model: &model.PrivateMessage{}},

		// 运行时资源（非 DB 表）
		{Key: "cloud_media_files", Label: "云图库文件", Domain: "AI 与形象", Capabilities: []string{"list", "delete"}, AdminRoute: "/system/platform?tab=media", Note: "Image.LocalDir 磁盘文件，文件名 userId__ 前缀可关联用户", Model: nil},

		// 系统管理
		{Key: "admin_accounts", Label: "管理员账号", Domain: "系统管理", Capabilities: []string{"list", "create", "update", "delete"}, AdminRoute: "/system/admins", Model: &model.AdminAccount{}},
		{Key: "admin_menus", Label: "侧栏菜单", Domain: "系统管理", Capabilities: []string{"list", "update", "bootstrap"}, AdminRoute: "/system/menus", BootstrapKey: "menus", Model: &model.AdminMenu{}},
		{Key: "admin_audit_logs", Label: "操作审计", Domain: "系统管理", Capabilities: []string{"list"}, AdminRoute: "/system/audit", Model: &model.AdminAuditLog{}},
		{Key: "user_behavior_events", Label: "用户行为事件", Domain: "用户画像", Capabilities: nil, Note: "App 埋点原始事件", Model: &model.UserBehaviorEvent{}},
		{Key: "user_behavior_daily", Label: "用户行为日聚合", Domain: "用户画像", Capabilities: nil, Note: "按页面维度聚合", Model: &model.UserBehaviorDaily{}},
	}
}

// AdminSchemaCoverage 根据能力标签计算管理覆盖级别。
func AdminSchemaCoverage(caps []string) string {
	if len(caps) == 0 {
		return "none"
	}
	hasList := schemaHasCap(caps, "list") || schemaHasCap(caps, "stats")
	hasWrite := schemaHasCap(caps, "create") || schemaHasCap(caps, "update") ||
		schemaHasCap(caps, "delete") || schemaHasCap(caps, "bootstrap") ||
		schemaHasCap(caps, "publish") || schemaHasCap(caps, "broadcast") || schemaHasCap(caps, "send")
	switch {
	case hasList && hasWrite:
		return "full"
	case hasList || schemaHasCap(caps, "stats"):
		return "readonly"
	default:
		return "partial"
	}
}

func schemaHasCap(caps []string, want string) bool {
	for _, c := range caps {
		if c == want {
			return true
		}
	}
	return false
}
