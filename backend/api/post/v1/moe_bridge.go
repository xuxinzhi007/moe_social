package postv1

import "backend/rpc/pb/moe"

func TopicTagFromMoe(t *moe.TopicTag) *TopicTag {
	if t == nil {
		return nil
	}
	return &TopicTag{
		Id:        t.GetId(),
		Name:      t.GetName(),
		Color:     t.GetColor(),
		CreatedAt: t.GetCreatedAt(),
	}
}

func TopicTagToMoe(t *TopicTag) *moe.TopicTag {
	if t == nil {
		return nil
	}
	return &moe.TopicTag{
		Id:        t.GetId(),
		Name:      t.GetName(),
		Color:     t.GetColor(),
		CreatedAt: t.GetCreatedAt(),
	}
}

func TopicTagsFromMoe(items []*moe.TopicTag) []*TopicTag {
	if len(items) == 0 {
		return nil
	}
	out := make([]*TopicTag, 0, len(items))
	for _, t := range items {
		if t == nil {
			continue
		}
		out = append(out, TopicTagFromMoe(t))
	}
	return out
}

func TopicTagsToMoe(items []*TopicTag) []*moe.TopicTag {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.TopicTag, 0, len(items))
	for _, t := range items {
		out = append(out, TopicTagToMoe(t))
	}
	return out
}

func PostFromMoe(p *moe.Post) *Post {
	if p == nil {
		return nil
	}
	return &Post{
		Id:                p.GetId(),
		UserId:            p.GetUserId(),
		UserName:          p.GetUserName(),
		UserAvatar:        p.GetUserAvatar(),
		Content:           p.GetContent(),
		Images:            append([]string(nil), p.GetImages()...),
		TopicTags:         TopicTagsFromMoe(p.GetTopicTags()),
		Likes:             p.GetLikes(),
		Comments:          p.GetComments(),
		IsLiked:           p.GetIsLiked(),
		CreatedAt:         p.GetCreatedAt(),
		HandDrawCard:      p.GetHandDrawCard(),
		HandDrawThumbUrl:  p.GetHandDrawThumbUrl(),
		ModerationStatus:  p.GetModerationStatus(),
		AuthorIsBot:       p.GetAuthorIsBot(),
		AuthorBotAgentKey: p.GetAuthorBotAgentKey(),
	}
}

func PostToMoe(p *Post) *moe.Post {
	if p == nil {
		return nil
	}
	return &moe.Post{
		Id:                p.GetId(),
		UserId:            p.GetUserId(),
		UserName:          p.GetUserName(),
		UserAvatar:        p.GetUserAvatar(),
		Content:           p.GetContent(),
		Images:            append([]string(nil), p.GetImages()...),
		TopicTags:         TopicTagsToMoe(p.GetTopicTags()),
		Likes:             p.GetLikes(),
		Comments:          p.GetComments(),
		IsLiked:           p.GetIsLiked(),
		CreatedAt:         p.GetCreatedAt(),
		HandDrawCard:      p.GetHandDrawCard(),
		HandDrawThumbUrl:  p.GetHandDrawThumbUrl(),
		ModerationStatus:  p.GetModerationStatus(),
		AuthorIsBot:       p.GetAuthorIsBot(),
		AuthorBotAgentKey: p.GetAuthorBotAgentKey(),
	}
}

func PostsFromMoe(items []*moe.Post) []*Post {
	if len(items) == 0 {
		return nil
	}
	out := make([]*Post, 0, len(items))
	for _, p := range items {
		if p == nil {
			continue
		}
		out = append(out, PostFromMoe(p))
	}
	return out
}

func AchievementUnlockFromMoe(u *moe.AchievementUnlock) *AchievementUnlock {
	if u == nil {
		return nil
	}
	return &AchievementUnlock{
		BadgeId:    u.GetBadgeId(),
		Name:       u.GetName(),
		ExpGranted: u.GetExpGranted(),
		LevelUp:    u.GetLevelUp(),
		NewLevel:   u.GetNewLevel(),
	}
}

func AchievementUnlocksFromMoe(items []*moe.AchievementUnlock) []*AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, AchievementUnlockFromMoe(u))
	}
	return out
}

func AchievementUnlocksToMoe(items []*AchievementUnlock) []*moe.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &moe.AchievementUnlock{
			BadgeId:    u.GetBadgeId(),
			Name:       u.GetName(),
			ExpGranted: u.GetExpGranted(),
			LevelUp:    u.GetLevelUp(),
			NewLevel:   u.GetNewLevel(),
		})
	}
	return out
}

func MoeSearchPostHitFromMoe(h *moe.MoeSearchPostHit) *MoeSearchPostHit {
	if h == nil {
		return nil
	}
	return &MoeSearchPostHit{
		PostId:      h.GetPostId(),
		UserId:      h.GetUserId(),
		UserName:    h.GetUserName(),
		Content:     h.GetContent(),
		Snippet:     h.GetSnippet(),
		MoodTag:     h.GetMoodTag(),
		Likes:       h.GetLikes(),
		Comments:    h.GetComments(),
		CreatedAt:   h.GetCreatedAt(),
		Score:       h.GetScore(),
		ScoreReason: h.GetScoreReason(),
	}
}

func MoeSearchPostsRequestFromMoe(in *moe.MoeSearchPostsReq) *MoeSearchPostsRequest {
	if in == nil {
		return &MoeSearchPostsRequest{}
	}
	return &MoeSearchPostsRequest{
		Query:        in.GetQuery(),
		Limit:        in.GetLimit(),
		ViewerUserId: in.GetViewerUserId(),
		MoodTag:      in.GetMoodTag(),
		TopicTagId:   in.GetTopicTagId(),
	}
}

func MoeSearchPostsReplyFromMoe(in *moe.MoeSearchPostsResp) *MoeSearchPostsReply {
	if in == nil {
		return &MoeSearchPostsReply{}
	}
	items := make([]*MoeSearchPostHit, 0, len(in.GetItems()))
	for _, h := range in.GetItems() {
		items = append(items, MoeSearchPostHitFromMoe(h))
	}
	return &MoeSearchPostsReply{Items: items, Total: in.GetTotal()}
}

func MoeSearchPostsReplyToMoe(out *MoeSearchPostsReply) *moe.MoeSearchPostsResp {
	if out == nil {
		return &moe.MoeSearchPostsResp{}
	}
	items := make([]*moe.MoeSearchPostHit, 0, len(out.GetItems()))
	for _, h := range out.GetItems() {
		if h == nil {
			continue
		}
		items = append(items, &moe.MoeSearchPostHit{
			PostId: h.GetPostId(), UserId: h.GetUserId(), UserName: h.GetUserName(),
			Content: h.GetContent(), Snippet: h.GetSnippet(), MoodTag: h.GetMoodTag(),
			Likes: h.GetLikes(), Comments: h.GetComments(), CreatedAt: h.GetCreatedAt(),
			Score: h.GetScore(), ScoreReason: h.GetScoreReason(),
		})
	}
	return &moe.MoeSearchPostsResp{Items: items, Total: out.GetTotal()}
}

func GetPostRequestFromMoe(in *moe.GetPostReq) *GetPostRequest {
	if in == nil {
		return &GetPostRequest{}
	}
	return &GetPostRequest{PostId: in.GetPostId(), ViewerUserId: in.GetViewerUserId()}
}

func GetPostReplyToMoe(out *GetPostReply) *moe.GetPostResp {
	if out == nil {
		return &moe.GetPostResp{}
	}
	return &moe.GetPostResp{Post: PostToMoe(out.GetPost())}
}

func GetPostsRequestFromMoe(in *moe.GetPostsReq) *GetPostsRequest {
	if in == nil {
		return &GetPostsRequest{}
	}
	return &GetPostsRequest{
		Page:         in.GetPage(),
		PageSize:     in.GetPageSize(),
		ViewerUserId: in.GetViewerUserId(),
		FeedMode:     in.GetFeedMode(),
		TopicTagId:   in.GetTopicTagId(),
		AuthorUserId: in.GetAuthorUserId(),
	}
}

func GetPostsReplyToMoe(out *GetPostsReply) *moe.GetPostsResp {
	if out == nil {
		return &moe.GetPostsResp{}
	}
	posts := make([]*moe.Post, 0, len(out.GetPosts()))
	for _, p := range out.GetPosts() {
		posts = append(posts, PostToMoe(p))
	}
	return &moe.GetPostsResp{Posts: posts, Total: out.GetTotal()}
}

func CreatePostRequestFromMoe(in *moe.CreatePostReq) *CreatePostRequest {
	if in == nil {
		return &CreatePostRequest{}
	}
	return &CreatePostRequest{
		UserId:           in.GetUserId(),
		Content:          in.GetContent(),
		Images:           append([]string(nil), in.GetImages()...),
		TopicTags:        TopicTagsFromMoe(in.GetTopicTags()),
		HandDrawCard:     in.GetHandDrawCard(),
		HandDrawThumbUrl: in.GetHandDrawThumbUrl(),
		MoodTag:          in.GetMoodTag(),
		GroupId:          in.GetGroupId(),
	}
}

func CreatePostReplyToMoe(out *CreatePostReply) *moe.CreatePostResp {
	if out == nil {
		return &moe.CreatePostResp{}
	}
	return &moe.CreatePostResp{
		Post:            PostToMoe(out.GetPost()),
		NewAchievements: AchievementUnlocksToMoe(out.GetNewAchievements()),
	}
}

func LikePostRequestFromMoe(in *moe.LikePostReq) *LikePostRequest {
	if in == nil {
		return &LikePostRequest{}
	}
	return &LikePostRequest{PostId: in.GetPostId(), UserId: in.GetUserId()}
}

func LikePostReplyToMoe(out *LikePostReply) *moe.LikePostResp {
	if out == nil {
		return &moe.LikePostResp{}
	}
	return &moe.LikePostResp{Post: PostToMoe(out.GetPost())}
}

func UpdatePostRequestFromMoe(in *moe.UpdatePostReq) *UpdatePostRequest {
	if in == nil {
		return &UpdatePostRequest{}
	}
	return &UpdatePostRequest{
		PostId:           in.GetPostId(),
		UserId:           in.GetUserId(),
		Content:          in.GetContent(),
		Images:           append([]string(nil), in.GetImages()...),
		TopicTags:        TopicTagsFromMoe(in.GetTopicTags()),
		HandDrawCard:     in.GetHandDrawCard(),
		HandDrawThumbUrl: in.GetHandDrawThumbUrl(),
	}
}

func UpdatePostReplyToMoe(out *UpdatePostReply) *moe.UpdatePostResp {
	if out == nil {
		return &moe.UpdatePostResp{}
	}
	return &moe.UpdatePostResp{Post: PostToMoe(out.GetPost())}
}

func DeletePostRequestFromMoe(in *moe.DeletePostReq) *DeletePostRequest {
	if in == nil {
		return &DeletePostRequest{}
	}
	return &DeletePostRequest{PostId: in.GetPostId(), UserId: in.GetUserId()}
}

func ReportPostRequestFromMoe(in *moe.ReportPostReq) *ReportPostRequest {
	if in == nil {
		return &ReportPostRequest{}
	}
	return &ReportPostRequest{
		PostId:         in.GetPostId(),
		ReporterUserId: in.GetReporterUserId(),
		Reason:         in.GetReason(),
	}
}
