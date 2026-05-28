//go:build hybrid

package handlerutil

import (
	userbiz "backend/internal/biz/user"
	"backend/rpc/pb/moe"
)

// SearchUserMemoriesResult re-export for legacy callers.
type SearchUserMemoriesResult = userbiz.SearchUserMemoriesResult

// SearchUserFacingMemories 在后端对用户记忆做关键词 + 新近度排序。
func SearchUserFacingMemories(memories []*moe.UserMemory, query string, limit int) SearchUserMemoriesResult {
	return userbiz.SearchUserFacingMemories(memories, query, limit)
}
