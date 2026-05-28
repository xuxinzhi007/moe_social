package commentgrpc

import (
	commentv1 "backend/api/comment/v1"
	moerpc "backend/rpc/pb/moe"
)

func commentToProto(in *moerpc.Comment) *commentv1.Comment {
	if in == nil {
		return nil
	}
	return &commentv1.Comment{
		Id: in.GetId(), PostId: in.GetPostId(), UserId: in.GetUserId(),
		UserName: in.GetUserName(), UserAvatar: in.GetUserAvatar(), Content: in.GetContent(),
		Likes: in.GetLikes(), IsLiked: in.GetIsLiked(), CreatedAt: in.GetCreatedAt(),
		ParentId: in.GetParentId(), ReplyToUserName: in.GetReplyToUserName(),
	}
}

func commentsToProto(rows []*moerpc.Comment) []*commentv1.Comment {
	out := make([]*commentv1.Comment, 0, len(rows))
	for _, row := range rows {
		out = append(out, commentToProto(row))
	}
	return out
}

func achievementUnlocksToProto(rows []*moerpc.AchievementUnlock) []*commentv1.AchievementUnlock {
	out := make([]*commentv1.AchievementUnlock, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &commentv1.AchievementUnlock{
			BadgeId: row.GetBadgeId(), Name: row.GetName(), ExpGranted: row.GetExpGranted(),
			LevelUp: row.GetLevelUp(), NewLevel: row.GetNewLevel(),
		})
	}
	return out
}
