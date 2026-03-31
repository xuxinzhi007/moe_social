package chat

import (
	"sync"
)

var (
	matchMu    sync.Mutex
	matchQueue []string
)

func removeFromMatchQueue(uid string) {
	out := matchQueue[:0]
	for _, x := range matchQueue {
		if x != uid {
			out = append(out, x)
		}
	}
	matchQueue = out
}

// TryMatchJoin 将用户加入在线匹配队列；若已有他人等待则立即配对并通过 send 下发 match_found。
func TryMatchJoin(userID string, send func(string, interface{}) bool) {
	matchMu.Lock()
	defer matchMu.Unlock()

	removeFromMatchQueue(userID)

	if len(matchQueue) > 0 {
		peer := matchQueue[0]
		matchQueue = matchQueue[1:]
		send(userID, map[string]interface{}{
			"type":    "match_found",
			"peer_id": peer,
		})
		send(peer, map[string]interface{}{
			"type":    "match_found",
			"peer_id": userID,
		})
		return
	}

	matchQueue = append(matchQueue, userID)
	send(userID, map[string]interface{}{
		"type": "match_waiting",
	})
}

// TryMatchCancel 离开匹配队列（未配对时）。
func TryMatchCancel(userID string) {
	matchMu.Lock()
	defer matchMu.Unlock()
	removeFromMatchQueue(userID)
}
