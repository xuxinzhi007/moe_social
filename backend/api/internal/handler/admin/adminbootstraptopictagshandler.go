package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminBootstrapTopicTagsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (resp *types.AdminBootstrapTopicTagsResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminBootstrapTopicTags(r.Context(), &moe.AdminBootstrapTopicTagsReq{})
			if err != nil {
			return &types.AdminBootstrapTopicTagsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			msg := "话题表已有数据，未导入"
			if rpcResp.GetCreated() > 0 {
			msg = "已导入官方话题标签"
			}
			resp = &types.AdminBootstrapTopicTagsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapTopicTagsData{Created: int(rpcResp.GetCreated())},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(r.Context(), svcCtx, "bootstrap", "topic_tag", "", "导入官方话题标签")
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
