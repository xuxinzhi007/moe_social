package userbiz

import (
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"
)

// ModelToProto 将数据库用户转为 RPC User。
func ModelToProto(user *model.User) *moe.User {
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
	return &moe.User{
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
