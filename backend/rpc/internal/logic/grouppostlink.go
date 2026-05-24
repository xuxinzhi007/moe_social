package logic

import (
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"

	"gorm.io/gorm"
)

// linkPostToGroupTx 在同一事务内将帖子关联到群组（调用方须已校验 post 归属 userID）。
func linkPostToGroupTx(tx *gorm.DB, groupIDStr string, postID, userID uint) error {
	if groupIDStr == "" {
		return nil
	}
	groupID, err := strconv.ParseUint(groupIDStr, 10, 64)
	if err != nil || groupID == 0 {
		return errorx.New(400, "无效的群组ID")
	}

	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return errorx.New(404, "群组不存在")
		}
		return errorx.New(500, "查询群组失败")
	}

	var member model.GroupMember
	if err := tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return errorx.New(403, "加入群组后才能发到本群")
	}

	var existing model.GroupPost
	if err := tx.Where("group_id = ? AND post_id = ?", groupID, postID).First(&existing).Error; err == nil {
		return nil
	}

	link := model.GroupPost{
		GroupID: uint(groupID),
		PostID:  postID,
	}
	if err := tx.Create(&link).Error; err != nil {
		return errorx.New(500, "关联群组失败")
	}
	return nil
}
