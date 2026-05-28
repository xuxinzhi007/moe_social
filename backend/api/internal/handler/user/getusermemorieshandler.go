package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserMemoriesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserMemoriesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.LLMGW.GetUserMemories(r.Context(), &moe.GetUserMemoriesReq{
			UserId: req.UserId,
			Limit:  int32(req.Limit),
			Offset: int32(req.Offset),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserMemoriesResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		memories := make([]types.UserMemory, 0, len(rpcResp.Memories))
		for _, m := range rpcResp.Memories {
			memories = append(memories, types.UserMemory{
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
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserMemoriesResp{
			BaseResp: common.HandleRPCError(nil, "获取用户记忆成功"),
			Data:     memories,
			Total:    rpcResp.Total,
			Limit:    int(rpcResp.Limit),
			Offset:   int(rpcResp.Offset),
			HasMore:  rpcResp.HasMore,
		})
	}
}
