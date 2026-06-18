package platformhttp

import (
	"context"

	platformv1 "backend/api/platform/v1"
	contentbiz "backend/internal/biz/content"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func (s *Server) ListUserContent(ctx context.Context, in *platformv1.ListUserContentReq) (*platformv1.ListUserContentResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.contentApp == nil {
		return nil, kerrors.BadRequest("CONTENT_UNAVAILABLE", "content app unavailable")
	}
	page := int(in.GetPage())
	if page <= 0 {
		page = 1
	}
	pageSize := int(in.GetPageSize())
	if pageSize <= 0 {
		pageSize = 10
	}
	result := s.contentApp.ListContent(ctx, contentbiz.ListInput{
		UserID: in.GetUserId(), Type: in.GetType(), Page: page, PageSize: pageSize,
	})
	items := make([]*platformv1.ContentItem, 0, len(result.Items))
	for _, item := range result.Items {
		items = append(items, &platformv1.ContentItem{
			Id: item.ID, UserId: item.UserID, Type: item.Type, Prompt: item.Prompt,
			Url: item.URL, Content: item.Content, CreatedAt: item.CreatedAt,
		})
	}
	return &platformv1.ListUserContentResp{
		Code: 200, Message: "获取内容列表成功", Success: true,
		Data: items, Total: int32(result.Total),
	}, nil
}
