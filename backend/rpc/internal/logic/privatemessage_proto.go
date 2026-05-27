package logic

import (
	chatbiz "backend/internal/biz/chat"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

func privateMessageModelToProto(m *model.PrivateMessage, moeByUID map[uint]string) *super.PrivateMessage {
	return chatbiz.PrivateMessageModelToProto(m, moeByUID)
}

func loadMoeNoByUserID(db *gorm.DB, ids ...uint) map[uint]string {
	return chatbiz.LoadMoeNoByUserID(db, ids...)
}
