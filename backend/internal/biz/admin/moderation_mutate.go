package adminbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	adminv1 "backend/api/admin/v1"
	communitybiz "backend/internal/biz/community"
	"backend/model"

	"gorm.io/gorm"
)

// DeleteFollow Admin 删除关注关系。
func DeleteFollow(ctx context.Context, db *gorm.DB, in *adminv1.AdminDeleteFollowReq) (*adminv1.AdminDeleteFollowResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetFollowId()), 10, 64)
	if err != nil || id == 0 {
		return nil, ErrInvalidFollowID
	}
	if err := db.WithContext(ctx).Delete(&model.Follow{}, id).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeleteFollow, err)
	}
	return &adminv1.AdminDeleteFollowResp{}, nil
}

// DeletePost Admin 删除动态。
func DeletePost(ctx context.Context, db *gorm.DB, in *adminv1.AdminDeletePostReq) (*adminv1.AdminDeletePostResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	raw := strings.TrimSpace(in.GetPostId())
	if raw == "" {
		return nil, ErrEmptyPostID
	}
	postID, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || postID == 0 {
		return nil, ErrInvalidPostID
	}

	var p model.Post
	if err := db.WithContext(ctx).First(&p, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPostNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDeletePost, err)
	}

	db.WithContext(ctx).Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
	if err := db.WithContext(ctx).Delete(&p).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeletePost, err)
	}
	return &adminv1.AdminDeletePostResp{}, nil
}

// DeleteComment Admin 删除评论。
func DeleteComment(ctx context.Context, db *gorm.DB, in *adminv1.AdminDeleteCommentReq) (*adminv1.AdminDeleteCommentResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	raw := strings.TrimSpace(in.GetCommentId())
	if raw == "" {
		return nil, ErrEmptyCommentID
	}
	commentID, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || commentID == 0 {
		return nil, ErrInvalidCommentID
	}

	var c model.Comment
	if err := db.WithContext(ctx).First(&c, commentID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrCommentNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDeleteComment, err)
	}
	if err := db.WithContext(ctx).Delete(&c).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeleteComment, err)
	}
	return &adminv1.AdminDeleteCommentResp{}, nil
}

// DeleteGroup Admin 删除社区。
func DeleteGroup(ctx context.Context, community communitybiz.CommunityStore, in *adminv1.AdminDeleteGroupReq) (*adminv1.AdminDeleteGroupResp, error) {
	if community == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := strconv.ParseUint(strings.TrimSpace(in.GetGroupId()), 10, 64)
	if err != nil || groupID == 0 {
		return nil, ErrInvalidGroupID
	}
	tx, err := community.Begin(ctx)
	if err != nil {
		return nil, err
	}
	group, err := tx.GetGroup(uint(groupID))
	if err != nil {
		_ = tx.Rollback()
		return nil, ErrGroupNotFound
	}
	if err := tx.DeleteGroupMembersByGroupID(uint(groupID)); err != nil {
		_ = tx.Rollback()
		return nil, fmt.Errorf("%w: %v", ErrDeleteGroup, err)
	}
	if err := tx.DeleteGroup(&group); err != nil {
		_ = tx.Rollback()
		return nil, fmt.Errorf("%w: %v", ErrDeleteGroup, err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeleteGroup, err)
	}
	return &adminv1.AdminDeleteGroupResp{}, nil
}

// DeleteMemory Admin 删除记忆。
func DeleteMemory(ctx context.Context, db *gorm.DB, in *adminv1.AdminDeleteMemoryReq) (*adminv1.AdminDeleteMemoryResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id := in.GetMemoryId()
	if id == 0 {
		return nil, ErrInvalidMemoryID
	}
	result := db.WithContext(ctx).Delete(&model.UserMemory{}, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, ErrMemoryNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDeleteMemory, result.Error)
	}
	if result.RowsAffected == 0 {
		return nil, ErrMemoryNotFound
	}
	return &adminv1.AdminDeleteMemoryResp{}, nil
}
