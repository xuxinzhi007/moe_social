package commentbiz

import (
	"context"
	"strconv"
	"strings"

	commentv1 "backend/api/comment/v1"
	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

// ListFilter 评论列表参数。
type ListFilter struct {
	PostID       string
	Page         int32
	PageSize     int32
	ViewerUserID string
}

func likedTargetIDSet(ctx context.Context, st CommentStore, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	out := make(map[uint]bool)
	if st == nil || userID == 0 || len(targetIDs) == 0 {
		return out
	}
	found, err := st.PluckLikedTargetIDs(ctx, userID, targetType, targetIDs)
	if err != nil {
		return out
	}
	for _, id := range found {
		out[id] = true
	}
	return out
}

// ListByPost 帖子评论列表。
func ListByPost(ctx context.Context, st CommentStore, f ListFilter) ([]*commentv1.Comment, int32, error) {
	if st == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(f.PostID), 10, 32)
	if err != nil || postID == 0 {
		return nil, 0, ErrInvalidPostID
	}
	page, pageSize := f.Page, f.PageSize
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 500 {
		pageSize = 500
	}
	offset := int((page - 1) * pageSize)

	st = st.WithContext(ctx)
	comments, total, err := st.ListCommentsByPost(ctx, uint(postID), offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}

	userMap := map[uint]model.User{}
	if len(comments) > 0 {
		userIDs := make([]uint, 0, len(comments))
		for _, c := range comments {
			userIDs = append(userIDs, c.UserID)
		}
		users, _ := st.GetUsersByIDs(ctx, userIDs)
		for _, u := range users {
			userMap[u.ID] = u
		}
	}
	var viewerUID uint
	if f.ViewerUserID != "" {
		if v, e := strconv.ParseUint(f.ViewerUserID, 10, 32); e == nil {
			viewerUID = uint(v)
		}
	}
	commentIDs := make([]uint, 0, len(comments))
	for _, c := range comments {
		commentIDs = append(commentIDs, c.ID)
	}
	likedComments := likedTargetIDSet(ctx, st, viewerUID, "comment", commentIDs)

	parentNameMap := map[uint]string{}
	parentIDs := make([]uint, 0)
	for _, c := range comments {
		if c.ParentID > 0 {
			parentIDs = append(parentIDs, c.ParentID)
		}
	}
	if len(parentIDs) > 0 {
		parents, _ := st.ListCommentsWithUserByIDs(ctx, parentIDs)
		for _, p := range parents {
			name := "用户"
			if p.User.Username != "" {
				name = p.User.Username
			} else if p.User.Email != "" {
				name = p.User.Email
			}
			parentNameMap[p.ID] = name
		}
	}

	out := make([]*commentv1.Comment, 0, len(comments))
	for _, comment := range comments {
		username := "未知用户"
		avatar := "https://picsum.photos/150"
		if user, ok := userMap[comment.UserID]; ok {
			if user.Username != "" {
				username = user.Username
			} else if user.Email != "" {
				username = user.Email
			}
			if user.Avatar != "" {
				avatar = user.Avatar
			}
		}
		out = append(out, &commentv1.Comment{
			Id:              strconv.FormatUint(uint64(comment.ID), 10),
			PostId:          strconv.FormatUint(uint64(comment.PostID), 10),
			UserId:          strconv.FormatUint(uint64(comment.UserID), 10),
			UserName:        username,
			UserAvatar:      avatar,
			Content:         comment.Content,
			Likes:           int32(comment.Likes),
			IsLiked:         likedComments[comment.ID],
			CreatedAt:       utils.FormatAPIDateTime(comment.CreatedAt),
			ParentId:        strconv.FormatUint(uint64(comment.ParentID), 10),
			ReplyToUserName: parentNameMap[comment.ParentID],
		})
	}
	return out, int32(total), nil
}
