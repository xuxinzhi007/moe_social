//go:build hybrid

package chat

import (
	"net/http"
	"strings"

	"backend/api/internal/presence"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ChatOnlineBatchHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ChatOnlineBatchReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		ids := make([]string, 0)
		if req.UserIds != "" {
			for _, part := range strings.Split(req.UserIds, ",") {
				id := strings.TrimSpace(part)
				if id == "" {
					continue
				}
				ids = append(ids, id)
			}
		}

		online := make(map[string]bool, len(ids))
		for _, id := range ids {
			if id == "" {
				continue
			}
			online[id] = presence.DefaultState.IsOnline(id)
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ChatOnlineBatchResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "success",
				Success: true,
			},
			Online: online,
		})
	}
}
