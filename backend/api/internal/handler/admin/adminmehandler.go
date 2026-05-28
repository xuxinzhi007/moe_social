//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminMeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, br := common.RequireAdminToken(r)
		if br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminMeResp{BaseResp: *br})
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (resp *types.AdminMeResp, err error) {
			if claims == nil {
			return &types.AdminMeResp{
			BaseResp: types.BaseResp{
			Code:    401,
			Message: "请先登录管理后台",
			Success: false,
			},
			}, nil
			}
			return &types.AdminMeResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminMeData{
			AdminId:  uint64(claims.AdminID),
			Username: claims.Username,
			Role:     claims.Role,
			},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
