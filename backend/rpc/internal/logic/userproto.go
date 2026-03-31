package logic

import (
	"strconv"

	"backend/model"
	"backend/rpc/pb/super"
)

// modelUserToProto 将数据库用户转为 RPC User（含 moe_no）。
func modelUserToProto(user *model.User) *super.User {
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
	return &super.User{
		Id:              strconv.Itoa(int(user.ID)),
		Username:        user.Username,
		Email:           user.Email,
		Avatar:          user.Avatar,
		Signature:       user.Signature,
		Gender:          user.Gender,
		Birthday:        bday,
		CreatedAt:       user.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:       user.UpdatedAt.Format("2006-01-02 15:04:05"),
		IsVip:           user.IsVip,
		VipExpiresAt:    vipEndAt,
		AutoRenew:       user.AutoRenew,
		Balance:         float32(user.Balance),
		Inventory:       user.Inventory,
		EquippedFrameId: user.EquippedFrameId,
		MoeNo:           user.MoeNo,
	}
}
