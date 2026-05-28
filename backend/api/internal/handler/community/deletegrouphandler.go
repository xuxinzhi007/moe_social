//go:build hybrid

package community

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func DeleteGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.DeleteGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.DeleteGroup(r.Context(), &moe.DeleteGroupReq{
			GroupId: req.GroupId,
			UserId:  req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{
				Code: 1, Message: err.Error(), Success: false,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{
			Code: 0, Message: rpcResp.Message, Success: rpcResp.Success,
		})
	}
}
