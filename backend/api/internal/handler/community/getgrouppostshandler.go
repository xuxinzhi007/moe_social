package community

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetGroupPostsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGroupPostsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.GetGroupPosts(r.Context(), &moe.GetGroupPostsReq{
			GroupId:  req.GroupId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			UserId:   req.UserId,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetGroupPostsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Data:     handlerutil.GroupPostsFromRPC(rpcResp.Posts),
			Total:    int(rpcResp.Total),
		})
	}
}
