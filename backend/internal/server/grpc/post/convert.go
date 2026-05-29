package postgrpc

import (
	postv1 "backend/api/post/v1"
	moerpc "backend/rpc/pb/moe"
)

func topicTagsToProto(rows []*moerpc.TopicTag) []*postv1.TopicTag {
	out := make([]*postv1.TopicTag, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &postv1.TopicTag{
			Id: row.GetId(), Name: row.GetName(), Color: row.GetColor(), CreatedAt: row.GetCreatedAt(),
		})
	}
	return out
}

func topicTagsFromProto(rows []*postv1.TopicTag) []*moerpc.TopicTag {
	out := make([]*moerpc.TopicTag, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &moerpc.TopicTag{
			Id: row.GetId(), Name: row.GetName(), Color: row.GetColor(), CreatedAt: row.GetCreatedAt(),
		})
	}
	return out
}

func postToProto(in *moerpc.Post) *postv1.Post {
	if in == nil {
		return nil
	}
	return &postv1.Post{
		Id: in.GetId(), UserId: in.GetUserId(), UserName: in.GetUserName(),
		UserAvatar: in.GetUserAvatar(), Content: in.GetContent(), Images: in.GetImages(),
		TopicTags: topicTagsToProto(in.GetTopicTags()), Likes: in.GetLikes(),
		Comments: in.GetComments(), IsLiked: in.GetIsLiked(), CreatedAt: in.GetCreatedAt(),
		HandDrawCard: in.GetHandDrawCard(), HandDrawThumbUrl: in.GetHandDrawThumbUrl(),
		ModerationStatus: in.GetModerationStatus(), AuthorIsBot: in.GetAuthorIsBot(),
		AuthorBotAgentKey: in.GetAuthorBotAgentKey(),
	}
}

func achievementUnlocksToProto(rows []*moerpc.AchievementUnlock) []*postv1.AchievementUnlock {
	out := make([]*postv1.AchievementUnlock, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &postv1.AchievementUnlock{
			BadgeId: row.GetBadgeId(), Name: row.GetName(), ExpGranted: row.GetExpGranted(),
			LevelUp: row.GetLevelUp(), NewLevel: row.GetNewLevel(),
		})
	}
	return out
}

func searchHitsToProto(rows []*moerpc.MoeSearchPostHit) []*postv1.MoeSearchPostHit {
	out := make([]*postv1.MoeSearchPostHit, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &postv1.MoeSearchPostHit{
			PostId: row.GetPostId(), UserId: row.GetUserId(), UserName: row.GetUserName(),
			Content: row.GetContent(), Snippet: row.GetSnippet(), MoodTag: row.GetMoodTag(),
			Likes: row.GetLikes(), Comments: row.GetComments(), CreatedAt: row.GetCreatedAt(),
			Score: row.GetScore(), ScoreReason: row.GetScoreReason(),
		})
	}
	return out
}
