package content

import (
	"context"
	"time"

	"backend/api/internal/svc"
	"backend/api/internal/types"
)

type GetContentListLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetContentListLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetContentListLogic {
	return &GetContentListLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetContentListLogic) GetContentList(req *types.ContentListReq) (resp *types.ContentListResp, err error) {
	// 这里返回模拟数据，实际应从数据库查询
	// 分页处理
	offset := (req.Page - 1) * req.PageSize

	// 模拟内容列表
	contentItems := []types.ContentItem{
		{
			Id:        "1",
			UserId:    req.UserId,
			Type:      "text",
			Prompt:    "生成一篇关于人工智能的文章",
			Content:   "人工智能是一种模拟人类智能的技术...",
			CreatedAt: time.Now().Add(-24 * time.Hour).Format(time.RFC3339),
		},
		{
			Id:        "2",
			UserId:    req.UserId,
			Type:      "image",
			Prompt:    "生成一张猫咪的图片",
			Url:       "https://example.com/images/cat.jpg",
			CreatedAt: time.Now().Add(-48 * time.Hour).Format(time.RFC3339),
		},
		{
			Id:        "3",
			UserId:    req.UserId,
			Type:      "video",
			Prompt:    "生成一段风景视频",
			Url:       "https://example.com/videos/landscape.mp4",
			CreatedAt: time.Now().Add(-72 * time.Hour).Format(time.RFC3339),
		},
	}

	// 过滤内容类型
	if req.Type != "" {
		filteredItems := []types.ContentItem{}
		for _, item := range contentItems {
			if item.Type == req.Type {
				filteredItems = append(filteredItems, item)
			}
		}
		contentItems = filteredItems
	}

	// 计算总数
	total := len(contentItems)

	// 分页处理
	if offset < len(contentItems) {
		end := offset + req.PageSize
		if end > len(contentItems) {
			end = len(contentItems)
		}
		contentItems = contentItems[offset:end]
	} else {
		contentItems = []types.ContentItem{}
	}

	return &types.ContentListResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "获取内容列表成功",
			Success: true,
		},
		Data:  contentItems,
		Total: total,
	}, nil
}
