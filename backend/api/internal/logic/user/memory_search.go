package user

import (
	"backend/pkg/memory"
	"backend/rpc/pb/super"
)

// SearchUserMemoriesResult 记忆库查询结果（文本库检索，与 LLM tools 无关）。
type SearchUserMemoriesResult struct {
	Query string                  `json:"query"`
	Items []UserMemoryDisplayItem `json:"items"`
	Total int                     `json:"total"`
}

// SearchUserFacingMemories 在后端对用户记忆做关键词 + 新近度排序（委托 pkg/memory SSOT）。
func SearchUserFacingMemories(memories []*super.UserMemory, query string, limit int) SearchUserMemoriesResult {
	res := memory.SearchFacing(memory.RecordsFromSuper(memories), query, limit)
	items := make([]UserMemoryDisplayItem, 0, len(res.Items))
	for _, it := range res.Items {
		items = append(items, UserMemoryDisplayItem{
			ID:        it.ID,
			Key:       it.Key,
			Title:     it.Title,
			Content:   it.Content,
			Category:  it.Category,
			UpdatedAt: it.UpdatedAt,
		})
	}
	return SearchUserMemoriesResult{
		Query: res.Query,
		Items: items,
		Total: res.Total,
	}
}
