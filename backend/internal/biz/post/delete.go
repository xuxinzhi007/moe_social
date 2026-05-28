package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"gorm.io/gorm"
)

// Delete 软删除帖子（仅作者）。
func Delete(ctx context.Context, st PostStore, postIDStr, userIDStr string) error {
	if st == nil {
		return gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDStr), 10, 64)
	if err != nil || postID == 0 {
		return ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 64)
	if err != nil || userID == 0 {
		return ErrInvalidUserID
	}

	st = st.WithContext(ctx)
	p, err := st.GetPost(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrPostNotFound
		}
		return err
	}
	if uint64(p.UserID) != userID {
		return ErrNotPostOwner
	}

	st.DeletePostTopics(ctx, p.ID)
	return st.DeletePost(ctx, &p)
}
