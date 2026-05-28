//go:build hybrid

package community

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.GetGroup(r.Context(), &moe.GetGroupReq{
			GroupId: req.GroupId,
			UserId:  req.UserId,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if !rpcResp.Success {
			httpx.OkJsonCtx(r.Context(), w, &types.GetGroupResp{
				BaseResp: types.BaseResp{
					Code:    1,
					Message: rpcResp.Message,
					Success: false,
				},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetGroupResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: rpcResp.Message,
				Success: true,
			},
			Data: handlerutil.GroupFromRPC(rpcResp.Group),
		})
	}
}
