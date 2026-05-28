package chatbiz

import (
	"context"
	"encoding/json"
	"errors"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

var safePrivateImageToken = regexp.MustCompile(`^[a-zA-Z0-9._-]+$`)

// SendPrivateMessage 持久化一条私信并返回 proto 视图。
func SendPrivateMessage(ctx context.Context, db *gorm.DB, in *moe.SendPrivateMessageReq) (*moe.SendPrivateMessageResp, error) {
	if db == nil {
		return nil, errors.New("db not ready")
	}
	senderID, err := strconv.ParseUint(strings.TrimSpace(in.GetSenderId()), 10, 32)
	if err != nil || senderID == 0 {
		return nil, errors.New("invalid sender_id")
	}
	receiverID, err := strconv.ParseUint(strings.TrimSpace(in.GetReceiverId()), 10, 32)
	if err != nil || receiverID == 0 {
		return nil, errors.New("invalid receiver_id")
	}
	if senderID == receiverID {
		return nil, errors.New("cannot message self")
	}

	body := strings.TrimSpace(in.GetBody())
	if body == "" {
		return nil, errors.New("empty body")
	}
	maxRunes := utils.PrivateMessageBodyMaxRunes()
	if utf8.RuneCountInString(body) > maxRunes {
		return nil, errors.New("body too long")
	}

	paths, err := NormalizePrivateImagePaths(in.GetImagePaths())
	if err != nil {
		return nil, err
	}

	var sender model.User
	if err := db.WithContext(ctx).First(&sender, uint(senderID)).Error; err != nil {
		return nil, errors.New("sender not found")
	}
	var receiver model.User
	if err := db.WithContext(ctx).First(&receiver, uint(receiverID)).Error; err != nil {
		return nil, errors.New("receiver not found")
	}

	days := utils.PrivateMessageRetentionDaysForSender(&sender)
	row := model.PrivateMessage{
		SenderID:      uint(senderID),
		ReceiverID:    uint(receiverID),
		Body:          body,
		RetentionDays: retentionDaysToUint8(days),
		ExpiresAt:     time.Now().Add(time.Duration(days) * 24 * time.Hour),
	}
	if len(paths) > 0 {
		b, err := json.Marshal(paths)
		if err != nil {
			return nil, errors.New("invalid image paths")
		}
		row.ImagePaths = string(b)
	} else {
		row.ImagePaths = "[]"
	}

	if err := db.WithContext(ctx).Create(&row).Error; err != nil {
		return nil, errors.New("save failed")
	}

	moeBy := loadMoeNoByUserID(db.WithContext(ctx), row.SenderID, row.ReceiverID)
	return &moe.SendPrivateMessageResp{Message: privateMessageModelToProto(&row, moeBy)}, nil
}

// NormalizePrivateImagePaths 校验并规范化私信图片 token 列表。
func NormalizePrivateImagePaths(in []string) ([]string, error) {
	maxN := utils.PrivateMessageImagePathsMax()
	if len(in) > maxN {
		return nil, errors.New("too many image_paths")
	}
	out := make([]string, 0, len(in))
	for _, p := range in {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if strings.Contains(p, "/") || strings.Contains(p, "\\") || strings.Contains(p, "..") {
			return nil, errors.New("invalid image path")
		}
		if !safePrivateImageToken.MatchString(p) {
			return nil, errors.New("invalid image path token")
		}
		out = append(out, p)
	}
	if len(out) > maxN {
		return nil, errors.New("too many image_paths")
	}
	return out, nil
}

func privateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *moe.PrivateMessage {
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
	return &moe.PrivateMessage{
		Id:            strconv.FormatUint(uint64(m.ID), 10),
		SenderId:      strconv.FormatUint(uint64(m.SenderID), 10),
		ReceiverId:    strconv.FormatUint(uint64(m.ReceiverID), 10),
		Body:          m.Body,
		ImagePaths:    paths,
		RetentionDays: int32(m.RetentionDays),
		CreatedAt:     m.CreatedAt.Format(time.RFC3339),
		ExpiresAt:     m.ExpiresAt.Format(time.RFC3339),
		SenderMoeNo:   sMoe,
		ReceiverMoeNo: rMoe,
	}
}

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

// PrivateMessageModelToProto 导出 proto 映射（list/conversation RPC 复用）。
func PrivateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *moe.PrivateMessage {
	return privateMessageModelToProto(m, moeByUID)
}

// LoadMoeNoByUserID 批量加载 moe_no 展示字段。
func LoadMoeNoByUserID(db *gorm.DB, ids ...uint) map[uint]string {
	return loadMoeNoByUserID(db, ids...)
}
