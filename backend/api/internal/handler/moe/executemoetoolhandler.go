package moe

import (
	"errors"
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ExecuteMoeToolHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.MoeToolExecuteReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing or invalid authorization header"))
			return
		}
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		userID, err := utils.GetUserIDFromToken(tokenString)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.MoeGW.MoeExecuteTool(r.Context(), &moe.MoeExecuteToolReq{
			Tool:           req.Tool,
			ArgumentsJson:  req.Arguments,
			AgentKey:       req.AgentKey,
			ActorUserId:    uint64(userID),
			IdempotencyKey: req.IdempotencyKey,
			Source:         "api",
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.MoeToolExecuteResp{BaseResp: common.HandleRPCError(err, "")})
			return
		}
		httpx.OkJsonCtx(r.Context(), w, &types.MoeToolExecuteResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.MoeToolExecuteData{
				Ok:     rpcResp.Ok,
				Result: rpcResp.Result,
				Error:  rpcResp.Error,
			},
		})
	}
}
