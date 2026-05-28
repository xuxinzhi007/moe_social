//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SubmitUserMemoryFeedbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SubmitUserMemoryFeedbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.LLMGW.SubmitUserMemoryFeedback(r.Context(), &moe.SubmitUserMemoryFeedbackReq{
			UserId:         req.UserId,
			Key:            req.Key,
			FeedbackType:   req.FeedbackType,
			CorrectedValue: req.CorrectedValue,
			Reason:         req.Reason,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SubmitUserMemoryFeedbackResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		m := rpcResp.Memory
		httpx.OkJsonCtx(r.Context(), w, &types.SubmitUserMemoryFeedbackResp{
			BaseResp: common.HandleRPCError(nil, "提交记忆反馈成功"),
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
