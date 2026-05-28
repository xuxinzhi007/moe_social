package chat

import chatbiz "backend/internal/biz/chat"

// TryMatchJoin 将用户加入在线匹配队列（委托 chatbiz）。
func TryMatchJoin(userID string, send func(string, interface{}) bool) {
	chatbiz.TryMatchJoin(userID, send)
}

// TryMatchCancel 离开匹配队列（委托 chatbiz）。
func TryMatchCancel(userID string) {
	chatbiz.TryMatchCancel(userID)
}
