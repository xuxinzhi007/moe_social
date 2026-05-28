package chat

import (
	"net/http"

	"backend/api/internal/presence"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ChatOnlineHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ChatOnlineReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		online := presence.DefaultState.IsOnline(req.UserId)
		httpx.OkJsonCtx(r.Context(), w, &types.ChatOnlineResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "success",
				Success: true,
			},
			Online: online,
		})
	}
}
