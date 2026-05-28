package logic

import (
	chatbiz "backend/internal/biz/chat"
	"backend/model"
	"backend/rpc/pb/moe"
)

func privateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *moe.PrivateMessage {
	return chatbiz.PrivateMessageModelToProto(m, moeByUID)
}

func loadMoeNoByUserID(st chatbiz.PrivateMessageStore, ids ...uint) map[uint]string {
	return chatbiz.LoadMoeNoByUserID(st, ids...)
}
