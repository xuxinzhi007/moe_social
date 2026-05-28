package postapp

import (
	"context"
	"strconv"

	postv1 "backend/api/post/v1"
	postbiz "backend/internal/biz/post"
	postdata "backend/internal/data/post"
	"backend/internal/platform/socialhook"
	"backend/model"
	"backend/rpc/pb/moe"

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
	resp, err := postbiz.Search(ctx, s.store, postbiz.SearchInput{
		Query: in.GetQuery(), Limit: in.GetLimit(),
		ViewerUserID: in.GetViewerUserId(), MoodTag: in.GetMoodTag(), TopicTagID: in.GetTopicTagId(),
	})
	if err != nil {
		return nil, err
	}
	return postv1.MoeSearchPostsReplyFromMoe(resp), nil
}

func (s *AppService) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	post, err := postbiz.GetByID(ctx, s.store, in.GetPostId(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostReply{Post: postv1.PostFromMoe(post)}, nil
}

func (s *AppService) GetPosts(ctx context.Context, in *postv1.GetPostsRequest) (*postv1.GetPostsReply, error) {
	posts, total, err := postbiz.List(ctx, s.store, postbiz.ListFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserID: in.GetViewerUserId(),
		FeedMode: in.GetFeedMode(), TopicTagID: in.GetTopicTagId(), AuthorUserID: in.GetAuthorUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &postv1.GetPostsReply{Posts: postv1.PostsFromMoe(posts), Total: total}, nil
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

	protoPost := postbiz.BuildProtoPost(result.Post, result.User, false)
	protoPost.Images = result.Images
	protoPost.TopicTags = topicTagsToMoe(result.TopicTags)
	return &postv1.CreatePostReply{
		Post:            postv1.PostFromMoe(protoPost),
		NewAchievements: postv1.AchievementUnlocksFromMoe(achUnlocks),
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
		Post: postv1.PostFromMoe(postbiz.BuildProtoPost(result.Post, result.User, result.IsLiked)),
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
		Post: postv1.PostFromMoe(postbiz.BuildProtoPost(result.Post, result.User, result.IsLiked)),
	}, nil
}

func (s *AppService) ReportPost(ctx context.Context, in *postv1.ReportPostRequest) (*postv1.ReportPostReply, error) {
	if err := postbiz.Report(ctx, s.store, in.GetPostId(), in.GetReporterUserId(), in.GetReason()); err != nil {
		return nil, err
	}
	return &postv1.ReportPostReply{}, nil
}

func topicTagsToMoe(tags []model.TopicTag) []*moe.TopicTag {
	out := make([]*moe.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &moe.TopicTag{
			Id: strconv.FormatUint(uint64(tag.ID), 10), Name: tag.Name, Color: tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
