package logic

import (
	"context"
	"errors"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminGetUserProfileLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetUserProfileLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserProfileLogic {
	return &AdminGetUserProfileLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminGetUserProfileLogic) AdminGetUserProfile(in *super.AdminGetUserProfileReq) (*super.AdminGetUserProfileResp, error) {
	uid := uint(in.GetUserId())
	if uid == 0 {
		return nil, errors.New("invalid user_id")
	}
	db := l.svcCtx.DB
	var user model.User
	if err := db.First(&user, uid).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}

	var unlockedAchievements int64
	_ = db.Model(&model.UserAchievementProgress{}).
		Where("user_id = ? AND unlocked_at IS NOT NULL", uid).
		Count(&unlockedAchievements).Error

	var aiAgentCount int64
	_ = db.Model(&model.AiUserConfig{}).Where("user_id = ?", uid).Count(&aiAgentCount).Error

	levelSnap := &super.AdminUserLevelSnapshot{}
	var levelRow model.UserLevel
	if err := db.Where("user_id = ?", uid).First(&levelRow).Error; err == nil {
		title := ""
		var cfg model.LevelConfig
		if err := db.Where("level = ?", levelRow.Level).First(&cfg).Error; err == nil {
			title = cfg.Title
		}
		levelSnap = &super.AdminUserLevelSnapshot{
			Level:      int32(levelRow.Level),
			Experience: int32(levelRow.Experience),
			TotalExp:   int32(levelRow.TotalExp),
			LevelTitle: title,
		}
	}

	uidStr := strconv.FormatUint(uint64(uid), 10)
	return &super.AdminGetUserProfileResp{
		Data: &super.AdminUserProfileData{
			User: modelUserToProto(&user),
			Counts: &super.AdminUserRelationCounts{
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

func buildUserProfileLinks(userID string) []*super.AdminUserRelationLink {
	return []*super.AdminUserRelationLink{
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
