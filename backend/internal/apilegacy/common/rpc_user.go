package common

import (
	adminv1 "backend/api/admin/v1"
	"backend/internal/legacy/types"
)

// RpcUserToTypes 将 admin User 转为 API User（含管理字段 role）。
func RpcUserToTypes(u *adminv1.User) types.User {
	if u == nil {
		return types.User{}
	}
	return types.User{
		Id:                     u.GetId(),
		Username:               u.GetUsername(),
		Email:                  u.GetEmail(),
		MoeNo:                  u.GetMoeNo(),
		DisplayUserId:          u.GetDisplayUserId(),
		MessageRetentionChoice: int(u.GetMessageRetentionChoice()),
		Avatar:                 u.GetAvatar(),
		Signature:              u.GetSignature(),
		Gender:                 u.GetGender(),
		Birthday:               u.GetBirthday(),
		CreatedAt:              u.GetCreatedAt(),
		UpdatedAt:              u.GetUpdatedAt(),
		IsVip:                  u.GetIsVip(),
		VipExpiresAt:           u.GetVipExpiresAt(),
		AutoRenew:              u.GetAutoRenew(),
		Balance:                float64(u.GetBalance()),
		GiftCharm:              int(u.GetGiftCharm()),
		ReceivedGiftValue:      u.GetReceivedGiftValue(),
		Inventory:              u.GetInventory(),
		EquippedFrameId:        u.GetEquippedFrameId(),
		FeishuEmail:            u.GetFeishuEmail(),
		FeishuName:             u.GetFeishuName(),
		FeishuBound:            u.GetFeishuBound(),
		WechatNickname:         u.GetWechatNickname(),
		WechatBound:            u.GetWechatBound(),
		Role:                   u.GetRole(),
		IsBot:                  u.GetIsBot(),
		BotAgentKey:            u.GetBotAgentKey(),
	}
}
