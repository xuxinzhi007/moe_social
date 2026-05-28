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

func GetPostCommentsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetPostCommentsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommentGW.GetPostComments(r.Context(), &moe.GetPostCommentsReq{
			PostId:       req.PostId,
			Page:         int32(req.Page),
			PageSize:     int32(req.PageSize),
			ViewerUserId: req.ViewerUserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetPostCommentsResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetPostCommentsResp{
			BaseResp: common.HandleRPCError(nil, "获取评论列表成功"),
			Data:     handlerutil.CommentsFromRPC(rpcResp.Comments),
			Total:    int(rpcResp.Total),
		})
	}
}
