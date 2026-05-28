package contentbiz

import "time"

// ListInput 内容列表查询。
type ListInput struct {
	UserID   string
	Type     string
	Page     int
	PageSize int
}

// ListItem 单条内容。
type ListItem struct {
	ID        string
	UserID    string
	Type      string
	Prompt    string
	URL       string
	Content   string
	CreatedAt string
}

// ListResult 分页列表结果。
type ListResult struct {
	Items []ListItem
	Total int
}

// ListContent 返回用户内容列表（当前为占位实现）。
func ListContent(in ListInput) ListResult {
	offset := (in.Page - 1) * in.PageSize

	items := []ListItem{
		{
			ID: "1", UserID: in.UserID, Type: "text",
			Prompt: "生成一篇关于人工智能的文章", Content: "人工智能是一种模拟人类智能的技术...",
			CreatedAt: time.Now().Add(-24 * time.Hour).Format(time.RFC3339),
		},
		{
			ID: "2", UserID: in.UserID, Type: "image",
			Prompt: "生成一张猫咪的图片", URL: "https://example.com/images/cat.jpg",
			CreatedAt: time.Now().Add(-48 * time.Hour).Format(time.RFC3339),
		},
		{
			ID: "3", UserID: in.UserID, Type: "video",
			Prompt: "生成一段风景视频", URL: "https://example.com/videos/landscape.mp4",
			CreatedAt: time.Now().Add(-72 * time.Hour).Format(time.RFC3339),
		},
	}

	if in.Type != "" {
		filtered := make([]ListItem, 0, len(items))
		for _, item := range items {
			if item.Type == in.Type {
				filtered = append(filtered, item)
			}
		}
		items = filtered
	}

	total := len(items)
	if offset < len(items) {
		end := offset + in.PageSize
		if end > len(items) {
			end = len(items)
		}
		items = items[offset:end]
	} else {
		items = []ListItem{}
	}

	return ListResult{Items: items, Total: total}
}
