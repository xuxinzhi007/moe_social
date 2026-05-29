package httplegacy

import (
	"net/http"

	commentv1 "backend/api/comment/v1"
	postv1 "backend/api/post/v1"
	"backend/internal/apilegacy/common"
	"backend/internal/apilegacy/moebridge"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	commentapp "backend/internal/service/comment"
	postapp "backend/internal/service/post"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativePostCompatRoutes 帖子域 Kratos HTTP（internal/service/post + comment）。
const PilotNativePostCompatRoutes = 0

// RegisterPostCompat D2：已迁入 RegisterPostServiceHTTPServer + RegisterCommentServiceHTTPServer。
func RegisterPostCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	_ = srv
	_ = svcCtx
}

func getPosts(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetPostsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPosts(ctx, &postv1.GetPostsRequest{
			Page: int32(req.Page), PageSize: int32(req.PageSize), ViewerUserId: req.ViewerUserId,
			FeedMode: req.FeedMode, TopicTagId: req.TopicTagId, AuthorUserId: req.AuthorUserId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetPostsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetPostsResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子列表成功"),
			Data:     postsFromProto(rpcResp.GetPosts()),
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func createPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreatePostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreatePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreatePost(ctx, &postv1.CreatePostRequest{
			UserId: req.UserId, Content: req.Content, Images: req.Images,
			TopicTags: topicTagsToProto(req.TopicTags), HandDrawCard: req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl, MoodTag: req.MoodTag, GroupId: req.GroupId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CreatePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.CreatePostResp{
			BaseResp:        common.HandleRPCError(nil, "创建帖子成功"),
			NewAchievements: achievementUnlocksFromRPC(postv1.AchievementUnlocksToMoe(rpcResp.GetNewAchievements())),
			Data:            postFromProto(rpcResp.GetPost()),
		})
	}
}

func getPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetPostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPost(ctx, &postv1.GetPostRequest{PostId: req.PostId, ViewerUserId: req.ViewerUserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetPostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetPostResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子成功"),
			Data:     postFromProto(rpcResp.GetPost()),
		})
	}
}

func updatePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdatePostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdatePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdatePost(ctx, &postv1.UpdatePostRequest{
			PostId: req.PostId, UserId: req.UserId, Content: req.Content, Images: req.Images,
			TopicTags: topicTagsToProto(req.TopicTags), HandDrawCard: req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdatePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdatePostResp{
			BaseResp: common.HandleRPCError(nil, "更新帖子成功"),
			Data:     postFromProto(rpcResp.GetPost()),
		})
	}
}

func deletePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeletePostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.DeletePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.DeletePost(ctx, &postv1.DeletePostRequest{PostId: req.PostId, UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.DeletePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.DeletePostResp{BaseResp: common.HandleRPCError(nil, "删除成功")})
	}
}

func getPostComments(app *commentapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if app == nil {
			return ctx.JSON(http.StatusOK, types.GetPostCommentsResp{
				BaseResp: types.BaseResp{Code: -1, Message: "comment service unavailable", Success: false},
			})
		}
		var req types.GetPostCommentsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostCommentsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPostComments(ctx, &commentv1.GetPostCommentsRequest{
			PostId: req.PostId, Page: int32(req.Page), PageSize: int32(req.PageSize),
			ViewerUserId: req.ViewerUserId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetPostCommentsResp{
				BaseResp: common.HandleRPCError(err, ""), Data: nil, Total: 0,
			})
		}
		return ctx.JSON(http.StatusOK, types.GetPostCommentsResp{
			BaseResp: common.HandleRPCError(nil, "获取评论列表成功"),
			Data:     commentsFromProto(rpcResp.GetComments()),
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func likePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LikePostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.LikePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.LikePost(ctx, &postv1.LikePostRequest{PostId: req.PostId, UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.LikePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.LikePostResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data:     postFromProto(rpcResp.GetPost()),
		})
	}
}

func reportPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ReportPostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ReportPostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.ReportPost(ctx, &postv1.ReportPostRequest{
			PostId: req.PostId, ReporterUserId: req.ReporterUserId, Reason: req.Reason,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ReportPostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.ReportPostResp{
			BaseResp: common.HandleRPCError(nil, "举报已提交"),
		})
	}
}

func searchPosts(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SearchPostsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SearchPostsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.MoeSearchPosts(ctx, &postv1.MoeSearchPostsRequest{
			Query: req.Q, Limit: searchPostsLimit(req.PageSize),
			ViewerUserId: parseUint32ID(req.ViewerUserId), MoodTag: req.MoodTag,
			TopicTagId: parseUint32ID(req.TopicTagId),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SearchPostsResp{BaseResp: common.HandleRPCError(err, "检索失败")})
		}
		return ctx.JSON(http.StatusOK, types.SearchPostsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     moebridge.SearchPostsFromRPC(postv1.MoeSearchPostsReplyToMoe(rpcResp)),
		})
	}
}
