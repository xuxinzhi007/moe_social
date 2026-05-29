package brain

import (
	"strings"
	"sync"
)

var (
	dreamingMu sync.Mutex
	dreaming   = map[string]bool{}
)

// IsDreaming 是否正在入梦 consolidation。
func IsDreaming(agentKey string) bool {
	key := strings.TrimSpace(agentKey)
	dreamingMu.Lock()
	defer dreamingMu.Unlock()
	return dreaming[key]
}

func setDreaming(agentKey string, on bool) {
	key := strings.TrimSpace(agentKey)
	dreamingMu.Lock()
	defer dreamingMu.Unlock()
	if on {
		dreaming[key] = true
		return
	}
	delete(dreaming, key)
}
