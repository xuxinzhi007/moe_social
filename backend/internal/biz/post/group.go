package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

func parseGroupID(groupIDStr string) (uint64, error) {
	groupIDStr = strings.TrimSpace(groupIDStr)
	if groupIDStr == "" {
		return 0, nil
	}
	groupID, err := strconv.ParseUint(groupIDStr, 10, 64)
	if err != nil || groupID == 0 {
		return 0, ErrInvalidGroupID
	}
	return groupID, nil
}

// ParseGroupID 解析群组 ID（供 RPC 兼容层使用）。
func ParseGroupID(groupIDStr string) (uint64, error) {
	return parseGroupID(groupIDStr)
}

// RequireGroupMember 校验用户已加入群组。
func RequireGroupMember(ctx context.Context, st PostStore, groupIDStr string, userID uint) error {
	groupID, err := parseGroupID(groupIDStr)
	if err != nil {
		return err
	}
	if groupID == 0 {
		return nil
	}
	if _, err := st.GetGroup(ctx, groupID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrGroupNotFound
		}
		return err
	}
	if _, err := st.GetGroupMember(ctx, groupID, userID); err != nil {
		return ErrNotGroupMember
	}
	return nil
}

// LinkPostToGroupTx 在同一事务内将帖子关联到群组。
func LinkPostToGroupTx(tx PostTx, groupIDStr string, postID, userID uint) error {
	groupID, err := parseGroupID(groupIDStr)
	if err != nil {
		return err
	}
	if groupID == 0 {
		return nil
	}
	if _, err := tx.GetGroup(groupID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrGroupNotFound
		}
		return err
	}
	if _, err := tx.GetGroupMember(groupID, userID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrNotGroupMember
		}
		return err
	}
	if _, ok, err := tx.FindGroupPost(groupID, postID); err != nil {
		return err
	} else if ok {
		return nil
	}
	return tx.CreateGroupPost(&model.GroupPost{GroupID: uint(groupID), PostID: postID})
}
