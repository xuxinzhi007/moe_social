//go:build hybrid

package community

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetGroupMembersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGroupMembersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommunityGW.GetGroupMembers(r.Context(), &moe.GetGroupMembersReq{
			GroupId:  req.GroupId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetGroupMembersResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Data:     handlerutil.GroupMembersFromRPC(rpcResp.Members),
			Total:    int(rpcResp.Total),
		})
	}
}
