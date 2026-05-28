package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ListOutgoingFriendRequestsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FriendUserPathReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		me, err := handlerutil.BearerUserID(r)
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendRequestsResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
			return
		}
		pathUID, err := handlerutil.ParsePathUint(req.UserId)
		if err != nil || pathUID != me {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendRequestsResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
			return
		}

		rpcResp, err := svcCtx.UserGW.ListOutgoingFriendRequests(r.Context(), &moe.ListOutgoingFriendRequestsReq{
			ActorUserId: handlerutil.ActorString(me),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendRequestsResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		out := make([]types.FriendRequestView, 0, len(rpcResp.Data))
		for _, v := range rpcResp.Data {
			out = append(out, handlerutil.FriendViewFromRPC(v))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ListFriendRequestsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     out,
		})
	}
}
