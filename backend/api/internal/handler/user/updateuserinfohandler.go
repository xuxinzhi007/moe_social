package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateUserInfoHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateUserInfoReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.UpdateUserInfo(r.Context(), &moe.UpdateUserInfoReq{
			UserId:             req.UserId,
			Username:           req.Username,
			Email:              req.Email,
			Avatar:             req.Avatar,
			Signature:          req.Signature,
			Gender:             req.Gender,
			Birthday:           req.Birthday,
			Inventory:          req.Inventory,
			EquippedFrameId:    req.EquippedFrameId,
			ClearEquippedFrame: req.ClearEquippedFrame,
			MessageRetention:   req.MessageRetention,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserInfoResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserInfoResp{
			BaseResp: common.HandleRPCError(nil, "更新用户信息成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
