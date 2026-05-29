package postapp

import (
	"context"

	postv1 "backend/api/post/v1"
	postbiz "backend/internal/biz/post"
	postdata "backend/internal/data/post"
	"backend/internal/platform/socialhook"
	"backend/pkg/achievement"

	"gorm.io/gorm"
)

// AppService 帖子应用层。
type AppService struct {
	store                     postbiz.PostStore
	handDrawRequireModeration bool
}

// New 构造 AppService。
func New(db *gorm.DB, handDrawRequireModeration bool) *AppService {
	return &AppService{
		store:                     postdata.NewStore(db),
		handDrawRequireModeration: handDrawRequireModeration,
	}
}

func (s *AppService) MoeSearchPosts(ctx context.Context, in *postv1.MoeSearchPostsRequest) (*postv1.MoeSearchPostsReply, error) {
	return postbiz.Search(ctx, s.store, postbiz.SearchInput{
		Query: in.GetQuery(), Limit: in.GetLimit(),
		ViewerUserID: in.GetViewerUserId(), MoodTag: in.GetMoodTag(), TopicTagID: in.GetTopicTagId(),
	})
}

func (s *AppService) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	post, err := postbiz.GetByID(ctx, s.store, in.GetPostId(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostReply{Post: post}, nil
}

func (s *AppService) GetPosts(ctx context.Context, in *postv1.GetPostsRequest) (*postv1.GetPostsReply, error) {
	posts, total, err := postbiz.List(ctx, s.store, postbiz.ListFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserID: in.GetViewerUserId(),
		FeedMode: in.GetFeedMode(), TopicTagID: in.GetTopicTagId(), AuthorUserID: in.GetAuthorUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostsReply{Posts: posts, Total: total}, nil
}

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

	achUnlocks := socialhook.ApplyPostCreatedAchievements(s.store.Raw(), socialhook.PostCreatedMeta{
		UserID: result.Post.UserID, ImageCount: result.ImageCount,
		TopicTagCount: result.TopicTagCount, ContentRuneLen: result.ContentRuneLen,
		MoodTag: result.Post.MoodTag, HasHandDraw: result.Post.HandDrawCard != "",
		HandDrawApproved: result.HandDrawApproved,
	})

	post := postbiz.BuildPostV1(result.Post, result.User, false)
	post.Images = result.Images
	post.TopicTags = postbiz.TopicTagsToPostV1(result.TopicTags)
	return &postv1.CreatePostReply{
		Post:            post,
		NewAchievements: achievement.UnlocksToPostV1(achUnlocks),
	}, nil
}

func (s *AppService) LikePost(ctx context.Context, in *postv1.LikePostRequest) (*postv1.LikePostReply, error) {
	result, err := postbiz.Like(ctx, s.store, in.GetPostId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	if result.DidLike {
		socialhook.ApplyPostLikedAchievements(s.store.Raw(), socialhook.PostLikedMeta{
			PostAuthorUserID: result.Post.UserID,
			PostLikeCount:    result.LikeCount,
		})
	}
	return &postv1.LikePostReply{
		Post: postbiz.BuildPostV1(result.Post, result.User, result.IsLiked),
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
	return &postv1.UpdatePostReply{
		Post: postbiz.BuildPostV1(result.Post, result.User, result.IsLiked),
	}, nil
}

func (s *AppService) ReportPost(ctx context.Context, in *postv1.ReportPostRequest) (*postv1.ReportPostReply, error) {
	if err := postbiz.Report(ctx, s.store, in.GetPostId(), in.GetReporterUserId(), in.GetReason()); err != nil {
		return nil, err
	}
	return &postv1.ReportPostReply{}, nil
}
