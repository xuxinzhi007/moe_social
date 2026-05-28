package logic

import (
	"context"
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"
)

func parseGroupID(groupIDStr string) (uint64, error) {
	return postbiz.ParseGroupID(groupIDStr)
}

func requireGroupMember(ctx context.Context, st postbiz.PostStore, groupIDStr string, userID uint) error {
	if err := postbiz.RequireGroupMember(ctx, st, groupIDStr, userID); err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidGroupID):
			return errorx.New(400, "无效的群组ID")
		case errors.Is(err, postbiz.ErrGroupNotFound):
			return errorx.New(404, "群组不存在")
		case errors.Is(err, postbiz.ErrNotGroupMember):
			return errorx.New(403, "加入群组后才能发到本群")
		default:
			return errorx.New(500, "查询群组失败")
		}
	}
	return nil
}

func linkPostToGroupTx(tx postbiz.PostTx, groupIDStr string, postID, userID uint) error {
	if err := postbiz.LinkPostToGroupTx(tx, groupIDStr, postID, userID); err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidGroupID):
			return errorx.New(400, "无效的群组ID")
		case errors.Is(err, postbiz.ErrGroupNotFound):
			return errorx.New(404, "群组不存在")
		case errors.Is(err, postbiz.ErrNotGroupMember):
			return errorx.New(403, "加入群组后才能发到本群")
		default:
			return errorx.New(500, "关联群组失败")
		}
	}
	return nil
}
