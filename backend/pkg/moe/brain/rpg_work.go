package brain

import (
	"strings"
	"sync"
)

var (
	workMu sync.Mutex
	workBy = map[string]string{}
)

// SetRpgWork 标记 Bot 正在执行的记忆整理类动作（供 presence / 游戏 UI）。
func SetRpgWork(agentKey, activity string) {
	key := strings.TrimSpace(agentKey)
	if key == "" {
		return
	}
	workMu.Lock()
	defer workMu.Unlock()
	if strings.TrimSpace(activity) == "" {
		delete(workBy, key)
		return
	}
	workBy[key] = strings.TrimSpace(activity)
}

// CurrentRpgWork 返回 tidying / compressing 等，无则空。
func CurrentRpgWork(agentKey string) string {
	key := strings.TrimSpace(agentKey)
	workMu.Lock()
	defer workMu.Unlock()
	return workBy[key]
}
