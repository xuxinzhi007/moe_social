package commentbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// LikeResult 评论点赞结果。
type LikeResult struct {
	Comment model.Comment
	User    model.User
	IsLiked bool
}

// Like 切换评论点赞状态。
func Like(ctx context.Context, st CommentStore, commentIDStr, userIDStr string) (LikeResult, error) {
	if st == nil {
		return LikeResult{}, gorm.ErrInvalidDB
	}
	commentID, err := strconv.ParseUint(strings.TrimSpace(commentIDStr), 10, 32)
	if err != nil || commentID == 0 {
		return LikeResult{}, ErrInvalidCommentID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 32)
	if err != nil || userID == 0 {
		return LikeResult{}, ErrInvalidUserID
	}

	st = st.WithContext(ctx)
	comment, err := st.GetComment(ctx, uint(commentID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return LikeResult{}, ErrCommentNotFound
		}
		return LikeResult{}, err
	}

	like, hasLiked, err := st.FindLike(ctx, uint(commentID), uint(userID), "comment")
	if err != nil {
		return LikeResult{}, err
	}

	tx, err := st.Begin(ctx)
	if err != nil {
		return LikeResult{}, err
	}
	if hasLiked {
		if err := tx.DeleteLike(&like); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.UpdateCommentLikes(comment.ID, comment.Likes-1); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		comment.Likes--
	} else {
		newLike := model.Like{TargetID: uint(commentID), UserID: uint(userID), TargetType: "comment"}
		if err := tx.CreateLike(&newLike); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.UpdateCommentLikes(comment.ID, comment.Likes+1); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		comment.Likes++
	}
	if err := tx.Commit(); err != nil {
		return LikeResult{}, err
	}

	comment, err = st.GetCommentWithUser(ctx, uint(commentID))
	if err != nil {
		return LikeResult{}, err
	}

	isLiked, err := st.HasLiked(ctx, uint(commentID), uint(userID), "comment")
	if err != nil {
		return LikeResult{}, err
	}

	return LikeResult{Comment: comment, User: comment.User, IsLiked: isLiked}, nil
}
