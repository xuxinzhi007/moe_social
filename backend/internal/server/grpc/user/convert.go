package usergrpc

import (
	userv1 "backend/api/user/v1"
	moerpc "backend/rpc/pb/moe"
)

func userToProto(in *moerpc.User) *userv1.User {
	if in == nil {
		return nil
	}
	return &userv1.User{
		Id: in.GetId(), Username: in.GetUsername(), Email: in.GetEmail(),
		Avatar: in.GetAvatar(), Signature: in.GetSignature(), Gender: in.GetGender(),
		Birthday: in.GetBirthday(), CreatedAt: in.GetCreatedAt(), UpdatedAt: in.GetUpdatedAt(),
		IsVip: in.GetIsVip(), VipExpiresAt: in.GetVipExpiresAt(), AutoRenew: in.GetAutoRenew(),
		Balance: in.GetBalance(), Inventory: in.GetInventory(),
		EquippedFrameId: in.GetEquippedFrameId(), MoeNo: in.GetMoeNo(),
		GiftCharm: in.GetGiftCharm(), ReceivedGiftValue: in.GetReceivedGiftValue(),
		DisplayUserId: in.GetDisplayUserId(), MessageRetentionChoice: in.GetMessageRetentionChoice(),
		FeishuEmail: in.GetFeishuEmail(), FeishuName: in.GetFeishuName(), FeishuBound: in.GetFeishuBound(),
		Role: in.GetRole(), WechatNickname: in.GetWechatNickname(), WechatBound: in.GetWechatBound(),
		IsBot: in.GetIsBot(), BotAgentKey: in.GetBotAgentKey(),
	}
}
