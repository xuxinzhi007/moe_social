package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListTopicTagsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminListTopicTagsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListTopicTagsReq) (*types.AdminListTopicTagsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListTopicTags(r.Context(), &moe.AdminListTopicTagsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListTopicTagsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.TopicTag, 0, len(rpcResp.GetItems()))
			for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcTopicTagToTypes(row))
			}
			return &types.AdminListTopicTagsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListTopicTagsData{
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
