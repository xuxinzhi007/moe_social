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

func GetPostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetPostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.PostGW.GetPost(r.Context(), &moe.GetPostReq{
			PostId:       req.PostId,
			ViewerUserId: req.ViewerUserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetPostResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetPostResp{
			BaseResp: common.HandleRPCError(nil, "获取帖子成功"),
			Data:     handlerutil.PostFromRPC(rpcResp.Post),
		})
	}
}
