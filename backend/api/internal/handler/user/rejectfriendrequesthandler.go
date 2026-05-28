//go:build hybrid

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

func RejectFriendRequestHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FriendRequestActionReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		me, err := handlerutil.BearerUserID(r)
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.FriendRequestActionResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
			return
		}
		pathUID, err := handlerutil.ParsePathUint(req.UserId)
		if err != nil || pathUID != me {
			httpx.OkJsonCtx(r.Context(), w, &types.FriendRequestActionResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
			return
		}

		_, err = svcCtx.UserGW.RejectFriendRequest(r.Context(), &moe.RejectFriendRequestReq{
			ActorUserId: handlerutil.ActorString(me),
			RequestId:   req.RequestId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.FriendRequestActionResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.FriendRequestActionResp{
			BaseResp: common.HandleRPCError(nil, "已拒绝"),
			Data:     true,
		})
	}
}
