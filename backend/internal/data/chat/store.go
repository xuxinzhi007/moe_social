package chatdata

import (
	"context"
	"time"

	chatbiz "backend/internal/biz/chat"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.PrivateMessageStore（P4-D4）。
func NewStore(db *gorm.DB) chatbiz.PrivateMessageStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) chatbiz.PrivateMessageStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) CreatePrivateMessage(ctx context.Context, msg *model.PrivateMessage) error {
	return s.db.WithContext(ctx).Create(msg).Error
}

func (s *store) MoeNoByUserIDs(ctx context.Context, ids []uint) (map[uint]string, error) {
	out := make(map[uint]string)
	if len(ids) == 0 {
		return out, nil
	}
	seen := make(map[uint]struct{}, len(ids))
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
		return out, nil
	}
	var users []model.User
	if err := s.db.WithContext(ctx).Select("id", "moe_no").Where("id IN ?", uniq).Find(&users).Error; err != nil {
		return out, err
	}
	for _, u := range users {
		out[u.ID] = u.MoeNo
	}
	return out, nil
}

func (s *store) ListPrivateMessages(ctx context.Context, viewerID, peerID uint, beforeID *uint, limit int, now time.Time) ([]model.PrivateMessage, error) {
	q := s.db.WithContext(ctx).Model(&model.PrivateMessage{}).
		Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND expires_at > ?",
			viewerID, peerID, peerID, viewerID, now)
	if beforeID != nil {
		q = q.Where("id < ?", *beforeID)
	}
	var rows []model.PrivateMessage
	err := q.Order("id DESC").Limit(limit).Find(&rows).Error
	return rows, err
}

func (s *store) CountPrivateConversations(ctx context.Context, viewerID uint, now time.Time) (int64, error) {
	type countRow struct {
		Total int64 `gorm:"column:total"`
	}
	var totalRow countRow
	countSQL := `
SELECT COUNT(1) AS total
FROM (
  SELECT CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS peer_id
  FROM private_messages
  WHERE (sender_id = ? OR receiver_id = ?) AND expires_at > ?
  GROUP BY peer_id
) t`
	err := s.db.WithContext(ctx).Raw(countSQL, viewerID, viewerID, viewerID, now).Scan(&totalRow).Error
	return totalRow.Total, err
}

func (s *store) ListPrivateConversationPeers(ctx context.Context, viewerID uint, limit, offset int, now time.Time) ([]chatbiz.ConversationPeerRow, error) {
	type convRow struct {
		PeerID uint `gorm:"column:peer_id"`
		LastID uint `gorm:"column:last_id"`
	}
	var rows []convRow
	listSQL := `
SELECT
  CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS peer_id,
  MAX(id) AS last_id
FROM private_messages
WHERE (sender_id = ? OR receiver_id = ?) AND expires_at > ?
GROUP BY peer_id
ORDER BY last_id DESC
LIMIT ? OFFSET ?`
	if err := s.db.WithContext(ctx).Raw(listSQL, viewerID, viewerID, viewerID, now, limit, offset).Scan(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]chatbiz.ConversationPeerRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, chatbiz.ConversationPeerRow{PeerID: row.PeerID, LastID: row.LastID})
	}
	return out, nil
}

func (s *store) GetPrivateMessagesByIDs(ctx context.Context, ids []uint) ([]model.PrivateMessage, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var msgs []model.PrivateMessage
	err := s.db.WithContext(ctx).Where("id IN ?", ids).Find(&msgs).Error
	return msgs, err
}

func (s *store) GetUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var users []model.User
	err := s.db.WithContext(ctx).Select("id", "username", "avatar", "moe_no").Where("id IN ?", ids).Find(&users).Error
	return users, err
}

func (s *store) CountPrivateChatUnreadByPeer(ctx context.Context, viewerID uint) (map[uint]int32, error) {
	type unreadRow struct {
		PeerID      uint  `gorm:"column:peer_id"`
		UnreadCount int64 `gorm:"column:unread_count"`
	}
	unreadByPeer := make(map[uint]int32)
	var unreadRows []unreadRow
	err := s.db.WithContext(ctx).Model(&model.Notification{}).
		Select("sender_id AS peer_id, COUNT(1) AS unread_count").
		Where("user_id = ? AND type = ? AND is_read = ?", viewerID, chatbiz.NotificationTypePrivateChat, false).
		Group("sender_id").
		Scan(&unreadRows).Error
	if err != nil {
		return nil, err
	}
	for _, row := range unreadRows {
		unreadByPeer[row.PeerID] = int32(row.UnreadCount)
	}
	return unreadByPeer, nil
}
