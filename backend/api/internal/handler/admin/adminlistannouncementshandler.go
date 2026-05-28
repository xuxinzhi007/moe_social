package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListAnnouncementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListAnnouncementsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListAnnouncementsReq) (*types.AdminListAnnouncementsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAnnouncements(ctx, &moe.AdminListAnnouncementsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Keyword:  req.Keyword,
			Status:   req.Status,
			})
			if err != nil {
			return &types.AdminListAnnouncementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminAnnouncementItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminAnnouncementToTypes(item)
			}
			return &types.AdminListAnnouncementsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAnnouncementsData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
