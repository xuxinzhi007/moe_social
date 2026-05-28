package moehttp

import (
	"net/http"

	commentv1 "backend/api/comment/v1"
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	commentapp "backend/internal/service/comment"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeCommentCompatRoutes 评论写操作 Kratos HTTP（internal/service/comment）。
const PilotNativeCommentCompatRoutes = 2

// RegisterCommentCompat POST /api/comments、点赞评论。
func RegisterCommentCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.CommentApp == nil {
		return
	}
	app := svcCtx.CommentApp
	r := srv.Route("/")
	r.POST("/api/comments", createComment(app))
	r.POST("/api/comments/:comment_id/like", likeComment(app))
}

func createComment(app *commentapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateCommentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateCommentResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreateComment(ctx, &commentv1.CreateCommentRequest{
			PostId: req.PostId, UserId: req.UserId, Content: req.Content, ParentId: req.ParentId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CreateCommentResp{BaseResp: common.HandleRPCError(err, "")})
		}
		c := rpcResp.GetComment()
		return ctx.JSON(http.StatusOK, types.CreateCommentResp{
			BaseResp:        common.HandleRPCError(nil, "创建评论成功"),
			NewAchievements: achievementUnlocksFromRPC(commentv1.AchievementUnlocksToMoe(rpcResp.GetNewAchievements())),
			Data: types.Comment{
				Id: c.GetId(), PostId: c.GetPostId(), UserId: c.GetUserId(),
				UserName: c.GetUserName(), UserAvatar: c.GetUserAvatar(), Content: c.GetContent(),
				Likes: int(c.GetLikes()), IsLiked: c.GetIsLiked(), CreatedAt: c.GetCreatedAt(),
				ParentId: c.GetParentId(), ReplyToUserName: c.GetReplyToUserName(),
			},
		})
	}
}

func likeComment(app *commentapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LikeCommentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.LikeCommentResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.LikeComment(ctx, &commentv1.LikeCommentRequest{
			CommentId: req.CommentId, UserId: req.UserId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.LikeCommentResp{BaseResp: common.HandleRPCError(err, "")})
		}
		c := rpcResp.GetComment()
		return ctx.JSON(http.StatusOK, types.LikeCommentResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data: types.Comment{
				Id: c.GetId(), PostId: c.GetPostId(), UserId: c.GetUserId(),
				UserName: c.GetUserName(), UserAvatar: c.GetUserAvatar(), Content: c.GetContent(),
				Likes: int(c.GetLikes()), IsLiked: c.GetIsLiked(), CreatedAt: c.GetCreatedAt(),
				ParentId: c.GetParentId(), ReplyToUserName: c.GetReplyToUserName(),
			},
		})
	}
}
