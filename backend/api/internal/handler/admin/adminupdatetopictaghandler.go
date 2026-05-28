//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateTopicTagHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminUpdateTopicTagReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateTopicTagReq) (*types.AdminUpdateTopicTagResp, error) {
			tagID, err := handlerutil.ParseAdminPathID(req.TagId)
			if err != nil {
			return &types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")}, nil
			}
			rpcResp, err := svcCtx.AdminGW.AdminUpdateTopicTag(r.Context(), &moe.AdminUpdateTopicTagReq{
			TagId: tagID,
			Name:  req.Name,
			Color: req.Color,
			})
			if err != nil {
			return &types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateTopicTagResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcTopicTagToTypes(rpcResp.GetItem()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "update", "topic_tag", req.TagId, "更新话题标签")
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
