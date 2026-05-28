package moehttp

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/types"
	llmv1 "backend/api/llm/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/rpc/pb/moe"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func userFromRPC(u *moe.User) types.User {
	return common.RpcUserToTypes(u)
}

func userFromUserV1(u *userv1.User) types.User {
	if u == nil {
		return types.User{}
	}
	return userFromRPC(userv1.UserToMoe(u))
}

func friendViewFromRPC(v *moe.FriendRequestView) types.FriendRequestView {
	if v == nil {
		return types.FriendRequestView{}
	}
	return types.FriendRequestView{
		Id:        v.Id,
		FromUser:  userFromRPC(v.FromUser),
		ToUser:    userFromRPC(v.ToUser),
		Status:    v.Status,
		CreatedAt: v.CreatedAt,
	}
}

func friendViewFromUserV1(v *userv1.FriendRequestView) types.FriendRequestView {
	return friendViewFromRPC(userv1.FriendRequestViewToMoe(v))
}

func userFromVipV1(u *vipv1.User) types.User {
	if u == nil {
		return types.User{}
	}
	return userFromRPC(vipv1.UserToMoe(u))
}

func vipOrderFromRPC(o *moe.VipOrder) types.VipOrder {
	if o == nil {
		return types.VipOrder{}
	}
	return types.VipOrder{
		Id:        o.Id,
		UserId:    o.UserId,
		PlanId:    o.PlanId,
		PlanName:  o.PlanName,
		Amount:    float64(o.Amount),
		Status:    o.Status,
		CreatedAt: o.CreatedAt,
		PaidAt:    o.PaidAt,
		OrderNo:   o.OrderNo,
	}
}

func vipOrderFromVipV1(o *vipv1.VipOrder) types.VipOrder {
	return vipOrderFromRPC(vipv1.VipOrderToMoe(o))
}

func vipRecordFromRPC(r *moe.VipRecord) types.VipRecord {
	if r == nil {
		return types.VipRecord{}
	}
	return types.VipRecord{
		Id:        r.Id,
		UserId:    r.UserId,
		PlanId:    r.PlanId,
		PlanName:  r.PlanName,
		StartAt:   r.StartAt,
		EndAt:     r.EndAt,
		Status:    r.Status,
		CreatedAt: r.CreatedAt,
	}
}

func vipRecordFromVipV1(r *vipv1.VipRecord) types.VipRecord {
	return vipRecordFromRPC(vipv1.VipRecordToMoe(r))
}

func transactionFromRPC(t *moe.Transaction) types.Transaction {
	if t == nil {
		return types.Transaction{}
	}
	return types.Transaction{
		Id:          t.Id,
		UserId:      t.UserId,
		Type:        t.Type,
		Amount:      float64(t.Amount),
		Description: t.Description,
		Status:      t.Status,
		CreatedAt:   t.CreatedAt,
	}
}

func userMemoryFromLLMV1(m *llmv1.UserMemory) types.UserMemory {
	return userMemoryFromRPC(llmv1.UserMemoryToMoe(m))
}

func userMemoriesToMoe(items []*llmv1.UserMemory) []*moe.UserMemory {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.UserMemory, len(items))
	for i, item := range items {
		out[i] = llmv1.UserMemoryToMoe(item)
	}
	return out
}

func userMemoryProfilesToMoe(items []*llmv1.UserMemoryProfile) []*moe.UserMemoryProfile {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.UserMemoryProfile, len(items))
	for i, item := range items {
		out[i] = llmv1.UserMemoryProfileToMoe(item)
	}
	return out
}

func userMemoryFromRPC(m *moe.UserMemory) types.UserMemory {
	if m == nil {
		return types.UserMemory{}
	}
	return types.UserMemory{
		Id:          m.Id,
		UserId:      m.UserId,
		Key:         m.Key,
		Value:       m.Value,
		MemoryType:  m.MemoryType,
		Confidence:  m.Confidence,
		Source:      m.Source,
		SourceMsgId: m.SourceMsgId,
		SessionId:   m.SessionId,
		CreatedAt:   m.CreatedAt,
		UpdatedAt:   m.UpdatedAt,
	}
}

func transactionFromUserV1(t *userv1.Transaction) types.Transaction {
	return transactionFromRPC(userv1.TransactionToMoe(t))
}

func userDeviceFromUserV1(d *userv1.UserDeviceRecord) types.UserDeviceRecord {
	return userDeviceFromRPC(userv1.UserDeviceRecordToMoe(d))
}

func userDeviceFromRPC(d *moe.UserDeviceRecord) types.UserDeviceRecord {
	if d == nil {
		return types.UserDeviceRecord{}
	}
	return types.UserDeviceRecord{
		Id:          d.Id,
		UserId:      d.UserId,
		DeviceId:    d.DeviceId,
		Platform:    d.Platform,
		OSVersion:   d.OsVersion,
		AppVersion:  d.AppVersion,
		DeviceName:  d.DeviceName,
		PayloadJSON: d.PayloadJson,
		LastSeen:    d.LastSeen,
		CreatedAt:   d.CreatedAt,
		UpdatedAt:   d.UpdatedAt,
	}
}

func achievementUnlocksFromVipV1(items []*vipv1.AchievementUnlock) []types.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	moeItems := make([]*moe.AchievementUnlock, len(items))
	for i, item := range items {
		moeItems[i] = vipv1.AchievementUnlockToMoe(item)
	}
	return achievementUnlocksFromRPC(moeItems)
}

func bearerUserID(r *http.Request) (uint, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return 0, errors.New("unauthorized")
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return 0, err
	}
	return cl.UserID, nil
}

func parsePathUint(s string) (uint, error) {
	v, err := strconv.ParseUint(strings.TrimSpace(s), 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(v), nil
}

func actorString(me uint) string {
	return strconv.FormatUint(uint64(me), 10)
}

func jwtUserIDString(ctx khttp.Context) (string, error) {
	if s, err := common.UserIDString(ctx); err == nil {
		return s, nil
	}
	uid, err := bearerUserID(ctx.Request())
	if err != nil {
		return "", err
	}
	return strconv.FormatUint(uint64(uid), 10), nil
}

func bearerUserIDString(r *http.Request) (string, error) {
	uid, err := bearerUserID(r)
	if err != nil {
		return "", err
	}
	return strconv.FormatUint(uint64(uid), 10), nil
}
