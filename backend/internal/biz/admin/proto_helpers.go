package adminbiz

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	adminv1 "backend/api/admin/v1"
	"backend/model"

	"gorm.io/gorm"
)

func userModelToAdminV1(user *model.User) *adminv1.User {
	if user == nil {
		return nil
	}
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}
	bday := ""
	if user.Birthday != nil {
		bday = user.Birthday.Format("2006-01-02")
	}
	return &adminv1.User{
		Id:                     strconv.Itoa(int(user.ID)),
		Username:               user.Username,
		Email:                  user.Email,
		Avatar:                 user.Avatar,
		Signature:              user.Signature,
		Gender:                 user.Gender,
		Birthday:               bday,
		CreatedAt:              user.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:              user.UpdatedAt.Format("2006-01-02 15:04:05"),
		IsVip:                  user.IsVip,
		VipExpiresAt:           vipEndAt,
		AutoRenew:              user.AutoRenew,
		Balance:                float32(user.Balance),
		Inventory:              user.Inventory,
		EquippedFrameId:        user.EquippedFrameId,
		MoeNo:                  user.MoeNo,
		GiftCharm:              int32(user.GiftCharm),
		ReceivedGiftValue:      user.ReceivedGiftValue,
		DisplayUserId:          user.MoeNo,
		MessageRetentionChoice: int32(user.MessageRetentionChoice),
		FeishuEmail:            user.FeishuEmail,
		FeishuName:             user.FeishuName,
		FeishuBound:            user.FeishuOpenID != nil && strings.TrimSpace(*user.FeishuOpenID) != "",
		Role:                   user.Role,
		WechatNickname:         user.WechatNickname,
		WechatBound:            user.WechatOpenID != nil && strings.TrimSpace(*user.WechatOpenID) != "",
		IsBot:                  user.IsBot,
		BotAgentKey:            strings.TrimSpace(user.BotAgentKey),
	}
}

func giftModelToAdminV1(gift model.Gift, ownedQty int32) *adminv1.Gift {
	return &adminv1.Gift{
		Id:            uint64(gift.ID),
		Name:          gift.Name,
		Price:         int32(gift.Price),
		Icon:          gift.Icon,
		Description:   gift.Description,
		CreatedAt:     gift.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:     gift.UpdatedAt.Format("2006-01-02 15:04:05"),
		OwnedQuantity: ownedQty,
		Category:      gift.Category,
		SortOrder:     int32(gift.SortOrder),
	}
}

func postModelToAdminV1(post model.Post, user model.User, isLiked bool) *adminv1.Post {
	var images []string
	if post.Images != "" {
		_ = json.Unmarshal([]byte(post.Images), &images)
	}
	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if user.Username != "" {
		username = user.Username
	} else if user.Email != "" {
		username = user.Email
	}
	if user.Avatar != "" {
		avatar = user.Avatar
	}
	moderationStatus := strings.TrimSpace(post.ModerationStatus)
	if moderationStatus == "" {
		moderationStatus = "ok"
	}
	topicTags := make([]*adminv1.TopicTag, 0, len(post.TopicTags))
	for _, tag := range post.TopicTags {
		topicTags = append(topicTags, &adminv1.TopicTag{
			Id:        strconv.FormatUint(uint64(tag.ID), 10),
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &adminv1.Post{
		Id:                strconv.FormatUint(uint64(post.ID), 10),
		UserId:            strconv.FormatUint(uint64(post.UserID), 10),
		UserName:          username,
		UserAvatar:        avatar,
		Content:           post.Content,
		Images:            images,
		TopicTags:         topicTags,
		Likes:             int32(post.Likes),
		Comments:          int32(post.Comments),
		IsLiked:           isLiked,
		CreatedAt:         post.CreatedAt.Format("2006-01-02 15:04:05"),
		HandDrawCard:      post.HandDrawCard,
		HandDrawThumbUrl:  post.HandDrawThumbURL,
		HasHandDraw:       post.HasHandDraw || post.HandDrawThumbURL != "" || post.HandDrawCard != "",
		ModerationStatus:  moderationStatus,
		AuthorIsBot:       user.IsBot,
		AuthorBotAgentKey: strings.TrimSpace(user.BotAgentKey),
	}
}

func postModelToAdminV1ForList(post model.Post, user model.User, isLiked bool) *adminv1.Post {
	p := postModelToAdminV1(post, user, isLiked)
	p.HandDrawCard = ""
	return p
}

func adminAccountToProto(row model.AdminAccount) *adminv1.AdminAccountItem {
	item := &adminv1.AdminAccountItem{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Username:  row.Username,
		Role:      row.Role,
		CreatedAt: row.CreatedAt.Format("2006-01-02 15:04:05"),
	}
	if row.LastLoginAt != nil {
		item.LastLoginAt = row.LastLoginAt.Format("2006-01-02 15:04:05")
	}
	return item
}

func levelConfigToProto(row model.LevelConfig) *adminv1.AdminLevelConfigItem {
	return &adminv1.AdminLevelConfigItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		Level:      int32(row.Level),
		Title:      row.Title,
		MinExp:     int32(row.MinExp),
		MaxExp:     int32(row.MaxExp),
		Privileges: row.Privileges,
		BadgeUrl:   row.BadgeUrl,
	}
}

func checkInRewardToProto(row model.CheckInReward) *adminv1.AdminCheckInRewardItem {
	return &adminv1.AdminCheckInRewardItem{
		Id:              strconv.FormatUint(uint64(row.ID), 10),
		ConsecutiveDays: int32(row.ConsecutiveDays),
		ExpReward:       int32(row.ExpReward),
		ExtraReward:     row.ExtraReward,
	}
}

func countWhere(db *gorm.DB, model interface{}, column string, uid uint) int32 {
	if db == nil {
		return 0
	}
	var n int64
	_ = db.Model(model).Where(column+" = ?", uid).Count(&n).Error
	return int32(n)
}

func memoryToAdminProto(row model.UserMemory, username string) *adminv1.AdminMemoryItem {
	return &adminv1.AdminMemoryItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		UserId:     strconv.FormatUint(uint64(row.UserID), 10),
		Username:   username,
		Key:        row.Key,
		Value:      row.Value,
		MemoryType: row.MemoryType,
		Confidence: row.Confidence,
		Source:     row.Source,
		UpdatedAt:  row.UpdatedAt.Format(time.DateTime),
	}
}

func previewContent(s string) string {
	s = strings.TrimSpace(s)
	if len(s) <= 120 {
		return s
	}
	return s[:120] + "…"
}

func adminUserDisplayName(db *gorm.DB, userID uint) string {
	if db == nil || userID == 0 {
		return ""
	}
	var user model.User
	if err := db.First(&user, userID).Error; err != nil {
		return ""
	}
	return adminUserLabel(user)
}

func adminUserLabel(user model.User) string {
	if user.Username != "" {
		return user.Username
	}
	if user.Email != "" {
		return user.Email
	}
	if user.ID != 0 {
		return fmt.Sprintf("用户#%d", user.ID)
	}
	return "未知用户"
}

func adminUserAvatar(user model.User) string {
	if user.Avatar != "" {
		return user.Avatar
	}
	return "https://picsum.photos/150"
}
