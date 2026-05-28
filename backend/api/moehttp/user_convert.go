package moehttp

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func userFromRPC(u *moe.User) types.User {
	return common.RpcUserToTypes(u)
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
