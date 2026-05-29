package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	postv1 "backend/api/post/v1"

	"gorm.io/gorm"
)

// ErrHandDrawNotFound 帖子无手绘笔迹数据。
var ErrHandDrawNotFound = errors.New("hand draw not found")

// GetHandDraw 懒加载手绘笔迹（含可见性校验，与 GetByID 一致）。
func GetHandDraw(ctx context.Context, st PostStore, postIDRaw, viewerUserIDRaw string) (*postv1.GetPostHandDrawReply, error) {
	if st == nil {
		return nil, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDRaw), 10, 32)
	if err != nil || postID == 0 {
		return nil, ErrInvalidPostID
	}
	st = st.WithContext(ctx)
	post, err := st.GetPost(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPostNotFound
		}
		return nil, err
	}
	var viewerUID uint
	if viewerUserIDRaw != "" {
		if v, e := strconv.ParseUint(viewerUserIDRaw, 10, 32); e == nil {
			viewerUID = uint(v)
		}
	}
	ms := moderationStatusOrDefault(post.ModerationStatus)
	if ms == "rejected" {
		return nil, ErrPostNotFound
	}
	if ms == "pending" && post.UserID != viewerUID {
		return nil, ErrPostNotFound
	}
	if strings.TrimSpace(post.HandDrawCard) == "" && strings.TrimSpace(post.HandDrawThumbURL) == "" {
		return nil, ErrHandDrawNotFound
	}
	return &postv1.GetPostHandDrawReply{
		HandDrawCard:     post.HandDrawCard,
		HandDrawThumbUrl: post.HandDrawThumbURL,
	}, nil
}
