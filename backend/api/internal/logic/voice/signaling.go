package voice

import (
	"backend/api/internal/logic/chat"
)

func pushToUser(userID string, payload map[string]interface{}) {
	chat.PushJSONToChatUser(userID, payload)
}
