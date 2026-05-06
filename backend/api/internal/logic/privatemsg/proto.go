package privatemsg

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func privateMessageItemFromProto(m *super.PrivateMessage) types.PrivateMessageItem {
	paths := m.GetImagePaths()
	if paths == nil {
		paths = []string{}
	}
	return types.PrivateMessageItem{
		Id:             m.GetId(),
		SenderId:       m.GetSenderId(),
		ReceiverId:     m.GetReceiverId(),
		SenderMoeNo:    m.GetSenderMoeNo(),
		ReceiverMoeNo:  m.GetReceiverMoeNo(),
		Body:           m.GetBody(),
		ImagePaths:     paths,
		RetentionDays:  int(m.GetRetentionDays()),
		CreatedAt:      m.GetCreatedAt(),
		ExpiresAt:      m.GetExpiresAt(),
	}
}
