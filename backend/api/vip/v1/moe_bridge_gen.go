package vipv1

import (
	"backend/rpc/pb/moe"

	"google.golang.org/protobuf/proto"
)

func cloneTo[S, D proto.Message](src S, newDst func() D) D {
	var zero D
	if any(src) == nil {
		return zero
	}
	dst := newDst()
	b, err := proto.Marshal(src)
	if err != nil {
		return zero
	}
	if err := proto.Unmarshal(b, dst); err != nil {
		return zero
	}
	return dst
}

func AchievementUnlockFromMoe(in *moe.AchievementUnlock) *AchievementUnlock {
	return cloneTo(in, func() *AchievementUnlock { return &AchievementUnlock{} })
}

func AchievementUnlockToMoe(in *AchievementUnlock) *moe.AchievementUnlock {
	return cloneTo(in, func() *moe.AchievementUnlock { return &moe.AchievementUnlock{} })
}

func CheckUserVipReqFromMoe(in *moe.CheckUserVipReq) *CheckUserVipReq {
	return cloneTo(in, func() *CheckUserVipReq { return &CheckUserVipReq{} })
}

func CheckUserVipReqToMoe(in *CheckUserVipReq) *moe.CheckUserVipReq {
	return cloneTo(in, func() *moe.CheckUserVipReq { return &moe.CheckUserVipReq{} })
}

func CheckUserVipRespFromMoe(in *moe.CheckUserVipResp) *CheckUserVipResp {
	return cloneTo(in, func() *CheckUserVipResp { return &CheckUserVipResp{} })
}

func CheckUserVipRespToMoe(in *CheckUserVipResp) *moe.CheckUserVipResp {
	return cloneTo(in, func() *moe.CheckUserVipResp { return &moe.CheckUserVipResp{} })
}

func CreateVipOrderReqFromMoe(in *moe.CreateVipOrderReq) *CreateVipOrderReq {
	return cloneTo(in, func() *CreateVipOrderReq { return &CreateVipOrderReq{} })
}

func CreateVipOrderReqToMoe(in *CreateVipOrderReq) *moe.CreateVipOrderReq {
	return cloneTo(in, func() *moe.CreateVipOrderReq { return &moe.CreateVipOrderReq{} })
}

func CreateVipOrderRespFromMoe(in *moe.CreateVipOrderResp) *CreateVipOrderResp {
	return cloneTo(in, func() *CreateVipOrderResp { return &CreateVipOrderResp{} })
}

func CreateVipOrderRespToMoe(in *CreateVipOrderResp) *moe.CreateVipOrderResp {
	return cloneTo(in, func() *moe.CreateVipOrderResp { return &moe.CreateVipOrderResp{} })
}

func CreateVipPlanReqFromMoe(in *moe.CreateVipPlanReq) *CreateVipPlanReq {
	return cloneTo(in, func() *CreateVipPlanReq { return &CreateVipPlanReq{} })
}

func CreateVipPlanReqToMoe(in *CreateVipPlanReq) *moe.CreateVipPlanReq {
	return cloneTo(in, func() *moe.CreateVipPlanReq { return &moe.CreateVipPlanReq{} })
}

func CreateVipPlanRespFromMoe(in *moe.CreateVipPlanResp) *CreateVipPlanResp {
	return cloneTo(in, func() *CreateVipPlanResp { return &CreateVipPlanResp{} })
}

func CreateVipPlanRespToMoe(in *CreateVipPlanResp) *moe.CreateVipPlanResp {
	return cloneTo(in, func() *moe.CreateVipPlanResp { return &moe.CreateVipPlanResp{} })
}

func GetUserActiveVipRecordReqFromMoe(in *moe.GetUserActiveVipRecordReq) *GetUserActiveVipRecordReq {
	return cloneTo(in, func() *GetUserActiveVipRecordReq { return &GetUserActiveVipRecordReq{} })
}

func GetUserActiveVipRecordReqToMoe(in *GetUserActiveVipRecordReq) *moe.GetUserActiveVipRecordReq {
	return cloneTo(in, func() *moe.GetUserActiveVipRecordReq { return &moe.GetUserActiveVipRecordReq{} })
}

func GetUserActiveVipRecordRespFromMoe(in *moe.GetUserActiveVipRecordResp) *GetUserActiveVipRecordResp {
	return cloneTo(in, func() *GetUserActiveVipRecordResp { return &GetUserActiveVipRecordResp{} })
}

func GetUserActiveVipRecordRespToMoe(in *GetUserActiveVipRecordResp) *moe.GetUserActiveVipRecordResp {
	return cloneTo(in, func() *moe.GetUserActiveVipRecordResp { return &moe.GetUserActiveVipRecordResp{} })
}

func GetUserVipStatusReqFromMoe(in *moe.GetUserVipStatusReq) *GetUserVipStatusReq {
	return cloneTo(in, func() *GetUserVipStatusReq { return &GetUserVipStatusReq{} })
}

func GetUserVipStatusReqToMoe(in *GetUserVipStatusReq) *moe.GetUserVipStatusReq {
	return cloneTo(in, func() *moe.GetUserVipStatusReq { return &moe.GetUserVipStatusReq{} })
}

func GetUserVipStatusRespFromMoe(in *moe.GetUserVipStatusResp) *GetUserVipStatusResp {
	return cloneTo(in, func() *GetUserVipStatusResp { return &GetUserVipStatusResp{} })
}

func GetUserVipStatusRespToMoe(in *GetUserVipStatusResp) *moe.GetUserVipStatusResp {
	return cloneTo(in, func() *moe.GetUserVipStatusResp { return &moe.GetUserVipStatusResp{} })
}

func GetVipOrdersReqFromMoe(in *moe.GetVipOrdersReq) *GetVipOrdersReq {
	return cloneTo(in, func() *GetVipOrdersReq { return &GetVipOrdersReq{} })
}

func GetVipOrdersReqToMoe(in *GetVipOrdersReq) *moe.GetVipOrdersReq {
	return cloneTo(in, func() *moe.GetVipOrdersReq { return &moe.GetVipOrdersReq{} })
}

func GetVipOrdersRespFromMoe(in *moe.GetVipOrdersResp) *GetVipOrdersResp {
	return cloneTo(in, func() *GetVipOrdersResp { return &GetVipOrdersResp{} })
}

func GetVipOrdersRespToMoe(in *GetVipOrdersResp) *moe.GetVipOrdersResp {
	return cloneTo(in, func() *moe.GetVipOrdersResp { return &moe.GetVipOrdersResp{} })
}

func GetVipPlanReqFromMoe(in *moe.GetVipPlanReq) *GetVipPlanReq {
	return cloneTo(in, func() *GetVipPlanReq { return &GetVipPlanReq{} })
}

func GetVipPlanReqToMoe(in *GetVipPlanReq) *moe.GetVipPlanReq {
	return cloneTo(in, func() *moe.GetVipPlanReq { return &moe.GetVipPlanReq{} })
}

func GetVipPlanRespFromMoe(in *moe.GetVipPlanResp) *GetVipPlanResp {
	return cloneTo(in, func() *GetVipPlanResp { return &GetVipPlanResp{} })
}

func GetVipPlanRespToMoe(in *GetVipPlanResp) *moe.GetVipPlanResp {
	return cloneTo(in, func() *moe.GetVipPlanResp { return &moe.GetVipPlanResp{} })
}

func GetVipPlansReqFromMoe(in *moe.GetVipPlansReq) *GetVipPlansReq {
	return cloneTo(in, func() *GetVipPlansReq { return &GetVipPlansReq{} })
}

func GetVipPlansReqToMoe(in *GetVipPlansReq) *moe.GetVipPlansReq {
	return cloneTo(in, func() *moe.GetVipPlansReq { return &moe.GetVipPlansReq{} })
}

func GetVipPlansRespFromMoe(in *moe.GetVipPlansResp) *GetVipPlansResp {
	return cloneTo(in, func() *GetVipPlansResp { return &GetVipPlansResp{} })
}

func GetVipPlansRespToMoe(in *GetVipPlansResp) *moe.GetVipPlansResp {
	return cloneTo(in, func() *moe.GetVipPlansResp { return &moe.GetVipPlansResp{} })
}

func GetVipRecordsReqFromMoe(in *moe.GetVipRecordsReq) *GetVipRecordsReq {
	return cloneTo(in, func() *GetVipRecordsReq { return &GetVipRecordsReq{} })
}

func GetVipRecordsReqToMoe(in *GetVipRecordsReq) *moe.GetVipRecordsReq {
	return cloneTo(in, func() *moe.GetVipRecordsReq { return &moe.GetVipRecordsReq{} })
}

func GetVipRecordsRespFromMoe(in *moe.GetVipRecordsResp) *GetVipRecordsResp {
	return cloneTo(in, func() *GetVipRecordsResp { return &GetVipRecordsResp{} })
}

func GetVipRecordsRespToMoe(in *GetVipRecordsResp) *moe.GetVipRecordsResp {
	return cloneTo(in, func() *moe.GetVipRecordsResp { return &moe.GetVipRecordsResp{} })
}

func SyncUserVipStatusReqFromMoe(in *moe.SyncUserVipStatusReq) *SyncUserVipStatusReq {
	return cloneTo(in, func() *SyncUserVipStatusReq { return &SyncUserVipStatusReq{} })
}

func SyncUserVipStatusReqToMoe(in *SyncUserVipStatusReq) *moe.SyncUserVipStatusReq {
	return cloneTo(in, func() *moe.SyncUserVipStatusReq { return &moe.SyncUserVipStatusReq{} })
}

func SyncUserVipStatusRespFromMoe(in *moe.SyncUserVipStatusResp) *SyncUserVipStatusResp {
	return cloneTo(in, func() *SyncUserVipStatusResp { return &SyncUserVipStatusResp{} })
}

func SyncUserVipStatusRespToMoe(in *SyncUserVipStatusResp) *moe.SyncUserVipStatusResp {
	return cloneTo(in, func() *moe.SyncUserVipStatusResp { return &moe.SyncUserVipStatusResp{} })
}

func UpdateAutoRenewReqFromMoe(in *moe.UpdateAutoRenewReq) *UpdateAutoRenewReq {
	return cloneTo(in, func() *UpdateAutoRenewReq { return &UpdateAutoRenewReq{} })
}

func UpdateAutoRenewReqToMoe(in *UpdateAutoRenewReq) *moe.UpdateAutoRenewReq {
	return cloneTo(in, func() *moe.UpdateAutoRenewReq { return &moe.UpdateAutoRenewReq{} })
}

func UpdateAutoRenewRespFromMoe(in *moe.UpdateAutoRenewResp) *UpdateAutoRenewResp {
	return cloneTo(in, func() *UpdateAutoRenewResp { return &UpdateAutoRenewResp{} })
}

func UpdateAutoRenewRespToMoe(in *UpdateAutoRenewResp) *moe.UpdateAutoRenewResp {
	return cloneTo(in, func() *moe.UpdateAutoRenewResp { return &moe.UpdateAutoRenewResp{} })
}

func UpdateUserVipReqFromMoe(in *moe.UpdateUserVipReq) *UpdateUserVipReq {
	return cloneTo(in, func() *UpdateUserVipReq { return &UpdateUserVipReq{} })
}

func UpdateUserVipReqToMoe(in *UpdateUserVipReq) *moe.UpdateUserVipReq {
	return cloneTo(in, func() *moe.UpdateUserVipReq { return &moe.UpdateUserVipReq{} })
}

func UpdateUserVipRespFromMoe(in *moe.UpdateUserVipResp) *UpdateUserVipResp {
	return cloneTo(in, func() *UpdateUserVipResp { return &UpdateUserVipResp{} })
}

func UpdateUserVipRespToMoe(in *UpdateUserVipResp) *moe.UpdateUserVipResp {
	return cloneTo(in, func() *moe.UpdateUserVipResp { return &moe.UpdateUserVipResp{} })
}

func UserFromMoe(in *moe.User) *User {
	return cloneTo(in, func() *User { return &User{} })
}

func UserToMoe(in *User) *moe.User {
	return cloneTo(in, func() *moe.User { return &moe.User{} })
}

func VipOrderFromMoe(in *moe.VipOrder) *VipOrder {
	return cloneTo(in, func() *VipOrder { return &VipOrder{} })
}

func VipOrderToMoe(in *VipOrder) *moe.VipOrder {
	return cloneTo(in, func() *moe.VipOrder { return &moe.VipOrder{} })
}

func VipPlanFromMoe(in *moe.VipPlan) *VipPlan {
	return cloneTo(in, func() *VipPlan { return &VipPlan{} })
}

func VipPlanToMoe(in *VipPlan) *moe.VipPlan {
	return cloneTo(in, func() *moe.VipPlan { return &moe.VipPlan{} })
}

func VipRecordFromMoe(in *moe.VipRecord) *VipRecord {
	return cloneTo(in, func() *VipRecord { return &VipRecord{} })
}

func VipRecordToMoe(in *VipRecord) *moe.VipRecord {
	return cloneTo(in, func() *moe.VipRecord { return &moe.VipRecord{} })
}
