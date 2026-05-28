package chatbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"
)

// ListPrivateMessages 分页拉取两人私信历史（viewer 视角）。
func ListPrivateMessages(ctx context.Context, st PrivateMessageStore, in *moe.ListPrivateMessagesReq) (*moe.ListPrivateMessagesResp, error) {
	if st == nil {
		return nil, errors.New("db not ready")
	}
	viewer, err := strconv.ParseUint(strings.TrimSpace(in.GetViewerId()), 10, 32)
	if err != nil || viewer == 0 {
		return nil, errors.New("invalid viewer_id")
	}
	peer, err := strconv.ParseUint(strings.TrimSpace(in.GetPeerId()), 10, 32)
	if err != nil || peer == 0 {
		return nil, errors.New("invalid peer_id")
	}
	if viewer == peer {
		return nil, errors.New("invalid peer")
	}

	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}

	now := time.Now()
	st = st.WithContext(ctx)

	var beforeID *uint
	if bid := strings.TrimSpace(in.GetBeforeId()); bid != "" {
		beforeUint, err := strconv.ParseUint(bid, 10, 32)
		if err != nil {
			return nil, errors.New("invalid before_id")
		}
		v := uint(beforeUint)
		beforeID = &v
	}

	rows, err := st.ListPrivateMessages(ctx, uint(viewer), uint(peer), beforeID, limit+1, now)
	if err != nil {
		return nil, errors.New("query failed")
	}

	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}

	idSet := make(map[uint]struct{})
	for _, r := range rows {
		idSet[r.SenderID] = struct{}{}
		idSet[r.ReceiverID] = struct{}{}
	}
	ids := make([]uint, 0, len(idSet))
	for id := range idSet {
		ids = append(ids, id)
	}
	moeBy, _ := st.MoeNoByUserIDs(ctx, ids)

	out := make([]*moe.PrivateMessage, 0, len(rows))
	for i := len(rows) - 1; i >= 0; i-- {
		out = append(out, privateMessageModelToProto(&rows[i], moeBy))
	}

	return &moe.ListPrivateMessagesResp{Messages: out, HasMore: hasMore}, nil
}

// ListPrivateConversations 列出 viewer 的私信会话摘要。
func ListPrivateConversations(ctx context.Context, st PrivateMessageStore, in *moe.ListPrivateConversationsReq) (*moe.ListPrivateConversationsResp, error) {
	if st == nil {
		return nil, errors.New("db not ready")
	}
	viewerID, err := strconv.ParseUint(strings.TrimSpace(in.GetViewerId()), 10, 32)
	if err != nil || viewerID == 0 {
		return nil, errors.New("invalid viewer_id")
	}

	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 30
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.GetOffset())
	if offset < 0 {
		offset = 0
	}

	now := time.Now()
	st = st.WithContext(ctx)

	total, err := st.CountPrivateConversations(ctx, uint(viewerID), now)
	if err != nil {
		return nil, err
	}

	rows, err := st.ListPrivateConversationPeers(ctx, uint(viewerID), limit, offset, now)
	if err != nil {
		return nil, err
	}

	lastIDs := make([]uint, 0, len(rows))
	peerIDs := make([]uint, 0, len(rows))
	for _, row := range rows {
		if row.PeerID == 0 || row.LastID == 0 {
			continue
		}
		peerIDs = append(peerIDs, row.PeerID)
		lastIDs = append(lastIDs, row.LastID)
	}

	msgByID := map[uint]model.PrivateMessage{}
	if len(lastIDs) > 0 {
		msgs, err := st.GetPrivateMessagesByIDs(ctx, lastIDs)
		if err != nil {
			return nil, err
		}
		for _, m := range msgs {
			msgByID[m.ID] = m
		}
	}

	userByID := map[uint]model.User{}
	if len(peerIDs) > 0 {
		users, err := st.GetUsersByIDs(ctx, peerIDs)
		if err != nil {
			return nil, err
		}
		for _, u := range users {
			userByID[u.ID] = u
		}
	}

	unreadByPeer, err := st.CountPrivateChatUnreadByPeer(ctx, uint(viewerID))
	if err != nil {
		return nil, err
	}

	moeIDs := append(peerIDs, uint(viewerID))
	moeBy, _ := st.MoeNoByUserIDs(ctx, moeIDs)
	out := make([]*moe.PrivateConversation, 0, len(rows))
	for _, row := range rows {
		msg, ok := msgByID[row.LastID]
		if !ok {
			continue
		}
		peer := userByID[row.PeerID]
		peerName := strings.TrimSpace(peer.Username)
		if peerName == "" {
			peerName = "用户"
		}
		lastMsg := privateMessageModelToProto(&msg, moeBy)
		if strings.TrimSpace(lastMsg.GetBody()) == "" && len(lastMsg.GetImagePaths()) > 0 {
			lastMsg.Body = "[IMG]"
		}
		out = append(out, &moe.PrivateConversation{
			PeerId:            strconv.FormatUint(uint64(row.PeerID), 10),
			PeerName:          peerName,
			PeerAvatar:        strings.TrimSpace(peer.Avatar),
			PeerMoeNo:         strings.TrimSpace(peer.MoeNo),
			PeerDisplayUserId: strings.TrimSpace(peer.MoeNo),
			LastMessage:       lastMsg,
			UnreadCount:       unreadByPeer[row.PeerID],
		})
	}

	hasMore := int64(offset+len(out)) < total
	return &moe.ListPrivateConversationsResp{
		Conversations: out,
		Total:         int32(total),
		Limit:         int32(limit),
		Offset:        int32(offset),
		HasMore:       hasMore,
	}, nil
}
