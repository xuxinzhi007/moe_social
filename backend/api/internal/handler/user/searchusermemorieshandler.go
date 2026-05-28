//go:build hybrid

package user

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// SearchUserMemoriesHandler 记忆文本库检索（编排层 / memory_search 工具共用）。
func SearchUserMemoriesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SearchUserMemoriesReq
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
		req.UserId = strconv.Itoa(int(userID))

		const listLimit = 200
		limit := req.Limit
		if limit <= 0 {
			limit = 8
		}

		memResp, err := svcCtx.LLMGW.GetUserMemories(r.Context(), &moe.GetUserMemoriesReq{
			UserId: req.UserId,
			Limit:  listLimit,
			Offset: 0,
		})
		if err != nil {
			base := common.HandleRPCError(err, "")
			httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
				"code": base.Code, "message": base.Message, "success": false,
			})
			return
		}

		result := handlerutil.HybridSearchUserFacingMemories(r.Context(), svcCtx, req.UserId, memResp.Memories, req.Q, limit)
		base := common.HandleRPCError(nil, "记忆检索成功")
		httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
			"code": base.Code, "message": base.Message, "success": base.Success, "data": result,
		})
	}
}
