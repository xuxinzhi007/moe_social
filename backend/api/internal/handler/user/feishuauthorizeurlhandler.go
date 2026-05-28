package user

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuAuthorizeURLHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FeishuAuthorizeURLReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.FeishuAuthorizeURL(r.Context(), &moe.FeishuAuthorizeURLReq{
			State: strings.TrimSpace(req.State),
		})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.FeishuAuthorizeURLResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.FeishuAuthorizeURLResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data: types.FeishuAuthorizeURLData{
				AuthorizeURL: rpcResp.GetAuthorizeUrl(),
			},
		})
	}
}
