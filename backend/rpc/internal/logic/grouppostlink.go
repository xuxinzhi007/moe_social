package logic

import (
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"

	"gorm.io/gorm"
)

func parseGroupID(groupIDStr string) (uint64, error) {
	return postbiz.ParseGroupID(groupIDStr)
}

func requireGroupMember(db *gorm.DB, groupIDStr string, userID uint) error {
	if err := postbiz.RequireGroupMember(db, groupIDStr, userID); err != nil {
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

func linkPostToGroupTx(tx *gorm.DB, groupIDStr string, postID, userID uint) error {
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
