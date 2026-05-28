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

func AdminCreateTopicTagHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminCreateTopicTagReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminCreateTopicTagReq) (*types.AdminCreateTopicTagResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminCreateTopicTag(r.Context(), &moe.AdminCreateTopicTagReq{
			Name:  req.Name,
			Color: req.Color,
			})
			if err != nil {
			return &types.AdminCreateTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminCreateTopicTagResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcTopicTagToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "create", "topic_tag", resp.Data.Id, "创建话题标签")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
