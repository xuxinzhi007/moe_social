package post

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetPostsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetPostsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.PostGW.GetPosts(r.Context(), &moe.GetPostsReq{
			Page:         int32(req.Page),
			PageSize:     int32(req.PageSize),
			ViewerUserId: req.ViewerUserId,
			FeedMode:     req.FeedMode,
			TopicTagId:   req.TopicTagId,
			AuthorUserId: req.AuthorUserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetPostsResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetPostsResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子列表成功"),
			Data:     handlerutil.PostsFromRPC(rpcResp.Posts),
			Total:    int(rpcResp.Total),
		})
	}
}
