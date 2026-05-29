package landingbiz

import (
	"time"

	landingv1 "backend/api/landing/v1"
	"backend/model"
)

// FeedbackItemsToProto 列表转 proto。
func FeedbackItemsToProto(rows []model.LandingFeedback) []*landingv1.LandingFeedbackItem {
	items := make([]*landingv1.LandingFeedbackItem, 0, len(rows))
	for i := range rows {
		row := rows[i]
		items = append(items, &landingv1.LandingFeedbackItem{
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
