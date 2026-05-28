package moehttp

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	commentapp "backend/internal/service/comment"
	postapp "backend/internal/service/post"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativePostCompatRoutes 帖子域 Kratos HTTP（internal/service/post + comment）。
const PilotNativePostCompatRoutes = 9

// RegisterPostCompat 帖子 HTTP → internal/service。
func RegisterPostCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.PostApp == nil {
		return
	}
	post := svcCtx.PostApp
	comment := svcCtx.CommentApp
	r := srv.Route("/")
	r.GET("/api/posts", getPosts(post))
	r.POST("/api/posts", createPost(post))
	r.GET("/api/posts/:post_id", getPost(post))
	r.PUT("/api/posts/:post_id", updatePost(post))
	r.DELETE("/api/posts/:post_id", deletePost(post))
	r.GET("/api/posts/:post_id/comments", getPostComments(comment))
	r.POST("/api/posts/:post_id/like", likePost(post))
	r.POST("/api/posts/:post_id/report", reportPost(post))
	r.GET("/api/posts/search", searchPosts(post))
}

func getPosts(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetPostsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPosts(ctx, &moe.GetPostsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), ViewerUserId: req.ViewerUserId,
			FeedMode: req.FeedMode, TopicTagId: req.TopicTagId, AuthorUserId: req.AuthorUserId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetPostsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetPostsResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子列表成功"),
			Data:     postsFromRPC(rpcResp.GetPosts()),
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func createPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreatePostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreatePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreatePost(ctx, &moe.CreatePostReq{
			UserId: req.UserId, Content: req.Content, Images: req.Images,
			TopicTags: topicTagsToRPC(req.TopicTags), HandDrawCard: req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl, MoodTag: req.MoodTag, GroupId: req.GroupId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CreatePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.CreatePostResp{
			BaseResp:        common.HandleRPCError(nil, "创建帖子成功"),
			NewAchievements: achievementUnlocksFromRPC(rpcResp.GetNewAchievements()),
			Data:            postFromRPC(rpcResp.GetPost()),
		})
	}
}

func getPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetPostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPost(ctx, &moe.GetPostReq{PostId: req.PostId, ViewerUserId: req.ViewerUserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetPostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetPostResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子成功"),
			Data:     postFromRPC(rpcResp.GetPost()),
		})
	}
}

func updatePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdatePostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdatePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdatePost(ctx, &moe.UpdatePostReq{
			PostId: req.PostId, UserId: req.UserId, Content: req.Content, Images: req.Images,
			TopicTags: topicTagsToRPC(req.TopicTags), HandDrawCard: req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdatePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdatePostResp{
			BaseResp: common.HandleRPCError(nil, "更新帖子成功"),
			Data:     postFromRPC(rpcResp.GetPost()),
		})
	}
}

func deletePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeletePostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.DeletePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.DeletePost(ctx, &moe.DeletePostReq{PostId: req.PostId, UserId: req.UserId})
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
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetPostCommentsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetPostComments(ctx, &moe.GetPostCommentsReq{
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
			Data:     commentsFromRPC(rpcResp.GetComments()),
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func likePost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LikePostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.LikePostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.LikePost(ctx, &moe.LikePostReq{PostId: req.PostId, UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.LikePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.LikePostResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data:     postFromRPC(rpcResp.GetPost()),
		})
	}
}

func reportPost(app *postapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ReportPostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ReportPostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.ReportPost(ctx, &moe.ReportPostReq{
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
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SearchPostsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.MoeSearchPosts(ctx, &moe.MoeSearchPostsReq{
			Query: req.Q, Limit: searchPostsLimit(req.PageSize),
			ViewerUserId: parseUint32ID(req.ViewerUserId), MoodTag: req.MoodTag,
			TopicTagId: parseUint32ID(req.TopicTagId),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SearchPostsResp{BaseResp: common.HandleRPCError(err, "检索失败")})
		}
		return ctx.JSON(http.StatusOK, types.SearchPostsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     moebridge.SearchPostsFromRPC(rpcResp),
		})
	}
}
