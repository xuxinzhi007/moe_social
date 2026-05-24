package voice

import (
	"sync"
	"time"
)

// callSession 内存中的呼叫会话（单机有效；多副本部署需 Redis）。
type callSession struct {
	CallID       string
	ChannelName  string
	CallerID     string
	ReceiverID   string
	CallerName   string
	CallerAvatar string
	CreatedAt    time.Time
}

var (
	callMu    sync.RWMutex
	callByID  = make(map[string]*callSession)
)

func putCall(s *callSession) {
	callMu.Lock()
	callByID[s.CallID] = s
	callMu.Unlock()
}

func getCall(callID string) (*callSession, bool) {
	callMu.RLock()
	s, ok := callByID[callID]
	callMu.RUnlock()
	return s, ok
}

func removeCall(callID string) {
	callMu.Lock()
	delete(callByID, callID)
	callMu.Unlock()
}
