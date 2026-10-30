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

// AdminSchemaCatalog 与 utils/migrate_registry.go 列表对齐（业务表 + 管理表）。
func AdminSchemaCatalog() []AdminSchemaEntry {
	return []AdminSchemaEntry{
		// 用户与会员
		{Key: "users", Label: "App 用户", Domain: "用户与会员", Capabilities: []string{"list", "get", "update", "profile"}, AdminRoute: "/users", Note: "可编辑 avatar URL、签名、角色与 VIP；详情含关联计数", Model: &model.User{}},
		{Key: "vip_plans", Label: "VIP 套餐", Domain: "用户与会员", Capabilities: []string{"list", "get", "create", "update", "delete", "bootstrap"}, AdminRoute: "/vip/plans", BootstrapKey: "vip_plans", Model: &model.VipPlan{}},
		{Key: "vip_orders", Label: "VIP 订单", Domain: "用户与会员", Capabilities: []string{"list"}, AdminRoute: "/wallet/orders", Model: &model.VipOrder{}},
		{Key: "transactions", Label: "钱包流水", Domain: "用户与会员", Capabilities: nil, Note: "App 内交易流水，后续可接钱包页", Model: &model.Transaction{}},

		// 内容与社区
		{Key: "posts", Label: "动态", Domain: "内容与社区", Capabilities: []string{"list", "delete"}, AdminRoute: "/content/posts", Model: &model.Post{}},
		{Key: "post_reports", Label: "动态举报", Domain: "内容与社区", Capabilities: []string{"list"}, AdminRoute: "/content/reports", Model: &model.PostReport{}},
		{Key: "comments", Label: "评论", Domain: "内容与社区", Capabilities: []string{"list", "delete"}, AdminRoute: "/content/comments", Model: &model.Comment{}},
		{Key: "likes", Label: "点赞", Domain: "内容与社区", Capabilities: nil, Note: "关联动态，通过动态页治理", Model: &model.Like{}},
		{Key: "topic_tags", Label: "话题标签", Domain: "内容与社区", Capabilities: []string{"list", "create", "update", "delete", "bootstrap"}, AdminRoute: "/content/tags", BootstrapKey: "topic_tags", Model: &model.TopicTag{}},
		{Key: "post_topics", Label: "动态-话题关联", Domain: "内容与社区", Capabilities: nil, Note: "中间表", Model: &model.PostTopic{}},
		{Key: "tag_dictionary_entries", Label: "标签字典", Domain: "内容与社区", Capabilities: []string{"list", "create", "update", "delete"}, AdminRoute: "/content/tags", Model: &model.TagDictionaryEntry{}},
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
		{Key: "battle_rooms", Label: "PK 对战房间", Domain: "礼物与玩法", Capabilities: nil, Note: "礼物 PK 房间状态", Model: &model.BattleRoom{}},
		{Key: "battle_scores", Label: "PK 对战积分", Domain: "礼物与玩法", Capabilities: nil, Note: "房间双方实时积分", Model: &model.BattleScore{}},
		{Key: "battle_gift_events", Label: "PK 送礼事件", Domain: "礼物与玩法", Capabilities: nil, Note: "PK 房间内送礼流水", Model: &model.BattleGiftEvent{}},
		{Key: "battle_idempotency_keys", Label: "PK 幂等键", Domain: "礼物与玩法", Capabilities: nil, Note: "防重放幂等记录", Model: &model.BattleIdempotencyKey{}},

		// AI 与形象
		{Key: "ai_user_configs", Label: "AI 用户配置", Domain: "AI 与形象", Capabilities: []string{"list", "delete"}, AdminRoute: "/app/ai", Note: "公开 Agent 治理", Model: &model.AiUserConfig{}},
		{Key: "llm_managed_models", Label: "派生模型管理", Domain: "AI 与形象", Capabilities: []string{"list", "create", "delete"}, AdminRoute: "/app/ai-models", Note: "受管派生模型生命周期", Model: &model.LLMManagedModel{}},
		{Key: "ai_chat_sessions", Label: "AI 对话会话", Domain: "AI 与形象", Capabilities: []string{"list"}, AdminRoute: "/app/ai", Model: &model.AiChatSession{}},
		{Key: "ai_chat_messages", Label: "AI 对话消息", Domain: "AI 与形象", Capabilities: []string{"list"}, AdminRoute: "/app/ai", Model: &model.AiChatMessage{}},
		{Key: "moe_agent_runtimes", Label: "Moe Bot 运行时", Domain: "AI 与形象", Capabilities: []string{"list", "create", "update"}, AdminRoute: "/app/moe", Note: "社区 AI Bot 配置与 run-once", Model: &model.MoeAgentRuntime{}},
		{Key: "moe_bot_episodes", Label: "Moe Bot 记忆片段", Domain: "AI 与形象", Capabilities: []string{"list", "delete"}, AdminRoute: "/app/moe", Model: &model.MoeBotEpisode{}},
		{Key: "moe_agent_topic_stats", Label: "Moe Bot 话题统计", Domain: "AI 与形象", Capabilities: []string{"stats"}, AdminRoute: "/app/moe", Model: &model.MoeAgentTopicStat{}},
		{Key: "moe_tool_calls", Label: "Moe 工具调用", Domain: "AI 与形象", Capabilities: []string{"list", "stats"}, AdminRoute: "/app/moe", Note: "AI 工具执行审计与统计", Model: &model.MoeToolCall{}},
		{Key: "moe_agent_run_logs", Label: "Moe 运行日志", Domain: "AI 与形象", Capabilities: []string{"list"}, AdminRoute: "/app/moe", Model: &model.MoeAgentRunLog{}},
		{Key: "moe_agent_flow_configs", Label: "Moe 流程画布配置", Domain: "AI 与形象", Capabilities: []string{"list", "update", "delete"}, AdminRoute: "/app/moe", Model: &model.MoeAgentFlowConfig{}},
		{Key: "moe_brain_dream_logs", Label: "Moe 入梦整合日志", Domain: "AI 与形象", Capabilities: nil, Note: "定时入梦整合记录", Model: &model.MoeBrainDreamLog{}},
		{Key: "user_avatars", Label: "用户形象", Domain: "AI 与形象", Capabilities: nil, Note: "App 内编辑，暂无 Admin CRUD", Model: &model.UserAvatar{}},
		{Key: "avatar_outfits", Label: "形象装扮", Domain: "AI 与形象", Capabilities: nil, Note: "商城装扮，后续可接商品管理", Model: &model.AvatarOutfit{}},
		{Key: "emojis", Label: "表情", Domain: "AI 与形象", Capabilities: nil, Note: "表情资源，后续可接素材管理", Model: &model.Emoji{}},
		{Key: "emoji_packs", Label: "表情包", Domain: "AI 与形象", Capabilities: nil, Note: "表情资源，后续可接素材管理", Model: &model.EmojiPack{}},
		{Key: "user_emoji_packs", Label: "用户表情包", Domain: "AI 与形象", Capabilities: nil, Note: "用户已购/解锁包", Model: &model.UserEmojiPack{}},

		// AI 伙伴（Companion）
		{Key: "companion_profiles", Label: "伙伴档案", Domain: "AI 伙伴", Capabilities: nil, Note: "用户专属 AI 伙伴与亲密度", Model: &model.CompanionProfile{}},
		{Key: "companion_memories", Label: "伙伴长期记忆", Domain: "AI 伙伴", Capabilities: nil, Note: "主伙伴与英雄闲聊记忆", Model: &model.CompanionMemory{}},
		{Key: "companion_memory_conflicts", Label: "伙伴记忆冲突", Domain: "AI 伙伴", Capabilities: nil, Note: "待用户确认的冲突记忆", Model: &model.CompanionMemoryConflict{}},
		{Key: "companion_memory_extraction_jobs", Label: "记忆抽取任务", Domain: "AI 伙伴", Capabilities: nil, Note: "异步记忆抽取队列", Model: &model.CompanionMemoryExtractionJob{}},
		{Key: "companion_chat_logs", Label: "伙伴对话记录", Domain: "AI 伙伴", Capabilities: nil, Note: "主伙伴与英雄闲聊历史", Model: &model.CompanionChatLog{}},
		{Key: "companion_relationship_events", Label: "伙伴关系里程碑", Domain: "AI 伙伴", Capabilities: nil, Note: "亲密度升级与纪念事件", Model: &model.CompanionRelationshipEvent{}},
		{Key: "companion_events", Label: "伙伴全域事件流", Domain: "AI 伙伴", Capabilities: nil, Note: "跨社交/世界行为投射事件", Model: &model.CompanionEvent{}},

		// 数字生命与小世界（Life / Arena / Game）
		{Key: "life_worlds", Label: "数字生命世界", Domain: "数字生命与游戏", Capabilities: nil, Note: "TA 的世界状态快照", Model: &model.LifeWorld{}},
		{Key: "life_entities", Label: "数字生命实体", Domain: "数字生命与游戏", Capabilities: nil, Note: "世界居民运行时存档", Model: &model.LifeEntity{}},
		{Key: "life_relationships", Label: "数字生命关系网", Domain: "数字生命与游戏", Capabilities: nil, Note: "居民间好感与关系", Model: &model.LifeRelationship{}},
		{Key: "life_event_logs", Label: "数字生命事件日志", Domain: "数字生命与游戏", Capabilities: nil, Note: "Tick 演化事件流水", Model: &model.LifeEventLog{}},
		{Key: "life_items", Label: "数字生命道具目录", Domain: "数字生命与游戏", Capabilities: nil, Note: "照料与世界道具定义", Model: &model.LifeItem{}},
		{Key: "life_inventory", Label: "数字生命背包", Domain: "数字生命与游戏", Capabilities: nil, Note: "用户持有的世界道具", Model: &model.LifeInventory{}},
		{Key: "life_daily_claim", Label: "数字生命每日补给", Domain: "数字生命与游戏", Capabilities: nil, Note: "每日免费道具领取记录", Model: &model.LifeDailyClaim{}},
		{Key: "arena_profiles", Label: "星辉远征存档", Domain: "数字生命与游戏", Capabilities: nil, Note: "Arena 英雄与编队存档", Model: &model.ArenaProfile{}},
		{Key: "game_sessions", Label: "文字游戏会话", Domain: "数字生命与游戏", Capabilities: nil, Note: "文字跑团会话状态", Model: &model.GameSession{}},
		{Key: "game_scenes", Label: "文字游戏场景", Domain: "数字生命与游戏", Capabilities: nil, Note: "世界地点与连接图", Model: &model.GameScene{}},
		{Key: "game_npcs", Label: "文字游戏 NPC", Domain: "数字生命与游戏", Capabilities: nil, Note: "场景内活跃 NPC", Model: &model.GameNpc{}},
		{Key: "game_npc_memories", Label: "NPC 记忆", Domain: "数字生命与游戏", Capabilities: nil, Note: "NPC 对玩家交互记忆", Model: &model.GameNpcMemory{}},
		{Key: "game_turn_logs", Label: "文字游戏回合日志", Domain: "数字生命与游戏", Capabilities: nil, Note: "玩家行动与叙事记录", Model: &model.GameTurnLog{}},
		{Key: "game_world_items", Label: "文字游戏世界物品", Domain: "数字生命与游戏", Capabilities: nil, Note: "可探索/拾取物品定义", Model: &model.GameWorldItem{}},
		{Key: "game_npc_templates", Label: "NPC 模板", Domain: "数字生命与游戏", Capabilities: nil, Note: "预设 NPC 原型", Model: &model.GameNpcTemplate{}},
		{Key: "game_dialogue_templates", Label: "对话模板", Domain: "数字生命与游戏", Capabilities: nil, Note: "条件触发台词模板", Model: &model.GameDialogueTemplate{}},
		{Key: "game_story_arcs", Label: "故事线进度", Domain: "数字生命与游戏", Capabilities: nil, Note: "主支线剧情阶段", Model: &model.GameStoryArc{}},
		{Key: "game_world_states", Label: "文字游戏世界时钟", Domain: "数字生命与游戏", Capabilities: nil, Note: "全局昼夜/天气状态", Model: &model.GameWorldState{}},
		{Key: "game_discovered_items", Label: "已发现物品", Domain: "数字生命与游戏", Capabilities: nil, Note: "玩家图鉴解锁记录", Model: &model.GameDiscoveredItem{}},
		{Key: "game_visited_scenes", Label: "已探索场景", Domain: "数字生命与游戏", Capabilities: nil, Note: "玩家足迹记录", Model: &model.GameVisitedScene{}},
		{Key: "game_npc_activities", Label: "NPC 日程活动", Domain: "数字生命与游戏", Capabilities: nil, Note: "NPC 自主行动日志", Model: &model.GameNpcActivity{}},
		{Key: "game_world_events", Label: "世界广播事件", Domain: "数字生命与游戏", Capabilities: nil, Note: "后台世界时钟演化事件", Model: &model.GameWorldEvent{}},

		{Key: "user_devices", Label: "用户设备", Domain: "记忆与设备", Capabilities: nil, Note: "App 同步写入，后续可接只读列表", Model: &model.UserDevice{}},

		// 触达
		{Key: "notifications", Label: "App 通知", Domain: "运营触达", Capabilities: []string{"broadcast", "send"}, AdminRoute: "/app/notify", Model: &model.Notification{}},
		{Key: "admin_announcements", Label: "运营公告", Domain: "运营触达", Capabilities: []string{"list", "get", "create", "update", "delete", "publish"}, AdminRoute: "/app/announcements", Model: &model.AdminAnnouncement{}},
		{Key: "app_releases", Label: "App 版本发布", Domain: "运营触达", Capabilities: []string{"list", "create", "update"}, AdminRoute: "/app/releases", Model: &model.AppRelease{}},
		{Key: "landing_feedbacks", Label: "官网反馈", Domain: "运营触达", Capabilities: []string{"list"}, AdminRoute: "/feedback", Model: &model.LandingFeedback{}},
		{Key: "private_messages", Label: "私信", Domain: "运营触达", Capabilities: nil, Note: "合规审计向，后续可接只读列表", Model: &model.PrivateMessage{}},

		// 运行时资源（非 DB 表）
		{Key: "cloud_media_files", Label: "云图库文件", Domain: "AI 与形象", Capabilities: []string{"list", "delete"}, AdminRoute: "/system/platform?tab=media", Note: "Image.LocalDir 磁盘文件，文件名 userId__ 前缀可关联用户", Model: nil},

		// 系统管理
		{Key: "admin_accounts", Label: "管理员账号", Domain: "系统管理", Capabilities: []string{"list", "create", "update", "delete"}, AdminRoute: "/system/admins", Model: &model.AdminAccount{}},
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
