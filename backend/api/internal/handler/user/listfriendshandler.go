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

func ListFriendsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FriendUserPathReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		me, err := handlerutil.BearerUserID(r)
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendsResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
			return
		}
		pathUID, err := handlerutil.ParsePathUint(req.UserId)
		if err != nil || pathUID != me {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendsResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
			return
		}

		rpcResp, err := svcCtx.UserGW.ListFriends(r.Context(), &moe.ListFriendsReq{
			ActorUserId: handlerutil.ActorString(me),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListFriendsResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		out := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			out = append(out, common.RpcUserToTypes(u))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ListFriendsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     out,
		})
	}
}
