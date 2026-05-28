package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListPostReportsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListPostReportsResp{BaseResp: *br})
			return
		}
		var req types.AdminListPostReportsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListPostReportsReq) (resp *types.AdminListPostReportsResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rpcResp, err := svcCtx.AdminGW.AdminListPostReports(r.Context(), &moe.AdminListPostReportsReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			})
			if err != nil {
			return &types.AdminListPostReportsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			items := make([]types.AdminPostReportItem, 0, len(rpcResp.GetReports()))
			for _, r := range rpcResp.GetReports() {
			items = append(items, types.AdminPostReportItem{
			Id:                 r.GetId(),
			PostId:             r.GetPostId(),
			ReporterUserId:     r.GetReporterUserId(),
			Reason:             r.GetReason(),
			CreatedAt:          r.GetCreatedAt(),
			PostContentPreview: r.GetPostContentPreview(),
			})
			}

			return &types.AdminListPostReportsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListPostReportsData{
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
