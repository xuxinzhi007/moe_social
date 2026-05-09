package logic

import (
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

func privateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *super.PrivateMessage {
	if m == nil {
		return nil
	}
	var paths []string
	if err := json.Unmarshal([]byte(strings.TrimSpace(m.ImagePaths)), &paths); err != nil || paths == nil {
		paths = []string{}
	}
	sMoe, rMoe := "", ""
	if moeByUID != nil {
		sMoe = moeByUID[m.SenderID]
		rMoe = moeByUID[m.ReceiverID]
	}
	return &super.PrivateMessage{
		Id:              strconv.FormatUint(uint64(m.ID), 10),
		SenderId:        strconv.FormatUint(uint64(m.SenderID), 10),
		ReceiverId:      strconv.FormatUint(uint64(m.ReceiverID), 10),
		Body:            m.Body,
		ImagePaths:      paths,
		RetentionDays:   int32(m.RetentionDays),
		CreatedAt:       m.CreatedAt.Format(time.RFC3339),
		ExpiresAt:       m.ExpiresAt.Format(time.RFC3339),
		SenderMoeNo:     sMoe,
		ReceiverMoeNo:   rMoe,
	}
}

// loadMoeNoByUserID 批量查 users.moe_no，供私信接口展示（入参仍用主键）。
func loadMoeNoByUserID(db *gorm.DB, ids ...uint) map[uint]string {
	out := make(map[uint]string)
	if db == nil || len(ids) == 0 {
		return out
	}
	seen := make(map[uint]struct{})
	uniq := make([]uint, 0, len(ids))
	for _, id := range ids {
		if id == 0 {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		uniq = append(uniq, id)
	}
	if len(uniq) == 0 {
		return out
	}
	var users []model.User
	if err := db.Select("id", "moe_no").Where("id IN ?", uniq).Find(&users).Error; err != nil {
		return out
	}
	for _, u := range users {
		out[u.ID] = u.MoeNo
	}
	return out
}

func retentionDaysToUint8(days int) uint8 {
	if days < 1 {
		days = 1
	}
	if days > 255 {
		days = 255
	}
	return uint8(days)
}
