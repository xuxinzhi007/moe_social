package commentv1

import "backend/rpc/pb/moe"

func CommentFromMoe(c *moe.Comment) *Comment {
	if c == nil {
		return nil
	}
	return &Comment{
		Id:              c.GetId(),
		PostId:          c.GetPostId(),
		UserId:          c.GetUserId(),
		UserName:        c.GetUserName(),
		UserAvatar:      c.GetUserAvatar(),
		Content:         c.GetContent(),
		Likes:           c.GetLikes(),
		IsLiked:         c.GetIsLiked(),
		CreatedAt:       c.GetCreatedAt(),
		ParentId:        c.GetParentId(),
		ReplyToUserName: c.GetReplyToUserName(),
	}
}

func CommentToMoe(c *Comment) *moe.Comment {
	if c == nil {
		return nil
	}
	return &moe.Comment{
		Id:              c.GetId(),
		PostId:          c.GetPostId(),
		UserId:          c.GetUserId(),
		UserName:        c.GetUserName(),
		UserAvatar:      c.GetUserAvatar(),
		Content:         c.GetContent(),
		Likes:           c.GetLikes(),
		IsLiked:         c.GetIsLiked(),
		CreatedAt:       c.GetCreatedAt(),
		ParentId:        c.GetParentId(),
		ReplyToUserName: c.GetReplyToUserName(),
	}
}

func CommentsFromMoe(items []*moe.Comment) []*Comment {
	if len(items) == 0 {
		return nil
	}
	out := make([]*Comment, 0, len(items))
	for _, c := range items {
		if c == nil {
			continue
		}
		out = append(out, CommentFromMoe(c))
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

func GetPostCommentsRequestFromMoe(in *moe.GetPostCommentsReq) *GetPostCommentsRequest {
	if in == nil {
		return &GetPostCommentsRequest{}
	}
	return &GetPostCommentsRequest{
		PostId:       in.GetPostId(),
		Page:         in.GetPage(),
		PageSize:     in.GetPageSize(),
		ViewerUserId: in.GetViewerUserId(),
	}
}

func GetPostCommentsReplyToMoe(out *GetPostCommentsReply) *moe.GetPostCommentsResp {
	if out == nil {
		return &moe.GetPostCommentsResp{}
	}
	comments := make([]*moe.Comment, 0, len(out.GetComments()))
	for _, c := range out.GetComments() {
		comments = append(comments, CommentToMoe(c))
	}
	return &moe.GetPostCommentsResp{Comments: comments, Total: out.GetTotal()}
}

func CreateCommentRequestFromMoe(in *moe.CreateCommentReq) *CreateCommentRequest {
	if in == nil {
		return &CreateCommentRequest{}
	}
	return &CreateCommentRequest{
		PostId:   in.GetPostId(),
		UserId:   in.GetUserId(),
		Content:  in.GetContent(),
		ParentId: in.GetParentId(),
	}
}

func CreateCommentReplyToMoe(out *CreateCommentReply) *moe.CreateCommentResp {
	if out == nil {
		return &moe.CreateCommentResp{}
	}
	return &moe.CreateCommentResp{
		Comment:         CommentToMoe(out.GetComment()),
		NewAchievements: AchievementUnlocksToMoe(out.GetNewAchievements()),
	}
}

func LikeCommentRequestFromMoe(in *moe.LikeCommentReq) *LikeCommentRequest {
	if in == nil {
		return &LikeCommentRequest{}
	}
	return &LikeCommentRequest{
		CommentId: in.GetCommentId(),
		UserId:    in.GetUserId(),
	}
}

func LikeCommentReplyToMoe(out *LikeCommentReply) *moe.LikeCommentResp {
	if out == nil {
		return &moe.LikeCommentResp{}
	}
	return &moe.LikeCommentResp{Comment: CommentToMoe(out.GetComment())}
}
