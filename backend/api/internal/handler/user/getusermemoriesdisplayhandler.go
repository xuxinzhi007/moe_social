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

// GetUserMemoriesDisplayHandler 返回面向用户展示的清洁记忆数据（过滤技术项、隐藏调试字段）。
func GetUserMemoriesDisplayHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserMemoriesReq
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

		profResp, err := svcCtx.LLMGW.GetUserMemoryProfiles(r.Context(), &moe.GetUserMemoryProfilesReq{
			UserId: req.UserId,
			Limit:  12,
		})
		if err != nil {
			base := common.HandleRPCError(err, "")
			httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
				"code": base.Code, "message": base.Message, "success": false,
			})
			return
		}

		data := handlerutil.BuildUserMemoryDisplay(memResp.Memories, profResp.Profiles)
		base := common.HandleRPCError(nil, "获取记忆展示数据成功")
		httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
			"code": base.Code, "message": base.Message, "success": base.Success, "data": data,
		})
	}
}
