package logic

import (
	"context"

	"backend/model"
	postbiz "backend/internal/biz/post"
	"backend/rpc/pb/moe"
)

func LikedTargetIDSet(ctx context.Context, st postbiz.PostStore, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	return postbiz.LikedTargetIDSet(ctx, st, userID, targetType, targetIDs)
}

func moderationStatusOrDefault(s string) string {
	return postbiz.ModerationStatusOrDefault(s)
}

func buildSuperPost(post model.Post, user model.User, isLiked bool) *moe.Post {
	return postbiz.BuildProtoPost(post, user, isLiked)
}
