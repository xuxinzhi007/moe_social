package moehttp

import (
	"net/http"

	commentlogic "backend/api/internal/logic/comment"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeCommentCompatRoutes 评论写操作 Kratos HTTP。
const PilotNativeCommentCompatRoutes = 2

// RegisterCommentCompat POST /api/comments、点赞评论。
func RegisterCommentCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/comments", createComment(svcCtx))
	r.POST("/api/comments/:comment_id/like", likeComment(svcCtx))
}

func createComment(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateCommentReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateCommentResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		l := commentlogic.NewCreateCommentLogic(ctx, svcCtx)
		resp, err := l.CreateComment(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func likeComment(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LikeCommentReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.LikeCommentResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		l := commentlogic.NewLikeCommentLogic(ctx, svcCtx)
		resp, err := l.LikeComment(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}
