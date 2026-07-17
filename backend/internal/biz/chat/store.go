package chatbiz

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// ConversationPeerRow 私信会话对端摘要。
type ConversationPeerRow struct {
	PeerID uint
	LastID uint
}

// PrivateMessageStore 私信持久化（P4-D4；默认由 internal/data/chat 实现）。
type PrivateMessageStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) PrivateMessageStore

	GetUser(ctx context.Context, userID uint) (model.User, error)
	CreatePrivateMessage(ctx context.Context, msg *model.PrivateMessage) error
	MoeNoByUserIDs(ctx context.Context, ids []uint) (map[uint]string, error)

	ListPrivateMessages(ctx context.Context, viewerID, peerID uint, beforeID *uint, limit int, now time.Time) ([]model.PrivateMessage, error)
	CountPrivateConversations(ctx context.Context, viewerID uint, now time.Time) (int64, error)
	ListPrivateConversationPeers(ctx context.Context, viewerID uint, limit, offset int, now time.Time) ([]ConversationPeerRow, error)
	GetPrivateMessagesByIDs(ctx context.Context, ids []uint) ([]model.PrivateMessage, error)
	GetUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error)
	CountPrivateChatUnreadByPeer(ctx context.Context, viewerID uint) (map[uint]int32, error)
	DeletePrivateMessagesBetween(ctx context.Context, userID, peerID uint) error
}
