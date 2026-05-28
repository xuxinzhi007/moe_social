//go:build hybrid

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

func WechatAuthorizeURLHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.WechatAuthorizeURLReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.WechatAuthorizeURL(r.Context(), &moe.WechatAuthorizeURLReq{
			State: strings.TrimSpace(req.State),
			Flow:  strings.TrimSpace(req.Flow),
		})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.WechatAuthorizeURLResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.WechatAuthorizeURLResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data: types.WechatAuthorizeURLData{
				AuthorizeURL: rpcResp.GetAuthorizeUrl(),
			},
		})
	}
}
