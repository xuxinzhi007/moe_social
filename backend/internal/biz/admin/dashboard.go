package adminbiz

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"time"

	userbiz "backend/internal/biz/user"
	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// Dashboard Admin 仪表盘统计。
func Dashboard(ctx context.Context, store AdminStore, _ *moe.AdminDashboardReq) (*moe.AdminDashboardResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	feedbackTotal, err := store.CountLandingFeedback(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDashboard, err)
	}
	userTotal, err := store.CountUsers(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDashboard, err)
	}
	return &moe.AdminDashboardResp{
		LandingFeedbackTotal: int32(feedbackTotal),
		UserTotal:            int32(userTotal),
		ServerTime:           time.Now().Format(time.RFC3339),
		FeishuEnabled:        viper.GetBool("feishu.enabled"),
	}, nil
}

// GetUser Admin 单用户详情。
func GetUser(ctx context.Context, store AdminStore, in *moe.AdminGetUserReq) (*moe.AdminGetUserResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if in.GetUserId() == 0 {
		return nil, ErrInvalidUserID
	}
	user, err := store.GetUserByID(ctx, uint(in.GetUserId()))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDashboard, err)
	}
	return &moe.AdminGetUserResp{User: userbiz.ModelToProto(&user)}, nil
}

// GetUserProfile Admin 用户画像与关联统计。
func GetUserProfile(ctx context.Context, store AdminStore, in *moe.AdminGetUserProfileReq) (*moe.AdminGetUserProfileResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	uid := uint(in.GetUserId())
	if uid == 0 {
		return nil, ErrInvalidProfileUserID
	}
	user, err := store.GetUserByID(ctx, uid)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrProfileUserNotFound
		}
		return nil, err
	}

	unlockedAchievements, _ := store.CountUnlockedAchievements(ctx, uid)
	aiAgentCount, _ := store.CountAiAgents(ctx, uid)

	levelSnap := &moe.AdminUserLevelSnapshot{}
	levelRow, err := store.GetUserLevel(ctx, uid)
	if err == nil {
		title := ""
		cfg, err := store.GetLevelConfigByLevel(ctx, levelRow.Level)
		if err == nil {
			title = cfg.Title
		}
		levelSnap = &moe.AdminUserLevelSnapshot{
			Level:      int32(levelRow.Level),
			Experience: int32(levelRow.Experience),
			TotalExp:   int32(levelRow.TotalExp),
			LevelTitle: title,
		}
	}

	ctxStore := store.WithContext(ctx)
	db := ctxStore.Raw()
	uidStr := strconv.FormatUint(uint64(uid), 10)
	return &moe.AdminGetUserProfileResp{
		Data: &moe.AdminUserProfileData{
			User: userbiz.ModelToProto(&user),
			Counts: &moe.AdminUserRelationCounts{
				Posts:                countWhere(db, &model.Post{}, "user_id", uid),
				Comments:             countWhere(db, &model.Comment{}, "user_id", uid),
				Following:            countWhere(db, &model.Follow{}, "follower_id", uid),
				Followers:            countWhere(db, &model.Follow{}, "following_id", uid),
				CheckIns:             countWhere(db, &model.UserCheckIn{}, "user_id", uid),
				AchievementsUnlocked: int32(unlockedAchievements),
				VipOrders:            countWhere(db, &model.VipOrder{}, "user_id", uid),
				GiftSent:             countWhere(db, &model.GiftRecord{}, "from_user_id", uid),
				GiftReceived:         countWhere(db, &model.GiftRecord{}, "to_user_id", uid),
				GiftStocks:           countWhere(db, &model.UserGiftStock{}, "user_id", uid),
				Transactions:         countWhere(db, &model.Transaction{}, "user_id", uid),
				AiAgents:             int32(aiAgentCount),
				GroupsJoined:         countWhere(db, &model.GroupMember{}, "user_id", uid),
			},
			Level:    levelSnap,
			Links:    buildUserProfileLinks(uidStr),
			Behavior: loadUserBehaviorSummary(db, uid),
		},
	}, nil
}

// GetMemoryStats Admin 记忆统计。
func GetMemoryStats(ctx context.Context, store AdminStore, _ *moe.AdminGetMemoryStatsReq) (*moe.AdminGetMemoryStatsResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	stats := &moe.AdminMemoryStats{}

	totalMemories, err := store.CountMemories(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMemoryStats, err)
	}
	stats.TotalMemories = int32(totalMemories)

	usersWith, err := store.CountDistinctUsersWithMemories(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMemoryStats, err)
	}
	stats.UsersWithMemories = int32(usersWith)

	totalFeedbacks, err := store.CountMemoryFeedbacks(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMemoryStats, err)
	}
	stats.TotalFeedbacks = int32(totalFeedbacks)

	totalEmbeddings, err := store.CountMemoryEmbeddings(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMemoryStats, err)
	}
	stats.TotalEmbeddings = int32(totalEmbeddings)

	typeRows, err := store.GroupMemoriesByType(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMemoryStats, err)
	}
	stats.ByType = make([]*moe.AdminMemoryTypeStat, len(typeRows))
	for i, row := range typeRows {
		stats.ByType[i] = &moe.AdminMemoryTypeStat{
			MemoryType: row.MemoryType,
			Count:      int32(row.Count),
		}
	}
	return &moe.AdminGetMemoryStatsResp{Stats: stats}, nil
}

func buildUserProfileLinks(userID string) []*moe.AdminUserRelationLink {
	return []*moe.AdminUserRelationLink{
		{Label: "动态", AdminRoute: "/content/posts?user_id=" + userID, Hint: "posts.user_id"},
		{Label: "评论", AdminRoute: "/content/comments?user_id=" + userID, Hint: "comments.user_id"},
		{Label: "粉丝", AdminRoute: "/social/follows?following_id=" + userID, Hint: "follows.following_id"},
		{Label: "关注", AdminRoute: "/social/follows?follower_id=" + userID, Hint: "follows.follower_id"},
		{Label: "签到记录", AdminRoute: "/growth?tab=stats&user_id=" + userID, Hint: "user_check_ins.user_id"},
		{Label: "VIP 订单", AdminRoute: "/commerce/vip-plans?user_id=" + userID, Hint: "vip_orders.user_id"},
		{Label: "礼物送出", AdminRoute: "/commerce/gifts?from_user_id=" + userID, Hint: "gift_records.from_user_id"},
		{Label: "礼物收到", AdminRoute: "/commerce/gifts?to_user_id=" + userID, Hint: "gift_records.to_user_id"},
		{Label: "成就", AdminRoute: "/growth?tab=achievements&user_id=" + userID, Hint: "user_achievement_progress.user_id"},
		{Label: "AI 分身", AdminRoute: "/ai/agents?user_id=" + userID, Hint: "ai_user_configs.user_id"},
		{Label: "记忆", AdminRoute: "/system/platform?tab=memory&user_id=" + userID, Hint: "user_memories.user_id"},
	}
}

func loadUserBehaviorSummary(db *gorm.DB, uid uint) *moe.AdminUserBehaviorSummary {
	if db == nil || uid == 0 {
		return nil
	}

	since := time.Now().UTC().AddDate(0, 0, -7)
	var dailyRows []model.UserBehaviorDaily
	_ = db.Where("user_id = ? AND activity_date >= ?", uid, since).
		Order("activity_date desc").
		Find(&dailyRows).Error

	type screenAgg struct {
		visits   int
		duration int64
	}
	byScreen := map[string]screenAgg{}
	for _, row := range dailyRows {
		item := byScreen[row.Screen]
		item.visits += row.VisitCount
		item.duration += row.TotalDurationMs
		byScreen[row.Screen] = item
	}

	type ranked struct {
		screen   string
		visits   int
		duration int64
	}
	rankedList := make([]ranked, 0, len(byScreen))
	for screen, item := range byScreen {
		rankedList = append(rankedList, ranked{
			screen:   screen,
			visits:   item.visits,
			duration: item.duration,
		})
	}
	sort.Slice(rankedList, func(i, j int) bool {
		if rankedList[i].visits == rankedList[j].visits {
			return rankedList[i].duration > rankedList[j].duration
		}
		return rankedList[i].visits > rankedList[j].visits
	})
	if len(rankedList) > 8 {
		rankedList = rankedList[:8]
	}

	topScreens := make([]*moe.AdminUserBehaviorScreenStat, 0, len(rankedList))
	for _, item := range rankedList {
		topScreens = append(topScreens, &moe.AdminUserBehaviorScreenStat{
			Screen:          item.screen,
			Label:           utils.BehaviorScreenLabel(item.screen),
			VisitCount:      int32(item.visits),
			TotalDurationMs: item.duration,
		})
	}

	var totalEvents7d int64
	_ = db.Model(&model.UserBehaviorEvent{}).
		Where("user_id = ? AND created_at >= ?", uid, since).
		Count(&totalEvents7d).Error

	lastActiveAt := ""
	var lastEvent model.UserBehaviorEvent
	if err := db.Where("user_id = ?", uid).Order("created_at desc").First(&lastEvent).Error; err == nil {
		lastActiveAt = lastEvent.CreatedAt.UTC().Format(time.RFC3339)
	}

	return &moe.AdminUserBehaviorSummary{
		TopScreens:     topScreens,
		Tags:           utils.BuildBehaviorTags(dailyRows),
		LastActiveAt:   lastActiveAt,
		TotalEvents_7D: int32(totalEvents7d),
	}
}
