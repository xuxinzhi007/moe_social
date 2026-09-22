package chatbiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	chatv1 "backend/api/chat/v1"
	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

var safePrivateImageToken = regexp.MustCompile(`^[a-zA-Z0-9._-]+$`)

// SendPrivateMessage 持久化一条私信并返回 proto 视图。
func SendPrivateMessage(ctx context.Context, st PrivateMessageStore, in *chatv1.SendPrivateMessageRequest) (*chatv1.SendPrivateMessageReply, error) {
	if st == nil {
		return nil, ErrChatStoreUnavailable
	}
	senderID, err := strconv.ParseUint(strings.TrimSpace(in.GetSenderId()), 10, 32)
	if err != nil || senderID == 0 {
		return nil, ErrInvalidSenderID
	}
	receiverID, err := strconv.ParseUint(strings.TrimSpace(in.GetReceiverId()), 10, 32)
	if err != nil || receiverID == 0 {
		return nil, ErrInvalidReceiverID
	}
	if senderID == receiverID {
		return nil, ErrMessageSelf
	}

	body := strings.TrimSpace(in.GetBody())
	if body == "" {
		return nil, ErrEmptyMessageBody
	}
	maxRunes := utils.PrivateMessageBodyMaxRunes()
	if utf8.RuneCountInString(body) > maxRunes {
		return nil, ErrMessageBodyTooLong
	}

	paths, err := NormalizePrivateImagePaths(in.GetImagePaths())
	if err != nil {
		return nil, err
	}

	st = st.WithContext(ctx)
	sender, err := st.GetUser(ctx, uint(senderID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get private message sender %d: %w", senderID, ErrUserNotFound)
	}
	if _, err := st.GetUser(ctx, uint(receiverID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPeerNotFound
		}
		return nil, fmt.Errorf("get private message receiver %d: %w", receiverID, ErrPeerNotFound)
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
			return nil, ErrInvalidImagePath
		}
		row.ImagePaths = string(b)
	} else {
		row.ImagePaths = "[]"
	}

	if err := st.CreatePrivateMessage(ctx, &row); err != nil {
		return nil, fmt.Errorf("save private message: %w", ErrSaveMessage)
	}

	moeBy, err := st.MoeNoByUserIDs(ctx, []uint{row.SenderID, row.ReceiverID})
	if err != nil {
		moeBy = map[uint]string{}
	}
	return &chatv1.SendPrivateMessageReply{Message: privateMessageModelToProto(&row, moeBy)}, nil
}

// NormalizePrivateImagePaths 校验并规范化私信图片 token 列表。
func NormalizePrivateImagePaths(in []string) ([]string, error) {
	maxN := utils.PrivateMessageImagePathsMax()
	if len(in) > maxN {
		return nil, ErrTooManyImagePaths
	}
	out := make([]string, 0, len(in))
	for _, p := range in {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if strings.Contains(p, "/") || strings.Contains(p, "\\") || strings.Contains(p, "..") {
			return nil, ErrInvalidImagePath
		}
		if !safePrivateImageToken.MatchString(p) {
			return nil, ErrInvalidImagePath
		}
		out = append(out, p)
	}
	if len(out) > maxN {
		return nil, ErrTooManyImagePaths
	}
	return out, nil
}

func privateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *chatv1.PrivateMessage {
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
	return &chatv1.PrivateMessage{
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
func PrivateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *chatv1.PrivateMessage {
	return privateMessageModelToProto(m, moeByUID)
}

// LoadMoeNoByUserID 批量加载 moe_no 展示字段。
func LoadMoeNoByUserID(st PrivateMessageStore, ids ...uint) map[uint]string {
	if st == nil || len(ids) == 0 {
		return map[uint]string{}
	}
	moeBy, err := st.MoeNoByUserIDs(context.Background(), ids)
	if err != nil {
		return map[uint]string{}
	}
	return moeBy
}

// ClearPrivateChatHistory 清空双方私信历史（双向删除）。
func ClearPrivateChatHistory(ctx context.Context, st PrivateMessageStore, userID, peerID uint) error {
	if st == nil {
		return ErrChatStoreUnavailable
	}
	if userID == 0 || peerID == 0 {
		return ErrInvalidPeerID
	}
	if userID == peerID {
		return ErrMessageSelf
	}
	st = st.WithContext(ctx)
	// 验证双方用户存在
	if _, err := st.GetUser(ctx, userID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return fmt.Errorf("get private chat user %d: %w", userID, ErrUserNotFound)
	}
	if _, err := st.GetUser(ctx, peerID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrPeerNotFound
		}
		return fmt.Errorf("get private chat peer %d: %w", peerID, ErrPeerNotFound)
	}
	return st.DeletePrivateMessagesBetween(ctx, userID, peerID)
}
