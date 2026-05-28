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

func AdminListCommentsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListCommentsResp{BaseResp: *br})
			return
		}
		var req types.AdminListCommentsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListCommentsReq) (resp *types.AdminListCommentsResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rpcResp, err := svcCtx.AdminGW.AdminListComments(r.Context(), &moe.AdminListCommentsReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			Keyword:  req.Keyword,
			PostId:   req.PostId,
			})
			if err != nil {
			return &types.AdminListCommentsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.Comment, 0, len(rpcResp.GetComments()))
			for _, c := range rpcResp.GetComments() {
			items = append(items, common.RpcCommentToTypes(c))
			}

			return &types.AdminListCommentsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListCommentsData{
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
