package post

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SearchPostsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SearchPostsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.PostGW.MoeSearchPosts(r.Context(), &moe.MoeSearchPostsReq{
			Query:        req.Q,
			Limit:        handlerutil.SearchPostsLimit(req.PageSize),
			ViewerUserId: handlerutil.ParseUint32ID(req.ViewerUserId),
			MoodTag:      req.MoodTag,
			TopicTagId:   handlerutil.ParseUint32ID(req.TopicTagId),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SearchPostsResp{
				BaseResp: common.HandleRPCError(err, "检索失败"),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.SearchPostsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     moebridge.SearchPostsFromRPC(rpcResp),
		})
	}
}
