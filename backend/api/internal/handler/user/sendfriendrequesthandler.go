//go:build hybrid

package user

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendFriendRequestHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendFriendRequestReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		me, err := handlerutil.BearerUserID(r)
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendFriendRequestResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
			return
		}
		pathUID, err := handlerutil.ParsePathUint(req.UserId)
		if err != nil || pathUID != me {
			httpx.OkJsonCtx(r.Context(), w, &types.SendFriendRequestResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
			return
		}

		rpcResp, err := svcCtx.UserGW.SendFriendRequest(r.Context(), &moe.SendFriendRequestReq{
			ActorUserId: handlerutil.ActorString(me),
			ToUserId:    strings.TrimSpace(req.ToUserId),
			ToMoeNo:     strings.TrimSpace(req.ToMoeNo),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendFriendRequestResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.SendFriendRequestResp{
			BaseResp: common.HandleRPCError(nil, "好友申请已发送"),
			Data:     handlerutil.FriendViewFromRPC(rpcResp.Data),
		})
	}
}
