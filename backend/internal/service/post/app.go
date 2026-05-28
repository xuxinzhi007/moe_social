package postapp

import (
	"context"
	"strconv"

	postbiz "backend/internal/biz/post"
	"backend/internal/platform/socialhook"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AppService 帖子应用层。
type AppService struct {
	db                        *gorm.DB
	handDrawRequireModeration bool
}

// New 构造 AppService。
func New(db *gorm.DB, handDrawRequireModeration bool) *AppService {
	return &AppService{db: db, handDrawRequireModeration: handDrawRequireModeration}
}

func (s *AppService) MoeSearchPosts(ctx context.Context, in *moe.MoeSearchPostsReq) (*moe.MoeSearchPostsResp, error) {
	return postbiz.Search(ctx, s.db, postbiz.SearchInput{
		Query: in.GetQuery(), Limit: in.GetLimit(),
		ViewerUserID: in.GetViewerUserId(), MoodTag: in.GetMoodTag(), TopicTagID: in.GetTopicTagId(),
	})
}

func (s *AppService) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	post, err := postbiz.GetByID(ctx, s.db, in.GetPostId(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &moe.GetPostResp{Post: post}, nil
}

func (s *AppService) GetPosts(ctx context.Context, in *moe.GetPostsReq) (*moe.GetPostsResp, error) {
	posts, total, err := postbiz.List(ctx, s.db, postbiz.ListFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserID: in.GetViewerUserId(),
		FeedMode: in.GetFeedMode(), TopicTagID: in.GetTopicTagId(), AuthorUserID: in.GetAuthorUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.GetPostsResp{Posts: posts, Total: total}, nil
}

func (s *AppService) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	tagInputs := make([]postbiz.TopicTagInput, 0, len(in.GetTopicTags()))
	for _, tag := range in.GetTopicTags() {
		if tag == nil {
			continue
		}
		tagInputs = append(tagInputs, postbiz.TopicTagInput{Name: tag.GetName(), Color: tag.GetColor()})
	}
	result, err := postbiz.Create(ctx, s.db, postbiz.CreateInput{
		UserID: in.GetUserId(), Content: in.GetContent(), Images: in.GetImages(),
		TopicTagNames: tagInputs, HandDrawCard: in.GetHandDrawCard(),
		HandDrawThumbURL: in.GetHandDrawThumbUrl(), MoodTag: in.GetMoodTag(), GroupID: in.GetGroupId(),
		HandDrawRequireModeration: s.handDrawRequireModeration,
	})
	if err != nil {
		return nil, err
	}

	achUnlocks := socialhook.ApplyPostCreatedAchievements(s.db, socialhook.PostCreatedMeta{
		UserID: result.Post.UserID, ImageCount: result.ImageCount,
		TopicTagCount: result.TopicTagCount, ContentRuneLen: result.ContentRuneLen,
		MoodTag: result.Post.MoodTag, HasHandDraw: result.Post.HandDrawCard != "",
		HandDrawApproved: result.HandDrawApproved,
	})

	protoTags := topicTagsToProto(result.TopicTags)
	rpcPost := postbiz.BuildProtoPost(result.Post, result.User, false)
	rpcPost.Images = result.Images
	rpcPost.TopicTags = protoTags
	return &moe.CreatePostResp{
		Post: rpcPost, NewAchievements: achUnlocks,
	}, nil
}

func (s *AppService) LikePost(ctx context.Context, in *moe.LikePostReq) (*moe.LikePostResp, error) {
	result, err := postbiz.Like(ctx, s.db, in.GetPostId(), in.GetUserId())
	if err != nil {
		return nil, err
	}
	if result.DidLike {
		socialhook.ApplyPostLikedAchievements(s.db, socialhook.PostLikedMeta{
			PostAuthorUserID: result.Post.UserID,
			PostLikeCount:    result.LikeCount,
		})
	}
	rpcPost := postbiz.BuildProtoPost(result.Post, result.User, result.IsLiked)
	return &moe.LikePostResp{Post: rpcPost}, nil
}

func (s *AppService) DeletePost(ctx context.Context, in *moe.DeletePostReq) (*moe.DeletePostResp, error) {
	if err := postbiz.Delete(ctx, s.db, in.GetPostId(), in.GetUserId()); err != nil {
		return nil, err
	}
	return &moe.DeletePostResp{}, nil
}

func (s *AppService) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	tagInputs := make([]postbiz.TopicTagInput, 0, len(in.GetTopicTags()))
	for _, tag := range in.GetTopicTags() {
		if tag == nil {
			continue
		}
		tagInputs = append(tagInputs, postbiz.TopicTagInput{Name: tag.GetName(), Color: tag.GetColor()})
	}
	result, err := postbiz.Update(ctx, s.db, postbiz.UpdateInput{
		PostID: in.GetPostId(), UserID: in.GetUserId(), Content: in.GetContent(),
		Images: in.GetImages(), TopicTags: tagInputs,
		HandDrawCard: in.GetHandDrawCard(), HandDrawThumbURL: in.GetHandDrawThumbUrl(),
		UpdateImages: in.GetImages() != nil, UpdateTopicTags: in.GetTopicTags() != nil,
	})
	if err != nil {
		return nil, err
	}
	return &moe.UpdatePostResp{
		Post: postbiz.BuildProtoPost(result.Post, result.User, result.IsLiked),
	}, nil
}

func (s *AppService) ReportPost(ctx context.Context, in *moe.ReportPostReq) (*moe.ReportPostResp, error) {
	if err := postbiz.Report(ctx, s.db, in.GetPostId(), in.GetReporterUserId(), in.GetReason()); err != nil {
		return nil, err
	}
	return &moe.ReportPostResp{}, nil
}

func topicTagsToProto(tags []model.TopicTag) []*moe.TopicTag {
	out := make([]*moe.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &moe.TopicTag{
			Id: strconv.FormatUint(uint64(tag.ID), 10), Name: tag.Name, Color: tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
