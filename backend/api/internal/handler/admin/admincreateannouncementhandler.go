package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminCreateAnnouncementHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminCreateAnnouncementReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminCreateAnnouncementReq) (*types.AdminCreateAnnouncementResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminCreateAnnouncement(ctx, &moe.AdminCreateAnnouncementReq{
			Title:   req.Title,
			Content: req.Content,
			})
			if err != nil {
			return &types.AdminCreateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminCreateAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "announcement", resp.Data.Id, "创建公告")
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
