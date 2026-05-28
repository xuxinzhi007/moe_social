package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func DeleteUserMemoryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.DeleteUserMemoryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.LLMGW.DeleteUserMemory(r.Context(), &moe.DeleteUserMemoryReq{
			UserId: req.UserId,
			Key:    req.Key,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.DeleteUserMemoryResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.DeleteUserMemoryResp{
			BaseResp: common.HandleRPCError(nil, "删除用户记忆成功"),
		})
	}
}
