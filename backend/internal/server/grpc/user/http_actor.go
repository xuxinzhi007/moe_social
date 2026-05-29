package usergrpc

import "strings"

// fillActorUserID 将 HTTP path 的 user_id 回填到 actor_user_id（compat 路径参数名）。
func fillActorUserID(actorUserID, userID string) string {
	if strings.TrimSpace(actorUserID) != "" {
		return actorUserID
	}
	return strings.TrimSpace(userID)
}
