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

func AdminGetAnnouncementHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetAnnouncementReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminGetAnnouncementReq) (*types.AdminGetAnnouncementResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetAnnouncement(ctx, &moe.AdminGetAnnouncementReq{
			AnnouncementId: req.AnnouncementId,
			})
			if err != nil {
			return &types.AdminGetAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminGetAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
