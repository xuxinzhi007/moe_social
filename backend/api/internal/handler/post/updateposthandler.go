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

func UpdatePostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdatePostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.PostGW.UpdatePost(r.Context(), &moe.UpdatePostReq{
			PostId:           req.PostId,
			UserId:           req.UserId,
			Content:          req.Content,
			Images:           req.Images,
			TopicTags:        handlerutil.TopicTagsToRPC(req.TopicTags),
			HandDrawCard:     req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UpdatePostResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UpdatePostResp{
			BaseResp: common.HandleRPCError(nil, "更新帖子成功"),
			Data:     handlerutil.PostFromRPC(rpcResp.Post),
		})
	}
}
