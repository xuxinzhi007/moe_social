package postbiz

import (
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
func RequireGroupMember(db *gorm.DB, groupIDStr string, userID uint) error {
	groupID, err := parseGroupID(groupIDStr)
	if err != nil {
		return err
	}
	if groupID == 0 {
		return nil
	}
	var group model.Group
	if err := db.First(&group, groupID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrGroupNotFound
		}
		return err
	}
	var member model.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return ErrNotGroupMember
	}
	return nil
}

// LinkPostToGroupTx 在同一事务内将帖子关联到群组。
func LinkPostToGroupTx(tx *gorm.DB, groupIDStr string, postID, userID uint) error {
	groupID, err := parseGroupID(groupIDStr)
	if err != nil {
		return err
	}
	if groupID == 0 {
		return nil
	}
	if err := RequireGroupMember(tx, groupIDStr, userID); err != nil {
		return err
	}
	var existing model.GroupPost
	if err := tx.Where("group_id = ? AND post_id = ?", groupID, postID).First(&existing).Error; err == nil {
		return nil
	}
	link := model.GroupPost{GroupID: uint(groupID), PostID: postID}
	if err := tx.Create(&link).Error; err != nil {
		return err
	}
	return nil
}
