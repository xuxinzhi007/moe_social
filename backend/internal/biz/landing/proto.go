package landingbiz

import (
	"time"

	"backend/model"
	"backend/rpc/pb/moe"
)

// FeedbackItemsToProto 列表转 proto。
func FeedbackItemsToProto(rows []model.LandingFeedback) []*moe.LandingFeedbackItem {
	items := make([]*moe.LandingFeedbackItem, 0, len(rows))
	for i := range rows {
		row := rows[i]
		items = append(items, &moe.LandingFeedbackItem{
			Id:        uint64(row.ID),
			Email:     row.Email,
			Category:  row.Category,
			Content:   row.Content,
			Source:    row.Source,
			ClientIp:  row.ClientIP,
			UserAgent: row.UserAgent,
			CreatedAt: row.CreatedAt.Format(time.RFC3339),
		})
	}
	return items
}
