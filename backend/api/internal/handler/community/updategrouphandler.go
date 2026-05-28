//go:build hybrid

package community

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.UpdateGroup(r.Context(), &moe.UpdateGroupReq{
			GroupId:     req.GroupId,
			Name:        req.Name,
			Description: req.Description,
			Avatar:      req.Avatar,
			Cover:       req.Cover,
			IsPublic:    req.IsPublic,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UpdateGroupResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: rpcResp.Message,
				Success: rpcResp.Success,
			},
		})
	}
}
