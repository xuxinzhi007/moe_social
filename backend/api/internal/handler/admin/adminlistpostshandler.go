//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListPostsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListPostsResp{BaseResp: *br})
			return
		}
		var req types.AdminListPostsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListPostsReq) (resp *types.AdminListPostsResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 20
			}

			rpcResp, err := svcCtx.AdminGW.AdminListPosts(r.Context(), &moe.AdminListPostsReq{
			Page:             int32(page),
			PageSize:         int32(pageSize),
			Keyword:          req.Keyword,
			ModerationStatus: req.ModerationStatus,
			IncludeDeleted:   req.IncludeDeleted,
			})
			if err != nil {
			return &types.AdminListPostsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.Post, 0, len(rpcResp.GetPosts()))
			for _, p := range rpcResp.GetPosts() {
			items = append(items, common.RpcPostToTypes(p))
			}

			return &types.AdminListPostsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListPostsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
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
