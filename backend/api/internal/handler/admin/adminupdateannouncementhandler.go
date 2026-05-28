//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminUpdateAnnouncementHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateAnnouncementReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateAnnouncementReq) (*types.AdminUpdateAnnouncementResp, error) {
			rpcReq := &moe.AdminUpdateAnnouncementReq{AnnouncementId: req.AnnouncementId}
			if title := strings.TrimSpace(req.Title); title != "" {
			rpcReq.Title = title
			rpcReq.UpdateTitle = true
			}
			if req.Content != "" {
			rpcReq.Content = req.Content
			rpcReq.UpdateContent = true
			}
			rpcResp, err := svcCtx.AdminGW.AdminUpdateAnnouncement(ctx, rpcReq)
			if err != nil {
			return &types.AdminUpdateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "announcement", req.AnnouncementId, "更新公告")
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
