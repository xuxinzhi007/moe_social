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

func AdminPublishAnnouncementHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminPublishAnnouncementReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminPublishAnnouncementReq) (*types.AdminPublishAnnouncementResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminPublishAnnouncement(ctx, &moe.AdminPublishAnnouncementReq{
			AnnouncementId: req.AnnouncementId,
			})
			if err != nil {
			return &types.AdminPublishAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminPublishAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "发布成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "publish", "announcement", req.AnnouncementId, "发布公告")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
