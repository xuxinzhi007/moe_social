package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpsertUserMemoryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpsertUserMemoryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.LLMGW.UpsertUserMemory(r.Context(), &moe.UpsertUserMemoryReq{
			UserId:      req.UserId,
			Key:         req.Key,
			Value:       req.Value,
			MemoryType:  req.MemoryType,
			Confidence:  req.Confidence,
			Source:      req.Source,
			SourceMsgId: req.SourceMsgId,
			SessionId:   req.SessionId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UpsertUserMemoryResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		m := rpcResp.Memory
		httpx.OkJsonCtx(r.Context(), w, &types.UpsertUserMemoryResp{
			BaseResp: common.HandleRPCError(nil, "更新用户记忆成功"),
			Data: types.UserMemory{
				Id:          m.Id,
				UserId:      m.UserId,
				Key:         m.Key,
				Value:       m.Value,
				MemoryType:  m.MemoryType,
				Confidence:  m.Confidence,
				Source:      m.Source,
				SourceMsgId: m.SourceMsgId,
				SessionId:   m.SessionId,
				CreatedAt:   m.CreatedAt,
				UpdatedAt:   m.UpdatedAt,
			},
		})
	}
}
