package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// LikeResult 点赞/取消点赞结果。
type LikeResult struct {
	Post      model.Post
	User      model.User
	IsLiked   bool
	DidLike   bool
	LikeCount int
}

// Like 切换帖子点赞状态。
func Like(ctx context.Context, st PostStore, postIDStr, userIDStr string) (LikeResult, error) {
	if st == nil {
		return LikeResult{}, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDStr), 10, 32)
	if err != nil || postID == 0 {
		return LikeResult{}, ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 32)
	if err != nil || userID == 0 {
		return LikeResult{}, ErrInvalidUserID
	}

	st = st.WithContext(ctx)
	post, err := st.GetPost(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return LikeResult{}, ErrPostNotFound
		}
		return LikeResult{}, err
	}

	like, hasLiked, err := st.FindLike(ctx, uint(postID), uint(userID), "post")
	if err != nil {
		return LikeResult{}, err
	}

	tx, err := st.Begin(ctx)
	if err != nil {
		return LikeResult{}, err
	}
	didLike := !hasLiked
	if hasLiked {
		if err := tx.DeleteLike(&like); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.UpdatePostLikes(post.ID, post.Likes-1); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		post.Likes--
	} else {
		newLike := model.Like{TargetID: uint(postID), UserID: uint(userID), TargetType: "post"}
		if err := tx.CreateLike(&newLike); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.UpdatePostLikes(post.ID, post.Likes+1); err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		post.Likes++
	}
	if err := tx.Commit(); err != nil {
		return LikeResult{}, err
	}

	post, err = st.GetPostWithUserAndTopicTags(ctx, uint(postID))
	if err != nil {
		return LikeResult{}, err
	}

	likedSet := LikedTargetIDSet(ctx, st, uint(userID), "post", []uint{uint(postID)})
	isLiked := likedSet[uint(postID)]
	user := post.User
	return LikeResult{
		Post: post, User: user, IsLiked: isLiked, DidLike: didLike, LikeCount: post.Likes,
	}, nil
}
