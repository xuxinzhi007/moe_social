package postapp

import (
	"context"

	"backend/internal/platform/moelog"
	"backend/internal/platform/socialhook"
	"backend/pkg/achievement"
	postv1 "backend/api/post/v1"
	postbiz "backend/internal/biz/post"
	checkinbiz "backend/internal/biz/checkin"
)

func (s *AppService) CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	tagInputs := make([]postbiz.TopicTagInput, 0, len(in.GetTopicTags()))
	for _, tag := range in.GetTopicTags() {
		if tag == nil {
			continue
		}
		tagInputs = append(tagInputs, postbiz.TopicTagInput{Name: tag.GetName(), Color: tag.GetColor()})
	}
	result, err := postbiz.Create(ctx, s.store, postbiz.CreateInput{
		UserID: in.GetUserId(), Content: in.GetContent(), Images: in.GetImages(),
		TopicTagNames: tagInputs, HandDrawCard: in.GetHandDrawCard(),
		HandDrawThumbURL: in.GetHandDrawThumbUrl(), MoodTag: in.GetMoodTag(), GroupID: in.GetGroupId(),
		HandDrawRequireModeration: s.handDrawRequireModeration,
	})
	if err != nil {
		return nil, err
	}

	if thumb, err := postbiz.EnsureHandDrawThumb(ctx, s.imageCfg, result.User, result.Post.HandDrawCard, result.Post.HandDrawThumbURL); err != nil {
		moelog.Warnf("ensure hand draw thumb failed post_id=%v err=%v", result.Post.ID, err)
	} else if thumb != "" && thumb != result.Post.HandDrawThumbURL {
		result.Post.HandDrawThumbURL = thumb
		if err := s.store.WithContext(ctx).SavePost(ctx, &result.Post); err != nil {
			moelog.Warnf("save hand draw thumb failed post_id=%v err=%v", result.Post.ID, err)
		}
	}

	achUnlocks := socialhook.ApplyPostCreatedAchievements(s.store.Raw(), socialhook.PostCreatedMeta{
		UserID: result.Post.UserID, ImageCount: result.ImageCount,
		TopicTagCount: result.TopicTagCount, ContentRuneLen: result.ContentRuneLen,
		MoodTag: result.Post.MoodTag, HasHandDraw: result.Post.HandDrawCard != "",
		HandDrawApproved: result.HandDrawApproved,
	})
	if _, err := checkinbiz.GrantDailyExpOnce(ctx, s.checkinStore, in.GetUserId(), checkinbiz.DailyExpActionPost); err != nil {
		moelog.Warnf("grant daily exp for post failed user_id=%s err=%v", in.GetUserId(), err)
	}

	post := postbiz.BuildPostV1ForDetail(result.Post, result.User, false)
	post.Images = result.Images
	post.TopicTags = postbiz.TopicTagsToPostV1(result.TopicTags)
	return &postv1.CreatePostReply{
		Post:            post,
		NewAchievements: achievement.UnlocksToPostV1(achUnlocks),
	}, nil
}

func (s *AppService) DeletePost(ctx context.Context, in *postv1.DeletePostRequest) (*postv1.DeletePostReply, error) {
	if err := postbiz.Delete(ctx, s.store, in.GetPostId(), in.GetUserId()); err != nil {
		return nil, err
	}
	return &postv1.DeletePostReply{}, nil
}

func (s *AppService) UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error) {
	tagInputs := make([]postbiz.TopicTagInput, 0, len(in.GetTopicTags()))
	for _, tag := range in.GetTopicTags() {
		if tag == nil {
			continue
		}
		tagInputs = append(tagInputs, postbiz.TopicTagInput{Name: tag.GetName(), Color: tag.GetColor()})
	}
	result, err := postbiz.Update(ctx, s.store, postbiz.UpdateInput{
		PostID: in.GetPostId(), UserID: in.GetUserId(), Content: in.GetContent(),
		Images: in.GetImages(), TopicTags: tagInputs,
		HandDrawCard: in.GetHandDrawCard(), HandDrawThumbURL: in.GetHandDrawThumbUrl(),
		UpdateImages: in.GetImages() != nil, UpdateTopicTags: in.GetTopicTags() != nil,
	})
	if err != nil {
		return nil, err
	}
	if thumb, err := postbiz.EnsureHandDrawThumb(ctx, s.imageCfg, result.User, result.Post.HandDrawCard, result.Post.HandDrawThumbURL); err == nil && thumb != "" && thumb != result.Post.HandDrawThumbURL {
		result.Post.HandDrawThumbURL = thumb
		_ = s.store.WithContext(ctx).SavePost(ctx, &result.Post)
	}
	return &postv1.UpdatePostReply{
		Post: postbiz.BuildPostV1ForDetail(result.Post, result.User, result.IsLiked),
	}, nil
}
