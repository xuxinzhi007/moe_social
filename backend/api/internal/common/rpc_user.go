package common

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

// RpcUserToTypes 将 RPC User 转为 API User（含管理字段 role）。
func RpcUserToTypes(u *super.User) types.User {
	if u == nil {
		return types.User{}
	}
	return types.User{
		Id:                     u.Id,
		Username:               u.Username,
		Email:                  u.Email,
		MoeNo:                  u.MoeNo,
		DisplayUserId:          u.GetDisplayUserId(),
		MessageRetentionChoice: int(u.GetMessageRetentionChoice()),
		Avatar:                 u.Avatar,
		Signature:              u.Signature,
		Gender:                 u.Gender,
		Birthday:               u.Birthday,
		CreatedAt:              u.CreatedAt,
		UpdatedAt:              u.UpdatedAt,
		IsVip:                  u.IsVip,
		VipExpiresAt:           u.VipExpiresAt,
		AutoRenew:              u.AutoRenew,
		Balance:                float64(u.Balance),
		GiftCharm:              int(u.GiftCharm),
		ReceivedGiftValue:      u.ReceivedGiftValue,
		Inventory:              u.Inventory,
		EquippedFrameId:        u.EquippedFrameId,
		FeishuEmail:            u.GetFeishuEmail(),
		FeishuName:             u.GetFeishuName(),
		FeishuBound:            u.GetFeishuBound(),
		WechatNickname:         u.GetWechatNickname(),
		WechatBound:            u.GetWechatBound(),
		Role:                   u.GetRole(),
	}
}
