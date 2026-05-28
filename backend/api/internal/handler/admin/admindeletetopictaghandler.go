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

func AdminDeleteTopicTagHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminDeleteTopicTagReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteTopicTagReq) (*types.AdminDeleteTopicTagResp, error) {
			tagID, err := handlerutil.ParseAdminPathID(req.TagId)
			if err != nil {
			return &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")}, nil
			}
			_, err = svcCtx.AdminGW.AdminDeleteTopicTag(r.Context(), &moe.AdminDeleteTopicTagReq{TagId: tagID})
			if err != nil {
			return &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "delete", "topic_tag", req.TagId, "删除话题标签")
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
