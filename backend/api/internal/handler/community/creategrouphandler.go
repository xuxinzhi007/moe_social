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

func CreateGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CreateGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.CreateGroup(r.Context(), &moe.CreateGroupReq{
			Name:        req.Name,
			Description: req.Description,
			Avatar:      req.Avatar,
			Cover:       req.Cover,
			UserId:      req.UserId,
			IsPublic:    req.IsPublic,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CreateGroupResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: rpcResp.Message,
				Success: rpcResp.Success,
			},
			Data: handlerutil.GroupFromRPC(rpcResp.Group),
		})
	}
}
